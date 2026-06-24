#!/bin/bash
# Ensure only a single instance runs to avoid multiple wineserver processes
LOCKFILE="/tmp/npp_flatpak_instance.lock"
exec 200>"$LOCKFILE"
flock -n 200 || {
    # Another instance is already running; exit to prevent multiple instances
    exit 0
}

export WINEPREFIX="${WINEPREFIX:-/var/data/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"
export PATH="/app/bin:$PATH"

NPP_SOURCE_DIR="/app/share/notepadplusplus"
NPP_HOME_DIR="/var/data/notepad-plus-plus"
NPP_EXE="$NPP_HOME_DIR/notepad++.exe"

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

sync_npp_files() {
    local src="$NPP_SOURCE_DIR"
    local dst="$NPP_HOME_DIR"
    local xml_file

    [ -d "$src" ] || return 0

    mkdir -p "$dst"

    # Remove stale links from previous versions and refresh with new files.
    find "$dst" -type l -delete 2>/dev/null || true
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

# Avoid noisy Wine cwd warnings when launched from odd host paths.
cd "$HOME" 2>/dev/null || cd /var/data || true

# First run setup
if [ ! -f "$WINEPREFIX/system.reg" ]; then
    echo "First run: setting up Wine prefix..."

    if ! wineboot --init; then
        echo "Wine initialization failed. Ensure required Flatpak runtime extensions are installed." >&2
        exit 1
    fi

    wineserver --wait
    echo "Linking host fonts..."
    link_fonts
    wineserver --wait
    echo "Setup complete."
fi

sync_npp_files

# Pass all arguments to Notepad++. The -multiInst flag is omitted to allow opening files in an existing instance.
NPP_ARGS=()
for arg in "$@"; do
    case "$arg" in
        file://*)
            win_path=$(winepath -w "${arg#file://}" 2>/dev/null || true)
            if [ -n "$win_path" ]; then
                NPP_ARGS+=("$win_path")
                continue
            fi
            ;;
    esac

    if [[ "$arg" == -* ]]; then
        NPP_ARGS+=("$arg")
        continue
    fi

    if [ -e "$arg" ]; then
        win_path=$(winepath -w "$arg" 2>/dev/null || true)
        if [ -n "$win_path" ]; then
            NPP_ARGS+=("$win_path")
            continue
        fi
    fi

    NPP_ARGS+=("$arg")
done

# Pass all arguments to Notepad++. The -multiInst flag is omitted to allow opening files in an existing instance.
exec "$WINE" "$NPP_EXE" "${NPP_ARGS[@]}"