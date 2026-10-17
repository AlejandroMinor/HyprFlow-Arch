// What a module is: an icon and a text on a pill that lights up on hover,
// with clicks, scroll and a tooltip. Most modules only fill these in; one
// that draws its own content puts it inside (it replaces the icon and text).
//
// Polling, for a module that reads something every so often: set `poll` to
// a command and `interval` to seconds; `polled(output)` brings each result.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

Item {
    id: mod

    property var bar
    property var settings: ({})
    property string name

    property string icon: ""
    property color iconColor: Colors.foreground
    readonly property var look: bar.style.module
    property string iconFont: look.font
    property int iconSize: look.iconSize
    property real iconRotation: 0  // animated: a drawer's handle turns
    property string text: ""
    property bool dim: false        // off, idle or muted
    property string tooltip: ""
    property bool hoverable: true
    // A HoverHandler, not the MouseArea: in Qt 6 hover goes to the topmost
    // item, so a slider opened on hover took it away, closed, gave it back
    // and opened again, over and over. The handler watches without competing.
    readonly property bool hovered: hover.hovered
    HoverHandler { id: hover }
    default property alias content: custom.data
    readonly property bool drawsOwn: custom.visibleChildren.length > 0

    property var poll: []
    property int interval: 5
    signal polled(string output)

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int steps)  // +1 up, -1 down

    implicitWidth: (mod.drawsOwn ? custom.childrenRect.width : row.implicitWidth) + 16
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: mod.look.radius
        color: mod.hoverable && mod.hovered ? BarTheme.tint(mod.look.hover) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    // Under the content: a module's own buttons take their clicks first.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: false  // the HoverHandler above does it
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => {
            mod.bar.tooltip.hide();
            if (e.button === Qt.RightButton) mod.rightClicked();
            else if (e.button === Qt.MiddleButton) mod.middleClicked();
            else mod.clicked();
        }
        onWheel: e => mod.scrolled(e.angleDelta.y > 0 ? 1 : -1)
    }
    onHoveredChanged: {
        if (hovered && tooltip) bar.tooltip.show(mod, tooltip);
        else bar.tooltip.hide(mod);
    }
    RowLayout {
        id: row
        visible: !mod.drawsOwn
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: mod.icon !== ""
            text: mod.icon
            // The module whose panel is open shows it in the accent.
            color: mod.bar?.expansion?.owner === mod ? BarTheme.accent
                 : Qt.alpha(mod.iconColor, mod.dim ? mod.look.dim : 1)
            font { family: mod.iconFont; pixelSize: mod.iconSize }
            rotation: mod.iconRotation
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on rotation { Anim { duration: Motion.normal + 60; curve: Motion.enter } }
        }
        Text {
            visible: mod.text !== ""
            text: mod.text
            textFormat: Text.StyledText
            color: Qt.alpha(Colors.foreground, mod.dim ? mod.look.dim : 1)
            font { family: mod.look.font; pixelSize: mod.look.fontSize }
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    Item {
        id: custom
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: parent.height
    }

    onTooltipChanged: {
        if (!hovered) return;
        if (tooltip) bar.tooltip.show(mod, tooltip);
        else bar.tooltip.hide(mod);  // emptied (the clock while its calendar is open)
    }

    Process {
        id: poller
        command: mod.poll
        stdout: StdioCollector { onStreamFinished: mod.polled(text) }
    }
    Timer {
        running: mod.poll.length > 0
        interval: mod.interval * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }

    function pollNow() {
        if (poll.length) poller.running = true;
    }

    // A command from bar.json, run as Waybar runs it: through the shell.
    function run(command) {
        if (command)
            Quickshell.execDetached(["sh", "-c", command]);
    }
}
