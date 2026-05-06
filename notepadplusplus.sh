#!/bin/bash
export WINEPREFIX=/var/data/wine
export WINEDEBUG=-all
export WINEARCH=win64
export PATH="/app/bin:$PATH"

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
    
    echo "Installing Notepad++..."
    "$WINE" /app/share/notepadplusplus/npp-installer.exe /S
    
    echo "Applying dark mode registry..."
    "$WINE" regedit /app/share/notepadplusplus/dark-mode.reg
    
fi

exec "$WINE" "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"
