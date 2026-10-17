# Development

## Layout

- `bin/`: commands you run, linked into `~/.local/bin` (on PATH).
- `lib/`: what only Waybar, the keybindings or other scripts call, linked into
  `~/.local/lib/hyprflow` (off PATH). Shared code lives here too:
  - `lib/hyprflow/` (Python): `paths`, `hyprland` (a facade over Hyprland),
    `notify`, `palette`, `lock` (one copy at a time), `menu` (rofi, with the
    confirmations on Quickshell) and
    `waybar` (`WaybarModule`).
  - `lib/common.sh` (Bash): `msg`, `warn`, `notify`, `load_palette`, and where
    `bin/` and `lib/` are.
- `dotconfig/`: copied into `~/.config` by `install.sh config`.
  `dotconfig/quickshell/hyprflow/bar/` is the Quickshell bar (`bar.json` +
  `modules/`, docs/bar.md).
  `dotconfig/quickshell/hyprflow/` holds the Quickshell panels (`qs -c hyprflow`):
  the Super+K and Super+I panels, the audio and theme pickers, the
  confirmations, the power menu, the submap HUD and the
  level OSD the volume and brightness keys show (it also watches Pipewire, so
  a headset's own volume buttons show it too).
- `packages/`: the package lists install.sh reads.

## How it fits together

What runs when something happens, in order: each arrow is one script calling
the next. Start here when you want to know which file to open.

### At login

`dotconfig/hypr/hyprland.lua`, `hyprland.start`:

1. `game-mode.sh off`: a session that ended in game mode starts normal.
2. `monitors.sh apply`: lays out the screens and starts Waybar (see below).
3. `awww-daemon` (wallpaper), `activate-linux.py` (watermark),
   `rgb-sync.sh --last` (LED colour).
4. The daemons, all in `lib/`:
   - `headset-watch.py`: the headset's hidraw; turned on → `rgb-sync.sh --rescan`
     (LED colour back).
   - `rgb-hotplug.py`: `udevadm monitor`; a USB device plugged in →
     `rgb-sync.sh --rescan` 3 s after the last event.
   - `mic-mute-watch.py`: a headset's own mic mute button → `wpctl set-mute`
     on its source.
   - `qs -n -d -c hyprflow`: the Quickshell panels and the OSD.
   - `osd-watch.py`: play/pause, Caps/Num Lock and do not disturb → the OSD.
   - `pad-listener.py`: the controller combo for game mode.
5. `nm-applet`, `blueman-applet`, the polkit agent, `hyprpm reload`.

It also hooks `monitor.added` / `monitor.removed` to `monitors.sh apply`.

### A monitor plugged in or out

```
Hyprland hotplug → monitors.sh apply --notify connected|disconnected → lib/monitors.py
  wait 2 s, then compare the ports with the last apply's
  (~/.local/state/hyprflow/monitors-hotplug.json): the one gone or new names
  the notification; none (a DP monitor that dropped and came back) → no notice
  detect (hyprctl monitors) → pick a profile: solo state, else the saved one
  for this set of screens, else the default (largest is primary)
  → write ~/.config/hypr/monitors_active.lua and ~/.config/waybar/config,
    and ~/.local/state/hyprflow/bars.json ({port: full|minimal}) for the
    Quickshell bar, which reloads on its own
  → lua changed:  hyprctl reload, then `_after-reload` a second later
                  (awww restore, workspaces back to their monitor)
  → bars changed, or Waybar not running: waybar-restart.sh (not in game mode;
    with the Quickshell bar on it only makes sure Waybar is off)
  → notify (only with --notify): "Screen connected/disconnected · MODEL" and
    the screens on ("Still on" after an unplug); login passes none and stays
    quiet; mirror and solo say
    "Mirror on/off", "Solo on/off"
```

activate-linux.py hears the same hotplug on Hyprland's event socket and moves
the watermark to the monitor holding workspace 1.

### The wallpaper changes

```
waypaper (Super+K → Random wallpaper, or waypaper itself) → its post_command, which you set
  → wallust-theme-manager.sh --generate-palette
      → wallust run: rewrites every template (Hyprland colors.lua, Waybar CSS,
        rofi, kitty, cava, hyprlock theme)
      → ~/.local/state/hyprflow/theme = "auto" (the theme picker marks it)
      → hyprctl reload
      → rgb-sync.sh WALLPAPER: dominant hue → OpenRGB, cached for --last
      → waybar-restart.sh
      → hyprlock/geometry.sh --wait-backdrop (detached): rebuilds the blurred
        lockscreen backdrop
      → with --notify: the OSD says "Theme · Wallpaper" (or the preset's name)
```

A preset instead: Super+K → Theme →
`theme-picker.sh --toggle` → the Quickshell panel (`--json` lists them, a pick
runs `--set NAME`; the fzf picker itself in a terminal or over SSH) →
`wallust-theme-manager.sh --theme NAME` → `wallust cs`, then the same chain
(the state file gets NAME).

### Locking

```
Super+Alt+L or the power menu's Lock → hyprlock-flow.sh
  → hyprlock/geometry.sh: writes hyprlock-geometry.conf and -extras.conf for
    the monitor holding workspace 1 (avatar.sh, backdrop.sh on the way)
  → hyprlock, which then polls layout.sh (2 s), music.sh (5 s) and, on a
    machine with a battery, battery.sh (30 s)
```

### Game mode

```
hold PS + Options (pad-listener.py) or `game-mode.sh on`
  → state file in ~/.local/state/hyprflow/game-mode, written first
  → monitors.sh solo on TV     (the other screens off)
  → Waybar stopped (or the Quickshell bar hidden: `ipc call bar hide`), LEDs
    off, do not disturb, audio to the TV, Big Picture
  → gamemode.lua keeps the game settings on every reload while the file exists
  → the OSD says "Game mode · On/Off" (do not disturb is on, so the panel
    ignores a notification; notify only if Quickshell is not running)
Big Picture closed → gamemode.lua → game-mode.sh bigpicture-closed → off
off → reads the state file and undoes each step
```

### Taking a screenshot

```
Super+Shift+S submap (keybindings.lua) → r/w/s (region/window/screen) or
  Shift+r/w/s (to the clipboard)
  → the submap HUD is dismissed first (or the frozen shot shows it)
  → lib/screenshot.sh MODE [--clipboard] → hyprshot, piped into satty
      (satty saves to ~/Pictures/Screenshots/<date>.png, right-click copies,
       --disable-notifications: the toast is ours, not satty's)
  → the saved path comes from satty's stderr "File saved to '<path>'." line, so
    "Save as" (a path the user picked) is announced too, not just the direct save
  → a saved shot: a notification whose body is an <img> of the shot (swaync
    draws it as a small preview at the bottom) followed by its path, with an
    "Open" button (dotconfig/swaync) that runs xdg-open
  → a copy (Shift+r/w/s, or right-click in satty): "Copied to clipboard" with
    a preview; Shift+ uses hyprshot --raw + our wl-copy (--clipboard-only
    returns before it has copied), satty copies through `screenshot.sh _copy`
```

### Switching the audio output

```
Waybar volume click, the Quickshell bar's volume right click (its click opens
SoundView: outputs, apps, microphone) or Super+K → Audio output → lib/sink-switch.py --toggle
  → qs ipc call sinkswitch toggle → SinkSwitch.qml (rofi without Quickshell)
      → sink-switch.py --json: pw-dump sinks, minus ~/.config/hyprflow/sink-switch.conf
  → a pick runs sink-switch.py --set ID
      → wpctl set-default, pactl moves the running streams (unless --no-sync)
      → without Quickshell, a notification names the output
`sinkswitch` (bin/) is the same script, for the terminal or SSH
Osd.qml watches the default sink: any change (a pick, or Pipewire falling back
when AirPods leave) settles 0.8 s, then "Audio output · NAME" with the glyph
and label from sink-switch.py --json; never at start
```

### Notifications

`lib/hyprflow/notify.py` (Python) and `common.sh`'s `notify` (Bash) are the one
way to raise a toast, so every script speaks the same options (urgency, icon,
timeout, category, an action button). A button is an `-A key=label` action; the
command it runs is matched on the app name in
`dotconfig/swaync/config.json` (`scripts`, `run-on: action`), so a
notification carries a single action. `style.css` imports swaync's own and
restyles it like the OSD card (white symbolic icons, same type and spacing).
The panel is `swaync`; the bar's `custom/swaync` widget drives it
(`swaync-client -swb/-t/-d`); `Super+N` toggles the panel, `Super+Shift+N`
clears it.

### The bar

Two bars, one at a time; the flag file `~/.local/state/hyprflow/qs-bar` says
which. `qs -c hyprflow ipc call bar enable` writes it and stops Waybar;
`disable` removes it and starts Waybar again (`waybar-restart.sh` reads the
flag, so nothing else brings Waybar back meanwhile).

```
Quickshell bar (dotconfig/quickshell/hyprflow/bar/, see docs/bar.md)
  Bars.qml: one Bar per screen, its type from bars.json (monitors.py),
            its layout from bar.json; hidden during game mode
  → Cluster (left / center / right) → ModuleLoader: a name → modules/<Type>.qml
  → a module: native (Hyprland, Pipewire, Mpris, tray) or `custom`, which runs
    the same scripts as Waybar and reads their JSON
Super+B → ipc call bar toggle, and SIGUSR1 to Waybar (whichever is up)
a click on a module that opens a panel → bar.expand: its card grows down
  into it (calendar, volume / microphone views, the full player)
calendar events: calendar-events.py add (or any sync) → ~/.local/share/
  hyprflow/calendar/YYYY-MM.json → CalendarPanel reads last, this and next
  month (upcoming until each event ends) and the month on screen (its days)
```

Waybar starts each module in `modules.json` as a long running process.
The Python ones are `WaybarModule`s: they print JSON whenever their events
say something changed, and log failures to the journal
(`journalctl -t hyprflow`) while they retry.

| Module | Reads | Events |
|--------|-------|--------|
| `battery-hub.py` | UPower, headsetcontrol, the Bolt receiver, AirPods LE adverts | UPower signals, receiver reports, polls, short LE scans |
| `mute_indicator.py` | `wpctl` | `pactl subscribe` |
| `vpn_status.py` | `pgrep openconnect/vpnc` | `ip monitor link` |
| `camera_status.py` | who holds `/dev/videoN` | inotify on `/dev` |
| `cava_waybar.py` | cava's bars | cava itself |

Clicks: battery-hub `--toggle` (all devices) and `--lights` (headset); the
volume module, `sink-switch.py --toggle` (see above).

### Keybindings that run scripts

| Keys | Script |
|------|--------|
| Super+I | `qs ipc call keyguide toggle` → KeyGuide.qml; without Quickshell, `help-binds.sh` → `help-binds-parse.py` reads keybindings.lua → rofi |
| Super+D, 4-finger pinch out | `hyprland-show-desktop.sh` |
| Super+Shift+Q | `close-workspace.sh` |
| Alt+G | `hyprland-group-all.sh` |
| Super+Shift+Return | `master-pick.py` |
| Super+K | `qs ipc call quickactions toggle` → QuickActions.qml (it reads `quick-actions.py --json`); without Quickshell, `quick-actions.py` → rofi |
| Super+W / Super+Shift+W / Super+M | `session-manager.py` save / load / logout |
| Waybar power button, Super+K → Power menu | `qs ipc call power toggle` → PowerMenu.qml: Lock (`hyprlock-flow.sh`) and Suspend at once; Log out (`session-manager.py logout --yes`), Reboot and Shut down on a second press |
| Volume, mute and brightness keys | `volume.sh` / `brightness.sh` → the Quickshell OSD (a notification without it); the OSD also watches Pipewire, so a headset's own buttons show it |
| Next and previous keys, Super+. / Super+, | `media.sh` → the Quickshell OSD (the skip glyph) |

### Syncing a change

`install.sh config` → copies `dotconfig/` into `~/.config` (keeping the
palette, monitor layout and bars this machine generated), links `bin/` and
`lib/`, then `monitors.sh apply` and a Waybar restart. Hyprland reloads by
itself: autoreload picks up the copied .lua files.

## Patterns

- **Template Method**: `WaybarModule.run()` fixes the loop (die with Waybar,
  skip repeated lines, restart a dead event source); a module only writes
  `state()` and `events()`.
- **Adapter + Observer**: battery-hub turns UPower, headsetcontrol, the Bolt
  receiver and AirPods (Bluetooth LE) into one `Device`; each source
  `watch()`es its own events.
- **Repository + Strategy + injection**: session-manager keeps layouts behind
  `Layouts`, asks through a `Menu` (rofi today), and `main()` wires them.
- **Repository**: monitors.py keeps profiles behind `Profiles`; the layout
  logic is pure functions.
- **Command**: each quick action is an `Action` (label, state, what to run);
  the Super+K menu only lists them, so a new one is one more entry.
- **Strategy, shared**: `hyprflow.menu` is the one rofi menu both
  session-manager and quick-actions ask through.
- **Facade**: `hyprflow.hyprland` is the one way to talk to Hyprland (through
  its `hyprctl` command and event socket); every failure comes out as
  `HyprlandError`, an `OSError`.
- **Quickshell panels**: every panel is an `Overlay` (the window, the fold
  open and closed, keyboard and click outside) plus its content; durations
  and curves live only in `Motion`, colours in `Colors` (fixed). The data
  stays in Python: the Super+K panel draws `quick-actions.py --json` and
  runs `--run LABEL`, so rofi and Quickshell share one list of actions; the
  audio switcher the same way (`sink-switch.py --json` / `--set ID`).
  A confirmation is asked through IPC with a pipe to answer on
  (`QuickshellMenu.confirm`), so the scripts wait for it as they wait for rofi.
  The OSD is a HUD (`interactive: false`) and hides itself, so no key ever
  leaves the app; a volume or mic bar can still be dragged with the mouse. Brightness pushes it through IPC with `common.sh`'s `osd`;
  audio does not: the OSD watches Pipewire's default sink and source itself
  (the source as `pw-metadata` names it, since Quickshell drops a configured
  one that is not there), so
  the headset's own volume buttons show it too, and `volume.sh` only asks
  `quickshell_up` before it falls back to a notification. The keyboard layout
  the OSD takes from Hyprland's own `activelayout` event; what has no service
  and no key of ours to push it -- play/pause, Caps/Num Lock, do not disturb --
  `osd-watch.py` watches (`playerctl`, the lock LEDs, `dconf`), while a skip is
  `media.sh`'s, the direction being the key's. A negative value draws no bar.

## Adding a bar module

Any Waybar module works as usual: a built-in one, or a `custom/` module running
whatever script you like. Define it in `dotconfig/waybar/modules.json` and place
it in `bars.json`.

`WaybarModule` is an optional shortcut for your own Python scripts that stream
JSON to the bar and update on events. Subclass it, write `state()` (what to show)
and `events()` (when to look again), and it handles the output and the loop.

## Tests

Every script in `bin/` and `lib/`, Python and Bash alike, has tests in `tests/`, run with pytest. They use no real devices or services: the commands a script calls (hyprctl, wpctl, openrgb...) are fakes that log what they were asked, so the tests run anywhere without touching the screens, the sound or the lights:

```bash
python -m venv --system-site-packages .venv   # sees python-gobject from the system
.venv/bin/pip install pytest vermin   # vermin checks the minimum Python
.venv/bin/pytest
```
