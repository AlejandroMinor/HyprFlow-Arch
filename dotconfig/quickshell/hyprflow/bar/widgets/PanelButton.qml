// A panel's button; the strong one filled with the accent, like today in
// the calendar.
import QtQuick
import qs
import qs.bar.services

Rectangle {
    id: button

    property string label
    property bool strong: false
    property string fontFamily
    signal clicked()

    implicitWidth: buttonText.implicitWidth + 24
    implicitHeight: 28
    radius: 8
    color: strong ? BarTheme.accent : buttonArea.containsMouse ? BarTheme.tint(0.12) : Qt.alpha(Colors.foreground, 0.06)

    Text {
        id: buttonText
        anchors.centerIn: parent
        text: button.label
        color: button.strong ? Colors.background : Colors.foreground
        font { family: button.fontFamily; pixelSize: 12; bold: button.strong }
    }
    MouseArea {
        id: buttonArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
