# Scripts and submodules

**Commands.** Everything in `bin/` lands in `~/.local/bin`, on your `PATH`:

| Script | Description |
|--------|-------------|
| `monitors.sh` | Monitor wizard: `list` / `setup` / `apply` / `mirror` / `solo`; hotplug `apply` and mirror/solo announce the new layout |
| `game-mode.sh` | Controller friendly mode for the TV: one screen, no effects, Big Picture; says on and off on the OSD |
| `wallust-theme-manager.sh` | Generate and apply color palettes |
| `theme-picker.sh` | Picks the wallpaper palette or a preset from `~/.config/wallust/themes/`, each with its colours and the one in use marked; the Quickshell panel from `Super + K`, and the fzf picker in a terminal or over SSH (`--json` / `--set NAME` work without a display) |
| `rgb-sync.sh` | Match the OpenRGB lighting to the wallpaper or theme |
| `pet-picker.sh` | Switch the bar's runner (cat / chicken): the Quickshell bar at once, Waybar after a restart |
| `hyprlock-flow.sh` | Rebuild the lockscreen layout, then lock |
| `sinkswitch` | Pick the audio output from the terminal or over SSH (`sinkswitch --json` / `--set ID` work without a display); the short name for `lib/sink-switch.py` |

**Internal.** `lib/` holds what only Waybar, the keybindings or other scripts
call. It lands in `~/.local/lib/hyprflow`, off your `PATH`, and the configs call
each one by its full path:

| Script | Called by | Description |
|--------|-----------|-------------|
| `battery-hub.py` | Waybar | Every battery (laptop, mice, keyboards, controllers, headsets) from UPower, headsetcontrol, Logitech Bolt receivers and AirPods Max (their Bluetooth LE broadcast, in 10 % steps) in one module: click for all of them (the Quickshell bar: a panel with each one, the middle click switches the view), right click for the headset lights, notifications when one runs low (the laptop's with a "Power saver" button) |
| `mute_indicator.py` | Waybar | Audio at a glance: output muted, and a badge while the microphone is muted |
| `volume.sh` | Volume and mute keys | Change volume or mute; the level shows on the Quickshell OSD (it watches Pipewire, so the headset's own buttons show it too), or a transient notification without Quickshell |
| `brightness.sh` | Brightness keys | Change the panel backlight; the level shows on the Quickshell OSD, or a notification without it |
| `media.sh` | Next and previous keys | Skip the track; the Quickshell OSD shows the matching skip glyph (play and pause the OSD shows by watching the player, which also catches Spotify's own controls) |
| `screenshot.sh` | `Super + Shift + S` submap | Capture a region, window or screen with hyprshot and annotate it in satty; a saved shot becomes a notification with an "Open" button (`dotconfig/swaync`), a copy goes straight to the clipboard |
| `osd-watch.py` | Hyprland | Shows the Quickshell OSD for what no key of ours reports: play/pause (`playerctl`), Caps/Num Lock (the lock LEDs) and Do Not Disturb (`dconf`) |
| `camera_status.py` | Waybar | Camera-in-use indicator |
| `vpn_status.py` | Waybar | VPN status |
| `cava_waybar.py` | Waybar | Audio visualizer, dims to a baseline when silent |
| `runcat-text` | Waybar | Animated CPU runner |
| `claude-usage.sh` | Waybar | Claude Code rate-limit indicator |
| `help-binds.sh` | `Super + I` | Keybinding cheatsheet |
| `master-pick.py` | `Super + Shift + Return` | Number windows and swap one to master |
| `close-workspace.sh` | `Super + Shift + Q` | Close every window in the workspace, after a confirmation |
| `hyprland-group-all.sh` | `Alt + G` | Group every window in the workspace |
| `hyprland-show-desktop.sh` | `Super + D` | Show the desktop |
| `battery-push.py` | SSH from another device (an iOS Shortcut) | Keeps the batteries other devices send (`add -`, JSON on stdin) for battery-hub, each for a day; `list`, `clear`. See optional-setup.md |
| `calendar-events.py` | the calendar's +, pencil and ×, you (or SSH), a sync later | Adds (also as JSON on stdin), edits, removes and lists the events the bar's calendar shows: one JSON file per month in `~/.local/share/hyprflow/calendar/`, kept as history |
| `session-manager.py` | `Super + W` / `Shift + W` | Save window layouts and reopen them from a menu; `logout` saves the session and leaves (Log out in the power menu) |
| `quick-actions.py` | `Super + K` | The Quickshell panel (rofi when Quickshell is not running) to mirror or solo the screens, toggle game mode, the lights, the microphone and do not disturb, pick the audio output or power profile, switch the keyboard layout, open the power menu, change the wallpaper, the theme or the bar's spectrum style; switches show their state, and actions whose program is missing are hidden |
| `confirm.py` | `close-workspace.sh` | Asks a yes/no question on the Quickshell panel (rofi when it is not running) and prints the answer |
| `power-profile.sh` | `Super + K` | Switches to the next power profile and says which one is on (the Quickshell OSD, or a notification without it) |
| `layout-picker.py` | `Super + K` | Picks the active keyboard layout among the ones declared in `hyprland.lua` (`es,us`): the chosen one moves to the front of `input:kb_layout`, and the OSD confirms it (a notification without Quickshell) |
| `sink-switch.py` | `sinkswitch` / Waybar / `Super + K` | Lists the PipeWire audio outputs and switches the default (moving the running streams too); the Quickshell panel, or a rofi menu without it. A personal `~/.config/hyprflow/sink-switch.conf` (out of the repo) hides outputs |
| `pad-listener.py` | Hyprland | Hold PS + Options (Guide + Menu) on a controller to toggle game mode |
| `headset-watch.py` | Hyprland | Gives the headset its LED colour back when it turns on (`rgb-sync.sh --rescan`) |
| `rgb-hotplug.py` | Hyprland | Rescans OpenRGB when a USB device is plugged in, so it takes the LED colour (or stays off) like the rest |
| `mic-mute-watch.py` | Hyprland | A headset's own mic mute button (any with the standard Phone Mute control) mutes its microphone in Pipewire too, so the bar and the OSD show it |
| `fastfetch-random.sh` | `.zshrc` | fastfetch with a random ascii/image logo |
| `activate-linux.py` | Hyprland, Super+K | The "Activate Linux" watermark, click-through, bottom right; `--toggle` switches it off/on |
| `monitors.py` | `monitors.sh` | The monitor logic behind the command |
| `hyprflow/` | the Python scripts | Shared package: paths, hyprctl, notifications, palette, the Waybar module base |
| `common.sh` | the Bash scripts | Shared paths, messages, notifications (with urgency, icon, timeout, category and an action button), the Quickshell level OSD (`osd`, `quickshell_up`) and palette |

## Submodules

Some pieces live in their own repositories and come in as git submodules, under
`modules/`:

| Module | What it gives you | Without it |
|--------|-------------------|------------|
| `runcat-text` | The animated CPU runner in the bar (cat or chicken) | No runner |
| `waybar-claude-usage` | The Claude usage indicator in the bar (needs the Claude Code CLI logged in) | No Claude indicator |

You do not have to fetch them yourself: if you cloned without `--recursive`,
`install.sh` downloads them. If it cannot (no network, say), the install still
finishes, prints which ones are missing, and you get everything except what the
last column lists. Run `install.sh` again later to add them.
