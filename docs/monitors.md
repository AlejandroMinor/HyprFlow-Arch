# Monitors

`monitors.sh` identifies monitors by **description** (`NZXTCANVAS27Q...`) instead of
connector name (`DP-2`), which changes between reboots. It saves one profile per set
of connected monitors and regenerates both the Hyprland and Waybar config from it.

| Command | What it does |
|---------|--------------|
| `monitors.sh list` | Print each monitor's description, port, current mode (`off` when disabled) and preferred mode |
| `monitors.sh setup` | Wizard: enable, resolution, refresh rate, rotation, scale, bar type, order, primary, mirror |
| `monitors.sh apply` | Non-interactive: load the matching profile and regenerate |
| `monitors.sh mirror [on [MONITOR]\|off\|toggle]` | Clone every monitor onto one (default: primary), or restore the extended layout |
| `monitors.sh solo [on [MONITOR [MODE]]\|off\|toggle]` | Keep one monitor on and switch the rest off (default: primary), or restore the layout |

It generates these in `~/.config` (not tracked in the repo):

- `hypr/monitors_active.lua`: `hl.monitor` + workspace rules, positioned left → right
- `waybar/config`: one bar per monitor, matched by identifier (`make model serial`)
- `hypr/monitor-profiles.json`: saved profiles
- `hypr/monitor-profiles.unmirrored.json`: the extended layout `mirror off` restores
- `hypr/monitor-solo.json`: the screen solo mode keeps on, while it is active

No daemon. `apply` runs on login and on hotplug (via `hl.on("monitor.added")` in
`hyprland.lua`), and only reloads if the output actually changed.

Rotation uses native Hyprland transforms (`0` normal, `1`/`3` portrait, `2` upside
down, `4-7` flipped). Portrait swaps width/height automatically.

`setup` asks for the resolution first, defaulting to the preferred one and listing the rest largest first, each with every refresh rate it offers. A TV often prefers 4K at 30 Hz, where 1080p at 60 Hz plays far better. Then it lists the refresh rates at that resolution, fastest first, and defaults to the fastest: many high refresh panels advertise 60 Hz as their preferred mode. Only resolutions and rates from those lists are accepted.

## Mirror mode

Clone every monitor onto one, e.g. to show the laptop on a TV:

```sh
monitors.sh mirror                # toggle between mirror and extended
monitors.sh mirror on             # clone the primary monitor
monitors.sh mirror on eDP-1       # clone a specific monitor, by port…
monitors.sh mirror on "AMZ FireTV"  # …or by description
monitors.sh mirror off            # back to the extended layout
```

`mirror on`:

1. Saves the current extended layout to `hypr/monitor-profiles.unmirrored.json`.
2. Picks the largest resolution every monitor supports, each at the refresh rate closest to its current one. A 4K TV mirroring a 1080p laptop runs at 1080p.
3. Clones the source onto the rest. Mirrored monitors get no workspaces and no bar.
4. Saves it as the profile for this set of monitors and reloads Hyprland + Waybar.

`mirror off` restores the saved extended layout (or the default one if there is none). Because the result is a regular profile, unplugging and replugging the same monitors brings the mirror back. `setup` also offers it at the end (`Mirror mode? [y/N]`), cloning onto the monitor you picked as primary.

In `monitor-profiles.json`, a mirrored monitor is an entry with a `mirror` key holding the source's description:

```json
{ "description": "AMZ FireTV", "mode": "1920x1080@60", "mirror": "Lenovo Group Limited 0x40A9", ... }
```

## Solo mode

Keep a single screen on and switch the others off, e.g. to play on the TV with the monitors dark:

```sh
monitors.sh solo                            # toggle
monitors.sh solo on                         # keep the primary monitor
monitors.sh solo on HDMI-A-1                # a specific one, by port or description
monitors.sh solo on HDMI-A-1 3840x2160@120  # and switch it to another mode
monitors.sh solo off                        # back to the previous layout
```

Unlike mirror, solo is not saved as a profile: `solo on` records the screen in `hypr/monitor-solo.json`, and while that file exists every `apply` (a reload, a hotplug) keeps only that screen on, whatever else is connected. That matters because a switched off DisplayPort monitor goes to sleep after a few seconds and reports itself disconnected, which changes the set of connected monitors; keyed on the set, solo would fall back to another layout and wake everything up. `solo off` removes the file and restores the saved profile. The remaining screen becomes the primary one with every workspace; a mode is only accepted if the monitor offers it. A monitor that is not in the profile yet, like a TV plugged in after `setup`, joins with its default settings.

Switched off monitors are written as `disabled = true`. Leaving a monitor out of the file is not enough: Hyprland turns on any monitor it has no rule for. The same applies to monitors you decline in `setup`.
