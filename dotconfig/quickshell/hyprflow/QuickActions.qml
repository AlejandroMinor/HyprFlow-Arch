// Super+K panel. The actions, their states and what they run all live in
// lib/quick-actions.py: this only draws its --json and runs the pick with --run.
// Opened through IPC: qs -c hyprflow ipc call quickactions toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/lib/hyprflow/quick-actions.py"
    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property var actions: []  // the last list read: opens with it at once
    property string query: ""

    // Fuzzy, like rofi: the typed letters in order, gaps allowed ("gm" finds
    // "Game mode").
    readonly property var shown: actions.filter(a => {
        const label = a.label.toLowerCase();
        let at = 0;
        for (const c of query.toLowerCase().replace(/ /g, "")) {
            at = label.indexOf(c, at) + 1;
            if (at === 0)
                return false;
        }
        return true;
    })

    IpcHandler {
        target: "quickactions"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            // Open now with the last list, refresh the states as they come in.
            // Only the very first open waits for them.
            list.running = true;
            if (root.actions.length > 0)
                root.show();
        }
    }

    Process {
        id: list
        command: [root.script, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const current = view.currentIndex;
                try {
                    root.actions = JSON.parse(text);
                } catch (e) {
                    return;
                }
                view.currentIndex = current;
                if (!root.open)
                    root.show();
            }
        }
    }

    function show() {
        search.text = "";  // typing broke its binding to query
        root.query = "";
        view.currentIndex = 0;
        root.open = true;
        search.forceActiveFocus();
    }

    Process { id: runner }

    function runCurrent() {
        const action = root.shown[view.currentIndex];
        if (action)
            root.run(action.label);
    }

    function run(label) {
        root.open = false;
        runner.command = [root.script, "--run", label];
        runner.running = true;
    }

    Overlay {
        name: "hyprflow-quickactions"
        open: root.open
        cardHeight: column.implicitHeight + 24
        onDismissed: root.open = false

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 4

            // Typing filters; the arrows, Enter and Esc work from here too.
            TextInput {
                id: search
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 4
                onTextEdited: { root.query = text; view.currentIndex = 0; }
                color: Colors.foreground
                selectionColor: Qt.alpha(Colors.accent, 0.4)
                font { family: root.font; pixelSize: 13 }

                Text {
                    visible: !search.text
                    text: "Quick actions"
                    color: Qt.alpha(Colors.foreground, 0.45)
                    font: search.font
                }

                Keys.onUpPressed: view.decrementCurrentIndex()
                Keys.onDownPressed: view.incrementCurrentIndex()
                Keys.onTabPressed: view.incrementCurrentIndex()
                Keys.onReturnPressed: root.runCurrent()
                Keys.onEnterPressed: root.runCurrent()
                Keys.onEscapePressed: root.open = false
            }

            ListView {
                id: view
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                model: root.shown
                keyNavigationWraps: true
                highlightMoveDuration: Motion.fast
                highlightResizeDuration: 0

                highlight: Rectangle {
                    radius: 10
                    color: Colors.selection
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: modelData.state === "on"
                    readonly property bool current: ListView.isCurrentItem
                    width: ListView.view.width
                    height: 42

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: view.currentIndex = row.index
                        onClicked: root.run(row.modelData.label)
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 12

                        Text {
                            text: row.modelData.icon
                            color: row.on ? Colors.accent : Colors.foreground
                            font { family: root.font; pixelSize: 18 }
                            Layout.preferredWidth: 22
                            horizontalAlignment: Text.AlignHCenter
                            scale: row.current ? 1.15 : 1
                            Behavior on scale { Anim {} }
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                        Text {
                            text: row.modelData.label
                            color: Colors.foreground
                            font { family: root.font; pixelSize: 14 }
                            Layout.fillWidth: true
                        }
                        // State pill: filled when on, plain otherwise.
                        Rectangle {
                            visible: row.modelData.state !== ""
                            radius: height / 2
                            implicitWidth: stateText.implicitWidth + 16
                            implicitHeight: 22
                            color: row.on ? Colors.accent : Qt.alpha(Colors.foreground, 0.08)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Text {
                                id: stateText
                                anchors.centerIn: parent
                                text: row.modelData.state
                                color: row.on ? Colors.background : Qt.alpha(Colors.foreground, 0.7)
                                font { family: root.font; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }
                    }
                }
            }
        }
    }
}
