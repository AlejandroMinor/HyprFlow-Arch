// A NumberAnimation on Motion's defaults; set `curve` to Motion.enter or
// Motion.leave for things arriving or leaving.
import QtQuick

NumberAnimation {
    property var curve: Motion.standard
    duration: Motion.fast
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curve
}
