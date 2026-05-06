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

# Find wine64 first, fall back to wine
if command -v wine64 >/dev/null 2>&1; then
    WINE="$(command -v wine64)"
elif command -v wine >/dev/null 2>&1; then
    WINE="$(command -v wine)"
else
    echo "Wine binary not found in application runtime." >&2
    exit 1
fi

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

    wineserver --wait
    echo "Setup complete."
fi

exec "$WINE" "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"