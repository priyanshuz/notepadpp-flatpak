#!/bin/bash
export WINEPREFIX=/var/data/wine
export WINEDEBUG=-all
export WINEARCH=win64

# First run setup
if [ ! -f "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" ]; then
    echo "First run: setting up Wine prefix..."
    wineboot --init
    
    echo "Installing Notepad++..."
    wine /app/share/notepadplusplus/npp-installer.exe /S
    
    echo "Applying dark mode registry..."
    wine regedit /app/share/notepadplusplus/dark-mode.reg
    
fi

exec wine "$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe" "$@"
