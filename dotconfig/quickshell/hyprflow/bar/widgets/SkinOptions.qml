// The picked skin's options, each a chip that steps through its values;
// wrapped, since a row wider than the panel widens the whole column.
import QtQuick
import qs.bar.services

Flow {
    id: options

    property var sample  // the picked skin's item, to read what it declares
    property string fontFamily

    spacing: 6
    Repeater {
        model: MediaSkin.options.filter(o => options.sample && (o.unless
            ? options.sample[o.unless] !== true : options.sample[o.needs ?? o.key] !== undefined))
        delegate: PanelButton {
            required property var modelData
            readonly property var value: MediaSkin.option(MediaSkin.skin, modelData.key) ?? options.sample[modelData.key] ?? modelData.values[0]
            readonly property int step: Math.max(0, modelData.values.indexOf(value))
            label: modelData.label + ": " + modelData.names[step]
            fontFamily: options.fontFamily
            onClicked: MediaSkin.setOption(MediaSkin.skin, modelData.key,
                modelData.values[(step + 1) % modelData.values.length])
        }
    }
    // For every skin with a pulse of its own: with the bass, or its own.
    PanelButton {
        visible: options.sample?.audioLevel !== undefined
        label: "Beat: " + (MediaSkin.beat ? "On" : "Off")
        fontFamily: options.fontFamily
        onClicked: {
            MediaSkin.beat = !MediaSkin.beat;
            MediaSkin.save();
        }
    }
}
