// The theme's accent for the bar: wallust's color5 (the one the glass tints
// with), read from the palette it writes for Waybar and redrawn when it
// changes. Accents only (the active workspace, sliders, today, Save, the
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
    property color wallust: Colors.foreground
    readonly property color accent: enabled ? wallust : Colors.foreground
    // A hover or a selection: the accent at ALPHA, made stronger with the
    // theme on (at white's strength the colour hardly showed).
    readonly property real strength: 2.5
    function tint(alpha) { return Qt.alpha(accent, enabled ? Math.min(1, alpha * strength) : alpha); }

    FileView {
        path: Paths.cache + "wallust/colors/colors-waybar.css"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const found = text().match(/@define-color\s+color5\s+(#[0-9A-Fa-f]{6})/);
            root.wallust = found ? found[1] : Colors.foreground;
        }
        onLoadFailed: root.wallust = Colors.foreground
    }
}
