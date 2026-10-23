// The full player's cog, in three sections: Skin (a live preview of every
// skin with the track that is playing, then the picked one's options),
// Spectrum (cava's styles for the bar; CavaLevels.setStyle, the bar
// switches at once) and Background (the blurred cover's opacity and blur).
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.widgets
import qs.bar.services

ColumnLayout {
    id: picker

    property var panel             // MediaPanel: art, player, look
    property var sample: null      // the picked skin's preview, to read its options
    signal back()

    spacing: 8

    // A section's title, like Super+K's headings.
    component Heading: Text {
        Layout.leftMargin: 2
        color: Qt.alpha(Colors.foreground, 0.45)
        font { family: picker.panel.look.font; pixelSize: 10; weight: Font.DemiBold }
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 1
        color: Qt.alpha(Colors.foreground, 0.08)
    }
    // A label and a slider; saved once the drag ends.
    component SliderRow: RowLayout {
        property alias label: name.text
        property alias value: slider.value
        signal moved(real value)
        Layout.alignment: Qt.AlignHCenter
        spacing: 10
        Text {
            id: name
            Layout.preferredWidth: 50
            color: Qt.alpha(Colors.foreground, 0.6)
            font { family: picker.panel.look.font; pixelSize: 10 }
        }
        BarSlider {
            id: slider
            Layout.preferredWidth: 200
            onMoved: v => parent.moved(v)
            onDraggingChanged: if (!dragging) MediaSkin.save()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "\u{F004D}"
            color: Qt.alpha(Colors.foreground, backArea.containsMouse ? 1 : 0.7)
            font { family: picker.panel.look.font; pixelSize: 16 }
            MouseArea {
                id: backArea
                anchors { fill: parent; margins: -6 }
                hoverEnabled: true
                onClicked: picker.back()
            }
        }
        Text {
            text: "Player style"
            color: Colors.foreground
            font { family: picker.panel.look.font; pixelSize: 12; bold: true }
        }
    }

    Heading { text: "Skin" }

    // Six to a row, the width of the panel.
    Grid {
        Layout.alignment: Qt.AlignHCenter
        columns: 6
        spacing: 8
        Repeater {
            model: MediaSkin.skins
            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property bool current: MediaSkin.skin === modelData.name
                // A skin missing from the submodule's checkout is left out.
                visible: modelData.file === "" || tileFace.drawn
                width: 68  // six skins fill the 448 px row
                height: 88
                radius: 10
                color: current ? BarTheme.tint(0.2) : tileArea.containsMouse ? BarTheme.tint(0.12) : Qt.alpha(Colors.foreground, 0.06)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                SkinFace {
                    id: tileFace
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
                    width: 60
                    height: 60
                    skin: tile.modelData.name
                    art: picker.panel.art
                    playing: picker.panel.player?.isPlaying ?? false
                    title: picker.panel.player?.trackTitle ?? ""
                    previousArt: picker.panel.media.previousArt
                    previousTitle: picker.panel.media.previousTitle
                    iconFont: picker.panel.look.font
                }
                Text {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                    text: tile.modelData.label
                    color: Qt.alpha(Colors.foreground, tile.current ? 1 : 0.6)
                    font { family: picker.panel.look.font; pixelSize: 10; bold: tile.current }
                }
                MouseArea {
                    id: tileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: MediaSkin.pick(tile.modelData.name)
                }
                Binding {
                    target: picker
                    property: "sample"
                    value: tileFace.item
                    when: tile.current
                }
            }
        }
    }

    // The picked skin's options, each a chip that steps through its values;
    // wrapped, since a row wider than the panel widens the whole column.
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: MediaSkin.options.filter(o => picker.sample && (o.unless
                ? picker.sample[o.unless] !== true : picker.sample[o.needs ?? o.key] !== undefined))
            delegate: PanelButton {
                required property var modelData
                readonly property var value: MediaSkin.option(MediaSkin.skin, modelData.key) ?? picker.sample[modelData.key] ?? modelData.values[0]
                readonly property int step: Math.max(0, modelData.values.indexOf(value))
                label: modelData.label + ": " + modelData.names[step]
                fontFamily: picker.panel.look.font
                onClicked: MediaSkin.setOption(MediaSkin.skin, modelData.key,
                    modelData.values[(step + 1) % modelData.values.length])
            }
        }
    }

    Divider {}
    Heading { text: "Spectrum" }

    // Silent: a made-up spectrum, so the previews still move.
    property var demo: []
    property real phase: 0
    Timer {
        running: picker.visible && CavaLevels.silent
        interval: 70
        repeat: true
        onTriggered: {
            picker.phase += 0.35;
            const levels = [];
            for (let i = 0; i < 10; i++)
                levels.push(Math.max(0, Math.min(1, 0.45 + 0.35 * Math.sin(picker.phase + i * 0.8) + 0.2 * Math.sin(picker.phase * 2.3 - i))));
            picker.demo = levels;
        }
    }

    readonly property var spectrumNames: ({
        bars: "Bars", equalizer: "Equalizer", peaks: "Peaks", leds: "LEDs",
        dots: "Dots", wave: "Wave", mirror: "Mirror"
    })

    // Narrower than the skins' tiles: all the styles fit on one row.
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 4
        Repeater {
            model: CavaLevels.styles
            delegate: Rectangle {
                id: styleTile
                required property string modelData
                readonly property bool current: CavaLevels.style === modelData
                width: 60
                height: 64
                radius: 10
                color: current ? BarTheme.tint(0.2) : styleArea.containsMouse ? BarTheme.tint(0.12) : Qt.alpha(Colors.foreground, 0.06)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Spectrum {
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
                    style: styleTile.modelData
                    levels: CavaLevels.silent ? picker.demo : CavaLevels.levels
                }
                Text {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                    text: picker.spectrumNames[styleTile.modelData] ?? styleTile.modelData
                    color: Qt.alpha(Colors.foreground, styleTile.current ? 1 : 0.6)
                    font { family: picker.panel.look.font; pixelSize: 10; bold: styleTile.current }
                }
                MouseArea {
                    id: styleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: CavaLevels.setStyle(styleTile.modelData)
                }
            }
        }
    }

    Divider {}
    Heading { text: "Background" }

    // The blurred cover behind the player: how strong, how blurred.
    SliderRow {
        label: "Opacity"
        value: MediaSkin.backdrop / MediaSkin.backdropMax
        onMoved: v => MediaSkin.backdrop = v * MediaSkin.backdropMax
    }
    SliderRow {
        label: "Blur"
        value: MediaSkin.backdropBlur
        onMoved: v => MediaSkin.backdropBlur = v
    }
}
