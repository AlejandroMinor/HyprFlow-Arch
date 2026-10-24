// Appearance's "Panels" tab: the tones of palettes.json, each drawn in its
// own colours (darks first), and for the tone in use how see-through the card
// is and how much the glass blurs. Everything runs lib/appearance.py, which
// Colors.qml follows. The text colour is a row of swatches, the tone's own
// first. A transparency drag shows at once (Colors.preview) and
// is saved on release; blur reloads Hyprland, so it applies on release.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.bar.widgets

ColumnLayout {
    id: settings

    property string font
    readonly property string script: Quickshell.env("HOME") + "/.local/lib/hyprflow/appearance.py"
    readonly property real blurMax: 4  // appearance.py's TWEAKS
    readonly property var names: Object.keys(Colors.tones)
    property real blurShown: 0  // the blur while dragging

    spacing: 14

    Process {
        id: runner
        onExited: Colors.preview = -1  // the saved value has taken over
    }
    function run(args) {
        runner.command = [settings.script].concat(args);
        runner.running = true;
    }
    function pick(index) {
        const n = settings.names.length;
        run(["tone", settings.names[(index + n) % n]]);
    }
    function step(by) { pick(settings.names.indexOf(Colors.tone) + by); }

    GridLayout {
        columns: 3
        columnSpacing: 12
        rowSpacing: 10
        Repeater {
            model: settings.names
            delegate: ColumnLayout {
                id: swatch
                required property string modelData
                required property int index
                readonly property var tone: Colors.resolved(modelData)
                readonly property bool current: modelData === Colors.tone
                spacing: 6

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 112; implicitHeight: 48
                    radius: 12
                    color: swatch.tone.background
                    border.width: swatch.current ? 2 : 1
                    border.color: swatch.current ? Colors.accent : Colors.fg(0.15)
                    Text {
                        anchors.centerIn: parent
                        text: "Aa"
                        color: swatch.tone.foreground
                        font { family: settings.font; pixelSize: 15 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settings.pick(swatch.index)
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: swatch.tone.label
                    color: swatch.current ? Colors.foreground : Colors.fg(0.45)
                    font { family: settings.font; pixelSize: 12; weight: swatch.current ? Font.DemiBold : Font.Normal }
                }
            }
        }
    }

    GridLayout {
        columns: 3
        columnSpacing: 12
        rowSpacing: 10

        Text {
            text: "Transparency"
            color: Colors.foreground
            font { family: settings.font; pixelSize: 12 }
        }
        BarSlider {
            Layout.fillWidth: true
            value: 1 - Colors.card
            onMoved: v => Colors.preview = Math.max(0.05, Math.min(0.95, 1 - v))
            onDraggingChanged: if (!dragging) settings.run(["set", "card", Colors.card.toFixed(3)])
        }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round((1 - Colors.card) * 100) + "%"
            color: Colors.fg(0.45)
            font { family: settings.font; pixelSize: 12 }
        }

        Text {
            text: "Blur"
            color: Colors.foreground
            font { family: settings.font; pixelSize: 12 }
        }
        BarSlider {
            id: blur
            Layout.fillWidth: true
            value: (blur.dragging ? settings.blurShown : Colors.blur) / settings.blurMax
            onMoved: v => settings.blurShown = v * settings.blurMax
            onDraggingChanged: if (!dragging) settings.run(["set", "blur", settings.blurShown.toFixed(2)])
        }
        Text {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: (blur.dragging ? settings.blurShown : Colors.blur).toFixed(1)
            color: Colors.fg(0.45)
            font { family: settings.font; pixelSize: 12 }
        }
    }

    RowLayout {
        spacing: 12
        Text {
            text: "Text"
            color: Colors.foreground
            font { family: settings.font; pixelSize: 12 }
        }
        Item { Layout.fillWidth: true }
        Repeater {
            // "" is the tone's own colour.
            model: ["", "#FFFFFF", "#E5E5EA", "#8E8E93", "#3C3C43", "#000000"]
            delegate: Rectangle {
                id: ink
                required property string modelData
                readonly property color shown: modelData || (Colors.palette.foreground ?? "#FFFFFF")
                readonly property bool current: (Colors.tweaks.text ?? "") === modelData
                implicitWidth: 20; implicitHeight: 20
                radius: 10
                color: ink.shown
                border.width: ink.current ? 2 : 1
                border.color: ink.current ? Colors.accent : Colors.fg(0.25)
                // The tone's own: a dot inside tells it apart.
                Rectangle {
                    visible: ink.modelData === ""
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: Colors.palette.background ?? "#000000"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settings.run(["set", "text", ink.modelData || "default"])
                }
            }
        }
    }

    PanelButton {
        Layout.alignment: Qt.AlignRight
        label: "Reset"
        fontFamily: settings.font
        onClicked: settings.run(["reset"])
    }
}
