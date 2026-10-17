// The bar's tooltip: one per bar, moved to whichever module is hovered.
// Shows after a short rest so a sweep across the bar does not flash it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: tip

    property var bar
    property Item target: null
    property string label: ""
    property bool open: false

    function show(item, text) {
        target = item;
        label = text;
        if (open) return;
        rest.restart();
    }
    function hide(item) {
        if (item && item !== target) return;
        rest.stop();
        open = false;
    }

    Timer { id: rest; interval: 350; onTriggered: tip.open = true }

    screen: bar.screen
    visible: open || fade.running
    color: "transparent"
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    // The final size at once, from the text: the card animates inside it,
    // a window that followed the animation kept a size from halfway.
    implicitWidth: text.implicitWidth + 24
    implicitHeight: text.implicitHeight + 16 + 8
    margins.top: bar.baseHeight + 2
    margins.left: {
        if (!target) return 0;
        const x = bar.margins.left + target.mapToItem(null, 0, 0).x + target.width / 2;
        return Math.max(0, Math.min(x - implicitWidth / 2, screen.width - implicitWidth));
    }
    mask: Region {}  // never in the way of a click
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "hyprflow-bar-tooltip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: card
        width: text.implicitWidth + 24
        height: text.implicitHeight + 16
        radius: tip.bar.style.tooltip.radius
        color: Qt.alpha(Colors.background, tip.bar.style.card.fill)
        border { width: 1; color: Qt.alpha(Colors.foreground, tip.bar.style.card.border) }
        Behavior on width { Anim { duration: Motion.fast } }
        Behavior on height { Anim { duration: Motion.fast } }

        opacity: tip.open ? 1 : 0
        y: tip.open ? 8 : 2
        Behavior on opacity { Anim { id: fade; duration: Motion.fast } }
        Behavior on y { Anim { duration: Motion.fast } }

        Text {
            id: text
            anchors.centerIn: parent
            text: tip.label.replace(/\n/g, "<br>")
            textFormat: Text.StyledText
            color: Colors.foreground
            font { family: tip.bar.style.module.font; pixelSize: tip.bar.style.tooltip.fontSize }
        }
    }
}
