// The full player's cog: a live preview of every skin with the track that
// is playing, and under them the options of the one picked.
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.widgets
import qs.bar.services

ColumnLayout {
    id: picker

    property var panel             // MediaPanel: art, player, look
    property var sample: null      // the picked skin's preview, to read its options
    signal back()

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "\u{F004D}"
            color: Qt.alpha(Colors.foreground, backArea.containsMouse ? 1 : 0.7)
            font { family: picker.panel.look.font; pixelSize: 16 }
            MouseArea {
                id: backArea
                anchors { fill: parent; margins: -6 }
                hoverEnabled: true
                onClicked: picker.back()
            }
        }
        Text {
            text: "Player style"
            color: Colors.foreground
            font { family: picker.panel.look.font; pixelSize: 12; bold: true }
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        Repeater {
            model: MediaSkin.skins
            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property bool current: MediaSkin.skin === modelData.name
                // A skin missing from the submodule's checkout is left out.
                visible: modelData.file === "" || tileFace.drawn
                width: 80
                height: 96
                radius: 10
                color: current ? BarTheme.tint(0.2) : tileArea.containsMouse ? BarTheme.tint(0.12) : Qt.alpha(Colors.foreground, 0.06)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                SkinFace {
                    id: tileFace
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                    width: 68
                    height: 68
                    skin: tile.modelData.name
                    art: picker.panel.art
                    playing: picker.panel.player?.isPlaying ?? false
                    iconFont: picker.panel.look.font
                }
                Text {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                    text: tile.modelData.label
                    color: Qt.alpha(Colors.foreground, tile.current ? 1 : 0.6)
                    font { family: picker.panel.look.font; pixelSize: 10; bold: tile.current }
                }
                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: MediaSkin.pick(tile.modelData.name)
                }
                Binding {
                    target: picker
                    property: "sample"
                    value: tileFace.item
                    when: tile.current
                }
            }
        }
    }

    // The picked skin's options, each a chip that steps through its values.
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6
        Repeater {
            model: MediaSkin.options.filter(o => picker.sample && picker.sample[o.key] !== undefined)
            delegate: PanelButton {
                required property var modelData
                readonly property var value: MediaSkin.option(MediaSkin.skin, modelData.key) ?? picker.sample[modelData.key]
                readonly property int step: Math.max(0, modelData.values.indexOf(value))
                label: modelData.label + ": " + modelData.names[step]
                fontFamily: picker.panel.look.font
                onClicked: MediaSkin.setOption(MediaSkin.skin, modelData.key,
                    modelData.values[(step + 1) % modelData.values.length])
            }
        }
    }

    Item { Layout.fillHeight: true }
}
