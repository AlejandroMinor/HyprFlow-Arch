// This screen's workspaces, then its scratchpad (special:magic, Super+Z)
// while it has windows. One pill slides and stretches to the active one, the
// scratchpad while it is open; a workspace asking for attention pulses.
// Click to go there (the scratchpad: open or close it), scroll to step
// through them.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Item {
    id: ws

    property var bar
    property var settings: ({})
    property string name

    readonly property string monitor: bar.screen?.name ?? ""
    // Special workspaces have negative ids: after the others.
    readonly property var shown: Hyprland.workspaces.values
        .filter(w => w.monitor?.name === monitor && (w.id > 0 || w.name.startsWith("special:")))
        .sort((a, b) => (a.id < 0) - (b.id < 0) || a.id - b.id)
    readonly property var screenMonitor: Hyprland.monitors.values.find(m => m.name === monitor) ?? null
    // An open scratchpad is where you are.
    readonly property string openSpecial: screenMonitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property int activeId: openSpecial
        ? (shown.find(w => w.name === openSpecial)?.id ?? -1)
        : (screenMonitor?.activeWorkspace?.id ?? -1)
    readonly property int activeIndex: shown.findIndex(w => w.id === activeId)

    readonly property var look: bar.style.workspaces

    implicitWidth: row.width + 8
    implicitHeight: 30

    function go(target) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + target + " })"]);
    }
    function open(workspace) {
        if (workspace.id > 0) return go(workspace.id);
        const special = workspace.name.replace("special:", "");
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.workspace.toggle_special("' + special + '")']);
    }
    // The monitor's open scratchpad is only in its IPC object: ask again when it changes.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") Hyprland.refreshMonitors();
        }
    }

    // The active pill, under the numbers.
    Rectangle {
        id: pill
        readonly property Item at: rep.count, ws.activeIndex >= 0 ? rep.itemAt(ws.activeIndex) : null
        visible: at !== null
        x: row.x + (at?.x ?? 0)
        width: at?.width ?? 0
        height: ws.look.height
        anchors.verticalCenter: parent.verticalCenter
        radius: ws.look.radius
        color: Qt.alpha(Colors.foreground, ws.look.pill)
        border { width: 1; color: Qt.alpha(Colors.foreground, ws.look.pillBorder) }
        Behavior on x { Anim { duration: Motion.normal; curve: Motion.enter } }
        Behavior on width { Anim { duration: Motion.normal; curve: Motion.enter } }
    }

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            id: rep
            model: ws.shown
            delegate: Item {
                id: slot
                required property var modelData
                readonly property bool active: modelData.id === ws.activeId
                readonly property bool urgent: modelData.urgent ?? false
                width: active ? ws.look.activeWidth : ws.look.width
                height: ws.look.height
                Behavior on width { Anim { duration: Motion.normal; curve: Motion.enter } }

                // A new workspace grows in.
                scale: 0
                Component.onCompleted: scale = 1
                Behavior on scale { Anim { duration: Motion.normal; curve: Motion.enter } }

                Rectangle {
                    anchors.fill: parent
                    radius: ws.look.radius
                    color: Qt.alpha(Colors.foreground, hover.containsMouse && !slot.active ? ws.bar.style.module.hover : 0)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                Rectangle {
                    id: alert
                    anchors.fill: parent
                    radius: ws.look.radius
                    color: Colors.foreground
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: slot.urgent
                        loops: Animation.Infinite
                        Anim { to: 0.45; duration: 500 }
                        Anim { to: 0.1; duration: 500 }
                        onRunningChanged: if (!running) alert.opacity = 0
                    }
                }
                Text {
                    anchors.centerIn: parent
                    // 901+: macOS-style fullscreen; special: the scratchpad (sparkles).
                    text: slot.modelData.id < 0 ? "\u{F0674}"
                        : slot.modelData.id > 900 ? "\u{F02A0}" : slot.modelData.name
                    color: Qt.alpha(Colors.foreground, slot.active ? 1 : ws.look.idle)
                    font { family: ws.bar.style.module.font; pixelSize: ws.look.fontSize; bold: slot.active }
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ws.open(slot.modelData)
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => ws.go(e.angleDelta.y > 0 ? '"e-1"' : '"e+1"')
    }
}
