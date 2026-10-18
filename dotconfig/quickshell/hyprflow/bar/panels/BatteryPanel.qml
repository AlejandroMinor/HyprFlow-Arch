// The batteries' panel, opened from battery-hub: every device with its
// level, a bar in the theme's accent (red when critical), a bolt while
// charging. Redrawn as battery-hub reports.
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.services

Item {
    id: panel

    property var devices: []  // battery-hub's "devices"
    property var look

    implicitHeight: column.implicitHeight + 28

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        Text {
            text: "BATTERIES"
            color: Qt.alpha(Colors.foreground, 0.45)
            font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
        }
        Text {
            visible: panel.devices.length === 0
            text: "No batteries"
            color: Qt.alpha(Colors.foreground, 0.45)
            font { family: panel.look.font; pixelSize: 12 }
        }

        Repeater {
            model: panel.devices
            delegate: RowLayout {
                id: row
                required property var modelData
                required property int index
                readonly property bool critical: modelData.level === "critical"
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.icon
                    color: Colors.foreground
                    font { family: panel.look.font; pixelSize: 16 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: Colors.foreground
                            font { family: panel.look.font; pixelSize: 12 }
                        }
                        Text {
                            // A bolt while charging.
                            text: (row.modelData.charging ? "\u{F140B} " : "") + row.modelData.percent + "%"
                            color: row.critical ? "#f7768e" : Colors.foreground
                            font { family: panel.look.font; pixelSize: 12; bold: true }
                        }
                    }
                    // The level, filling in as the panel opens.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Qt.alpha(Colors.foreground, 0.15)
                        Rectangle {
                            id: fill
                            height: parent.height
                            radius: 2
                            width: 0
                            color: row.critical ? "#f7768e" : BarTheme.accent
                            readonly property real target: parent.width * Math.max(0, Math.min(1, row.modelData.percent / 100))
                            onTargetChanged: grow.restart()
                            SequentialAnimation {
                                id: grow
                                PauseAnimation { duration: row.index * 40 }
                                Anim { target: fill; property: "width"; to: fill.target; duration: Motion.normal }
                            }
                        }
                    }
                }

                // One after the other, like the calendar's rows.
                opacity: 0
                Component.onCompleted: show.start()
                SequentialAnimation {
                    id: show
                    PauseAnimation { duration: row.index * 40 }
                    Anim { target: row; property: "opacity"; to: 1; duration: Motion.normal }
                }
            }
        }
    }
}
