# HyprFlow-Arch

Hyprland + Arch Linux desktop config: multi-monitor, dynamic theming from the
wallpaper, and Waybar modules for peripheral batteries and system status.

![Desktop](assets/screenshots/desktop.png)
![Desktop Alt](assets/screenshots/desktop-alt.png)

## Quick start

```bash
git clone --recursive https://github.com/AlejandroMinor/HyprFlow-Arch.git
cd HyprFlow-Arch
bash install.sh
```

That is the whole install. The script checks your packages, submodules and
Hyprland plugins first, then copies the configs, links the scripts, installs the
fonts and walks you through your monitors. Anything still missing is printed
again at the end with the exact command to fix it, so nothing scrolls past.

Add `--with-deps --with-plugins` and it installs those for you too.

Then press `Super + I` for the keybindings.

### Running it again

It is also the sync tool: name a step and only that step runs. `install.sh config`
is the one you will use most, to push a dotfile change into `~/.config` without
the checks or the monitor wizard.

```bash
install.sh                  # everything
install.sh config           # dotfiles, scripts and fonts, then reload
install.sh check            # just tell me what is missing
install.sh theme            # just recolour
install.sh monitors         # just the monitor wizard
install.sh lockscreen       # just rebuild the lockscreen layout
install.sh zsh              # just install .zshrc
install.sh config theme     # steps combine
```

| Option | Effect |
|--------|--------|
| `--with-deps` | Install the missing packages (pacman, then yay or paru) |
| `--with-plugins` | Install the missing Hyprland plugins (compiles, slow) |
| `--with-zsh` | Include the zsh step in a full run |
| `--help` | The list above |

Cloned without `--recursive`? `install.sh` fetches the submodules itself.

## Requirements

Arch, with Hyprland already running. `install.sh` tells you what you are missing,
so you can run it first and let it decide.

| Tool | Version |
|------|---------|
| Hyprland | 0.56+ |
| Waybar | 0.15.0 |
| eww | 0.6.0 |
| swaync | 0.12.6 |
| wallust | 3.5.2 |
| rofi | 2.0.0 |

<details>
<summary>Full package list</summary>

```bash
sudo pacman -S hyprland hyprlock hyprshot hyprpicker hyprpm waybar rofi swaync wlogout cava awww kitty yazi satty btop fastfetch gnome-disk-utility pipewire pipewire-pulse wireplumber pavucontrol rtkit bluez bluez-utils blueman brightnessctl playerctl upower openconnect network-manager-applet gtk4 gtk4-layer-shell gnome-themes-extra polkit-gnome libnotify xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland ttf-jetbrains-mono-nerd noto-fonts-cjk gnu-free-fonts python python-gobject python-pillow jq curl imagemagick wl-clipboard fzf cpio cmake pacman-contrib noto-fonts-emoji
```

```bash
yay -S eww-git waypaper-git wallust headsetcontrol bibata-cursor-theme-bin
```

These live in the `PACMAN_PKGS` and `AUR_PKGS` arrays at the top of `install.sh`.

</details>

`install.sh` does not enable system services. Bluetooth needs its daemon running:

```bash
sudo systemctl enable --now bluetooth
```

Pairing prompts come from `blueman-applet`, which Hyprland starts at login. Without it BlueZ has nobody to ask and cancels the request, so a device like a DualShock connects for a few seconds and drops.

> Hyprland configs here use the Lua format (`.conf`/hyprlang is deprecated since 0.55).
> The last `.conf` checkpoint is tagged `pre-lua-migration`.

Built around a Logitech MX Master 3S, MX Keys S, and an Apple Magic Trackpad.
That is what the battery modules read. Everything else works without them.

# Customizing

Everything below is optional. Pick the piece you want to change.

