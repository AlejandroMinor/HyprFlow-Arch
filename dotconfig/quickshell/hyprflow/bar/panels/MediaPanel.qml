// The full player, opened under the media module (its click, or cava's): the
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
    readonly property string art: media.panelArt
    property bool picking: false   // the cog's skin picker instead of the player
    // The lyrics in place of the track, once there are synced ones.
    readonly property bool lyricsShown: MediaSkin.lyricsPanel && LyricsState.synced
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
            // Clear of the buttons in the top right corner (pop out, lyrics, cog).
            Layout.topMargin: 14
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
                        color: current ? BarTheme.tint(0.2) : chipHover.containsMouse ? BarTheme.tint(0.12) : Colors.fg(0.06)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.identity || "Player"
                            color: Colors.fg(chip.current ? 1 : 0.6)
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
                visible: !panel.lyricsShown
                text: panel.player?.trackTitle || "Nothing playing"
                elide: Text.ElideRight
                color: Colors.foreground
                font { family: panel.look.font; pixelSize: 15; bold: true }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== "" && !panel.lyricsShown
                text: panel.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: Colors.fg(0.75)
                font { family: panel.look.font; pixelSize: 12 }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== "" && !panel.lyricsShown
                text: panel.player?.trackAlbum ?? ""
                elide: Text.ElideRight
                color: Colors.fg(0.45)
                font { family: panel.look.font; pixelSize: 11 }
            }
            // Asked for lyrics, none to show (yet).
            Text {
                Layout.fillWidth: true
                visible: MediaSkin.lyricsPanel && !panel.lyricsShown
                text: LyricsState.status === "loading" ? "Looking for lyrics…" : "No synced lyrics"
                color: Colors.fg(0.45)
                font { family: panel.look.font; pixelSize: 10; italic: true }
            }

            // The lyrics: the line being sung, the ones around it faded; how
            // many, per the cog's Lines (1: just it, 2: and the next, 3: one
            // either side, 4: and one more after).
            Repeater {
                model: ({ 1: [0], 2: [0, 1], 3: [-1, 0, 1], 4: [-1, 0, 1, 2] })[MediaSkin.lyricsLines] ?? [-1, 0, 1]
                delegate: Text {
                    required property int modelData
                    Layout.fillWidth: true
                    visible: panel.lyricsShown
                    text: modelData === 0 ? (LyricsState.current || "\u266A") : LyricsState.line(modelData)
                    wrapMode: modelData === 0 ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: modelData === 0 ? 2 : 1
                    elide: Text.ElideRight
                    color: modelData === 0 ? Colors.foreground : Colors.fg(0.4)
                    font { family: panel.look.font; pixelSize: modelData === 0 ? 14 : 11; bold: modelData === 0 }
                }
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
                    color: Colors.fg(0.6)
                    font { family: panel.look.font; pixelSize: 10 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: panel.player?.length > 0 ? panel.clock(panel.player.length) : "live"
                    color: Colors.fg(0.6)
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
                        color: Colors.fg(control.on ? 1 : 0.7)
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

    // Pop out: NowSpinning on its own with the bar's look, like picture-in-
    // picture (PopOut); lit while it runs, and pressed again closes it.
    Text {
        anchors { top: parent.top; right: lyricsButton.left; topMargin: 14; rightMargin: 12 }
        visible: !panel.picking
        text: "\u{F0E57}"
        color: PopOut.running ? BarTheme.accent
            : Colors.fg(popArea.containsMouse ? 1 : 0.5)
        font { family: panel.look.font; pixelSize: 14 }
        Component.onCompleted: PopOut.watchers++
        Component.onDestruction: PopOut.watchers--
        MouseArea {
            id: popArea
            anchors { fill: parent; margins: -6 }
            hoverEnabled: true
            onClicked: {
                const opening = !PopOut.running;
                PopOut.toggle();
                if (opening)
                    panel.media.bar.collapse();
            }
        }
    }

    // Lyrics on or off, left of the cog.
    Text {
        id: lyricsButton
        anchors { top: parent.top; right: cog.left; topMargin: 14; rightMargin: 12 }
        visible: !panel.picking
        text: "\u{F1021}"
        color: MediaSkin.lyricsPanel ? BarTheme.accent
            : Colors.fg(lyricsArea.containsMouse ? 1 : 0.5)
        font { family: panel.look.font; pixelSize: 14 }
        MouseArea {
            id: lyricsArea
            anchors { fill: parent; margins: -6 }
            hoverEnabled: true
            onClicked: {
                MediaSkin.lyricsPanel = !MediaSkin.lyricsPanel;
                MediaSkin.save();
            }
        }
    }

    // The cog: pick how the cover and the bar's spectrum are drawn.
    Text {
        id: cog
        anchors { top: parent.top; right: parent.right; margins: 14 }
        visible: !panel.picking
        text: "\u{F0493}"
        color: Colors.fg(cogArea.containsMouse ? 1 : 0.5)
        font { family: panel.look.font; pixelSize: 14 }
        MouseArea {
            id: cogArea
            anchors { fill: parent; margins: -6 }
            hoverEnabled: true
            onClicked: panel.picking = true
        }
    }
}
