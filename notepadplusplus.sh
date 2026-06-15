#!/bin/bash
export WINEPREFIX=/var/data/wine
export WINEDEBUG=-all
export WINEARCH=win64
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
export WINE_MONO_OVERRIDES="Microsoft.Xna.Framework,Microsoft.Xna.Framework.*"
export PATH="/app/bin:$PATH"

# Point Wine to bundled Mono and Gecko
export WINE_MONO_DIR="/app/share/wine/mono"
export WINE_GECKO_DIR="/app/share/wine/gecko"

NPP_EXE="$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe"

set_wine_dpi() {
    local dpi="$1"
    "$WINE" reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
    "$WINE" reg add "HKCU\\Software\\Wine\\Fonts" /v LogPixels /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
}

normalize_dark_theme() {
    case "${WINE_DARK_THEME:-NO}" in
        YES|yes|Yes|TRUE|true|True|1|ON|on|On)
            echo "YES"
            ;;
        *)
            echo "NO"
            ;;
    esac
}

apply_wine_dpi() {
    local dpi="${NPP_WINE_DPI:-96}"

    if ! [ "$dpi" -eq "$dpi" ] 2>/dev/null; then
        dpi=96
    fi

    if [ "$dpi" -lt 96 ] 2>/dev/null; then dpi=96; fi
    if [ "$dpi" -gt 288 ] 2>/dev/null; then dpi=288; fi

    set_wine_dpi "$dpi"
}

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

sync_wine_theme() {
    local theme_mode theme_stamp reg_file
    theme_mode=$(normalize_dark_theme)
    theme_stamp="$WINEPREFIX/.notepadplusplus-theme"

    if [ "$theme_mode" = "YES" ]; then
        reg_file="/app/share/notepadplusplus/dark-mode.reg"
    else
        reg_file="/app/share/notepadplusplus/light-mode.reg"
    fi

    if [ -f "$theme_stamp" ] && [ "$(cat "$theme_stamp" 2>/dev/null)" = "$theme_mode" ]; then
        return
    fi

    echo "Applying ${theme_mode,,} theme registry..."
    if ! "$WINE" regedit "$reg_file"; then
        echo "Warning: failed to apply ${theme_mode,,} theme registry." >&2
        return
    fi
    printf '%s\n' "$theme_mode" > "$theme_stamp"
}

sync_npp_config_theme() {
    local theme_mode config_file stamp
    theme_mode=$(normalize_dark_theme)
    config_file=$(find "$WINEPREFIX/drive_c/users" -maxdepth 5 -type f -path '*/AppData/Roaming/Notepad++/config.xml' 2>/dev/null | head -n1)
    stamp="$WINEPREFIX/.notepadplusplus-npp-config"

    [ -n "$config_file" ] || return
    [ -f "$config_file" ] || return

    # Skip if config was already patched for the current theme.
    if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$theme_mode" ]; then
        return
    fi

    if ! python3 - "$config_file" "$theme_mode" <<'PYEOF'
import sys, re

config_file = sys.argv[1]
theme_mode  = sys.argv[2].upper()

with open(config_file, 'r', encoding='utf-8') as f:
    content = f.read()

def set_attr(text, tag_name, attr, value):
    """Set attr="value" only within the GUIConfig tag with the given name."""
    def replacer(m):
        tag = m.group(0)
        tag = re.sub(r'(?<=' + attr + r'=")[^"]*(?=")', value, tag)
        return tag
    return re.sub(
        r'<GUIConfig name="' + re.escape(tag_name) + r'"[^>]*/?>',
        replacer, text
    )

def set_text_content(text, tag_name, value):
    """Replace text content of <GUIConfig name="TAG">...</GUIConfig>."""
    return re.sub(
        r'(<GUIConfig name="' + re.escape(tag_name) + r'"[^>]*>)[^<]*(</GUIConfig>)',
        lambda m: m.group(1) + value + m.group(2),
        text
    )

# ── Always-on preferences ─────────────────────────────────────────────────────
# Hide right shortcuts in menu bar
content = set_attr(content, 'MISC', 'hideMenuRightShortcuts', 'yes')

# Fluent UI: small toolbar
content = set_text_content(content, 'ToolBar', 'fluent:small')

# Enable smooth font
content = set_attr(content, 'ScintillaPrimaryView', 'smoothFont', 'yes')

# ── Theme ─────────────────────────────────────────────────────────────────────
if '<GUIConfig name="DarkMode"' in content:
    if theme_mode == 'YES':
        content = set_attr(content, 'DarkMode', 'enable',           'yes')
        content = set_attr(content, 'DarkMode', 'colorTone',         '0')
        content = set_attr(content, 'DarkMode', 'enableWindowsMode', 'no')
        content = set_attr(content, 'DarkMode', 'darkThemeName',     'Obsidian.xml')
    else:
        content = set_attr(content, 'DarkMode', 'enable',            'no')
        content = set_attr(content, 'DarkMode', 'enableWindowsMode', 'no')

with open(config_file, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
    then
        echo "Warning: failed to patch Notepad++ config.xml." >&2
        return
    fi
    printf '%s\n' "$theme_mode" > "$stamp"
}

is_npp_running() {
    # Prefer host-side process checks to avoid Wine IPC edge cases.
    if pgrep -f 'notepad\+\+\.exe' >/dev/null 2>&1; then
        return 0
    fi

    # Fallback: ask Wine for running tasks in this prefix.
    if "$WINE" tasklist /FI "IMAGENAME eq notepad++.exe" 2>/dev/null | grep -qi 'notepad++.exe'; then
        return 0
    fi

    return 1
}

build_npp_args() {
    local arg win_path
    NPP_ARGS=()

    for arg in "$@"; do
        # Preserve CLI flags as-is.
        if [[ "$arg" == -* ]]; then
            NPP_ARGS+=("$arg")
            continue
        fi

        # Convert local paths so Wine receives canonical Windows paths.
        if [ -e "$arg" ]; then
            win_path=$(winepath -w "$arg" 2>/dev/null || true)
            if [ -n "$win_path" ]; then
                NPP_ARGS+=("$win_path")
                continue
            fi
        fi

        NPP_ARGS+=("$arg")
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
if [ ! -f "$NPP_EXE" ]; then
    echo "First run: setting up Wine prefix..."

    if ! wineboot --init; then
        echo "Wine initialization failed. Ensure required Flatpak runtime extensions are installed." >&2
        exit 1
    fi
    
    # Wait for wineboot to finish
    wineserver --wait

    echo "Installing Notepad++..."
    if ! "$WINE" /app/share/notepadplusplus/npp-installer.exe /S; then
        echo "Notepad++ installer failed to run." >&2
        exit 1
    fi

    # Wait for installer to finish
    wineserver --wait

    echo "Linking host fonts..."
    link_fonts

    wineserver --wait
    echo "Setup complete."
fi

sync_wine_theme
sync_npp_config_theme
apply_wine_dpi

build_npp_args "$@"

# When opening files while another instance is already running, avoid DDE
# handoff and force a separate process to prevent hangs.
if [ "${#NPP_ARGS[@]}" -gt 0 ] && is_npp_running; then
    exec "$WINE" "$NPP_EXE" -multiInst -nosession "${NPP_ARGS[@]}"
fi

exec "$WINE" "$NPP_EXE" "${NPP_ARGS[@]}"