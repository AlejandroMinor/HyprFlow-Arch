// The full player, opened under the media module (its right click): the
// cover (or a NowSpinning skin, picked with the cog) over a blurred copy of
// itself, the track, a seek bar with the times, and shuffle, previous,
// play/pause, next and repeat. With more than one player, chips to pick
// which one the bar follows.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.bar.widgets
import qs.bar.services

Item {
    id: panel

    property var media             // the Media module: player, players, look
    readonly property var player: media.player
    readonly property var look: media.look
    readonly property string art: media.art
    property bool picking: false   // the cog's skin picker instead of the player
    // How far the backdrop is past its default, 0..1: drives the scrim and
    // the text shadow, so the default look is unchanged.
    readonly property real strength: Math.max(0, (MediaSkin.backdrop - 0.35) / (MediaSkin.backdropMax - 0.35))
    // The card grows to fit the picker while it is open.
    implicitHeight: picking ? picker.implicitHeight + 32 : 200
    Behavior on implicitHeight { Anim {} }

    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // The cover, blurred and faint, behind everything (both set in the cog).
    ClippingRectangle {
        anchors { fill: parent; margins: 6 }
        radius: 10
        color: "transparent"
        Image {
            id: backdrop
            anchors.fill: parent
            source: panel.art
            fillMode: Image.PreserveAspectCrop
            sourceSize { width: 128; height: 128 }
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: backdrop
            blurEnabled: true
            blur: MediaSkin.backdropBlur
            blurMax: 48
            opacity: panel.art ? MediaSkin.backdrop : 0
            Behavior on opacity { Anim { duration: Motion.normal } }
        }
        // Darkens a strong backdrop so the text stays readable.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: panel.art ? panel.strength * 0.2 : 0
        }
    }

    RowLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 16
        visible: !panel.picking
        layer.enabled: panel.strength > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowBlur: 0.5
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
            shadowOpacity: 0.8 * panel.strength
        }

        // The cover, or the NowSpinning skin picked with the cog.
        SkinFace {
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            Layout.alignment: Qt.AlignVCenter
            skin: MediaSkin.skin
            art: panel.art
            playing: panel.player?.isPlaying ?? false
            title: panel.player?.trackTitle ?? ""
            previousArt: panel.media.previousArt
            previousTitle: panel.media.previousTitle
            progress: panel.player && panel.player.length > 0 ? panel.player.position / panel.player.length : 0
            iconFont: panel.look.font
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            // Which player, when there is a choice.
            Row {
                visible: panel.media.players.length > 1
                spacing: 6
                Repeater {
                    model: panel.media.players
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: modelData === panel.player
                        width: chipText.implicitWidth + 16
                        height: 20
                        radius: 10
                        color: current ? BarTheme.tint(0.2) : chipHover.containsMouse ? BarTheme.tint(0.12) : Qt.alpha(Colors.foreground, 0.06)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.identity || "Player"
                            color: Qt.alpha(Colors.foreground, chip.current ? 1 : 0.6)
                            font { family: panel.look.font; pixelSize: 10; bold: chip.current }
                        }
                        MouseArea {
                            id: chipHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: panel.media.chosen = chip.modelData
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: panel.player?.trackTitle || "Nothing playing"
                elide: Text.ElideRight
                color: Colors.foreground
                font { family: panel.look.font; pixelSize: 15; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: panel.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: Qt.alpha(Colors.foreground, 0.75)
                font { family: panel.look.font; pixelSize: 12 }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: panel.player?.trackAlbum ?? ""
                elide: Text.ElideRight
                color: Qt.alpha(Colors.foreground, 0.45)
                font { family: panel.look.font; pixelSize: 11 }
            }

            Item { Layout.fillHeight: true }

            // Where it is: drag to seek, when the player allows it.
            BarSlider {
                Layout.fillWidth: true
                enabled: panel.player?.canSeek ?? false
                value: panel.player && panel.player.length > 0 ? panel.player.position / panel.player.length : 0
                dim: panel.look.dim
                onMoved: v => { if (panel.player) panel.player.position = v * panel.player.length; }
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: panel.clock(panel.player?.position ?? 0)
                    color: Qt.alpha(Colors.foreground, 0.6)
                    font { family: panel.look.font; pixelSize: 10 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: panel.player?.length > 0 ? panel.clock(panel.player.length) : "live"
                    color: Qt.alpha(Colors.foreground, 0.6)
                    font { family: panel.look.font; pixelSize: 10 }
                }
            }

            // The controls; play/pause the big one in the middle.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                component Control: Item {
                    id: control
                    property string glyph
                    property bool on: false
                    property bool available: true
                    property int size: 16
                    signal pressed()
                    implicitWidth: size + 12
                    implicitHeight: size + 12
                    opacity: available ? 1 : 0.3
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: controlArea.containsMouse && control.available ? BarTheme.tint(0.12) : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: control.glyph
                        color: Qt.alpha(Colors.foreground, control.on ? 1 : 0.7)
                        font { family: panel.look.font; pixelSize: control.size }
                        scale: controlArea.pressed ? 0.85 : 1
                        Behavior on scale { Anim { duration: Motion.fast } }
                    }
                    MouseArea {
                        id: controlArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (control.available) control.pressed()
                    }
                }

                Control {
                    glyph: panel.player?.shuffle ? "\u{F049F}" : "\u{F049E}"
                    on: panel.player?.shuffle ?? false
                    available: panel.player?.shuffleSupported ?? false
                    onPressed: panel.player.shuffle = !panel.player.shuffle
                }
                Control {
                    glyph: "\u{F04AE}"
                    available: panel.player?.canGoPrevious ?? false
                    onPressed: panel.player.previous()
                }
                // Play / pause, on a filled circle.
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 20
                    color: BarTheme.accent
                    scale: playArea.pressed ? 0.9 : playArea.containsMouse ? 1.06 : 1
                    Behavior on scale { Anim { duration: Motion.fast } }
                    Text {
                        anchors.centerIn: parent
                        text: panel.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                        color: Colors.background
                        font { family: panel.look.font; pixelSize: 20 }
                    }
                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: panel.player?.togglePlaying()
                    }
                }
                Control {
                    glyph: "\u{F04AD}"
                    available: panel.player?.canGoNext ?? false
                    onPressed: panel.player.next()
                }
                Control {
                    readonly property int loop: panel.player?.loopState ?? MprisLoopState.None
                    glyph: loop === MprisLoopState.Track ? "\u{F0458}" : loop === MprisLoopState.Playlist ? "\u{F0456}" : "\u{F0457}"
                    on: loop !== MprisLoopState.None
                    available: panel.player?.loopSupported ?? false
                    // None → Playlist → Track → None
                    onPressed: panel.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                        : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }
        }
    }

    MediaSkinPicker {
        id: picker
        anchors { fill: parent; margins: 16 }
        visible: panel.picking
        panel: panel
        onBack: panel.picking = false
    }

    // The cog: pick how the cover and the bar's spectrum are drawn.
    Text {
        anchors { top: parent.top; right: parent.right; margins: 14 }
        visible: !panel.picking
        text: "\u{F0493}"
        color: Qt.alpha(Colors.foreground, cogArea.containsMouse ? 1 : 0.5)
        font { family: panel.look.font; pixelSize: 14 }
        MouseArea {
            id: cogArea
            anchors { fill: parent; margins: -6 }
            hoverEnabled: true
            onClicked: panel.picking = true
        }
    }
}
