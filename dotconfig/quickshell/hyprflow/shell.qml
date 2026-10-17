// HyprFlow's Quickshell config: run with `qs -c hyprflow`. The Super+K and
// Super+I panels, the audio and theme pickers, the confirmations, the submap
// keys, the power menu and the level OSD; without it, rofi and notifications stand in.
import Quickshell

ShellRoot {
    QuickActions {}
    SinkSwitch {}
    ThemePicker {}
    KeyGuide {}
    Confirm {}
    SubmapHud {}
    PowerMenu {}
    Osd {}
}
