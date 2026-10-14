// Every duration and curve the panels animate with inside; tune motion here,
// never in a panel. Hyprland only adds a fade on top (quickshell-anim).
// Curves are Material 3's: arriving decelerates, leaving accelerates.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property int fast: 120    // hover, highlight, small changes
    readonly property int normal: 260  // a panel unfolding
    readonly property int hud: 220     // the level OSD
    readonly property int exit: 160    // a panel folding away: quicker

    readonly property var enter:    [0.05, 0.7, 0.1, 1.0, 1, 1]
    readonly property var leave:    [0.3, 0.0, 0.8, 0.15, 1, 1]
    readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1, 1]
}
