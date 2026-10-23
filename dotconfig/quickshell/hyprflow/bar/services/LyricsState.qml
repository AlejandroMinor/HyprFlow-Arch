// Synced lyrics for the player the bar follows, for the media panel and,
// optionally, the bar's media module. The lookup is NowSpinning's own
// (Lyrics.qml: LRCLIB, cached per track), loaded by URL, so without the
// submodule there are simply no lyrics. One for every bar: one lookup.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property var player: null  // the MprisPlayer the media module follows
    readonly property bool wanted: player !== null && (MediaSkin.lyricsPanel || MediaSkin.lyricsBar)

    // "idle" | "loading" | "synced" | "none"; "none" without the submodule.
    readonly property string status: lyrics.item?.status ?? "none"
    readonly property bool synced: status === "synced"
    readonly property string previous: lyrics.item?.previous ?? ""
    readonly property string current: lyrics.item?.current ?? ""
    readonly property string next: lyrics.item?.next ?? ""

    // What Lyrics.qml reads, in the shape of NowSpinning's MprisSource.
    // MPRIS reports the position only when asked: asked every second, and
    // run on a local clock in between, or lines would switch up to a
    // second late.
    QtObject {
        id: source
        readonly property string title: root.player?.trackTitle ?? ""
        readonly property string artist: root.player?.trackArtist ?? ""
        readonly property string album: root.player?.trackAlbum ?? ""
        readonly property real duration: root.player && root.player.lengthSupported ? root.player.length : 0
        property real position: 0
    }
    Timer {
        running: root.wanted
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.player.positionChanged();
            source.position = root.player.position;
        }
    }
    Timer {
        property real last: 0
        running: root.wanted && (root.player?.isPlaying ?? false)
        interval: 100
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            source.position += (now - last) / 1000;
            last = now;
        }
    }

    Loader {
        id: lyrics
        source: Qt.resolvedUrl("../nowspinning/Lyrics.qml")
        onLoaded: {
            item.player = source;
            item.enabled = Qt.binding(() => root.wanted);
        }
    }
}
