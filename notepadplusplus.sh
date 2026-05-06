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

detect_dpi() {
    local dpi=96

    # Explicit override if user wants deterministic behavior.
    if [ -n "$NPP_WINE_DPI" ] && [ "$NPP_WINE_DPI" -eq "$NPP_WINE_DPI" ] 2>/dev/null; then
        dpi="$NPP_WINE_DPI"
    elif command -v xrandr >/dev/null 2>&1; then
        local values
        values=$(xrandr 2>/dev/null | awk '
            / connected/ && /[0-9]+x[0-9]+/ && /[0-9]+mm x [0-9]+mm/ {
                split($0, a, " ")
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^[0-9]+x[0-9]+/) {
                        split($i, r, "x")
                        rw = r[1]
                        break
                    }
                }
                if (match($0, /([0-9]+)mm x ([0-9]+)mm/, m)) {
                    print rw " " m[1]
                    exit
                }
            }
        ')
        if [ -n "$values" ]; then
            local res_w phys_w
            res_w=$(echo "$values" | awk '{print $1}')
            phys_w=$(echo "$values" | awk '{print $2}')
            if [ -n "$res_w" ] && [ -n "$phys_w" ] && [ "$phys_w" -gt 0 ] 2>/dev/null; then
                dpi=$(awk -v rw="$res_w" -v pw="$phys_w" 'BEGIN { printf "%d", (rw / pw) * 25.4 + 0.5 }')
            fi
        fi
    elif [ -n "$GDK_SCALE" ] && [ "$GDK_SCALE" -eq "$GDK_SCALE" ] 2>/dev/null; then
        dpi=$((96 * GDK_SCALE))
    fi

    if [ "$dpi" -lt 96 ] 2>/dev/null; then dpi=96; fi
    if [ "$dpi" -gt 288 ] 2>/dev/null; then dpi=288; fi
    echo "$dpi"
}

set_wine_dpi() {
    local dpi="$1"
    "$WINE" reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
    "$WINE" reg add "HKCU\\Software\\Wine\\Fonts" /v LogPixels /t REG_DWORD /d "$dpi" /f >/dev/null 2>&1 || true
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

    echo "Applying dark mode registry..."
    "$WINE" regedit /app/share/notepadplusplus/dark-mode.reg

    echo "Linking host fonts..."
    link_fonts

    wineserver --wait
    echo "Setup complete."
fi

set_wine_dpi "$(detect_dpi)"

exec "$WINE" "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"