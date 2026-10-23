// The player in use: its cover spinning like a record while it plays, the
// track scrolling when it does not fit, and a thin line for how far along
// it is. Hovering brings out previous / next. Click plays or pauses; right
// click opens the bar downward into the full player (MediaPanel).
// A player counts when it reports a length, or plays something with a title:
// YouTube reports none on a live stream or while loading, and a chat app's
// notification sound (no title, no length) stays out, as in osd-watch.py.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.bar
import qs.bar.panels
import qs.bar.services

Module {
    id: mod

    // A real player: a track with a length, or one with a title that is
    // playing or can skip on (Spotify's DJ has no length); not a page's
    // stray voice note.
    readonly property var players: Mpris.players.values.filter(p =>
        (p.lengthSupported && p.length > 0) || (!!p.trackTitle && (p.isPlaying || p.canGoNext)))
    property var chosen: null  // picked in the full player
    readonly property var player: (players.includes(chosen) ? chosen : null)
        ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    // Browsers often send no cover: for YouTube, use the video thumbnail.
    readonly property string art: player?.trackArtUrl || youtubeThumb(player?.metadata?.["xesam:url"] ?? "")
    readonly property int maxText: settings["max-width"] ?? 220
    readonly property string track: [player?.trackArtist, player?.trackTitle].filter(s => s).join(" - ")
    // With "Lyrics in bar", the line being sung takes the track's place.
    readonly property bool singing: MediaSkin.lyricsBar && LyricsState.synced && LyricsState.current !== ""
    Component.onCompleted: LyricsState.player = Qt.binding(() => mod.player)
    // Singletons start when first used: PopOut must be up from the start
    // to keep a popped-out NowSpinning in step with the cog.
    readonly property bool poppedOut: PopOut.running

    // The last track's cover and title: the module outlives the panel, so a
    // skin made again on reopening (the Polaroid's stack) gets them here.
    property string previousArt: ""
    property string previousTitle: ""
    property string lastArt: ""
    property string lastTitle: ""
    onArtChanged: {
        if (lastArt && art && art !== lastArt) previousArt = lastArt;
        if (art) lastArt = art;
    }
    readonly property string trackTitle: player?.trackTitle ?? ""
    onTrackTitleChanged: {
        if (lastTitle && trackTitle && trackTitle !== lastTitle) previousTitle = lastTitle;
        if (trackTitle) lastTitle = trackTitle;
    }

    function youtubeThumb(url) {
        const m = url.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/)|youtu\.be\/)([\w-]{11})/);
        return m ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : "";
    }

    visible: player !== null
    readonly property bool expanded: bar.expansion?.owner === mod
    tooltip: player && !expanded ? (player.trackTitle + "\n" + (player.trackArtist ?? "") + "\n" + (player.identity ?? "")) : ""
    // A click opens the full player; a right click plays or pauses.
    onClicked: openPanel()
    onRightClicked: player?.togglePlaying()
    function openPanel() {
        if (player) bar.expand(mod, full, 480, 200);
    }
    Component { id: full; MediaPanel { media: mod } }
    onScrolled: steps => steps > 0 ? player?.previous() : player?.next()

    // Mpris only reports the position when asked.
    Timer {
        running: mod.playing
        interval: 1000
        repeat: true
        onTriggered: mod.player.positionChanged()
    }

    RowLayout {
        spacing: 8
        height: 30

        // The cover, round, turning while it plays.
        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 22
            implicitHeight: 22
            radius: 11
            color: Qt.alpha(Colors.foreground, 0.1)
            Image {
                anchors.fill: parent
                source: mod.art
                fillMode: Image.PreserveAspectCrop
                sourceSize { width: 64; height: 64 }
                asynchronous: true
                // Turn the image, not the clip: a 22 px clip turned is resampled
                // whole and looks jagged at in-between angles.
                mipmap: true
                RotationAnimation on rotation {
                    running: mod.playing
                    from: 0; to: 360
                    duration: 8000
                    loops: Animation.Infinite
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !mod.art
                text: "\u{F075A}"
                color: Colors.foreground
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            }
        }

        // Previous, only on hover.
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "\u{F04AE}"
            color: Colors.foreground
            font { family: mod.look.font; pixelSize: mod.iconSize }
            Layout.preferredWidth: mod.hovered ? implicitWidth : 0
            opacity: mod.hovered ? 1 : 0
            Behavior on Layout.preferredWidth { Anim {} }
            Behavior on opacity { Anim {} }
            MouseArea { anchors.fill: parent; onClicked: mod.player?.previous() }
        }

        // The track, scrolling when too long, over the progress line.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.min(title.implicitWidth, mod.maxText)
            implicitHeight: 30
            clip: true

            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                text: mod.singing ? LyricsState.current : mod.track
                // A lyric changes every few seconds, too fast to scroll:
                // cut with an ellipsis instead. Any new text starts at 0.
                width: mod.singing ? Math.min(implicitWidth, mod.maxText) : implicitWidth
                elide: mod.singing ? Text.ElideRight : Text.ElideNone
                onTextChanged: x = 0
                color: Qt.alpha(Colors.foreground, mod.playing ? 1 : 0.45)
                font { family: mod.look.font; pixelSize: mod.look.fontSize; bold: true }
                Behavior on color { ColorAnimation { duration: Motion.normal } }

                readonly property real overflow: implicitWidth - mod.maxText
                SequentialAnimation on x {
                    running: title.overflow > 0 && mod.playing && !mod.singing
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2500 }
                    NumberAnimation { to: -title.overflow; duration: Math.max(0, title.overflow * 30); easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 2000 }
                    NumberAnimation { to: 0; duration: Math.max(0, title.overflow * 30); easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) title.x = 0
                }
            }

            Rectangle {
                anchors { left: parent.left; bottom: parent.bottom; bottomMargin: 3 }
                height: 2
                radius: 1
                width: parent.width
                color: Qt.alpha(Colors.foreground, 0.12)
                Rectangle {
                    height: parent.height
                    radius: 1
                    color: Qt.alpha(Colors.foreground, 0.7)
                    width: mod.player && mod.player.length > 0
                        ? parent.width * Math.min(1, mod.player.position / mod.player.length) : 0
                    Behavior on width { Anim { duration: 1000; curve: [0, 0, 1, 1, 1, 1] } }
                }
            }
        }

        // Next, only on hover.
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "\u{F04AD}"
            color: Colors.foreground
            font { family: mod.look.font; pixelSize: mod.iconSize }
            Layout.preferredWidth: mod.hovered ? implicitWidth : 0
            opacity: mod.hovered ? 1 : 0
            Behavior on Layout.preferredWidth { Anim {} }
            Behavior on opacity { Anim {} }
            MouseArea { anchors.fill: parent; onClicked: mod.player?.next() }
        }
    }
}
