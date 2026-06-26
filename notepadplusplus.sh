#!/bin/bash
# Notepad++ uses a Win32 mutex (via wineserver) for single-instance.
# No external locking or process detection is needed — in fact, external
# locks can interfere with Wine's internal synchronization.
# Force the Wine prefix into the central .notepadpp directory.
export WINEPREFIX="$HOME/.notepadpp/.wine"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d;mscoree,mshtml=}"
export PATH="/app/bin:$PATH"

# DXVK settings borrowed from the AppImage wrapper to keep Wine/DirectX
# logging and caches quiet.
export DXVK_HUD="${DXVK_HUD:-0}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export DXVK_STATE_CACHE="${DXVK_STATE_CACHE:-0}"

NPP_SOURCE_DIR="/app/share/notepadplusplus"
NPP_HOME_DIR="$HOME/.notepadpp"
NPP_EXE="$NPP_HOME_DIR/notepad++.exe"

LOG_FILE="$NPP_HOME_DIR/launcher.log"
mkdir -p "$NPP_HOME_DIR"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "===== launcher invoked ====="
log "Arguments ($#): $*"
log "WINEPREFIX: $WINEPREFIX"

link_fonts() {
    local font_dir="$WINEPREFIX/drive_c/windows/Fonts"
    mkdir -p "$font_dir"
    if [ -d /run/host/fonts ]; then
        find /run/host/fonts -type f \( -iname "*.ttf" -o -iname "*.otf" -o -iname "*.ttc" \) -print0 2>/dev/null |
            while IFS= read -r -d '' font; do
                ln -sf "$font" "$font_dir/" 2>/dev/null || true
            done
    fi
}

apply_cjk_font_substitutes() {
    local reg_file="$NPP_HOME_DIR/.cjk_fonts.reg"
    local lang
    lang="${LANG:-${LC_ALL:-${LC_CTYPE:-}}}"

    case "$lang" in
        zh_CN*|zh_SG*)
            cat > "$reg_file" <<'EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"MS Shell Dlg"="Noto Sans CJK SC"
"Tms Rmn"="Noto Sans CJK SC"
EOF
            ;;
        zh_HK*|zh_MO*|zh_TW*)
            cat > "$reg_file" <<'EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\FontSubstitutes]
"MS Shell Dlg"="Noto Sans CJK TC"
"Tms Rmn"="Noto Sans CJK TC"
EOF
            ;;
        *)
            return 0
            ;;
    esac

    "$WINE" regedit "$reg_file" 2>/dev/null || true
}

sync_npp_files() {
    local src="$NPP_SOURCE_DIR"
    local dst="$NPP_HOME_DIR"
    local xml_file

    [ -d "$src" ] || return 0

    mkdir -p "$dst"

    # Only remove broken symlinks, then add/update links for new/existing files.
    find -L "$dst" -maxdepth 2 -type l -delete 2>/dev/null || true
    cp -urs "$src"/* "$dst"/ 2>/dev/null || true

    # Force-refresh updater XML and top-level XML config files.
    if [ -d "$src/updater" ] && [ -d "$dst/updater" ]; then
        rm -f "$dst/updater/gup.xml" 2>/dev/null || true
        cp -f "$src/updater/gup.xml" "$dst/updater/" 2>/dev/null || true
    fi

    for xml_file in "$src"/*.xml; do
        [ -e "$xml_file" ] || continue
        rm -f "$dst/$(basename "$xml_file")" 2>/dev/null || true
        cp -f "$xml_file" "$dst/" 2>/dev/null || true
    done
}

# Find wine64 first, fall back to wine
if command -v wine64 >/dev/null 2>&1; then
    WINE="$(command -v wine64)"
elif command -v wine >/dev/null 2>&1; then
    WINE="$(command -v wine)"
else
    echo "Wine binary not found in application runtime." >&2
    exit 1
fi
log "Wine: $WINE"

# Avoid noisy Wine cwd warnings when launched from odd host paths.
cd "$HOME" 2>/dev/null || true

# First run setup
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "First run: setting up Wine prefix..."

    mkdir -p "$WINEPREFIX"

    if ! wineboot --init; then
        echo "Wine initialization failed. Ensure required Flatpak runtime extensions are installed." >&2
        exit 1
    fi

    wineserver --wait
    echo "Linking host fonts..."
    link_fonts
    apply_cjk_font_substitutes
    wineserver --wait
    echo "Setup complete."
fi

# Version-based update check: avoid re-syncing files on every launch.
APP_VERSION_FILE="$NPP_SOURCE_DIR/.version"
NPP_VERSION_FILE="$NPP_HOME_DIR/.version"

if [ -f "$APP_VERSION_FILE" ] && [ -f "$NPP_VERSION_FILE" ]; then
    if [ "$(cat "$APP_VERSION_FILE")" != "$(cat "$NPP_VERSION_FILE")" ]; then
        sync_npp_files
        cp -f "$APP_VERSION_FILE" "$NPP_VERSION_FILE" 2>/dev/null || true
    fi
else
    sync_npp_files
    [ -f "$APP_VERSION_FILE" ] && cp -f "$APP_VERSION_FILE" "$NPP_VERSION_FILE" 2>/dev/null || true
fi

# Detect dark/light mode from Notepad++ config.xml and apply the matching
# Wine theme so non-client areas match the editor chrome.
NPP_CFG="$NPP_HOME_DIR/config.xml"
if [ -f "$NPP_CFG" ]; then
    dark_mode_line=$(grep -o '<GUIConfig name="DarkMode"[^/]*/>' "$NPP_CFG" 2>/dev/null || true)
    if [ -n "$dark_mode_line" ] && [[ "$dark_mode_line" == *'enable="yes"'* ]]; then
        "$WINE" regedit /app/share/notepadplusplus/dark-mode.reg 2>/dev/null || true
    else
        "$WINE" regedit /app/share/notepadplusplus/light-mode.reg 2>/dev/null || true
    fi
fi

# Allow launching Wine tools directly from the Flatpak command line, e.g.:
# flatpak run com.notepadplusplus.NotepadPlusPlus winecfg
case "$1" in
    winecfg|wineboot|regedit|cmd|taskmgr|winefile|winemine|control)
        "$WINE" "$1"
        exit $?
        ;;
esac

# Convert existing file arguments to Windows paths; pass everything else through.
NPP_ARGS=()
for arg in "$@"; do
    if [ -e "$arg" ]; then
        win_path=$(winepath -w "$arg" 2>/dev/null || true)
        if [ -n "$win_path" ]; then
            NPP_ARGS+=("$win_path")
            continue
        fi
    fi
    NPP_ARGS+=("$arg")
done

log "Launching: $WINE $NPP_EXE ${NPP_ARGS[*]}"

# Launch without exec so the shell stays as parent. After Notepad++ exits,
# return its exit code directly; wineserver has already shut down by then.
"$WINE" "$NPP_EXE" "${NPP_ARGS[@]}"
exit $?
