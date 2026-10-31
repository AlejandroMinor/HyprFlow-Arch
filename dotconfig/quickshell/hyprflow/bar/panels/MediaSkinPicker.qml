// The full player's cog, in tabs: Skin (a live preview of every skin with
// the track that is playing, then the picked one's options), Spectrum
// (cava's styles for the bar; CavaLevels.setStyle, the bar switches at
// once), Lyrics (in the bar, how many lines), Background (the blurred
// cover's opacity and blur) and Pop-out (its monitor and size). The panel grows to
// the open tab.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.bar.widgets
import qs.bar.services

ColumnLayout {
    id: picker

    property var panel             // MediaPanel: art, player, look
    readonly property var sample: sampleFace.item  // the picked skin's preview, to read its options
    signal back()

    spacing: 8

    readonly property var tabs: [["skin", "Skin"], ["spectrum", "Spectrum"], ["lyrics", "Lyrics"], ["background", "Background"], ["popout", "Pop-out"]]
    // Tab and Shift+Tab (Ctrl too, like a browser) go through the tabs,
    // wrapping around; the cog is opened with a click, so the keys are ours.
    function step(by) {
        const i = tabs.findIndex(t => t[0] === MediaSkin.pickerTab);
        MediaSkin.pickerTab = tabs[(i + by + tabs.length) % tabs.length][0];
    }
    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onTabPressed: step(1)
    Keys.onBacktabPressed: step(-1)

    component Divider: Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        implicitHeight: 1
        color: Colors.fg(0.08)
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
            color: Colors.fg(0.6)
            font { family: picker.panel.look.font; pixelSize: 10 }
        }
        BarSlider {
            id: slider
            Layout.preferredWidth: 200
            onMoved: v => parent.moved(v)
            onDraggingChanged: if (!dragging) MediaSkin.save()
        }
    }

    // A label and a row of choices, for the pop-out's tab.
    component ChoiceRow: RowLayout {
        property alias label: name.text
        default property alias choices: flow.data
        visible: MediaSkin.pickerTab === "popout"
        Layout.fillWidth: true
        spacing: 10
        Text {
            id: name
            Layout.preferredWidth: 50
            color: Colors.fg(0.6)
            font { family: picker.panel.look.font; pixelSize: 10 }
        }
        Flow {
            id: flow
            Layout.fillWidth: true
            spacing: 6
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: "\u{F004D}"
            color: Colors.fg(backArea.containsMouse ? 1 : 0.7)
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
        Item { Layout.fillWidth: true }

        // The tabs: one section at a time, the one picked underlined.
        Repeater {
            model: picker.tabs
            delegate: Item {
                id: tabItem
                required property var modelData
                readonly property bool current: MediaSkin.pickerTab === modelData[0]
                implicitWidth: tabText.implicitWidth + 12
                implicitHeight: 22
                Text {
                    id: tabText
                    anchors.centerIn: parent
                    text: tabItem.modelData[1]
                    color: Colors.fg(tabItem.current ? 1 : tabArea.containsMouse ? 0.8 : 0.5)
                    font { family: picker.panel.look.font; pixelSize: 11; bold: tabItem.current }
                }
                Rectangle {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    width: tabText.implicitWidth
                    height: 2
                    radius: 1
                    color: BarTheme.accent
                    opacity: tabItem.current ? 1 : 0
                    Behavior on opacity { Anim {} }
                }
                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: MediaSkin.pickerTab = tabItem.modelData[0]
                }
            }
        }
    }

    Divider {}

    // The skins in groups, one at a time, opening on the current skin's;
    // the button on the right opens all of them, bigger, in the gallery.
    Component.onCompleted: MediaSkin.pickerGroup = MediaSkin.groupOf(MediaSkin.skin)
    RowLayout {
        visible: MediaSkin.pickerTab === "skin"
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: MediaSkin.groups
            delegate: Item {
                id: groupItem
                required property var modelData
                readonly property bool current: MediaSkin.pickerGroup === modelData.name
                implicitWidth: groupText.implicitWidth + 12
                implicitHeight: 20
                Text {
                    id: groupText
                    anchors.centerIn: parent
                    text: groupItem.modelData.label
                    color: Colors.fg(groupItem.current ? 1 : groupArea.containsMouse ? 0.8 : 0.5)
                    font { family: picker.panel.look.font; pixelSize: 10; bold: groupItem.current }
                }
                Rectangle {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    width: groupText.implicitWidth
                    height: 2
                    radius: 1
                    color: BarTheme.accent
                    opacity: groupItem.current ? 1 : 0
                    Behavior on opacity { Anim {} }
                }
                MouseArea {
                    id: groupArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: picker.showGroup(groupItem.modelData.name)
                }
            }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "\u{F0293}"
            color: Colors.fg(galleryArea.containsMouse ? 1 : 0.6)
            font { family: picker.panel.look.font; pixelSize: 15 }
            MouseArea {
                id: galleryArea
                anchors { fill: parent; margins: -6 }
                hoverEnabled: true
                onClicked: MediaSkin.galleryOwner = picker.panel.media
            }
        }
    }

    // Six to a row, the width of the panel. As tall as the biggest group,
    // so switching groups doesn't resize the card; the new one fades and
    // slides in from its side.
    Item {
        visible: MediaSkin.pickerTab === "skin"
        Layout.fillWidth: true
        implicitHeight: 2 * 88 + 8  // Physical's two rows
        clip: true

        Grid {
            id: skinGrid
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: picker.slide
            columns: 6
            spacing: 8
            Repeater {
                model: MediaSkin.skins.filter(s => s.group === MediaSkin.pickerGroup)
                delegate: SkinTile {
                    required property var modelData
                    entry: modelData
                    media: picker.panel.media
                    faceSize: 60  // six skins fill the 448 px row
                }
            }
        }
    }
    property real slide: 0
    function showGroup(name) {
        if (name === MediaSkin.pickerGroup)
            return;
        const index = n => MediaSkin.groups.findIndex(g => g.name === n);
        slideIn.from = 24 * Math.sign(index(name) - index(MediaSkin.pickerGroup));
        MediaSkin.pickerGroup = name;
        groupIn.restart();
    }
    ParallelAnimation {
        id: groupIn
        Anim { id: slideIn; target: picker; property: "slide"; to: 0; duration: Motion.normal; curve: Motion.enter }
        Anim { target: skinGrid; property: "opacity"; from: 0; to: 1; duration: Motion.normal; curve: Motion.enter }
    }

    // The picked skin's preview, to read its options; kept even while
    // another group is showing.
    SkinFace {
        id: sampleFace
        visible: false
        skin: MediaSkin.skin
    }

    SkinOptions {
        visible: MediaSkin.pickerTab === "skin"
        Layout.fillWidth: true
        sample: picker.sample
        fontFamily: picker.panel.look.font
    }

    // Silent: a made-up spectrum, so the previews still move.
    property var demo: []
    property real phase: 0
    Timer {
        running: picker.visible && MediaSkin.pickerTab === "spectrum" && CavaLevels.silent
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
        visible: MediaSkin.pickerTab === "spectrum"
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
                color: current ? BarTheme.tint(0.2) : styleArea.containsMouse ? BarTheme.tint(0.12) : Colors.fg(0.06)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Spectrum {
                    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
                    style: styleTile.modelData
                    levels: CavaLevels.silent ? picker.demo : CavaLevels.levels
                }
                Text {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
                    text: picker.spectrumNames[styleTile.modelData] ?? styleTile.modelData
                    color: Colors.fg(styleTile.current ? 1 : 0.6)
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

    // The bar's media module showing the line being sung, and how many
    // lines the full player shows.
    Row {
        visible: MediaSkin.pickerTab === "lyrics"
        spacing: 6
        PanelButton {
            label: "In bar: " + (MediaSkin.lyricsBar ? "On" : "Off")
            fontFamily: picker.panel.look.font
            onClicked: {
                MediaSkin.lyricsBar = !MediaSkin.lyricsBar;
                MediaSkin.save();
            }
        }
        // How many lines the full player shows.
        PanelButton {
            label: "Lines: " + MediaSkin.lyricsLines
            fontFamily: picker.panel.look.font
            onClicked: {
                MediaSkin.lyricsLines = MediaSkin.lyricsLines % 4 + 1;
                MediaSkin.save();
            }
        }
    }


    // The blurred cover behind the player: how strong, how blurred.
    SliderRow {
        visible: MediaSkin.pickerTab === "background"
        label: "Opacity"
        value: MediaSkin.backdrop / MediaSkin.backdropMax
        onMoved: v => MediaSkin.backdrop = v * MediaSkin.backdropMax
    }
    SliderRow {
        visible: MediaSkin.pickerTab === "background"
        label: "Blur"
        value: MediaSkin.backdropBlur
        onMoved: v => MediaSkin.backdropBlur = v
    }

    // Which monitor the popped-out player sits on; Auto lets Hyprland pick.
    ChoiceRow {
        label: "Screen"
        Repeater {
            model: [""].concat(Quickshell.screens.map(s => s.name))
            delegate: PanelButton {
                required property string modelData
                label: modelData || "Auto"
                strong: MediaSkin.popOutScreen === modelData
                fontFamily: picker.panel.look.font
                onClicked: {
                    MediaSkin.popOutScreen = modelData;
                    MediaSkin.save();
                }
            }
        }
    }
    // How big it is, NowSpinning's own sizes; it follows at once if open.
    ChoiceRow {
        label: "Size"
        Repeater {
            model: MediaSkin.popOutSizes
            delegate: PanelButton {
                required property string modelData
                required property int index
                label: ["S", "M", "L", "XL"][index]
                strong: MediaSkin.popOutSize === modelData
                fontFamily: picker.panel.look.font
                onClicked: {
                    MediaSkin.popOutSize = modelData;
                    MediaSkin.save();
                }
            }
        }
    }
}
