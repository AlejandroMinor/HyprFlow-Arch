# Optional setup

## Zsh

`install.sh zsh` (backs up your `.zshrc` first, and asks before
changing your login shell). Needs
`zsh zsh-autosuggestions zsh-syntax-highlighting zoxide bat` plus `fzf-tab` and
`oh-my-zsh-git` from the AUR. Adds git/sudo/copypath/fzf plugins, autosuggestions,
syntax highlighting, fzf-tab with `bat` preview, and zoxide (`z`, `zi`).

## RGB lighting

With [OpenRGB](https://openrgb.org) the case lighting follows
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

## Battery notifications

`battery-hub.py` shows a desktop notification when a device drops below 35 %, and
an urgent one below 20 %, once per level. That is all you get by default.

### Getting the warnings somewhere else

If you want those warnings to also reach you away from the desk, on your phone for
example, you can add a **hook**: a small script of yours that battery-hub runs
every time it warns.

How it works:

1. A battery drops below 35 % or 20 %.
2. battery-hub shows the desktop notification, as always.
3. If the file `~/.config/hyprflow/battery-hook` exists and is executable,
   battery-hub also runs it, passing the device, the percentage and the level.
4. Your script decides what to do with them: send a message, an email, anything.

Worth knowing:

- **One file, that exact name.** battery-hub looks for `battery-hook` and nothing
  else; other files in `~/.config/hyprflow/` are ignored. To do several things
  (a message and a sound, say), put them all in that one script.
- **Only on warnings.** It runs when a device crosses 35 % or 20 %, once per level.
  Connecting a device, charging or any other battery change does not run it.
- **Without the file nothing changes**: you keep the desktop notification only.

The steps below set one up; the example sends a Telegram message.

#### Step 1: create the folder

```bash
mkdir -p ~/.config/hyprflow
```

This folder is yours: it is not part of the repo and `install.sh` never writes to
it, so your script and whatever secrets it holds stay on your machine.

#### Step 2: write the script

Create the file `~/.config/hyprflow/battery-hook` with your editor, with this
content:

```sh
#!/bin/sh
TOKEN="123456:your-bot-token"
CHAT_ID="your-chat-id"
curl -s "https://api.telegram.org/bot$TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" -d text="$1 is at $2% ($3)"
```

- `#!/bin/sh` tells the system to run the file with the shell.
- `TOKEN` and `CHAT_ID` identify your Telegram bot and the chat to write to. This
  assumes you already have a bot; creating one is up to you.
- `curl` sends the message. `$1`, `$2` and `$3` are what battery-hub passes in
  (see step 4).

Telegram is only the example. Put any command that reaches you in its place.

#### Step 3: make it executable

```bash
chmod +x ~/.config/hyprflow/battery-hook
```

battery-hub only runs the hook if it is executable, so skipping this step means it
is silently ignored.

#### Step 4: know what it receives

When, say, the mouse drops to 18 %, battery-hub runs:

```
~/.config/hyprflow/battery-hook "MX Master 3S" 18 critical
```

| Argument | Meaning | Example |
|----------|---------|---------|
| `$1` | device name | `MX Master 3S` |
| `$2` | percentage | `18` |
| `$3` | level: `warning` (below 35 %) or `critical` (below 20 %) | `critical` |

#### Step 5: try it

You do not have to wait for a battery to run low. Run the hook yourself with made
up values:

```bash
~/.config/hyprflow/battery-hook "Test" 18 critical
```

If the message arrives, the hook is ready: battery-hub will use it from the next
warning on, no restart needed.

## Logitech Bolt receiver

A mouse or keyboard paired to a Logi Bolt receiver
never reaches UPower: the kernel has no driver for the Bolt. `battery-hub.py`
asks the receiver itself, which needs read access to it, once:

```bash
sudo cp ~/HyprFlow-Arch/system/udev/42-logitech-bolt.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger -s hidraw
```

The rule gives the logged in user access to the receiver only. Its devices then
show up in the battery module within five minutes (they are polled, not
signalled). Over Bluetooth instead, UPower already reports them.

## Magic Trackpad

Only if you use an Apple Magic Trackpad. Over Bluetooth its driver often does not
report the battery to UPower, and battery-hub only shows what UPower reports, so
the trackpad may be missing from the bar. The `apple-magic-trackpad-battery`
submodule asks the trackpad directly: run `trackpad-battery` to see its charge.

Reading the trackpad needs a udev rule and your user in a group, once. The steps
are in the
[submodule README](https://github.com/AlejandroMinor/apple-magic-trackpad-battery-percent-python/blob/main/README.md).

## DisplayLink

Only for monitors plugged into a DisplayLink dock or USB display adapter (common
on laptop docks: the screen hangs off USB, not a video port). Those need
DisplayLink's own driver; without it the monitor stays black and Hyprland never
sees it. Once installed, `monitors.sh` handles it like any other screen.

```bash
yay -S displaylink evdi-dkms-git
sudo systemctl enable --now displaylink.service
```
