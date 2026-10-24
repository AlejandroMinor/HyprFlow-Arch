// The system tray. Icons pop in as apps arrive (bar.json "icons" swaps them
// for a glyph or an .svg); click activates, right click opens the app's menu
// in the card (panels/TrayMenu).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.bar
import qs.bar.panels
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
            // bar.json "icons", by the app's id or tooltip title: a Nerd Font
            // glyph, or an .svg of bar/icons/ drawn in the text colour. Apps
            // with none keep their own icon, in greys.
            readonly property string mapped: (tray.settings.icons ?? {})[slot.modelData.id]
                ?? (tray.settings.icons ?? {})[slot.modelData.tooltipTitle] ?? ""
            readonly property bool svg: mapped.endsWith(".svg")

            Text {
                anchors.centerIn: parent
                visible: slot.mapped !== "" && !slot.svg
                text: slot.mapped
                color: Colors.foreground
                font { family: tray.look.font; pixelSize: tray.look.iconSize }
            }
            IconImage {
                anchors.centerIn: parent
                visible: slot.mapped === "" || slot.svg
                implicitSize: tray.look.iconSize
                source: slot.svg ? Qt.resolvedUrl("../icons/" + slot.mapped) : slot.modelData.icon
                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: -1
                    // brightness lifts a black drawing to white, then it takes the colour.
                    brightness: slot.svg ? 1 : 0
                    colorization: slot.svg ? 1 : 0
                    colorizationColor: Colors.foreground
                }
            }
            Component {
                id: menu
                TrayMenu {
                    menu: slot.modelData.menu
                    title: slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id
                    look: tray.look
                    onDone: tray.bar.collapse()
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    if (e.button === Qt.RightButton || slot.modelData.onlyMenu) {
                        if (slot.modelData.hasMenu) tray.bar.expand(slot, menu, 0, 0, 220);
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
