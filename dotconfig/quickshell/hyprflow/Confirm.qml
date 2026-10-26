// "Are you sure?" for Super+Shift+Q and the logout command. hyprflow.menu (QuickshellMenu)
// asks through IPC with a reply pipe and waits on it; this writes the chosen
// option there, or an empty line when dismissed.
// qs -c hyprflow ipc call confirm ask PROMPT "Cancel\nLog out" /path/to/pipe
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property string prompt: ""
    property var options: []
    property string pipe: ""  // where the asking script waits

    IpcHandler {
        target: "confirm"
        function ask(prompt: string, options: string, pipe: string): void {
            root.answer("");  // a question still open counts as dismissed
            root.prompt = prompt;
            root.options = options.split("\n");
            root.pipe = pipe;
            view.currentIndex = 0;  // the safe option comes first
            root.open = true;
            title.forceActiveFocus();
        }
    }

    function answer(option) {
        root.open = false;
        if (!root.pipe)
            return;
        // timeout: a script that gave up leaves nobody reading the pipe.
        Quickshell.execDetached(["timeout", "2", "sh", "-c", 'printf "%s\\n" "$1" > "$2"',
                                 "sh", option, root.pipe]);
        root.pipe = "";
    }

    Overlay {
        name: "hyprflow-confirm"
        open: root.open
        cardWidth: 400
        cardHeight: column.implicitHeight + 24
        onDismissed: root.answer("")

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 4

            Text {
                id: title  // holds the keyboard: arrows, Enter, Esc
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                text: root.prompt
                color: Colors.foreground
                font { family: root.font; pixelSize: 13; weight: Font.DemiBold }
                elide: Text.ElideRight

                Keys.onUpPressed: view.decrementCurrentIndex()
                Keys.onDownPressed: view.incrementCurrentIndex()
                Keys.onTabPressed: view.incrementCurrentIndex()
                Keys.onReturnPressed: root.answer(root.options[view.currentIndex])
                Keys.onEnterPressed: root.answer(root.options[view.currentIndex])
                Keys.onEscapePressed: root.answer("")
            }

            ListView {
                id: view
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                model: root.options
                keyNavigationWraps: true
                highlightMoveDuration: Motion.fast
                highlightResizeDuration: 0

                // Darker, not accent: in Super+K the accent means "on".
                highlight: Rectangle {
                    radius: 8
                    color: Colors.selection
                }

                delegate: Item {
                    id: row
                    required property string modelData
                    required property int index
                    width: ListView.view.width
                    height: 36

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: view.currentIndex = row.index
                        onClicked: root.answer(row.modelData)
                    }

                    Text {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData
                        color: Colors.foreground
                        font { family: root.font; pixelSize: 13 }
                    }
                }
            }
        }
    }
}
