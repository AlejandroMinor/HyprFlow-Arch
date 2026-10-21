// A tray app's menu, drawn as the bar's own card (opened from Tray.qml)
// instead of Qt's: its entries, checks and submenus, which open in place
// with a row to go back.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.bar.services

Item {
    id: panel

    property var menu    // the tray item's QsMenuHandle
    property string title
    property var look
    signal done()

    // The submenus opened, the last one shown.
    property var stack: []
    readonly property var current: stack.length ? stack[stack.length - 1] : menu

    implicitHeight: column.implicitHeight + 28

    QsMenuOpener { id: opener; menu: panel.current }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 2

        Heading { text: panel.title.toUpperCase(); Layout.bottomMargin: 8 }

        MenuRow {
            visible: panel.stack.length > 0
            icon: "󰁍"
            label: "Back"
            onPicked: panel.stack = panel.stack.slice(0, -1)
        }

        Repeater {
            model: opener.children
            delegate: Loader {
                id: entry
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.isSeparator ? separator : row

                Component {
                    id: separator
                    Item {
                        implicitHeight: 9
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            height: 1
                            color: Qt.alpha(Colors.foreground, 0.1)
                        }
                    }
                }
                Component {
                    id: row
                    MenuRow {
                        image: entry.modelData.icon
                        label: entry.modelData.text.replace(/_(?!_)/g, "")  // mnemonics
                        enabled: entry.modelData.enabled
                        checked: entry.modelData.buttonType !== QsMenuButtonType.None
                                 && entry.modelData.checkState === Qt.Checked
                        submenu: entry.modelData.hasChildren
                        onPicked: {
                            if (entry.modelData.hasChildren) {
                                panel.stack = [...panel.stack, entry.modelData];
                            } else {
                                entry.modelData.triggered();
                                panel.done();
                            }
                        }
                    }
                }
            }
        }
    }

    component Heading: Text {
        color: Qt.alpha(Colors.foreground, 0.45)
        font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
    }

    // One entry: an icon (a glyph or the app's image), its text, a check
    // or an arrow into its submenu.
    component MenuRow: Rectangle {
        id: rowItem
        property string icon
        property string image
        property string label
        property bool checked: false
        property bool submenu: false
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 30
        radius: 8
        color: area.containsMouse && enabled ? BarTheme.tint(panel.look.hover) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        opacity: enabled ? 1 : 0.45

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10
            Item {
                Layout.preferredWidth: 20
                implicitHeight: 14
                Text {
                    anchors.centerIn: parent
                    visible: rowItem.icon !== ""
                    text: rowItem.icon
                    color: Colors.foreground
                    font { family: panel.look.font; pixelSize: 14 }
                }
                IconImage {
                    anchors.centerIn: parent
                    visible: rowItem.icon === "" && rowItem.image !== ""
                    implicitSize: 14
                    source: rowItem.image
                }
            }
            Text {
                Layout.fillWidth: true
                text: rowItem.label
                elide: Text.ElideRight
                color: Colors.foreground
                font { family: panel.look.font; pixelSize: 12 }
            }
            Text {
                visible: rowItem.checked || rowItem.submenu
                text: rowItem.submenu ? "󰅂" : "󰄬"
                color: rowItem.checked ? BarTheme.accent : Colors.foreground
                font { family: panel.look.font; pixelSize: 14 }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: rowItem.enabled
            onClicked: rowItem.picked()
        }
    }
}
