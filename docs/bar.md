# Quickshell bar

The bar that replaces Waybar, with the panels' look and motion: clusters that
drop in, a workspace pill that slides to the active one, drawers that slide
open, a visualizer, a spinning cover, a calendar under the clock.

```bash
bash install.sh config --bar=quickshell   # use it (a full install asks)
bash install.sh config --bar=waybar       # back to Waybar
```

The choice is kept (the flag file `~/.local/state/hyprflow/qs-bar`) and
holds at every login. The same, live, without the installer:
`qs -c hyprflow ipc call bar enable | disable`.

`Super + B` hides and shows it; game mode hides it.

## Where things are

```
dotconfig/quickshell/hyprflow/bar/
  bar.json          what goes where, each module's settings, the style
  styles/           the looks: clusters.json (every value), others on top
  Bars.qml          a bar per screen (type from monitors.sh: full, minimal, none)
  Bar.qml           the window and its three clusters
  Cluster.qml       a card of modules
  ModuleLoader.qml  a name from bar.json → modules/<Type>.qml
  Module.qml        what a module is: icon, text, hover, clicks, tooltip, polling
  modules/          one file per kind of module (what bar.json names)
  panels/           what a card opens into (bar.expand): CalendarPanel,
                    SoundView (volume and microphone), MediaPanel (the player)
                    and MediaSkinPicker (its cog), BatteryPanel, TrayMenu (a
                    tray app's menu)
  widgets/          pieces the panels share: BarSlider, Ring, BarTooltip,
                    TextField, PanelButton, Spectrum (cava's six styles),
                    SkinFace (the cover, or a NowSpinning skin)
  services/         singletons with the data, no drawing: AudioState
                    (Pipewire), BarTheme (the accent), CalendarEvents (the
                    calendar's files and changes), CavaLevels (one cava for
                    every bar, and the style), MediaSkin (the player's
                    skin), Paths (where things live)
  nowspinning/      link to the NowSpinning submodule (install.sh config)
```

Motion and colours come from `Motion.qml` and `Colors.qml`, like the panels.
The bar reloads on save.

## Styles

One line in bar.json picks the look, as Waybar's `@import 'style-….css'`:

```jsonc
"style": "clusters",     // a file in styles/
```

`styles/clusters.json` holds every value the bar draws with: card height,
gaps and margin, radii, opacities, font sizes, the workspace pill. Another
style lists only what it changes and takes the rest from clusters, one level
deep, so `{"card": {"radius": 20}}` keeps the card's fill and border:

```jsonc
// styles/single.json: one card across the screen
{ "cards": "single" }
```

A new style is a new file in `styles/` and its name in that line.

The accents take the LED colour (`~/.cache/wallust/led-color`, the dominant hue
of the wallpaper that rgb-sync.sh picks; `services/BarTheme.qml`), like the
focus border: the
active workspace, the sliders, the play button, today, Save, the event under
way, the hovers, what is picked in a panel, the open panel's module, the
Claude ring and the notification badge. Everything else stays black and
white. `"colors": false` turns
the accents white too.

## Opening a card downward

A module can grow its card into a panel, the bar seeming to stretch open
(the calendar, the volume and microphone views, the full player, every
battery):

```qml
Module {
    id: mod
    onClicked: bar.expand(mod, panel, 320)   // again, or a click elsewhere, closes
    Component { id: panel; Item { implicitHeight: 200; /* … */ } }
}
```

The card widens to the width asked for and grows to the panel's
`implicitHeight`; the panel sits under the module that opened it.

## The spectrum

cava draws in one of six styles: bars, equalizer, LEDs, dots, wave or
mirror. Super+K → Spectrum style shows them all live and saves the pick
(`~/.local/state/hyprflow/cava-style`); the bar switches at once.

## The player's skin

The full player draws its cover plain or with a skin from
[NowSpinning](https://github.com/AlejandroMinor/NowSpinning) (the
`modules/NowSpinning` submodule): vinyl, CD, bare disc or cassette, spinning
with the track. Its cog shows every skin live with what is playing, and under
the picked one its own options (tonearm, turntable, disc side, clear shell).
Both are saved in `~/.local/state/hyprflow/media-skin.json`. A skin missing
from the submodule's checkout is left out of the picker.

## Calendar events

The clock's panel lists what comes up, and a click on a day shows that day's
events. They come from one JSON file per month, kept as history:

