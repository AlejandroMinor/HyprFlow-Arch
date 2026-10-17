// The system tray. Icons pop in as apps arrive; click activates, right
// click opens the app's menu.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.bar
import qs.bar.services

Row {
    id: tray

    property var bar
    property var settings: ({})
    property string name

    // Each icon spaced as a module is: the same padding either side.
    readonly property var look: bar.style.module
    spacing: 0
    height: 30

    Repeater {
        model: SystemTray.items.values
        delegate: Item {
            id: slot
            required property var modelData
            width: tray.look.iconSize + 16
            height: 30
            anchors.verticalCenter: parent?.verticalCenter

            scale: 0
            Component.onCompleted: scale = 1
            Behavior on scale { Anim { duration: Motion.normal; curve: Motion.enter } }

            Rectangle {
                anchors.fill: parent
                radius: tray.look.radius
                color: area.containsMouse ? BarTheme.tint(tray.look.hover) : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: tray.look.iconSize
                source: slot.modelData.icon
            }
            QsMenuAnchor {
                id: menu
                menu: slot.modelData.menu
                anchor.window: tray.bar
                anchor.item: slot
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    if (e.button === Qt.RightButton || slot.modelData.onlyMenu) {
                        if (slot.modelData.hasMenu) menu.open();
                    } else if (e.button === Qt.MiddleButton) {
                        slot.modelData.secondaryActivate();
                    } else {
                        slot.modelData.activate();
                    }
                }
                onContainsMouseChanged: {
                    const title = slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id;
                    if (containsMouse) tray.bar.tooltip.show(slot, title);
                    else tray.bar.tooltip.hide(slot);
                }
            }
        }
    }
}
