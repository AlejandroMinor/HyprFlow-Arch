// A one-line text box for the panels: a hint while empty, Tab to `next`,
// Enter `accepted`, Esc `cancelled`.
import QtQuick
import qs

Rectangle {
    id: box

    property string hint
    property alias text: input.text
    property alias field: input
    property Item next
    property string fontFamily
    signal accepted()
    signal cancelled()

    implicitHeight: 28
    radius: 8
    color: Colors.fg(input.activeFocus ? 0.12 : 0.06)

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Colors.foreground
        selectionColor: Colors.fg(0.3)
        font { family: box.fontFamily; pixelSize: 12 }
        KeyNavigation.tab: box.next?.field ?? null
        Keys.onReturnPressed: box.accepted()
        Keys.onEnterPressed: box.accepted()
        Keys.onEscapePressed: box.cancelled()
    }
    Text {
        visible: input.text === "" && !input.activeFocus
        anchors { fill: parent; leftMargin: 10 }
        verticalAlignment: Text.AlignVCenter
        text: box.hint
        color: Colors.fg(0.45)
        font { family: box.fontFamily; pixelSize: 12 }
    }
}
