// A slider: a track, its fill and a knob; click or drag to set. The value
// shown slides to each new one.
import QtQuick
import qs

Item {
    id: slider

    property real value: 0  // 0..1
    property bool muted: false
    property real dim: 0.45
    readonly property bool dragging: area.pressed
    signal moved(real value)

    property real shown: value
    Behavior on shown { enabled: !slider.dragging; Anim { duration: Motion.normal } }

    implicitWidth: 120
    implicitHeight: 14

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.alpha(Colors.foreground, 0.15)
        Rectangle {
            height: parent.height
            radius: 2
            width: parent.width * Math.max(0, Math.min(1, slider.shown))
            color: slider.muted ? Qt.alpha(Colors.foreground, slider.dim) : Qt.alpha(BarTheme.accent, 0.9)
        }
    }
    Rectangle {
        x: track.width * Math.max(0, Math.min(1, slider.shown)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 10; height: 10; radius: 5
        color: slider.muted ? Colors.foreground : BarTheme.accent
        scale: area.containsMouse || slider.dragging ? 1.2 : 1
        Behavior on scale { Anim {} }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6  // easier to grab
        hoverEnabled: true
        function set(x) { slider.moved(Math.max(0, Math.min(1, (x - 6) / track.width))); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x); }
    }
}
