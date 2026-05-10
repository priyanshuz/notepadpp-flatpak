# Notepad++ Flatpak

Unofficial Flatpak packaging of [Notepad++](https://notepad-plus-plus.org/) for Linux, running via Wine.

> **Status:** Unofficial. Not affiliated with or endorsed by the Notepad++ project.

---

## Screenshots

| Light mode | Dark mode |
|---|---|
| ![Notepad++ light mode](screenshots/notepadpp-light-mode.png) | ![Notepad++ dark mode](screenshots/notepadpp-dark-mode.png) |

---

## Requirements

- Flatpak runtime `org.freedesktop.Platform//24.08`
- Wine base `org.winehq.Wine//stable-24.08`
- Wine extensions:
  - `org.freedesktop.Platform.Compat.i386//24.08` (32-bit compatibility)
  - `org.freedesktop.Platform.GL32.default//24.08` (32-bit graphics)
  - `org.winehq.Wine.gecko` (IE engine)
  - `org.winehq.Wine.mono` (.NET runtime)

**When installing from Flathub:** Extensions are installed automatically.

**When installing from a local `.flatpak` file:** You must pre-install the extensions first:
```bash
flatpak install -y flathub \
  org.freedesktop.Platform.Compat.i386//24.08 \
  org.freedesktop.Platform.GL32.default//24.08 \
  org.winehq.Wine.gecko/x86_64/stable-24.08 \
  org.winehq.Wine.mono/x86_64/stable-24.08
```

Then install the Notepad++ app.

---

## Installation

### From GitHub Actions artifact

1. Go to [Actions](../../actions) and open the latest successful build.
2. Download the `Notepad++-flatpak` artifact and unzip it.
3. **Install required extensions first** (see [Requirements](#requirements)):
```bash
flatpak install -y flathub org.freedesktop.Platform.Compat.i386//24.08 org.freedesktop.Platform.GL32.default//24.08 org.winehq.Wine.gecko/x86_64/stable-24.08 org.winehq.Wine.mono/x86_64/stable-24.08
```
4. Install the app:
```bash
flatpak install --user notepad-plus-plus.flatpak
```

### From GitHub Release

1. Go to [Releases](../../releases) and download the latest `notepad-plus-plus.flatpak`.
2. **Install required extensions first** (see [Requirements](#requirements)):
```bash
flatpak install -y flathub org.freedesktop.Platform.Compat.i386//24.08 org.freedesktop.Platform.GL32.default//24.08 org.winehq.Wine.gecko/x86_64/stable-24.08 org.winehq.Wine.mono/x86_64/stable-24.08
```
3. Install the app:
```bash
flatpak install --user notepad-plus-plus.flatpak
```

### First launch

The first launch will:
1. Initialise the Wine prefix.
2. Silently install Notepad++ into the prefix.
3. Link host fonts into the Wine font directory.
4. Apply your configured theme and preferences.

Subsequent launches skip all of the above and start Notepad++ directly.

---

## Configuration

All options are exposed as environment variables. You can set them using [Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) or via the command line:

```bash
flatpak override --user --env=OPTION=value com.notepadplusplus.NotepadPlusPlus
```

### Available options

| Variable | Default | Description |
|---|---|---|
| `NPP_WINE_DPI` | `96` | Wine DPI for UI scaling. Increase for HiDPI displays (e.g. `144`, `192`, `240`). |
| `WINE_DARK_THEME` | `NO` | Set to `YES` to enable dark mode and the Obsidian syntax theme. |

### DPI guide

| Display type | Suggested value |
|---|---|
| 1080p standard | `96` |
| 1440p / 24" | `120` |
| 4K / HiDPI | `192`–`240` |

### Dark mode

Setting `WINE_DARK_THEME=YES`:
- Applies a dark colour palette to Wine system UI (title bars, menus, dialogs).
- Enables **Dark mode** in Notepad++ Preferences → Dark Mode (Black tone).
- Sets the **Obsidian** syntax highlighting theme in Style Configurator.

Setting `WINE_DARK_THEME=NO` (default):
- Restores the standard light Windows colour palette.
- Switches Notepad++ back to Light mode.

The theme is only re-applied when the value changes, so switching in Flatseal and restarting the app is all that's needed.

---

## Defaults applied on first launch

These preferences are set automatically and do not change on subsequent launches unless the theme stamp is cleared:

| Setting | Value |
|---|---|
| Preferences → General → Hide right shortcuts | Enabled |
| Preferences → Toolbar | Fluent UI: small |
| Preferences → Editing 1 → Enable smooth font | Enabled |
| Dark Mode | Light (follows `WINE_DARK_THEME`) |
| Style Configurator theme (dark mode only) | Obsidian |

---

## Resetting the Wine prefix

To start fresh (re-runs first-launch setup):

```bash
rm -rf ~/.var/app/com.notepadplusplus.NotepadPlusPlus/data/wine
flatpak run com.notepadplusplus.NotepadPlusPlus
```

---

## Fonts

Host system fonts are automatically linked into the Wine font directory on first launch via `/run/host/fonts` (the standard Flatpak host font path). User fonts from `~/.fonts` are also accessible.

---

## Build locally

```bash
git clone https://github.com/priyanshuz/notepadpp-flatpak.git
cd notepadpp-flatpak

flatpak-builder --user --install --force-clean build-dir \
    com.notepadplusplus.NotepadPlusPlus.yml
```

---

## Files

| File | Purpose |
|---|---|
| `com.notepadplusplus.NotepadPlusPlus.yml` | Flatpak manifest |
| `notepadplusplus.sh` | Launch script (DPI, theme, first-run setup) |
| `dark-mode.reg` | Wine registry patch for dark UI colours |
| `light-mode.reg` | Wine registry patch for light UI colours |
| `com.notepadplusplus.NotepadPlusPlus.desktop` | Desktop entry |
| `com.notepadplusplus.NotepadPlusPlus.png` | Application icon |

---

## License

Notepad++ is licensed under the [GPL v3](https://www.gnu.org/licenses/gpl-3.0.html).  
This packaging is provided as-is with no warranty.
