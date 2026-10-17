// A ring that fills with a value (0..1), clockwise from the top, and sweeps
// to each new one. A custom module's "ring" (claude-usage's percentage).
import QtQuick
import QtQuick.Shapes
import qs
import qs.bar.services

Item {
    id: ring

    property real value: 0
    property real size: 14
    property real thickness: 2.5
    property real shown: value
    Behavior on shown { Anim { duration: Motion.normal; curve: Motion.enter } }

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.alpha(Colors.foreground, 0.18)
            strokeWidth: ring.thickness
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.thickness) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: BarTheme.accent
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.thickness) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, ring.shown))
            }
        }
    }
}
