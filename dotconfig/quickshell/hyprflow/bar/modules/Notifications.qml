// swaync's unread count and do not disturb. The bell swings and the badge
// pops when something new arrives. Click: the panel; right: do not disturb.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.bar
import qs.bar.services

Module {
    id: mod

    property int count: 0
    property bool dnd: false

    tooltip: dnd ? "Do not disturb" : count + (count === 1 ? " notification" : " notifications")
    onClicked: Quickshell.execDetached(["swaync-client", "-t", "-sw"])
    onRightClicked: Quickshell.execDetached(["swaync-client", "-d", "-sw"])

    LongProcess {
        id: watch
        running: true
        argv: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: line => {
                let data;
                try { data = JSON.parse(line); } catch (e) { return; }
                const count = Number(data.text) || 0;
                mod.dnd = String(data.alt ?? "").startsWith("dnd");
                if (count > mod.count) ring.restart();
                mod.count = count;
            }
        }
        onExited: again.start()
    }
    Timer { id: again; interval: 5000; onTriggered: watch.running = true }

    // Just the bell's width: the badge sits over its corner, not beside it.
    Item {
        width: bell.implicitWidth + 4
        height: 30

        Text {
            id: bell
            anchors.centerIn: parent
            text: mod.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Qt.alpha(Colors.foreground, mod.dnd ? 0.45 : 1)
            font { family: mod.look.font; pixelSize: mod.iconSize }
            transformOrigin: Item.Top
        }

        // The count, in a badge that pops in.
        Rectangle {
            id: badge
            visible: mod.count > 0 && !mod.dnd
            x: bell.x + bell.implicitWidth - 6; y: 3
            height: 14
            width: Math.max(14, label.implicitWidth + 6)
            radius: 7
            color: BarTheme.accent
            Text {
                id: label
                anchors.centerIn: parent
                text: mod.count > 99 ? "99+" : mod.count
                color: Colors.background
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true }
            }
        }

        SequentialAnimation {
            id: ring
            ParallelAnimation {
                SequentialAnimation {
                    NumberAnimation { target: bell; property: "rotation"; to: 18; duration: 80 }
                    NumberAnimation { target: bell; property: "rotation"; to: -14; duration: 120 }
                    NumberAnimation { target: bell; property: "rotation"; to: 8; duration: 110 }
                    NumberAnimation { target: bell; property: "rotation"; to: 0; duration: 140; easing.type: Easing.OutBack }
                }
                SequentialAnimation {
                    NumberAnimation { target: badge; property: "scale"; from: 0.4; to: 1.25; duration: 140; easing.type: Easing.OutQuad }
                    NumberAnimation { target: badge; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
                }
            }
        }
    }
}
