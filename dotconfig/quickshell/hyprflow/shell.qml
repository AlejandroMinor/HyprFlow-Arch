//@ pragma UseQApplication
// HyprFlow's Quickshell config: run with `qs -c hyprflow`. The Super+K and
// Super+I panels, the audio and theme pickers, the confirmations, the submap
// keys, the power menu, the level OSD and the bar (bar/); without it, rofi,
// notifications and Waybar stand in.
import Quickshell
import qs.bar

ShellRoot {
    QuickActions {}
    SinkSwitch {}
    ThemePicker {}
    KeyGuide {}
    Confirm {}
    SubmapHud {}
    PowerMenu {}
    Osd {}
    Bars {}
}
