// Super+K's "Keyboard effect": the keyboard's 20 lighting effects, each a
// live preview (KeyPreview) in the theme's colour, the one in use marked.
// The list comes from lib/keyboard-rgb.py --json; picking one runs
// `effect N`, which also gives it the theme's colour.
// qs -c hyprflow ipc call keyboardfx toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.bar.services

Scope {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/lib/hyprflow/keyboard-rgb.py"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string check: "󰄬"
    readonly property int columns: 4
    readonly property int tileWidth: 150
    readonly property int tileHeight: 100
    readonly property int gap: 8
    property bool open: false
    property var effects: []     // [{number, name, current}]
    property color colour: "white"  // the theme's, as the keyboard shows it
    property real t: 0

    function show() {
        grid.currentIndex = Math.max(0, root.effects.findIndex(e => e.current));
        root.open = true;
        grid.forceActiveFocus();
    }

    IpcHandler {
        target: "keyboardfx"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            // Read again: the Fn keys may have changed it.
            list.running = true;
        }
    }

    Process {
        id: list
        command: [root.script, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let answer;
                try {
                    answer = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.effects = answer.effects;
                if (answer.color)
                    root.colour = answer.color;
                if (root.effects.length > 0)
                    root.show();
            }
        }
    }

    Process { id: runner }

    function choose(index) {
        root.open = false;
        runner.command = [root.script, "effect", String(root.effects[index].number)];
        runner.running = true;
    }

    // 15 frames a second, only while open.
    Timer {
        running: root.open
        interval: 66
        repeat: true
        onTriggered: root.t += interval / 1000
    }

    Overlay {
        name: "hyprflow-keyboardfx"
        open: root.open
        cardWidth: grid.width + 24
        cardHeight: title.height + grid.height + 36
        onDismissed: root.open = false

        Text {
            id: title
            x: 22; y: 14
            text: "Keyboard effect"
            color: Colors.fg(0.45)
            font { family: root.font; pixelSize: 13 }
        }

        GridView {
            id: grid
            x: 12
            y: title.y + title.height + 10
            width: root.columns * (root.tileWidth + root.gap)
            height: Math.ceil(root.effects.length / root.columns) * (root.tileHeight + root.gap)
            cellWidth: root.tileWidth + root.gap
            cellHeight: root.tileHeight + root.gap
            interactive: false
            model: root.effects
            keyNavigationWraps: true
            highlightMoveDuration: Motion.fast
            highlight: Rectangle {
                width: root.tileWidth; height: root.tileHeight
                radius: 10
                color: Colors.selection
            }

            focus: true
            Keys.onLeftPressed: moveCurrentIndexLeft()
            Keys.onRightPressed: moveCurrentIndexRight()
            Keys.onUpPressed: moveCurrentIndexUp()
            Keys.onDownPressed: moveCurrentIndexDown()
            Keys.onTabPressed: currentIndex = (currentIndex + 1) % count
            Keys.onReturnPressed: root.choose(currentIndex)
            Keys.onEnterPressed: root.choose(currentIndex)
            Keys.onEscapePressed: root.open = false

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: root.tileWidth
                height: root.tileHeight

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: grid.currentIndex = tile.index
                    onClicked: root.choose(tile.index)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    KeyPreview {
                        Layout.alignment: Qt.AlignHCenter
                        effect: tile.modelData.number
                        color: root.colour
                        t: root.t
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (tile.modelData.current ? root.check + "  " : "")
                              + tile.modelData.number + "  " + tile.modelData.name
                        color: tile.modelData.current ? BarTheme.accent : Colors.foreground
                        font { family: root.font; pixelSize: 12; weight: tile.modelData.current ? Font.DemiBold : Font.Normal }
                    }
                }
            }
        }
    }
}