```jsonc
// ~/.local/share/hyprflow/calendar/2026-10.json
[{ "title": "Daily", "start": "2026-10-17T10:00", "end": "2026-10-17T11:00", "where": "Teams",
   "link": "https://teams.microsoft.com/l/meetup-join/…" }]
```

An event stays in the list until its end, marked "now" while it runs. On
the bar, a dot by the clock's icon says today still has events; it pulses
while one runs or starts within fifteen minutes. Its tooltip names the next
one.
In the panel, "+" adds one on the picked day (today if none), the pencil on a
row edits it and × deletes it (a second click confirms). The same from a terminal, or over SSH:

```bash
calendar-events.py add "Daily" 2026-10-17T10:00 2026-10-17T11:00 --where Teams \
    --link https://teams.microsoft.com/l/meetup-join/…   # two clicks on it open the call
calendar-events.py add "Holiday" 2026-11-02          # a date alone: all day
echo '[{"title": "Daily", "start": "2026-10-17T10:00"}]' | calendar-events.py add -
#   one object, a list or several in a row (an iOS Shortcut's dictionaries);
#   without "link", the call's URL is taken from "notes"
calendar-events.py list 2026-10                       # each with its key
calendar-events.py edit a5fbf0 --start 2026-10-17T12:00   # keeps its length
calendar-events.py remove a5fbf0
```

A call shows its service's icon by the link (Teams, Meet, Discord, Slack,
WhatsApp; `callIcons` in panels/CalendarPanel.qml), any other link a camera.

Anything else may write the files too (a sync from Outlook or Google), and
the bar redraws when one changes.

## bar.json

```jsonc
{
  "bars": {
    "full":    { "left": ["launcher", "workspaces"], "center": ["media"], "right": ["clock"] },
    "minimal": { "center": ["workspaces"] }
  },
  "modules": {
    "clock": { "format": "dd/MM HH:mm" }
  }
}
```

A name loads `modules/<Name>.qml` (`clock` → `Clock.qml`,
`system-tools` → `SystemTools.qml`) with `modules.<name>` as its settings.
With a `"type"`, that file loads instead, so one kind serves many names.

## Adding a module

**A script**: anything that already works as a Waybar custom module.
Same keys as Waybar:

```jsonc
"weather": {
  "type": "custom",
  "exec": "~/.local/lib/hyprflow/weather.sh",   // JSON or text, a line per update
  "interval": 600,                              // without it: keeps running
  "format": "{}",
  "on-click": "xdg-open https://wttr.in"
}
```

Also `tooltip`, `on-click-right`, `on-click-middle`, `on-scroll-up`,
`on-scroll-down`, and `font` / `font-size` for glyph fonts. Without `exec`,
`format` is a fixed label (the launcher and power buttons are this).
A glyph the script puts first is shown as the icon. Beyond Waybar's keys:

- `icon`: a glyph in place of the script's own.
- `ring`: `true` draws a ring filled to the JSON's `percentage` instead of
  the icon (claude-usage).
- `classes`: per class the script reports, its own `format` and `dim`, the
  way Waybar's CSS styled `#custom-vpn.vpn-status-warning`:

```jsonc
"classes": {
  "vpn-status-active":  { "format": "\udb81\udc83" },
  "vpn-status-warning": { "format": "\udb82\udd9e", "dim": true }
}
```

**A drawer**: modules that slide out of a handle.

```jsonc
"hardware": { "type": "drawer", "modules": ["runcat", "cpu", "memory"] }
```

The first module is the handle, or set `"icon"` for a plain one.

**A QML module**: when it needs a native source (Pipewire, Mpris,
Hyprland) or its own drawing. A file in `modules/`, built on `Module`:

```qml
// modules/Uptime.qml
import QtQuick
import qs.bar

Module {
    icon: "\u{F0954}"
    poll: ["cat", "/proc/uptime"]          // run every `interval` seconds
    interval: 60
    onPolled: out => text = Math.floor(out.split(" ")[0] / 3600) + "h"
    onClicked: run("kitty -e btop")        // run(): through the shell, as Waybar
}
```

Then `"uptime"` in a layout. `Module` gives `icon`, `text`, `dim`, `tooltip`,
`hovered`, the click and scroll signals and `settings` (its bar.json entry).
A module that draws its own content puts it inside `Module { … }` and that
replaces the icon and text (see `Media.qml`, `Notifications.qml`).

`tests/test_quickshell_bar.py` checks that every name in bar.json has its file.
