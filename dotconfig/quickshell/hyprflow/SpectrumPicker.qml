// Super+K's "Spectrum style": the six ways the bar can draw cava, each a
// live preview (the music playing, or a made-up one while silent), the one
// in use marked. Picking one saves it (CavaLevels.setStyle) and the bar
// switches at once.
// qs -c hyprflow ipc call spectrum toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.bar.services
import qs.bar.widgets

Scope {
    id: root

    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    readonly property var names: ({
        bars: "Bars", equalizer: "Equalizer", leds: "LEDs",
        dots: "Dots", wave: "Wave", mirror: "Mirror"
    })
    readonly property int columns: 3
    readonly property int tileWidth: 150
    readonly property int tileHeight: 104
    readonly property int gap: 8

    IpcHandler {
        target: "spectrum"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            grid.currentIndex = Math.max(0, CavaLevels.styles.indexOf(CavaLevels.style));
            root.open = true;
            grid.forceActiveFocus();
        }
    }

    function choose(index) {
        CavaLevels.setStyle(CavaLevels.styles[index]);
        root.open = false;
    }

    // Silent: a made-up spectrum, so the previews still move.
    property var demo: []
    property real phase: 0
    Timer {
        running: root.open && CavaLevels.silent
        interval: 70
        repeat: true
        onTriggered: {
            root.phase += 0.35;
            const levels = [];
            for (let i = 0; i < 10; i++)
                levels.push(Math.max(0, Math.min(1, 0.45 + 0.35 * Math.sin(root.phase + i * 0.8) + 0.2 * Math.sin(root.phase * 2.3 - i))));
            root.demo = levels;
        }
    }

    Overlay {
        name: "hyprflow-spectrum"
        open: root.open
        cardWidth: grid.width + 24
        cardHeight: title.height + grid.height + 36
        onDismissed: root.open = false

        Text {
            id: title
            x: 22; y: 14
            text: "Spectrum style"
            color: Qt.alpha(Colors.foreground, 0.45)
            font { family: root.font; pixelSize: 13 }
        }

        GridView {
            id: grid
            x: 12
            y: title.y + title.height + 10
            width: root.columns * (root.tileWidth + root.gap)
            height: Math.ceil(CavaLevels.styles.length / root.columns) * (root.tileHeight + root.gap)
            cellWidth: root.tileWidth + root.gap
            cellHeight: root.tileHeight + root.gap
            interactive: false
            model: CavaLevels.styles
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
                required property string modelData
                required property int index
                readonly property bool inUse: CavaLevels.style === modelData
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
                    spacing: 10
                    // Twice the bar's size.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: preview.implicitWidth * 2
                        implicitHeight: preview.implicitHeight * 2
                        Spectrum {
                            id: preview
                            style: tile.modelData
                            levels: CavaLevels.silent ? root.demo : CavaLevels.levels
                            scale: 2
                            anchors.centerIn: parent
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (tile.inUse ? "\u{F012C}  " : "") + root.names[tile.modelData]
                        color: tile.inUse ? BarTheme.accent : Colors.foreground
                        font { family: root.font; pixelSize: 12; weight: tile.inUse ? Font.DemiBold : Font.Normal }
                    }
                }
            }
        }
    }
}
