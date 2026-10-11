// The panels' colours, shared by every panel. Fixed on purpose: they do not
// follow wallust.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color background: "#000000"
    readonly property color foreground: "#FFFFFF"
    readonly property color accent:     "#3DFF3D"  // a switch that is on
    readonly property color selection:  Qt.rgba(0, 0, 0, 0.55)  // the selected row
}
