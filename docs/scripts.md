# Scripts and submodules

**Commands.** Everything in `bin/` lands in `~/.local/bin`, on your `PATH`:

| Script | Description |
|--------|-------------|
| `monitors.sh` | Monitor wizard: `list` / `setup` / `apply` / `mirror` / `solo` |
| `game-mode.sh` | Controller friendly mode for the TV: one screen, no effects, Big Picture |
| `wallust-theme-manager.sh` | Generate and apply color palettes |
| `theme-picker.sh` | Interactive theme selector |
| `rgb-sync.sh` | Match the OpenRGB lighting to the wallpaper or theme |
| `pet-picker.sh` | Switch the Waybar runner (cat / chicken) |
| `hyprlock-flow.sh` | Rebuild the lockscreen layout, then lock |
| `sinkswitch` | Quick audio output switcher |
| `trackpad-battery` | Apple Magic Trackpad battery, read from the trackpad itself |

**Internal.** `lib/` holds what only Waybar, the keybindings or other scripts
call. It lands in `~/.local/lib/hyprflow`, off your `PATH`, and the configs call
each one by its full path:

| Script | Called by | Description |
|--------|-----------|-------------|
| `battery-hub.py` | Waybar | Every battery (laptop, mice, keyboards, controllers, headsets) from UPower, headsetcontrol and Logitech Bolt receivers in one module: click for all of them, right click for the headset lights, notifications when one runs low |
| `mute_indicator.py` | Waybar | Audio at a glance: output muted, and a badge while the microphone is muted |
| `volume.sh` | Volume keys | Change volume or mute, with a transient notification showing the level |
| `camera_status.py` | Waybar | Camera-in-use indicator |
| `vpn_status.py` | Waybar | VPN status |
| `cava_waybar.py` | Waybar | Audio visualizer, dims to a baseline when silent |
| `runcat-text` | Waybar | Animated CPU runner |
| `claude-usage.sh` | Waybar | Claude Code rate-limit indicator |
| `help-binds.sh` | `Super + I` | Keybinding cheatsheet |
| `master-pick.py` | `Super + Shift + Return` | Number windows and swap one to master |
| `close-workspace.sh` | `Super + Shift + Q` | Close every window in the workspace, with confirmation |
| `hyprland-group-all.sh` | `Super + Shift + G` | Group every window in the workspace |
| `hyprland-show-desktop.sh` | `Super + D` | Show the desktop |
| `session-manager.py` | `Super + W` / `Shift + W` / `M` | Save window layouts and reopen them from a menu; `Super + M` saves the session and logs out |
| `pad-listener.py` | Hyprland | Hold PS + Options (Guide + Menu) on a controller to toggle game mode |
| `fastfetch-random.sh` | `.zshrc` | fastfetch with a random ascii/image logo |
| `activate-linux.py` | Hyprland | The "Activate Linux" watermark, click-through, bottom right |
| `monitors.py` | `monitors.sh` | The monitor logic behind the command |
| `hyprflow/` | the Python scripts | Shared package: paths, hyprctl, notifications, palette, the Waybar module base |
| `common.sh` | the Bash scripts | Shared paths, messages, notifications and palette |

## Submodules

Some pieces live in their own repositories and come in as git submodules, under
`modules/`:

| Module | What it gives you | Without it |
|--------|-------------------|------------|
| `runcat-text` | The animated CPU runner in the bar (cat or chicken) | No runner |
| `waybar-claude-usage` | The Claude usage indicator in the bar (needs the Claude Code CLI logged in) | No Claude indicator |
| `sinkswitch` | The `sinkswitch` command, to switch audio output | No `sinkswitch` |
| `apple-magic-trackpad-battery` | The `trackpad-battery` command | No `trackpad-battery` |

You do not have to fetch them yourself: if you cloned without `--recursive`,
`install.sh` downloads them. If it cannot (no network, say), the install still
finishes, prints which ones are missing, and you get everything except what the
last column lists. Run `install.sh` again later to add them.