| I want to change… | Go to |
|-------------------|-------|
| Which monitor gets which bar, rotation, scale | [Monitors](#monitors) |
| What is in the bar, and how it looks | [Waybar](#waybar) |
| Colors, wallpaper, presets | [Theming](#theming) |
| The lockscreen layout and avatar | [Lockscreen](#lockscreen) |
| The launcher and power menu | [Rofi](#rofi) |
| Hyprland plugins | [Plugins](#plugins) |
| What a given script does | [Scripts](#scripts) |

**Per machine extras.** For things only one machine needs (mounting a games drive, an app to autostart, a device specific setting), create `~/.config/hypr/local.lua`. `hyprland.lua` loads it when it exists and it is not part of the repo, so `install.sh config` never overwrites it:

```lua
hl.on("hyprland.start", function ()
    hl.exec_cmd("udisksctl mount -b /dev/disk/by-label/Games")
end)
```

## Monitors

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

### Mirror mode

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

### Solo mode

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

## Waybar

Three layers. Edit the right one:

| To change… | Edit |
|------------|------|
| A module's behaviour | `waybar/modules.json` |
| Which modules go in a bar | `waybar/bars.json` (`full` / `minimal` archetypes) |
| Which monitor a bar lands on | nothing, `monitors.sh` handles it |

Adding a module means defining it in `modules.json`, placing it in `bars.json`, then
running `monitors.sh apply`. `dotconfig/waybar/config` is only a fallback for when
`monitors.sh` has never run.

**Styles.** Four variants: `style-minor`, `style-island`, `style-glass`,
`style-clusters`. Switch by changing the single `@import` in `style.css`.

**Runner.** `custom/hardware-wrap` is an animated runner that speeds up with CPU load
and opens the hardware drawer. Two fonts ship in the repo (cat and chicken, sharing
codepoints `U+E900`-`U+E904`). Run `pet-picker.sh` to switch, or edit
`runcat-runner.css`, the one file all four styles import. Tunables (icons, CPU
thresholds, FPS) live in `runcat-config.json`.

## Theming

Colors come from `wallust`, regenerated on wallpaper change and pushed to Waybar,
Hyprland, kitty, rofi, wlogout, hyprlock, and cava.

Wire it up in `~/.config/waypaper/config.ini`:

```ini
[Settings]
backend = awww
fill = fill
zen_mode = True
post_command = bash -c "$HOME/HyprFlow-Arch/bin/wallust-theme-manager.sh --generate-palette --notify"
```

Run `theme-picker.sh` to pick between the wallpaper palette and eighteen presets:

- **Classic** — pure black background and a high-contrast ANSI palette. This is the
  default, restored by `wallust-theme-manager.sh --restore-default`.
- **Nocturne** — dark grey background, desaturated everything, for night work.
- **Accent Blue / Red / Yellow / Green / Purple** — a shared neutral grey base where
  a single saturated hue carries the window border, the cursor and the selected
  states, so the terminal stays readable under any wallpaper.
- **Solarized Dark** — the Schoonover palette, tuned for uniform luminance so no
  single color jumps out. Low contrast by design.
- **Phosphor Amber** — a single amber hue stepped by luminance, VT220 style.
- **High Contrast** — every text color clears WCAG AAA (7:1) against pure black,
  for working outdoors or in direct sunlight.
- Tokyo Night, Catppuccin, Nord, Gruvbox, Dracula, Monochrome, Synthwave, Kanagawa.

Cava runs both in the terminal and as the `custom/cava` Waybar module, which hides
itself when there's no audio. Its palette follows wallust too.

## Lockscreen

`hyprlock`, bound to `Super + L` and the wlogout Lock button: oversized clock, glass
bar with avatar and password field, now-playing card. Track details show only for
dedicated music apps, since a lockscreen is visible to passers-by. Media keys keep working
under the lock.

`hyprlock.conf` holds no coordinates. `dotconfig/hypr/hyprlock/geometry.sh` runs before
each lock and writes them, so the layout follows whatever monitor is attached. Edit
that script, never the generated `hyprlock-geometry.conf`.

Content lands on the monitor holding workspace 1; the rest are blurred. Override with
`HYPRLOCK_MONITOR`. The avatar is `~/.config/hypr/avatar.png`. Replace it with any
square image and it's never overwritten, or delete it for the Arch glyph instead.

## Rofi

`dotconfig/rofi/hyprflow/`: real transparency, wallust colors.
`launcher-centered.rasi` is the launcher, reached by `Super + Space`, the
four-finger pinch gesture and the Waybar launcher icon; it builds on
`launcher-base.rasi`. Power menu is `wlogout`, also themed.

## Plugins

| Plugin | Repo | Description |
|--------|------|-------------|
| `hymission` | `gfhdhytghd/hymission` | Mission Control-style overview |
| `hyprglass` | `hyprnux/hyprglass` | Liquid glass on transparent windows |

`install.sh` reports which of these are missing or disabled. It does not install
them unless you pass `--with-plugins`, because `hyprpm` compiles each one against
your running Hyprland, which is slow and can fail. By hand:

```bash
hyprpm update
hyprpm add https://github.com/gfhdhytghd/hymission
hyprpm enable hymission
```

Add a plugin to `PLUGIN_NAMES` and `PLUGIN_REPOS` at the top of `install.sh` and the
check picks it up.

> Animation or invalid-reference errors on startup usually mean the plugins are stale
> relative to your Hyprland version. Run `hyprpm update`.

## Scripts

Everything in `bin/` lands in `~/.local/bin`.

**Theming & layout**

| Script | Description |
|--------|-------------|
| `wallust-theme-manager.sh` | Generate and apply color palettes |
| `theme-picker.sh` | Interactive theme selector |
| `rgb-sync.sh` | Match the OpenRGB lighting to the wallpaper or theme |
| `pet-picker.sh` | Switch the Waybar runner (cat / chicken) |
| `hyprlock-flow.sh` | Rebuild the lockscreen layout, then lock |
| `master-pick.py` | Number windows and swap one to master (`Super + Shift + Return`) |
| `monitors.sh` | Monitor wizard: `list` / `setup` / `apply` / `mirror` / `solo` |
| `hyprland-group-all.sh` | Group every window in the workspace |
| `close-workspace.sh` | Close every window in the workspace, with confirmation (`Super + Shift + Q`) |
| `session-manager/` | Save and restore window layouts |

**Waybar modules**

| Script | Description |
|--------|-------------|
| `battery-hub.py` | Every battery (laptop, mice, keyboards, controllers, headsets) from UPower in one module: click for all of them, right click for the headset lights, notifications when one runs low |
| `trackpad-battery` | Apple Magic Trackpad battery |
| `cava-waybar.sh` | Audio visualizer, hides when silent |
| `claude-usage.sh` | Claude Code rate-limit indicator |
| `mute_indicator.py` | Output mute indicator |
| `camera_status.py` | Camera-in-use indicator |
| `vpn_status.py` | VPN status |

**Misc**

| Script | Description |
|--------|-------------|
| `help-binds.sh` | Keybinding cheatsheet (`Super + I`) |
| `fastfetch-random.sh` | fastfetch with a random ascii/image logo |
| `sinkswitch` | Quick audio output switcher |

## Submodules

| Module | Purpose |
|--------|---------|
| `apple-magic-trackpad-battery` | Trackpad battery reader |
| `sinkswitch` | Audio output switcher |
| `waybar-claude-usage` | Claude usage module, needs the Claude Code CLI logged in |
| `runcat-text` | Animated CPU runner, needs `python` |

The `check` step runs `git submodule update --init --recursive`
for any that are missing, so a clone without `--recursive` still works. If that
fails (no network, no git), it says which ones are missing and keeps going: the
rofi themes and the cat runner font are skipped, and `claude-usage.sh`,
`sinkswitch` and `trackpad-battery` are not linked into `~/.local/bin`.

To drop the Claude module, remove `custom/claude-usage` from `bars.json`.

The `config` step overwrites `runcat-text/config.json` with the repo's
`waybar/runcat-config.json`, so edits survive a submodule update.

# Extras

## Optional setup

**Zsh.** `install.sh zsh` (backs up your `.zshrc` first, and asks before
changing your login shell). Needs
`zsh zsh-autosuggestions zsh-syntax-highlighting zoxide bat` plus `fzf-tab` and
`oh-my-zsh-git` from the AUR. Adds git/sudo/copypath/fzf plugins, autosuggestions,
syntax highlighting, fzf-tab with `bat` preview, and zoxide (`z`, `zi`).

**RGB lighting.** With [OpenRGB](https://openrgb.org) the case lighting follows
the theme: a wallpaper sets it to the image's dominant vivid hue, a preset to its
accent colour, always at full saturation since LEDs wash dim tones out to white.
Without OpenRGB or its server, `rgb-sync.sh` does nothing.

First check that OpenRGB sees your hardware. If an ARGB strip or fan only lights
up partly, open the `openrgb` GUI, resize its zone and save.

```bash
sudo pacman -S openrgb
openrgb -l
```

Then run OpenRGB as a system server. It runs as root because some controllers,
such as NVMe drives, only answer to root; the drop-in binds it to `127.0.0.1`
instead of the whole LAN.

```bash
sudo mkdir -p /etc/systemd/system/openrgb.service.d /etc/openrgb
sudo cp ~/HyprFlow-Arch/system/openrgb.service.d/override.conf /etc/systemd/system/openrgb.service.d/
# Only if you resized zones in the GUI: the root server reads /etc/openrgb.
sudo cp ~/.config/OpenRGB/sizes.ors /etc/openrgb/
sudo systemctl daemon-reload
sudo systemctl enable --now openrgb
```

The colour applies on the next wallpaper or theme change, or right away with
`rgb-sync.sh`.

**Battery notifications.** `battery-hub.py` sends a desktop notification when a device drops below 35 % and an urgent one below 20 %, once per level. To get them somewhere else too (a phone message, say), make `~/.config/hyprflow/battery-hook` executable; it runs with the device name, the percentage and the level (`warning` or `critical`), and stays out of the repo:

```sh
#!/bin/sh
my-phone-notifier "$1 is at $2%"
```

**GTK dark theme**

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
```

**Magic Trackpad.** Permissions and group setup are in the
[submodule README](https://github.com/AlejandroMinor/apple-magic-trackpad-battery-percent-python/blob/main/README.md).

**DisplayLink.** `yay -S displaylink evdi-dkms-git` then
`sudo systemctl enable --now displaylink.service`.

## Troubleshooting

- **Bar on the wrong monitor.** Run `monitors.sh list` to see identifiers, then
  `monitors.sh setup` to rebuild.
- **Script won't run.** `chmod +x <script>`. `install.sh` does this automatically.
- **Swapped a monitor on the same port and it kept the old one's rotation.** Hyprland only notices a new screen after a real disconnect: unplug, wait about five seconds, plug the new one in. Profiles belong to the set of connected monitors (by make, model and serial), so the new set gets the default layout until you run `monitors.sh setup` for it.
- **Screens flicker to default modes for a moment when leaving solo or game mode.** A switched off DisplayPort monitor sleeps and wakes every few seconds, reporting itself disconnected meanwhile; if it drops right as the layout is restored, Hyprland falls back for a few seconds and then settles. Turning off the monitor's deep sleep (often called Deep Sleep or DP Auto Sleep in its menu) avoids it.

## Tests

The Python scripts under `bin/` have unit tests in `tests/`, run with pytest. They use no real devices or services, so they run anywhere:

```bash
python -m venv --system-site-packages .venv   # sees python-gobject from the system
.venv/bin/pip install pytest
.venv/bin/pytest
```
