# kde-displayset

A lightweight, state-aware display settings launcher for KDE Plasma on Wayland.

Automatically sets HDR and Adaptive Sync (VRR/G-Sync/FreeSync) to the right state when an app or game launches, and restores (or sets) them to a defined state when it exits — without touching settings you didn't ask it to change.

Built for KDE Plasma 6 + Wayland. Developed and tested on CachyOS, KDE Plasma 6.7, Nvidia RTX series.

---

## Why

KDE Plasma doesn't auto-toggle HDR or VRR per-application. If you want HDR off at the desktop but on for games, or VRR on only when gaming, you'd normally have to do it manually every time. This tool automates that.

It's also non-destructive: it snapshots your current state before doing anything, so `restore` on exit always brings you back to exactly where you were — even if HDR was already on when you launched. Every change is verified by reading the state back, so a setting that fails to apply is reported rather than silently assumed.

---

## Requirements

- KDE Plasma 6 on Wayland (VRR is set via Plasma's `vrrpolicy`; developed against Plasma 6.7)
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

Scripts are installed to `~/.local/bin/` and configs go to `~/.config/kde-displayset/`. No root required. The example config is refreshed on every install; your own `*.conf` files are never touched.

If `~/.local/bin` isn't in your `$PATH`, the installer will warn you and tell you how to add it for your shell.

---

## Quick Start

1. Copy the example config and edit it for your app:
   ```bash
   cp ~/.config/kde-displayset/example.conf ~/.config/kde-displayset/stalker2.conf
   nano ~/.config/kde-displayset/stalker2.conf
   ```

2. Set your desired entry/exit states (see [Config Reference](#config-reference)). For a Steam game, add `LAUNCHER="steam"` and `LAUNCHER_ID="<AppID>"` so it can be auto-detected.

3. Preview without changing anything:
   ```bash
   kds-launch stalker2 --dry-run
   ```

4. Use it with Steam — set the game's Launch Options to:
   ```
   kds-launch %command%
   ```
   With `LAUNCHER`/`LAUNCHER_ID` set in the config, kds-launch auto-detects which config to use from Steam's environment, applies your entry state, runs the game, and restores on exit. See [Using with Steam](#using-with-steam-launch-options).

---

## Usage

```
kds-launch %command%              Auto-detect config from launcher env vars, then run %command%
kds-launch=myapp %command%        Force the 'myapp' config, then run %command%
kds-launch myapp                  Standalone: load myapp.conf, auto-generate launch command
kds-launch --list                 List all configs
kds-launch --status               Show current HDR and VRR state
kds-launch --help                 Show help
```

Append `--dry-run` to any launch invocation to preview what would happen without changing anything.

### How a config is matched

**With `%command%` (Steam/Heroic auto-detect):**

1. Filename match — `<SteamAppId>.conf` or `<HEROIC_APP_NAME>.conf`.
2. Field scan — any config whose `LAUNCHER` + `LAUNCHER_ID` match the launcher's environment.
3. No match — the command is passed through untouched (your game still launches; nothing is changed).

**Standalone (`kds-launch myapp`):**

1. Filename match — `myapp.conf`.
2. `NAME` field scan — any config whose `NAME` equals `myapp` (case-insensitive).
3. No match — error.

Supported launcher environment variables: `steam` → `SteamAppId`, `heroic` → `HEROIC_APP_NAME`.

---

## Config Reference

Config files live at `~/.config/kde-displayset/<appname>.conf`. Each is a small Bash file of `KEY="value"` lines.

| Variable      | Values                          | Default      | Description                                                        |
|---------------|---------------------------------|--------------|--------------------------------------------------------------------|
| `NAME`        | Any string                      | *(filename)* | Human-readable name shown in `--list`                              |
| `LAUNCHER`    | `steam` / `heroic` / `none`     | *(unset)*    | Launcher type, for `%command%` auto-detection                      |
| `LAUNCHER_ID` | AppID / launcher-specific ID    | *(unset)*    | Matched against the launcher's env var (e.g. Steam AppID)          |
| `ENTRY_HDR`   | `on` / `off` / `passthrough`    | `passthrough`| HDR state to apply when the app launches                           |
| `ENTRY_VRR`   | `on` / `off` / `passthrough`    | `passthrough`| VRR state to apply when the app launches                           |
| `EXIT_HDR`    | `on` / `off` / `restore`        | `restore`    | HDR state to apply when the app exits                              |
| `EXIT_VRR`    | `on` / `off` / `restore`        | `restore`    | VRR state to apply when the app exits                              |
| `APPLY_MODE`  | `combined` / `separate`         | `combined`   | How HDR+VRR are applied when both change at once                   |
| `HDR_SEQUENCE`| `safe` / `off`                  | `safe`       | Sequence HDR changes safely: VRR off → HDR → VRR restore           |

### Value meanings

- **`on`** / **`off`** — Explicitly set to that state.
- **`passthrough`** (entry only) — Don't touch this setting on launch; leave it exactly as it is.
- **`restore`** (exit only) — On exit, set this back to whatever it was *before* the app launched. Resolved at launch time, so it always reflects your true pre-launch state.

> `VRR = on` maps to KWin's **Always** mode (not Automatic) — chosen deliberately so adaptive sync doesn't flip on and off mid-game.

### APPLY_MODE

When a launch (or exit) changes **both** HDR and VRR at once, `APPLY_MODE` controls how:

- **`combined`** (default) — both settings go in a single atomic `kscreen-doctor` call, so the display re-negotiates once. Faster (~2–3× on measured dual changes) and usually fewer/shorter blinks.
- **`separate`** — HDR and VRR are applied in two distinct calls, one after the other. Some games or panels negotiate more reliably one-at-a-time; use this if `combined` misbehaves.

This only matters when both change together — a single-setting change is one call either way.

### Example configs

**Steam game, auto-detected via `%command%` — HDR + VRR on, restore on exit:**
```bash
NAME="STALKER 2"
LAUNCHER="steam"
LAUNCHER_ID="1643380"
ENTRY_HDR="on"
ENTRY_VRR="on"
EXIT_HDR="restore"
EXIT_VRR="restore"
```

**Minimal Steam config (filename is the AppID, e.g. `1643380.conf`):**
```bash
ENTRY_HDR="on"
ENTRY_VRR="on"
EXIT_HDR="restore"
EXIT_VRR="restore"
```

**Standalone media player — HDR on, leave VRR alone, HDR off when done:**
```bash
NAME="mpv"
LAUNCHER="none"
ENTRY_HDR="on"
ENTRY_VRR="passthrough"
EXIT_HDR="off"
EXIT_VRR="passthrough"
```
Run with: `kds-launch mpv` (execs `mpv`) or pass args directly: `kds-launch mpv mpv --fullscreen /path/to/file`

---

## Using with Steam Launch Options

In Steam → right-click game → Properties → Launch Options:

```
kds-launch %command%
```

Steam passes the real game command through `%command%`. kds-launch auto-detects the matching config from `SteamAppId` (set `LAUNCHER="steam"` and `LAUNCHER_ID="<AppID>"` in the config, or name the config file `<AppID>.conf`), applies your entry state, runs the game, and restores on exit.

To force a specific config regardless of environment, use the `=name` form:

```
kds-launch=stalker2 %command%
```

If no config matches, kds-launch passes the command through untouched — the game still launches, nothing is changed.

---

## How It Works

1. `kds-launch` sources `kds-state.sh` for the state detection/apply functions.
2. It resolves which config to use (see [matching](#how-a-config-is-matched)) and loads your entry/exit settings.
3. It snapshots current HDR and VRR via `kscreen-doctor`, and resolves any `restore` values against that snapshot.
4. It applies only the settings that need to change on entry, verifying each by reading the state back.
5. It runs your app as a child process and waits for it to exit.
6. On exit — clean exit, crash, or termination (`EXIT`, `INT`, `TERM` traps) — it applies your defined exit state. HDR and VRR are restored independently, so a failure in one never blocks the other.

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

---

## FAQ

### HDR isn't activating — my display flashes but doesn't enter HDR mode

This is a negotiation quirk seen on some older TVs and monitors. When VRR (adaptive sync) is already active, certain displays reject an HDR mode change during the same negotiation cycle — they flash but land back in SDR.

The fix is `HDR_SEQUENCE="safe"` in your config, which is the default. It sequences the changes as: VRR off → HDR on → VRR on, giving the display two clean re-negotiations instead of one ambiguous one.

If you've explicitly set `HDR_SEQUENCE="off"` and are seeing this issue, change it back to `"safe"`.

**Known affected displays:**

| Year | Brand   | Model       | Notes                              |
|------|---------|-------------|------------------------------------|
| 2020 | Samsung | QN55Q80T    | Requires `HDR_SEQUENCE="safe"`     |

If your display has this issue, please open an issue or PR at https://github.com/jinxcase000/kde-displayset with your year, brand, and model so it can be added to this list. Over time the goal is to build a database of affected panels and potentially auto-detect them during install.
