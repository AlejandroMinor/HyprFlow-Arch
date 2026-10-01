# Development

## Layout

- `bin/`: commands you run, linked into `~/.local/bin` (on PATH).
- `lib/`: what only Waybar, the keybindings or other scripts call, linked into
  `~/.local/lib/hyprflow` (off PATH). Shared code lives here too:
  - `lib/hyprflow/` (Python): `paths`, `hyprland` (a facade over Hyprland),
    `notify`, `palette`, `lock` (one copy at a time), `menu` (rofi) and
    `waybar` (`WaybarModule`).
  - `lib/common.sh` (Bash): `msg`, `warn`, `notify`, `load_palette`, and where
    `bin/` and `lib/` are.
- `dotconfig/`: copied into `~/.config` by `install.sh config`.
- `packages/`: the package lists install.sh reads.

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
