#!/bin/bash
export WINEPREFIX=/var/data/wine
export WINEDEBUG=-all
export WINEARCH=win64
export WINE=/app/wine/bin/wine64

# First run setup
if [ ! -f "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" ]; then
    echo "First run: setting up Wine prefix..."
    
    echo "Installing Notepad++..."
    $WINE /app/share/notepadplusplus/npp-installer.exe /S
    
    echo "Applying dark mode registry..."
    $WINE regedit /app/share/notepadplusplus/dark-mode.reg
    
fi

exec $WINE "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"
