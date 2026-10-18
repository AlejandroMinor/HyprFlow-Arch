// The audio spectrum, one cava for every bar and for the style picker: its
// raw output (Paths.config/cava/waybar.conf, heights 0..7) as levels 0..1,
// the gradient wallust writes for cava, and the drawing style picked in
// Super+K (Paths.state/cava-style, "bars" without it).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    // What widgets/Spectrum.qml draws, in the picker's order.
    readonly property var styles: ["bars", "equalizer", "leds", "dots", "wave", "mirror"]
    property string style: "bars"
    property var levels: []
    readonly property bool silent: levels.every(l => l === 0)
    property var gradient: []

    LongProcess {
        running: true
        argv: ["cava", "-p", Paths.config + "cava/waybar.conf"]
        stdout: SplitParser {
            onRead: line => root.levels = line.trim().split(/[ ;]+/).map(Number)
                .filter(n => !isNaN(n)).map(n => n / 7)
        }
    }

    FileView {
        path: Paths.config + "cava/themes/wallust"
        watchChanges: true  // a new wallpaper, a new gradient
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const theme = text(), found = [], pattern = /gradient_color_\d+\s*=\s*'([^']+)'/g;
            let m;
            while ((m = pattern.exec(theme)) !== null) found.push(m[1]);
            root.gradient = found;
        }
    }

    FileView {
        id: chosen
        path: Paths.state + "cava-style"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { const name = text().trim(); root.style = root.styles.includes(name) ? name : "bars"; }
        onLoadFailed: root.style = "bars"
    }
    function setStyle(name) {
        root.style = name;
        chosen.setText(name + "\n");
    }
}
