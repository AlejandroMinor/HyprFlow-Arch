// A card of modules, like the panels' (38 % black, faint border). Its width
// follows the modules exactly, frame by frame, while they animate their own
// (a second animation here lagged behind and let them spill out of the card).
// Drops in after `delay` ms.
//
// A module can open its card downward (bar.expand): the same card grows,
// wider and taller, and its panel fades in below the modules, so the bar
// itself seems to stretch open. It shrinks back on the way out.
import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: cluster
    objectName: "cluster"  // bar.expand finds a module's card by it

    property var bar
    property var names: []
    property int delay: 0
    property string side: "center"  // where the card sits; its modules keep to it
    readonly property bool moving: drop.running

    // The expansion this card holds, if any ({owner, component, width, height});
    // the panel's own height wins over the one asked for.
    readonly property var opened: bar.expansion?.cluster === cluster ? bar.expansion : null
    property var shown: null  // the last one, kept while shrinking away
    readonly property real baseWidth: row.implicitWidth + 2 * bar.style.card.padding
    // The panel's width: the one asked for, or 0 for the card's whole width
    // (but at least its minWidth: the card widens for it).
    readonly property real panelWidth: shown
        ? (shown.width || Math.max(shown.minWidth, baseWidth - 2 * bar.style.card.padding)) : 0

    // How open the card is, 0..1: the card's growth and the panel's entrance
    // both follow it. Started by hand on each change, so opening takes the
    // arriving curve and closing the leaving one (a Behavior would read the
    // curve of the change before).
    property real openness: 0
    // The panel's height plus the card's padding under it, like at the sides.
    readonly property real grow: ((panel.item?.implicitHeight || (shown?.height ?? 0)) + bar.style.card.padding) * openness
    readonly property real widen: Math.max(0, panelWidth + 2 * bar.style.card.padding - baseWidth) * openness
    Anim {
        id: unfold
        target: cluster
        property: "openness"
        onFinished: if (!cluster.opened) cluster.shown = null  // shrunk: let the panel go
    }
    onOpenedChanged: {
        if (opened) shown = opened;
        unfold.stop();
        unfold.to = opened ? 1 : 0;
        unfold.duration = opened ? Motion.normal + 80 : Motion.exit + 60;
        unfold.curve = opened ? Motion.enter : Motion.leave;
        unfold.start();
    }

    visible: names.length > 0
    y: bar.gap
    width: baseWidth + widen
    height: bar.clusterHeight + grow
    clip: true
    // In the single style the bar draws the one card; these are bare,
    // unless open, when the card below needs its own fill.
    radius: bar.style.card.radius
    color: bar.single && grow < 0.5 ? "transparent" : Qt.alpha(Colors.background, bar.style.card.fill ?? Colors.card)
    border { width: bar.single && grow < 0.5 ? 0 : 1; color: bar.style.card.border == null ? Colors.border : Colors.fg(bar.style.card.border) }

    // Starts above the screen; `bar.shown` brings it down. A value, set once
    // (not a binding): a style with another height re-ran the binding and
    // sent the card back up, out of sight.
    property real offset: 0
    opacity: 0
    transform: Translate { y: cluster.offset }

    SequentialAnimation {
        id: drop
        PauseAnimation { duration: cluster.bar.shown ? cluster.delay : 0 }
        ParallelAnimation {
            Anim {
                target: cluster; property: "offset"
                to: cluster.bar.shown ? 0 : -(cluster.bar.clusterHeight + cluster.bar.gap + 8)
                duration: cluster.bar.shown ? Motion.normal + 80 : Motion.exit
                curve: cluster.bar.shown ? Motion.enter : Motion.leave
            }
            Anim {
                target: cluster; property: "opacity"
                to: cluster.bar.shown ? 1 : 0
                duration: cluster.bar.shown ? Motion.normal : Motion.exit
            }
        }
    }
    Connections {
        target: cluster.bar
        function onShownChanged() { drop.restart(); }
    }
    Component.onCompleted: {
        offset = -(bar.clusterHeight + bar.gap + 8);
        drop.start();
    }

    // The modules stay in the card's top strip, however tall it grows, and on
    // its side however wide: a right card widens leftward around them.
    RowLayout {
        id: row
        x: cluster.side === "left" ? cluster.bar.style.card.padding
         : cluster.side === "right" ? cluster.width - width - cluster.bar.style.card.padding
         : (cluster.width - width) / 2
        y: (cluster.bar.clusterHeight - height) / 2
        spacing: 0
        Repeater {
            model: cluster.names
            delegate: ModuleLoader {
                required property string modelData
                name: modelData
                bar: cluster.bar
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // The opened panel, below the modules and under the one that opened it;
    // in once the card has room.
    Loader {
        id: panel
        active: cluster.shown !== null
        sourceComponent: cluster.shown?.component ?? null
        x: {
            const owner = cluster.shown?.owner;
            const pad = cluster.bar.style.card.padding;
            const center = owner ? owner.mapToItem(cluster, owner.width / 2, 0).x : cluster.width / 2;
            return Math.max(pad, Math.min(center - width / 2, cluster.width - width - pad));
        }
        y: cluster.bar.clusterHeight
        width: cluster.panelWidth
        height: item?.implicitHeight || (cluster.shown?.height ?? 0)
        // In over the last part of the growth, settling down a little;
        // closing, it goes first and the card follows.
        opacity: Math.max(0, (cluster.openness - 0.45) / 0.55)
        transform: Translate { y: (1 - cluster.openness) * -12 }
    }
}
