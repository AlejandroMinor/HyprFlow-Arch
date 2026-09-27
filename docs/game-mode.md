# Game mode

`game-mode.sh` turns the desktop into a console for the controller: only the game screen stays on and the rest are switched off, animations, blur and shadows go off, variable refresh (VRR) turns on for fullscreen games, notifications are silenced, Waybar hides, the case lighting goes dark and Steam Big Picture opens. `off` puts all of it back. Other programs keep running; their windows move to the game screen, behind the game.

```sh
game-mode.sh              # toggle
game-mode.sh on           # the first connected screen from your list
game-mode.sh on NZXT      # this screen for this time, by port or part of its description
game-mode.sh on --keep    # leave the other screens on this time (Discord on a side monitor)
game-mode.sh off
game-mode.sh status       # on / off
```

From the couch, hold **PS + Options** on the controller for a second (Guide + Menu on Xbox style pads) to toggle it, and close Big Picture to leave: game mode ends by itself a couple of seconds later. `pad-listener.py`, started by Hyprland, watches the controllers for that combo, since Hyprland does not read gamepads. It only reads, so Steam and games still get every press. Needs `python-evdev`.

Settings are per machine and live outside the repo, in `~/.config/hypr/game-mode.conf`:

```sh
GAME_DISPLAY=("FireTV" "NZXT")  # in order of preference, the first connected wins; empty = largest
GAME_MODE=""                    # e.g. 3840x2160@120; empty = the profile's mode
GAME_VRR=1                      # variable refresh in fullscreen only; always on flickers on the desktop
GAME_STEAM=1                    # open Big Picture
GAME_RGB=1                      # case lighting off while playing (needs the RGB setup below)
GAME_AUDIO=1                    # sound to the game screen (the TV's HDMI), back when leaving
```

Without the file it uses the largest screen. Switching screens off goes through `monitors.sh solo`, so the monitors come back as they were. While game mode is on, `gamemode.lua` keeps the game settings on every reload, so a hotplug or `monitors.sh` does not undo them, and `monitors.sh` leaves Waybar hidden.

It also runs over SSH, from a phone for instance: it finds the running Hyprland session by itself and launches Steam and Waybar through Hyprland, so they show up on the screen and survive the SSH logout.

```sh
ssh user@pc '~/.local/bin/game-mode.sh on'
```

The full path is needed because a command sent over SSH does not load `.zshrc`, where `~/.local/bin` joins the `PATH`.
