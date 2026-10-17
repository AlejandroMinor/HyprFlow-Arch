// A live audio visualizer: cava's raw output (~/.config/cava/waybar.conf,
// heights 0..7) drawn as bars that rise and fall smoothly. Quickshell stops
// cava with the bar. A Module, so it can be a drawer's handle (the media).
// Coloured by the gradient wallust writes for cava, the higher the warmer,
// as cava_waybar.py did; white with "colors": false or without the
// gradient, faint while silent.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.bar
import qs.bar.services

Module {
    id: cava

    property var heights: []
    // Right click opens the panel of the module named in "panel" (the media).
    onRightClicked: bar.loaded[settings.panel]?.openPanel?.()
    readonly property int maxLevel: 7
    readonly property bool silent: heights.every(h => h === 0)
    property var gradient: []

    FileView {
        path: Paths.config + "cava/themes/wallust"
        watchChanges: true  // a new wallpaper, a new gradient
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const theme = text(), found = [], pattern = /gradient_color_\d+\s*=\s*'([^']+)'/g;
            let m;
            while ((m = pattern.exec(theme)) !== null) found.push(m[1]);
            cava.gradient = found;
        }
    }
    function tint(level) {
        if (settings.colors === false || !gradient.length) return Qt.alpha(Colors.foreground, 0.45 + level * 0.55);
        return gradient[Math.round(level * (gradient.length - 1))];
    }

    LongProcess {
        running: true
        argv: ["cava", "-p", Paths.config + "cava/waybar.conf"]
        stdout: SplitParser {
            onRead: line => cava.heights = line.trim().split(/[ ;]+/).map(Number).filter(n => !isNaN(n))
        }
    }

    Row {
        id: bars
        height: 30
        spacing: 3
        Repeater {
            model: cava.heights.length || 10
            delegate: Rectangle {
                required property int index
                readonly property real level: (cava.heights[index] ?? 0) / cava.maxLevel
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 3 + level * 17
                radius: 1.5
                color: cava.silent ? Qt.alpha(Colors.foreground, 0.25) : cava.tint(level)
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 90 } }
            }
        }
    }
}
