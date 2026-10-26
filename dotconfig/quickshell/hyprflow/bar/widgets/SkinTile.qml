// One skin to pick, live with the track that is playing: in the cog and in
// the gallery. A skin missing from the submodule's checkout is left out.
import QtQuick
import qs
import qs.bar.services

Rectangle {
    id: tile

    required property var entry   // a MediaSkin.skins row
    property var media            // the Media module: player, art, look
    property int faceSize: 60
    readonly property bool current: MediaSkin.skin === entry.name
    readonly property var skinItem: tileFace.item

    visible: entry.file === "" || tileFace.drawn
    width: faceSize + 8
    height: faceSize + 28
    radius: 10
    color: current ? BarTheme.tint(0.2) : tileArea.containsMouse ? BarTheme.tint(0.12) : Colors.fg(0.06)
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    SkinFace {
        id: tileFace
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 6 }
        width: tile.faceSize
        height: tile.faceSize
        skin: tile.entry.name
        art: tile.media?.art ?? ""
        playing: tile.media?.player?.isPlaying ?? false
        title: tile.media?.player?.trackTitle ?? ""
        artist: tile.media?.player?.trackArtist ?? ""
        duration: tile.media?.player?.length ?? 0
        previousArt: tile.media?.previousArt ?? ""
        previousTitle: tile.media?.previousTitle ?? ""
        iconFont: tile.media?.look.font ?? ""
    }
    Text {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 6 }
        text: tile.entry.label
        color: Colors.fg(tile.current ? 1 : 0.6)
        font { family: tile.media?.look.font ?? ""; pixelSize: 10; bold: tile.current }
    }
    MouseArea {
        id: tileArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: MediaSkin.pick(tile.entry.name)
    }
}
