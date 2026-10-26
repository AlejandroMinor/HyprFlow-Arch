// Super+I panel: every keybinding, grouped by section. The list comes from
// help-binds-parse.py, the same one help-binds.sh (rofi) and the submap HUD read.
// Opened through IPC: qs -c hyprflow ipc call keyguide toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property var binds: []  // [{section, keys, description, submap}]
    property string query: ""

    // Like rofi: every typed word somewhere in the row.
    function matches(bind) {
        const row = `${bind.keys} ${bind.description} ${bind.submap}`.toLowerCase();
        return query.toLowerCase().split(" ").every(word => row.includes(word));
    }

    // A ListModel, not an array: ListView only groups sections over roles.
    function refill() {
        shown.clear();
        for (const bind of binds)
            if (matches(bind))
                shown.append(bind);
        view.currentIndex = 0;
        view.positionViewAtBeginning();
    }

    ListModel { id: shown }

    IpcHandler {
        target: "keyguide"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            // Read again: the keybindings may have changed since last time.
            parser.running = true;
        }
    }

    Process {
        id: parser
        command: [root.home + "/.local/lib/hyprflow/help-binds-parse.py",
                  root.home + "/.config/hypr/keybindings.lua",
                  root.home + "/.config/hypr/gestures.lua"]
        stdout: StdioCollector {
            onStreamFinished: {
                // SECTION, KEYS, DESCRIPTION, SUBMAP
                root.binds = text.split("\n")
                    .map(line => line.split("\t"))
                    .filter(f => f.length === 4 && f[1] && f[2])
                    .map(f => ({ section: f[0], keys: f[1], description: f[2], submap: f[3] }));
                search.text = "";  // typing broke its binding to query
                root.query = "";
                root.refill();
                root.open = true;
                search.forceActiveFocus();
            }
        }
    }

    Overlay {
        name: "hyprflow-keyguide"
        open: root.open
        cardWidth: 900
        cardHeight: column.implicitHeight + 24
        onDismissed: root.open = false

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 4

            // Typing filters; the arrows, Page Up/Down and Esc work from here too.
            TextInput {
                id: search
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                onTextEdited: { root.query = text.trim(); root.refill(); }
                color: Colors.foreground
                selectionColor: Qt.alpha(Colors.accent, 0.4)
                font { family: root.font; pixelSize: 13 }

                Text {
                    visible: !search.text
                    text: "\uf11c  Keybindings"  // keyboard
                    color: Colors.fg(0.45)
                    font: search.font
                }

                Keys.onUpPressed: view.decrementCurrentIndex()
                Keys.onDownPressed: view.incrementCurrentIndex()
                Keys.onTabPressed: view.incrementCurrentIndex()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageDown)
                        view.currentIndex = Math.min(view.currentIndex + 12, view.count - 1);
                    else if (event.key === Qt.Key_PageUp)
                        view.currentIndex = Math.max(view.currentIndex - 12, 0);
                }
                Keys.onReturnPressed: root.open = false
                Keys.onEnterPressed: root.open = false
                Keys.onEscapePressed: root.open = false
            }

            ListView {
                id: view
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 12 * 30 + 4 * 28)
                clip: true
                model: shown
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Motion.fast
                highlightResizeDuration: 0

                // Darker, not accent: in Super+K the accent means "on".
                highlight: Rectangle {
                    radius: 8
                    color: Colors.selection
                }

                section.property: "section"
                section.delegate: Text {
                    required property string section
                    width: ListView.view.width
                    height: 28
                    leftPadding: 8
                    verticalAlignment: Text.AlignBottom
                    bottomPadding: 4
                    text: section
                    color: Colors.fg(0.5)
                    font { family: root.font; pixelSize: 11; weight: Font.Bold }
                }

                delegate: Item {
                    id: row
                    required property string keys
                    required property string description
                    required property string submap
                    required property int index
                    width: ListView.view.width
                    height: 30

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: view.currentIndex = row.index
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 12

                        // Fixed width so the descriptions line up.
                        Item {
                            Layout.preferredWidth: 240
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 6
                                width: keyText.implicitWidth + 12
                                height: 22
                                color: Colors.fg(0.08)
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: row.keys
                                    color: Colors.foreground
                                    font { family: root.font; pixelSize: 11; weight: Font.DemiBold }
                                }
                            }
                        }
                        Text {
                            text: row.description
                            color: Colors.foreground
                            font { family: root.font; pixelSize: 13 }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: row.submap !== ""
                            text: row.submap
                            color: Colors.fg(0.45)
                            font { family: root.font; pixelSize: 10 }
                        }
                    }
                }
            }
        }
    }
}
