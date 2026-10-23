// The cover drawn by a NowSpinning skin, scaled to fit its box, or the
// plain cover for "cover" (and for a skin whose file is not there), or
// that cover pixelated for "pixel".
import QtQuick
import Quickshell.Widgets
import qs
import qs.bar.services
// Never used by name: it makes Quickshell scan the skins and the parts they
// import, which loading them by URL alone does not. Without the submodule
// the folder is missing, which is fine (the skins fail, the cover shows);
// an empty folder is not: Quickshell calls it "not installed" and the
// whole bar fails to load.
import "../nowspinning/skins" as NowSpinning

Item {
    id: face

    property string skin: "cover"
    property string art
    property bool playing: false
    property real progress: 0
    property string iconFont
    readonly property bool drawn: skinLoader.status === Loader.Ready  // a skin, not the cover
    readonly property bool pixel: skin === "pixel"
    // What the picker reads the skin's options from: the loaded skin, or
    // for "pixel" its one option and the default.
    readonly property var item: skinLoader.item ?? (pixel ? pixelDefaults : null)
    QtObject {
        id: pixelDefaults
        property int pixels: 32
    }
    readonly property int pixels: MediaSkin.option("pixel", "pixels") ?? pixelDefaults.pixels

    clip: true

    ClippingRectangle {
        anchors.centerIn: parent
        width: Math.min(face.width, face.height)
        height: width
        visible: !face.drawn
        radius: 10
        color: Qt.alpha(Colors.foreground, 0.08)
        Image {
            anchors.fill: parent
            source: face.art
            fillMode: Image.PreserveAspectCrop
            // Pixel: loaded tiny and scaled up without smoothing.
            sourceSize { width: face.pixel ? face.pixels : 300; height: face.pixel ? face.pixels : 300 }
            smooth: !face.pixel
            asynchronous: true
        }
        Text {
            anchors.centerIn: parent
            visible: !face.art
            text: "\u{F0387}"
            color: Qt.alpha(Colors.foreground, 0.5)
            font { family: face.iconFont; pixelSize: parent.width * 0.27 }
        }
    }

    // What the skin shows, in its own coordinates. The CD's box leaves room
    // for the disc pulled out (its flip, never done here): fit the case and
    // the bit that peeks out instead.
    readonly property rect shown: {
        if (!item)
            return Qt.rect(0, 0, 1, 1);
        if (item.peekFraction === undefined)
            return Qt.rect(0, 0, item.implicitWidth, item.implicitHeight);
        const f = item.faceRect, peek = item.discSize * item.peekFraction;
        switch (item.peekSide) {
        case "left": return Qt.rect(f.x - peek, f.y, f.width + peek, f.height);
        case "top": return Qt.rect(f.x, f.y - peek, f.width, f.height + peek);
        case "bottom": return Qt.rect(f.x, f.y, f.width, f.height + peek);
        default: return Qt.rect(f.x, f.y, f.width + peek, f.height);
        }
    }
    readonly property real fit: Math.min(width / shown.width, height / shown.height)

    // Drawn at NowSpinning's medium size, then scaled into the box.
    Loader {
        id: skinLoader
        source: MediaSkin.url(face.skin)
        transformOrigin: Item.TopLeft
        scale: face.fit
        // Shrunk through a mipmapped layer: scaled straight, the fine
        // grooves and the sheen came out jagged.
        layer.enabled: item !== null
        layer.mipmap: true
        layer.smooth: true
        x: face.width / 2 - (face.shown.x + face.shown.width / 2) * face.fit
        y: face.height / 2 - (face.shown.y + face.shown.height / 2) * face.fit
        onLoaded: {
            item.size = 170;
            // The CD case opens on its first track change, once its cover has
            // loaded: armed before the cover, or a cached one loads first and
            // the disc waits for NowSpinning's 6 s fallback.
            if (item.trackChangeToken !== undefined)
                item.trackChangeToken += 1;
            item.artUrl = Qt.binding(() => face.art);
            item.playing = Qt.binding(() => face.playing);
            if (item.progress !== undefined)
                item.progress = Qt.binding(() => face.progress);
            if (item.accent !== undefined)
                item.accent = Qt.binding(() => BarTheme.accent);
            for (const option of MediaSkin.options) {
                if (item[option.key] === undefined)
                    continue;
                const fallback = item[option.key];
                item[option.key] = Qt.binding(() => MediaSkin.option(face.skin, option.key) ?? fallback);
            }
        }
    }

    // A new track: the CD skin swaps discs.
    onArtChanged: if (item && item.trackChangeToken !== undefined) item.trackChangeToken += 1
}
