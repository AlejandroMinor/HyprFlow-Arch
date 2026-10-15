// Super+K's "Audio output" and the Waybar volume click. The sinks come from
// lib/sink-switch.py --json (the personal ~/.config/hyprflow/sink-switch.conf
// hides some); picking one runs --set. Opened through IPC:
// qs -c hyprflow ipc call sinkswitch toggle
//
// The switcher itself is a Quickshell take on Seyloria's sinkswitch
// (https://github.com/Seyloria/sinkswitch, GPL-3.0), which in turn credits
// Sebastiaan76's waybar_wireplumber_audio_changer for the idea.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.local/lib/hyprflow/sink-switch.py"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string speaker: "󰕾"  // volume high, the Osd.qml glyph
    readonly property string check: "󰄬"
    property bool open: false
    property var sinks: []  // [{id, label, default, kind, icon}]
    property int play: 0    // bumped on every open: the rows slide in again

    function current() {
        const i = root.sinks.findIndex(s => s.default);
        return i < 0 ? 0 : i;
    }

    function show() {
        view.currentIndex = root.current();
        root.open = true;
        root.play = root.play + 1;
        view.forceActiveFocus();
    }

    IpcHandler {
        target: "sinkswitch"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            // Read again: devices come and go.
            list.running = true;
            if (root.sinks.length > 0)
                root.show();
        }
    }

    Process {
        id: list
        command: [root.script, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.sinks = JSON.parse(text);
                } catch (e) {
                    return;
                }
                if (!root.open)
                    root.show();
                else
                    view.currentIndex = root.current();  // the list may have changed
            }
        }
    }

    Process { id: runner }

    function choose(sink) {
        root.open = false;
        runner.command = [root.script, "--set", String(sink.id)];
        runner.running = true;
    }

    function chooseCurrent() {
        const sink = root.sinks[view.currentIndex];
        if (sink)
            root.choose(sink);
    }

    Overlay {
        id: overlay
        name: "hyprflow-sinkswitch"
        open: root.open
        cardWidth: 420
        cardHeight: column.implicitHeight + 24
        onDismissed: root.open = false

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 2
                spacing: 10

                Text {
                    text: root.speaker
                    color: Qt.alpha(Colors.foreground, 0.45)
                    font { family: root.font; pixelSize: 14 }
                }
                Text {
                    text: "Audio output"
                    color: Qt.alpha(Colors.foreground, 0.45)
                    font { family: root.font; pixelSize: 13 }
                    Layout.fillWidth: true
                }
                Text {
                    visible: root.sinks.length > 1
                    text: root.sinks.length + " outputs"
                    color: Qt.alpha(Colors.foreground, 0.3)
                    font { family: root.font; pixelSize: 11 }
                }
            }

            ListView {
                id: view
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                focus: true
                model: root.sinks
                keyNavigationWraps: true
                highlightMoveDuration: Motion.fast
                highlightResizeDuration: 0
                Keys.onUpPressed: view.decrementCurrentIndex()
                Keys.onDownPressed: view.incrementCurrentIndex()
                Keys.onTabPressed: view.incrementCurrentIndex()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageDown)
                        view.currentIndex = Math.min(view.currentIndex + 5, view.count - 1);
                    else if (event.key === Qt.Key_PageUp)
                        view.currentIndex = Math.max(view.currentIndex - 5, 0);
                }
                Keys.onReturnPressed: root.chooseCurrent()
                Keys.onEnterPressed: root.chooseCurrent()
                Keys.onEscapePressed: root.open = false

                // The layer maps after open: take the keys once it is up.
                Connections {
                    target: overlay
                    function onVisibleChanged() {
                        if (overlay.visible && root.open)
                            view.forceActiveFocus();
                    }
                }

                highlight: Rectangle {
                    radius: 10
                    color: Colors.selection
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: ListView.view.width
                    height: 46

                    // Rows drop in together, a step each; replay on every open.
                    opacity: 0
                    transform: Translate { id: slide; x: 14 }
                    function enter() { entrance.restart(); }
                    Component.onCompleted: enter()
                    Connections {
                        target: root
                        function onPlayChanged() { row.enter(); }
                    }
                    SequentialAnimation {
                        id: entrance
                        PauseAnimation { duration: Math.min(row.index, 10) * 28 }
                        ParallelAnimation {
                            NumberAnimation { target: row; property: "opacity"; to: 1
                                              duration: Motion.normal; easing.type: Easing.OutCubic }
                            NumberAnimation { target: slide; property: "x"; to: 0
                                              duration: Motion.normal; easing.type: Easing.OutCubic }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: view.currentIndex = row.index
                        onClicked: root.choose(row.modelData)
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 12

                        Text {
                            text: row.modelData.icon
                            color: row.modelData.default ? Colors.accent : Qt.alpha(Colors.foreground, 0.75)
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
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            visible: row.modelData.default
                            radius: height / 2
                            implicitWidth: stateText.implicitWidth + 16
                            implicitHeight: 22
                            color: Colors.accent
                            Text {
                                id: stateText
                                anchors.centerIn: parent
                                text: root.check + "  current"
                                color: Colors.background
                                font { family: root.font; pixelSize: 11; weight: Font.DemiBold }
                            }
                        }
                    }
                }
            }
        }
    }
}
