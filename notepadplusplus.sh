#!/bin/bash
export WINEPREFIX="${WINEPREFIX:-/var/data/wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEARCH="${WINEARCH:-win64}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"
export WINE_MONO_OVERRIDES="Microsoft.Xna.Framework,Microsoft.Xna.Framework.*"
export PATH="/app/bin:$PATH"

# Point Wine to bundled Mono and Gecko
export WINE_MONO_DIR="/app/share/wine/mono"
export WINE_GECKO_DIR="/app/share/wine/gecko"

NPP_EXE="$WINEPREFIX/drive_c/Program Files/Notepad++/notepad++.exe"

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

is_npp_running() {
    "$WINE" tasklist /FI "IMAGENAME eq notepad++.exe" 2>/dev/null | grep -qi 'notepad++.exe'
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

build_npp_args "$@"

# If a Notepad++ instance is already running, hand off file-open requests using
# Wine start and return success so launchers do not treat it as a crash.
if [ "${#NPP_ARGS[@]}" -gt 0 ] && is_npp_running; then
    "$WINE" start /unix "$NPP_EXE" "${NPP_ARGS[@]}" >/dev/null 2>&1 || true
    exit 0
fi

exec "$WINE" "$NPP_EXE" "${NPP_ARGS[@]}"