# HyprFlow-Arch

Complete **Hyprland + Arch Linux** configuration optimized for technical productivity on desktop, with multi-monitor support, Logitech/Apple peripherals, and automated dynamic theming.

## Key Features

- **Automated install** — one script copies configs, creates symlinks, and applies the base theme
- **Dynamic theming** — color palettes auto-generated with `wallust` on wallpaper change
- **Master layout** — main window takes priority, secondary windows stack on the side
- **3-monitor management** — automatic logical mapping via `monitors.sh`, configurable layout (4 with ThinkPad)
- **Peripheral battery in Waybar** — mouse, keyboard, trackpad, and headset in real time
- **Status modules** — VPN, camera, microphone, audio, and DND notifications integrated

## Table of Contents

- [Preview](#preview)
- [Hardware & Peripherals](#hardware--peripherals)
- [Installation](#installation)
- [Included Scripts](#included-scripts)
- [Post-Installation](#post-installation)
- [Hyprland Plugins](#hyprland-plugins)
- [Tips](#tips)

## Preview

![Desktop](assets/screenshots/desktop.png)
![Desktop Alt](assets/screenshots/desktop-alt.png)

## Hardware & Peripherals

Setup designed for the following peripherals, with integrated battery monitoring:

| Peripheral | Model |
|------------|-------|
| Mouse | Logitech MX Master 3S |
| Keyboard | Logitech MX Keys S |
| Trackpad | Apple Magic Trackpad |

### Monitor Layout

Primary desktop setup with 3 monitors. The logical mapping is defined in `monitors_ids.conf` (auto-generated). Current layout left to right:

| Position | Monitor | Resolution |
|----------|---------|------------|
| 1 | AOC | 1080p |
| 2 | NZXT (Primary) | 1440p @ 120Hz |
| 3 | ASUS | 1080p |

> When connecting the ThinkPad it joins as a 4th monitor (`eDP-1`).

## Installation

### 1. Install dependencies

**Official repositories:**
```bash
sudo pacman -S cpio cmake fzf rtkit hyprland waybar yazi kitty awww brightnessctl playerctl pipewire wireplumber pipewire-pulse pavucontrol network-manager-applet upower openconnect jq pacman-contrib swaync hyprshot hyprpicker rofi-wayland ttf-jetbrains-mono-nerd noto-fonts-cjk wl-clipboard satty gnu-free-fonts gnome-themes-extra xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland gnome-disk-utility polkit-gnome
```

**AUR (requires `yay` or another helper):**
```bash
yay -S wlogout eww-git displaylink evdi-dkms-git waypaper-git warp-terminal-bin wallust headsetcontrol bibata-cursor-theme-bin paru
```

### 2. Clone and install

This repo uses **Git submodules** (Rofi themes, trackpad-battery, sinkswitch). Clone with `--recursive`:

```bash
git clone --recursive https://github.com/AlejandroMinor/HyprFlow-Arch.git
cd HyprFlow-Arch
bash install.sh
```

If you want to skip applying the default theme and color palettes (e.g. reinstalling while keeping your current theme), use the `--skip-theme` flag:

```bash
bash install.sh --skip-theme
```

If you already cloned without `--recursive`:
```bash
git submodule update --init --recursive
```

The install script handles:
- Setting execute permissions on all `.sh` and `.py` scripts
- Copying configuration to `~/.config`
- Creating symlinks for binaries in `~/.local/bin`
- Applying the default color palette
- Reloading Hyprland and plugins

### 3. First steps

Run `help-binds` to see all available keybindings:

```bash
help-binds.sh
```

## Included Scripts

All scripts in `bin/` are available globally in `~/.local/bin` after installation.

| Script | Description |
|--------|-------------|
| `wallust-theme-manager.sh` | Generates dynamic color palettes and applies themes |
| `theme-picker.sh` | Interactive theme selector with pre-designed color palettes |
| `monitors.sh` | Detects monitors and creates the mapping in `monitors_ids.conf` |
| `help-binds.sh` | Shows all keybindings in a visual interface |
| `hyprland-group-all.sh` | Groups all windows in the current workspace |
| `kb-layout-toggle.sh` | Toggles keyboard layout |
| `mute_indicator.sh` | Microphone status indicator in Waybar |
| `swaync-dnd.sh` | Do Not Disturb control for SwayNC |
| `vpn_status.sh` | VPN connection status in Waybar |
| `peripherals_battery.sh` | Peripheral battery levels in Waybar |
| `battery_alert.py` | Low system battery alert |
| `camera_status.py` | Camera-in-use indicator |
| `g733_battery.sh` | Logitech G733 headset battery |
| `trackpad-battery` | Apple Magic Trackpad battery |
| `sinkswitch` | Quick audio output switcher |

**Included submodules:**
- `modules/rofi-collection` — collection of Rofi themes, applets, and launchers
- `modules/apple-magic-trackpad-battery` — trackpad battery script
- `modules/sinkswitch` — audio output switching utility

## Post-Installation

### Dark theme
To force dark colors for GTK apps:

```bash
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
```

### Magic Trackpad (optional)

For the trackpad battery module to work correctly, see the full setup guide (permissions, groups, and security options) in the submodule README:

[apple-magic-trackpad-battery/README.md](https://github.com/AlejandroMinor/apple-magic-trackpad-battery-percent-python/blob/main/README.md)

### Theming with Waypaper (recommended)

In `~/.config/waypaper/config.ini`, enable `zen_mode` and set the `post_command` to regenerate the palette on wallpaper change:

```ini
[Settings]
backend = awww
fill = fill
zen_mode = True
post_command = bash -c "$HOME/HyprFlow-Arch/bin/wallust-theme-manager.sh --generate-palette --notify"
```

To restore or change the color palette, use the interactive theme picker:

```bash
theme-picker.sh
```

Or manually restore the default theme:

```bash
wallust cs ~/HyprFlow-Arch/wallust/themes/minor-default.json
~/HyprFlow-Arch/bin/wallust-theme-manager.sh --restore-default --notify
```

### Monitor detection

If you add or change monitors, regenerate the logical mapping:

```bash
monitors.sh
```

If Waybar has issues, check `monitors_ids.conf` and adjust the IDs manually.
You can also reload Hyprland to pick up the new configuration:

```bash
hyprctl reload
```

### Dell D6000 / DisplayLink

```bash
sudo systemctl enable --now displaylink.service
```

## Hyprland Plugins

Install and manage plugins with `hyprpm`:

```bash
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm enable <plugin-name>
```

Currently active plugins:

| Plugin | Description |
|--------|-------------|
| `hyprfocus` | Enhanced window focus animation |
| `hyprwinwrap` | Embed apps directly as desktop background |
| `hymission` | macOS-style Mission Control window overview, install via `hyprpm add https://github.com/gfhdhytghd/hymission` |

> **Note:** If errors about animations or invalid references appear on startup, the plugins are likely outdated relative to the installed Hyprland version. Run:
>
> ```bash
> hyprpm update
> ```

## Tips

- **Waybar + monitors:** If Waybar doesn't appear correctly, check `dotconfig/hypr/monitors_ids.conf` and adjust the IDs. `monitors.sh` fixes it in most cases, but some setups may require manual adjustment in `dotconfig/waybar/config`.
- **Sessions:** `session-manager/save.sh` saves the current layout; `restore.sh` restores it. Both are available as keybindings.
- **Permissions:** If a script won't run, `chmod +x script_name`. `install.sh` sets them automatically.
