// One bar on one screen: the left, center and right clusters of its layout.
// The clusters drop in one after the other; hidden, they rise away and the
// windows get the space back.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.bar.widgets

PanelWindow {
    id: bar

    property var layout: ({})
    property var settings: ({})
    property bool shown: true
    property var style: ({})  // styles/*.json, merged by Bars
    readonly property bool single: style.cards === "single"
    readonly property int clusterHeight: style.height
    readonly property int gap: style.gap
    readonly property bool settled: !shown && !left.moving && !center.moving && !right.moving

    anchors { top: true; left: true; right: true }
    margins { left: style.margin; right: style.margin }
    readonly property int baseHeight: clusterHeight + 2 * gap
    // Room, always, for a card growing down (expand): resizing the window on
    // each open made Hyprland replay its layer animation, the whole bar
    // shrinking and growing back. The room is see-through and takes no
    // clicks (mask), and the windows keep only the bar's own height.
    readonly property int roomBelow: 648
    implicitHeight: baseHeight + roomBelow
    exclusiveZone: shown ? baseHeight : 0
    visible: !settled
    color: "transparent"
    WlrLayershell.namespace: "hyprflow-bar"
    WlrLayershell.layer: WlrLayer.Top
    // Typing only into an open panel (the calendar's form), and only on a click.
    WlrLayershell.keyboardFocus: expansion ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the clusters take clicks: the gaps between them belong to the
    // windows underneath.
    mask: Region {
        Region { item: bar.single ? strip : left }
        Region { item: center }
        Region { item: right }
    }

    // The single style: one card behind the three, moving with the left one.
    Rectangle {
        id: strip
        visible: bar.single
        y: bar.gap
        width: parent.width
        height: bar.clusterHeight
        radius: bar.style.card.radius
        color: Qt.alpha(Colors.background, bar.style.card.fill ?? Colors.card)
        border { width: 1; color: bar.style.card.border == null ? Colors.border : Colors.fg(bar.style.card.border) }
        opacity: left.opacity
        transform: Translate { y: left.offset }
    }

    // The modules by their bar.json name, for one to reach another (cava
    // opens the media's panel).
    property var loaded: ({})

    // A module opens its card downward: expand(this, panel, width, height,
    // minWidth) (width 0: the card's whole width, but at least minWidth),
    // the height a fallback for a panel without its own implicitHeight; the
    // same call again, or a click anywhere else, closes it.
    property var expansion: null
    function expand(owner, component, width, height, minWidth) {
        if (expansion && expansion.owner !== owner) collapse();
        if (expansion?.owner === owner) { collapse(); return; }
        let card = owner;
        while (card && card.objectName !== "cluster") card = card.parent;
        if (!card) return;
        tooltip.hide();
        expansion = { owner, cluster: card, component, width, height, minWidth: minWidth || 0 };
    }
    function collapse() {
        expansion = null;
    }
    HyprlandFocusGrab {
        windows: [bar]
        active: bar.expansion !== null
        onCleared: bar.collapse()
    }

    // The tooltip every module of this bar shares.
    property alias tooltip: tip
    BarTooltip { id: tip; bar: bar }

    Cluster {
        id: left
        bar: bar
        names: bar.layout.left ?? []
        side: "left"
        delay: 0
        anchors.left: parent.left
    }
    Cluster {
        id: center
        bar: bar
        names: bar.layout.center ?? []
        delay: 60
        anchors.horizontalCenter: parent.horizontalCenter
    }
    Cluster {
        id: right
        bar: bar
        names: bar.layout.right ?? []
        side: "right"
        delay: 120
        anchors.right: parent.right
    }
}
