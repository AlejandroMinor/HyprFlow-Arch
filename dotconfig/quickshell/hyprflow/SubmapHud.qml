// The keys of the submap you are in (Super+G, Super+R, Super+Shift+S), at the
// bottom while it lasts. SubmapState brings the title and exit key; the keys
// come from help-binds-parse.py, the same list as Super+I.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    readonly property string submap: SubmapState.name
    readonly property string title: SubmapState.title
    readonly property string exitKey: SubmapState.exitKey
    property var binds: []  // [{keys, description}] of this submap

    Connections {
        target: SubmapState
        function onEntered() { parser.running = true; }  // opens once the keys are read
        function onActiveChanged() { if (!SubmapState.active) root.open = false; }
    }

    Process {
        id: parser
        command: [root.home + "/.local/lib/hyprflow/help-binds-parse.py",
                  root.home + "/.config/hypr/keybindings.lua"]
        stdout: StdioCollector {
            onStreamFinished: {
                // SECTION, KEYS, DESCRIPTION, SUBMAP; the exit rows are in the header.
                root.binds = text.split("\n")
                    .map(line => line.split("\t"))
                    .filter(f => f.length === 4 && f[3] === root.submap && !f[2].startsWith("Exit"))
                    .map(f => ({ keys: f[1], description: f[2] }));
                root.open = SubmapState.active;  // not if left while reading
            }
        }
    }

    Overlay {
        name: "hyprflow-submap"
        open: root.open
        interactive: false
        atBottom: true
        cardWidth: 640
        cardHeight: column.implicitHeight + 28

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                Text {
                    text: root.title
                    color: Colors.accent
                    font { family: root.font; pixelSize: 14; weight: Font.Bold }
                    Layout.fillWidth: true
                }
                Text {
                    text: root.exitKey + "  ·  Esc to exit"
                    color: Colors.fg(0.55)
                    font { family: root.font; pixelSize: 11 }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 18
                rowSpacing: 6

                Repeater {
                    model: root.binds
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1  // both columns the same width
                        spacing: 10

                        Rectangle {
                            radius: 6
                            implicitWidth: Math.max(keyText.implicitWidth + 12, 28)
                            implicitHeight: 22
                            color: Colors.fg(0.08)
                            Text {
                                id: keyText
                                anchors.centerIn: parent
                                text: modelData.keys
                                color: Colors.foreground
                                font { family: root.font; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }
                        Text {
                            text: modelData.description
                            color: Colors.fg(0.85)
                            font { family: root.font; pixelSize: 12 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
