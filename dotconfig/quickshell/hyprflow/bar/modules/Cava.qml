// The live audio visualizer: CavaLevels' spectrum, drawn in the style
// picked in the media panel's cog (widgets/Spectrum.qml). A Module, so it can be a
// drawer's handle (the media). "colors": false draws it white.
import QtQuick
import qs.bar
import qs.bar.widgets

Module {
    id: cava

    // A click opens the panel of the module named in "panel" (the media);
    // its drawer opens on hover ("toggle": "hover").
    onClicked: bar.loaded[settings.panel]?.openPanel?.()

    Spectrum {
        anchors.verticalCenter: parent.verticalCenter
        colored: cava.settings.colors !== false
    }
}
