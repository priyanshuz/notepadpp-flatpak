#!/bin/bash
# Notepad++ Flatpak installer
# Installs required Wine runtime extensions from Flathub, then the app.
set -e

FLATPAKREF="https://priyanshuz.github.io/notepadpp-flatpak/com.notepadplusplus.NotepadPlusPlus.flatpakref"

echo "==> Adding Flathub remote (if not already present)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> Installing required Wine runtime extensions from Flathub..."
flatpak install -y --or-update flathub \
  org.freedesktop.Platform.Compat.i386//25.08 \
  org.freedesktop.Platform.GL32.default//25.08 \
  org.winehq.Wine.gecko/x86_64/stable-25.08 \
  org.winehq.Wine.mono/x86_64/stable-25.08

echo "==> Installing Notepad++..."
flatpak install -y --user "$FLATPAKREF"

echo ""
echo "Installation complete!"
echo "Run with: flatpak run com.notepadplusplus.NotepadPlusPlus"
