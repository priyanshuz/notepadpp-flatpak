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
    "$WINE" regedit "$reg_file"
    printf '%s\n' "$theme_mode" > "$theme_stamp"
}

sync_npp_config_theme() {
    local theme_mode config_file
    theme_mode=$(normalize_dark_theme)
    config_file="$WINEPREFIX/drive_c/users/$USER/AppData/Roaming/Notepad++/config.xml"

    [ -f "$config_file" ] || return

    python3 - "$config_file" "$theme_mode" <<'PYEOF'
import sys, re

config_file = sys.argv[1]
theme_mode  = sys.argv[2].upper()

with open(config_file, 'r', encoding='utf-8') as f:
    content = f.read()

def set_attr(text, attr, value):
    pattern = r'(?<=' + attr + r'=")[^"]*(?=")'
    if re.search(pattern, text):
        return re.sub(pattern, value, text)
    return text

if '<GUIConfig name="DarkMode"' not in content:
    sys.exit(0)

if theme_mode == 'YES':
    content = set_attr(content, 'enable',           'yes')
    content = set_attr(content, 'colorTone',         '0')
    content = set_attr(content, 'enableWindowsMode', 'no')
    content = set_attr(content, 'darkThemeName',     'Obsidian.xml')
else:
    content = set_attr(content, 'enable',            'no')
    content = set_attr(content, 'enableWindowsMode', 'no')

with open(config_file, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
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
if [ ! -f "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" ]; then
    echo "First run: setting up Wine prefix..."

    wineboot --init
    
    # Wait for wineboot to finish
    wineserver --wait

    echo "Installing Notepad++..."
    "$WINE" /app/share/notepadplusplus/npp-installer.exe /S

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

exec "$WINE" "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"