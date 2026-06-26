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

- Flatpak runtime `org.freedesktop.Platform//25.08`
- Wine base `org.winehq.Wine//stable-25.08`
- Wine extensions:
  - `org.freedesktop.Platform.Compat.i386//25.08` (32-bit compatibility)
  - `org.freedesktop.Platform.GL32.default//25.08` (32-bit graphics)

With the `.flatpakref` install path below, Flatpak resolves these automatically.

---

## Installation

### Recommended (one-command installer)

Download and run the installer script — it installs required Wine extensions from Flathub and then the app:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/priyanshuz/notepadpp-flatpak/main/install.sh)
```

Or download `install.sh` from [Releases](../../releases) and run:

```bash
bash install.sh
```

### Manual (advanced)

1. Install required Wine runtime extensions from Flathub:

```bash
flatpak install -y flathub \
  org.freedesktop.Platform.Compat.i386//25.08 \
  org.freedesktop.Platform.GL32.default//25.08
```

2. Install the app:

```bash
flatpak install --user https://priyanshuz.github.io/notepadpp-flatpak/com.notepadplusplus.NotepadPlusPlus.flatpakref
```

### First launch

The first launch will:
1. Initialise the Wine prefix in `~/.notepadpp/.wine`.
2. Sync the portable Notepad++ files into `~/.notepadpp`.
3. Link host fonts into the Wine font directory.
4. Apply your configured theme and preferences.

Subsequent launches skip all of the above and start Notepad++ directly.

---

## Configuration

Notepad++ stores its settings in `~/.notepadpp`. The Wine prefix is `~/.notepadpp/.wine` and the portable Notepad++ files live directly in `~/.notepadpp`.

### Dark mode

The wrapper reads Notepad++'s own `config.xml` and applies the matching Wine system theme automatically:

- If **Dark mode** is enabled in Notepad++ (`Preferences → Dark Mode`), the Wine non-client areas (title bars, menus, dialogs) are switched to a dark palette.
- If **Light mode** is enabled, the standard light Windows palette is used.

Switch the mode inside Notepad++ and restart the app; the Wine theme will follow on the next launch.

---

## Defaults applied on first launch

These preferences are set automatically and do not change on subsequent launches unless the theme stamp is cleared:

| Setting | Value |
|---|---|
| Preferences → General → Hide right shortcuts | Enabled |
| Preferences → Toolbar | Fluent UI: small |
| Preferences → Editing 1 → Enable smooth font | Enabled |
| Dark Mode | Follows Notepad++ `config.xml` |
| Style Configurator theme (dark mode only) | Obsidian |

---

## Resetting the Wine prefix

To start fresh (re-runs first-launch setup):

```bash
rm -rf ~/.notepadpp
flatpak run com.notepadplusplus.NotepadPlusPlus
```

---

## Fonts

Host system fonts are automatically linked into the Wine font directory on first launch via `/run/host/fonts` (the standard Flatpak host font path). User fonts from `~/.fonts` are also accessible.

CJK font substitutes are applied automatically on first launch when a Chinese locale is detected.

---

## Build locally

```bash
git clone https://github.com/priyanshuz/notepadpp-flatpak.git
cd notepadpp-flatpak

flatpak-builder --user --install --force-clean build-dir \
    com.notepadplusplus.NotepadPlusPlus.yml
```

---

## Automated updates and publishing

This repository is configured to auto-publish whenever upstream Notepad++ releases a new version.

### What is automated

- Upstream version check: `.github/workflows/auto-update-notepadpp.yml` runs every 6 hours.
- Manifest bump: it updates `com.notepadplusplus.NotepadPlusPlus.yml` with the latest installer URL and SHA256 checksums.
- Auto commit + tag: it commits to `main` and pushes a version tag (for example `v8.9.6.1`).
- Flatpak build + Pages publish: `.github/workflows/build.yml` runs on `main` push and publishes:
  - `repo/` to `gh-pages`
  - `com.notepadplusplus.NotepadPlusPlus.flatpakref` to the root of `gh-pages`
- GitHub Release assets: `.github/workflows/build.yml` runs on `v*` tags and uploads:
  - `notepad-plus-plus.flatpak`
  - `com.notepadplusplus.NotepadPlusPlus.flatpakref`
  - `install.sh`

### One-time GitHub settings

- Actions workflow permissions: set to **Read and write**.
- GitHub Pages source: publish from branch `gh-pages`.

### GitHub setup runbook (click path)

1. Open **Settings -> Actions -> General**.
2. Under **Workflow permissions**, select **Read and write permissions**.
3. Save the setting.
4. Open **Settings -> Pages**.
5. Under **Build and deployment**, choose:
  - **Source**: `Deploy from a branch`
  - **Branch**: `gh-pages`
  - **Folder**: `/ (root)`
6. Save and wait for the first successful publish.
7. Optional verification:
  - Run **Actions -> Auto Update Notepad++ -> Run workflow**.
  - Confirm the `Build and Publish Flatpak` workflow runs after the bump commit/tag.
  - Open the Pages URL and confirm `com.notepadplusplus.NotepadPlusPlus.flatpakref` is reachable.

---

## Wine tools

You can launch Wine tools through the same Flatpak entry point:

```bash
flatpak run com.notepadplusplus.NotepadPlusPlus winecfg
flatpak run com.notepadplusplus.NotepadPlusPlus regedit
flatpak run com.notepadplusplus.NotepadPlusPlus taskmgr
flatpak run com.notepadplusplus.NotepadPlusPlus winefile
flatpak run com.notepadplusplus.NotepadPlusPlus control
```

---

## Files

| File | Purpose |
|---|---|
| `com.notepadplusplus.NotepadPlusPlus.yml` | Flatpak manifest |
| `notepadplusplus.sh` | Launch script (theme sync, first-run setup, Wine tools) |
| `dark-mode.reg` | Wine registry patch for dark UI colours |
| `light-mode.reg` | Wine registry patch for light UI colours |
| `com.notepadplusplus.NotepadPlusPlus.desktop` | Desktop entry |
| `com.notepadplusplus.NotepadPlusPlus.png` | Application icon |

---

## Single-instance and "Open With"

Notepad++ relies on Wine's built-in single-instance mechanism (a Win32 mutex via the wineserver). The wrapper does not use any external locking, so "Open With" from file managers and command-line file arguments work reliably with a running instance.

## License

Notepad++ is licensed under the [GPL v3](https://www.gnu.org/licenses/gpl-3.0.html).  
This packaging is provided as-is with no warranty.
