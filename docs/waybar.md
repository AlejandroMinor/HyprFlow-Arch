# Waybar

Each monitor gets one of these:

- **full**: the whole bar. The default for the primary monitor and a laptop's own
  screen.
- **minimal**: only the workspaces. The default for the rest.
- **none**: no bar at all.

`monitors.sh setup` asks which one for every monitor and keeps the answer in that
monitor's profile.

## What is in the full bar

| Side | Modules |
|------|---------|
| Left | launcher, workspaces, hymission overview, hardware (runner, CPU, temperature, memory, disk, network) |
| Centre | media (visualizer and player) |
| Right | system tools (updates, taskbar, tray, keyboard layout, theme), Claude usage, privacy (screen share, microphone, camera), batteries, submap, audio, VPN, notifications, clock, power |

Hardware, system tools, privacy and audio are drawers: only their first icon shows,
and clicking it opens the rest.

## Where to edit

The files live in `dotconfig/waybar/` in the repo. Edit them there and run
`install.sh config` to copy them into `~/.config/waybar`; editing the copies in
`~/.config` works too, but the next `install.sh config` overwrites them.

| To change… | Edit |
|------------|------|
| What a module shows or does on click | `modules.json` |
| Which modules a bar has, and where | `bars.json` |
| How the bar looks | `style.css` (see [Styles](#styles)) |
| Which monitor gets which bar | nothing here: `monitors.sh setup` |

`~/.config/waybar/config` is generated: `monitors.sh` builds it from `bars.json`,
one bar per monitor, each set to that monitor and sized to it. Do not edit it; it
is rewritten on the next `monitors.sh apply`.

## Adding or removing a module

To add one:

1. Define it in `modules.json`. Waybar's built-in modules (`clock`, `cpu`...) can
   skip this if the defaults are fine.
2. Put its name in `modules-left`, `modules-center` or `modules-right` of the bar
   you want in `bars.json`.
3. Run `install.sh config` to copy the files, then `monitors.sh apply` to rebuild
   the bars. Waybar restarts on its own.

To remove one, take its name out of `bars.json` and do step 3. Its definition can
stay in `modules.json`; unused ones are ignored.

A module can run any script of yours. For Python scripts that update on events,
there is a shortcut; see [Adding a bar module](development.md#adding-a-bar-module).

## Styles

Four variants: `style-minor`, `style-island`, `style-glass` and `style-clusters`.
`style.css` imports one of them; change that import to switch:

```css
@import 'style-clusters.css';
```

Colours are not in these files: every variant takes them from the wallust palette,
so the bar follows the wallpaper or theme on its own.

## Audio

The speaker icon is always there: struck through when the output is
muted, with a microphone badge next to it while the mic is muted, so a muted mic
is never a surprise in a call. Its tooltip names both devices and their volume.
Click it for the drawer: output volume (click to switch output, right click for
the mixer) and the microphone (click to mute, scroll for its volume).

## Runner

`custom/hardware-wrap` is an animated runner that speeds up with CPU load
and opens the hardware drawer. It comes from the
[runcat-text](https://github.com/AlejandroMinor/runcat-text) submodule, which ships
two runner fonts (cat and chicken, sharing codepoints `U+E900`-`U+E904`). Run
`pet-picker.sh` to switch, or edit `runcat-runner.css`, the one file all four
styles import. Tunables (icons, CPU thresholds, FPS) live in the submodule's
`config.json`.
