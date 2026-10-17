// The full view of a sound module, opened from the bar under it (its click,
// bar.expand: the card grows down into it):
// the device in use with its level, every device to pick from, each app's
// own level and the mixer.
//   kind "output"  the outputs (sink-switch.py, so the playing streams move
//                  along), the apps playing, and the microphone too
//   kind "input"   the microphones, the apps recording
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

Item {
    id: view

    property var module            // the Module it unfolds from: look, glyphs
    property string kind: "output"
    readonly property bool output: kind === "output"
    readonly property var look: module.look
    readonly property string lib: Quickshell.env("HOME") + "/.local/lib/hyprflow/"

    readonly property var device: output ? AudioState.sink : AudioState.source
    readonly property var apps: output ? AudioState.playing : AudioState.recording

    implicitHeight: column.implicitHeight + 28  // the card grows to fit it
    Component.onCompleted: if (output) outputs.running = true

    // The devices as rows: {label, icon, current, pick()}.
    property var sinks: []
    readonly property var devices: output
        ? sinks.map(s => ({ label: s.label, icon: s.icon, current: s.default,
                            pick: () => { pick.command = [lib + "sink-switch.py", "--set", String(s.id)]; pick.running = true; } }))
        : AudioState.sources.map(n => ({ label: n.description || n.name, icon: "\u{F036C}", current: n === AudioState.source,
                                         pick: () => AudioState.useSource(n) }))

    Process {
        id: outputs
        command: [view.lib + "sink-switch.py", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { view.sinks = JSON.parse(text); } catch (e) {} } }
    }
    Process { id: pick; onExited: outputs.running = true }

    function volumeGlyph(volume, muted) {
        return muted ? "\u{F0581}" : volume < 0.34 ? "\u{F057F}" : volume < 0.67 ? "\u{F0580}" : "\u{F057E}";
    }

    component Heading: Text {
        Layout.fillWidth: true
        Layout.topMargin: 12
        color: Qt.alpha(Colors.foreground, 0.45)
        font { family: view.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
    }

    // A row with a level: icon (click mutes), name, slider.
    component LevelRow: RowLayout {
        id: levelRow
        property var node
        property string glyphOn
        property string glyphOff
        property string label
        readonly property bool rowMuted: node?.audio?.muted ?? false
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: levelRow.rowMuted ? levelRow.glyphOff : levelRow.glyphOn
            color: Qt.alpha(Colors.foreground, levelRow.rowMuted ? view.look.dim : 1)
            font { family: view.look.font; pixelSize: 16 }
            Layout.preferredWidth: 20
            MouseArea { anchors.fill: parent; onClicked: AudioState.toggleMute(levelRow.node) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: levelRow.label
                    elide: Text.ElideRight
                    color: Colors.foreground
                    font { family: view.look.font; pixelSize: 12 }
                }
                Text {
                    text: levelRow.rowMuted ? "off" : Math.round(slider.shown * 100) + "%"
                    color: Qt.alpha(Colors.foreground, 0.6)
                    font { family: view.look.font; pixelSize: 11 }
                }
            }
            BarSlider {
                id: slider
                Layout.fillWidth: true
                value: levelRow.node?.audio?.volume ?? 0
                muted: levelRow.rowMuted
                dim: view.look.dim
                onMoved: v => AudioState.setVolume(levelRow.node, v)
            }
        }
    }

    // Wide (the card's whole width): the device and its list on the left,
    // the apps, the microphone and the mixer on the right; narrow, one column.
    GridLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        columns: view.width >= 460 ? 2 : 1
        columnSpacing: 18
        rowSpacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1  // the two columns share the width evenly
            Layout.alignment: Qt.AlignTop
            spacing: 8

            Heading { text: view.output ? "OUTPUT" : "MICROPHONE"; Layout.topMargin: 0 }
            LevelRow {
                node: view.device
                glyphOn: view.output ? view.volumeGlyph(view.device?.audio?.volume ?? 0, false) : "\u{F036C}"
                glyphOff: view.output ? "\u{F0581}" : "\u{F036D}"
                label: view.device?.description ?? ""
            }

            // Every device; the one in use marked. A click moves to it.
            Repeater {
                model: view.devices
                delegate: Rectangle {
                    id: deviceRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 8
                    color: modelData.current ? BarTheme.tint(0.12)
                         : hover.containsMouse ? BarTheme.tint(view.look.hover) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 10
                        Text {
                            text: deviceRow.modelData.icon
                            color: Colors.foreground
                            font { family: view.look.font; pixelSize: 14 }
                            Layout.preferredWidth: 20
                        }
                        Text {
                            Layout.fillWidth: true
                            text: deviceRow.modelData.label
                            elide: Text.ElideRight
                            color: Qt.alpha(Colors.foreground, deviceRow.modelData.current ? 1 : 0.7)
                            font { family: view.look.font; pixelSize: 12; bold: deviceRow.modelData.current }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: deviceRow.modelData.pick()
                    }
                }
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 8
            // The right column starts level with the left one.
            Heading {
                text: view.output ? "APPS" : "RECORDING"
                visible: view.apps.length > 0
                Layout.topMargin: column.columns === 2 ? 0 : 12
            }
            Repeater {
                model: view.apps
                delegate: LevelRow {
                    required property var modelData
                    node: modelData
                    glyphOn: view.output ? "\u{F075A}" : "\u{F036C}"
                    glyphOff: view.output ? "\u{F075B}" : "\u{F036D}"
                    label: AudioState.appName(modelData)
                }
            }

            // From the output's view, the microphone is a glance away.
            Heading {
                text: "MICROPHONE"
                visible: view.output && AudioState.source !== null
                Layout.topMargin: column.columns === 2 && view.apps.length === 0 ? 0 : 12
            }
            LevelRow {
                visible: view.output && AudioState.source !== null
                node: AudioState.source
                glyphOn: "\u{F036C}"
                glyphOff: "\u{F036D}"
                label: AudioState.source?.description ?? ""
            }

            // The mixer, for what this view does not cover.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 30
                radius: 8
                color: mixer.containsMouse ? BarTheme.tint(0.14) : Qt.alpha(Colors.foreground, 0.08)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "\u{F0EA2}  Mixer"
                    color: Colors.foreground
                    font { family: view.look.font; pixelSize: 12 }
                }
                MouseArea {
                    id: mixer
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        view.module.bar.collapse();
                        // pavucontrol's tab 4 is the input devices.
                        Quickshell.execDetached(view.output ? ["pavucontrol"] : ["pavucontrol", "-t", "4"]);
                    }
                }
            }
        }
    }
}
