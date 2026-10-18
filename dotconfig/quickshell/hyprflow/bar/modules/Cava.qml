// The live audio visualizer: CavaLevels' spectrum, drawn in the style
// picked in Super+K (widgets/Spectrum.qml). A Module, so it can be a
// drawer's handle (the media). "colors": false draws it white.
import QtQuick
import qs.bar
import qs.bar.widgets

Module {
    id: cava

    // Right click opens the panel of the module named in "panel" (the media).
    onRightClicked: bar.loaded[settings.panel]?.openPanel?.()

    Spectrum {
        anchors.verticalCenter: parent.verticalCenter
        colored: cava.settings.colors !== false
    }
}
