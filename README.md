# kde-displayset

A lightweight, state-aware display settings launcher for KDE Plasma on Wayland.

Automatically sets HDR and Adaptive Sync (VRR/G-Sync/FreeSync) to the right state when an app or game launches, and restores (or sets) them to a defined state when it exits — without touching settings you didn't ask it to change.

Built for KDE Plasma 6 + Wayland. Tested on CachyOS with Nvidia RTX series.

---

## Why

KDE Plasma doesn't auto-toggle HDR or VRR per-application. If you want HDR off at the desktop but on for games, or VRR on only when gaming, you'd normally have to do it manually every time. This tool automates that.

It's also non-destructive: it snapshots your current state before doing anything, so `restore` on exit always brings you back to exactly where you were — even if HDR was already on when you launched.

---

## Requirements

- KDE Plasma 6 on Wayland
- `kscreen-doctor` — part of the `kscreen` package
  ```
  sudo pacman -S kscreen       # Arch / CachyOS / Manjaro
  sudo apt install kscreen     # Debian / Ubuntu
  ```
- Bash 4+
- An HDR and/or VRR capable display connected via HDMI or DisplayPort

---

## Install

```bash
git clone https://github.com/jinxcase000/kde-displayset.git
cd kde-displayset
bash install.sh
```

Scripts are installed to `~/.local/bin/` and configs go to `~/.config/kde-displayset/`. No root required.

If `~/.local/bin` isn't in your `$PATH`, the installer will warn you and tell you how to add it for your shell.

---

## Quick Start

1. Copy the example config and edit it for your app:
   ```bash
   cp ~/.config/kde-displayset/example.conf ~/.config/kde-displayset/stalker2.conf
   nano ~/.config/kde-displayset/stalker2.conf
   ```

2. Set your desired entry/exit states and the launch command (see [Config Reference](#config-reference) below).

3. Test it without applying anything:
   ```bash
   kds-launch stalker2 --dry-run
   ```

4. Launch it for real:
   ```bash
   kds-launch stalker2
   ```

5. To use with Steam, set the Steam launch options for the game to:
   ```
   kds-launch stalker2 %command%
   ```
   > **Note:** When using `%command%`, Steam passes the game's own launch arguments via `%command%`. Set `COMMAND="%command%"` in your config, or omit COMMAND entirely and let Steam handle the launch — see the Steam section below.

---

## Config Reference

Config files live at `~/.config/kde-displayset/<appname>.conf`.

| Variable    | Values                        | Default       | Description                                      |
|-------------|-------------------------------|---------------|--------------------------------------------------|
| `ENTRY_HDR` | `on` / `off` / `passthrough`  | `passthrough` | HDR state to apply when the app launches         |
| `ENTRY_VRR` | `on` / `off` / `passthrough`  | `passthrough` | VRR state to apply when the app launches         |
| `EXIT_HDR`  | `on` / `off` / `restore`      | `restore`     | HDR state to apply when the app exits            |
| `EXIT_VRR`  | `on` / `off` / `restore`      | `restore`     | VRR state to apply when the app exits            |
| `COMMAND`   | Any valid shell command        | *(required)*  | The command to launch your app                   |

### Value meanings

- **`passthrough`** — Don't touch this setting at all on entry. Leave it exactly as it is.
- **`restore`** — On exit, set this back to whatever it was *before* the app launched.
- **`on`** / **`off`** — Explicitly set to that state, regardless of what it was before.

### Example configs

**Game that needs HDR and VRR, restore everything on exit:**
```bash
ENTRY_HDR="on"
ENTRY_VRR="on"
EXIT_HDR="restore"
EXIT_VRR="restore"
COMMAND="steam steam://rungameid/1643380"
```

**Media player — HDR on, leave VRR alone, turn HDR off when done:**
```bash
ENTRY_HDR="on"
ENTRY_VRR="passthrough"
EXIT_HDR="off"
EXIT_VRR="passthrough"
COMMAND="mpv --fullscreen /home/jinx/movies/mymovie.mkv"
```

**Game that doesn't need HDR, but does need VRR:**
```bash
ENTRY_HDR="off"
ENTRY_VRR="on"
EXIT_HDR="restore"
EXIT_VRR="restore"
COMMAND="steam steam://rungameid/292030"
```

---

## Using with Steam Launch Options

In Steam → right-click game → Properties → Launch Options:

```
kds-launch mygame %command%
```

When used this way, Steam passes the real game command via `%command%`. Set your config's `COMMAND` to a Steam game URI instead, and use the launch options field just to invoke `kds-launch` before Steam handles the rest. Or simply wrap the whole launch:

```
kds-launch mygame
```

And set `COMMAND="steam steam://rungameid/<AppID>"` in the config — Steam will launch the game via URI and kds-launch will wait for it to exit before restoring settings.

---

## CLI Reference

```
kds-launch <config-name>            Launch app using named config
kds-launch <config-name> --dry-run  Show what would happen without doing it
kds-launch --list                   List all available configs
kds-launch --status                 Show current HDR and VRR state
kds-launch --help                   Show help
```

---

## How It Works

1. `kds-launch` sources `kds-state.sh` to get the state detection functions.
2. It reads your `.conf` file to get entry/exit states and the command.
3. It snapshots current HDR and VRR state via `kscreen-doctor`.
4. It applies only the settings that need to change on entry.
5. It launches your app and waits for it to exit.
6. On exit (including crashes, via `trap`), it applies your defined exit state.

The `restore` exit value is resolved at snapshot time, so it always reflects what was active *before* kds-launch ran — not what's active at the moment of exit.

---

## Uninstall

```bash
bash uninstall.sh
```

Your config directory (`~/.config/kde-displayset/`) is preserved. Remove it manually if you want:
```bash
rm -rf ~/.config/kde-displayset
```

---

## License

GPL-3.0 — free to use, modify, and share. Any derivative work must also be open source under the same license.

---

## Contributing

Issues and PRs welcome at https://github.com/jinxcase000/kde-displayset
