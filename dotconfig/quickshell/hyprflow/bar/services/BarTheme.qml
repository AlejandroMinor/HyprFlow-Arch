// The theme's accent for the bar: the LED colour rgb-sync.sh picks from the
// wallpaper (the focus border uses it too), redrawn when it changes. Accents only (the active workspace, sliders, today, Save, the
// event under way, hovers, what is picked in a panel, the ring and the
// notification badge); the rest stays black and white. `"colors": false` in
// bar.json turns it white, as before.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool enabled: true  // bar.json "colors"
    property color led: Colors.foreground
    readonly property color accent: enabled ? led : Colors.foreground
    // A hover or a selection: the accent at ALPHA, made stronger with the
    // theme on (at white's strength the colour hardly showed).
    readonly property real strength: 2.5
    function tint(alpha) { return Qt.alpha(accent, enabled ? Math.min(1, alpha * strength) : alpha); }

    FileView {
        path: Paths.cache + "wallust/led-color"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const found = text().trim().match(/^[0-9A-Fa-f]{6}$/);
            root.led = found ? "#" + found[0] : Colors.foreground;
        }
        onLoadFailed: root.led = Colors.foreground
    }
}
