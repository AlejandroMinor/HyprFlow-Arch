// The cover drawn by a NowSpinning skin, scaled to fit its box, or the
// plain cover for "cover" (and for a skin whose file is not there).
import QtQuick
import QtQuick.Effects
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
    readonly property var item: skinLoader.item
    property string title  // for skins that write it (Polaroid)
    property string previousArt    // the last track's, for the Polaroid's stack
    property string previousTitle

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
            sourceSize { width: 300; height: 300 }
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
    // A soft shadow under the skin, unless it casts its own (ownShadow).
    readonly property bool shadowOn: drawn && item.ownShadow !== true
        && (MediaSkin.option(skin, "shadow") ?? true)
    readonly property real pad: shadowOn ? Math.min(width, height) * 0.06 : 0  // room for its blur
    readonly property real fit: Math.min((width - 2 * pad) / shown.width, (height - 2 * pad) / shown.height)

    // Drawn once from the face's outline (the whole skin, for a solid one)
    // and blurred once, like NowSpinning's: spinning costs nothing.
    Item {
        id: shadow
        visible: face.shadowOn
        readonly property bool round: face.item ? face.item.faceIsCircle === true && face.item.solidBox !== true : false
        readonly property rect outline: !face.item ? Qt.rect(0, 0, 0, 0)
            // The CD's box has room for its disc pulled out: shade the case.
            : round || face.item.peekFraction !== undefined ? face.item.faceRect
            : Qt.rect(0, 0, face.item.implicitWidth, face.item.implicitHeight)
        x: skinLoader.x + outline.x * face.fit
        y: skinLoader.y + outline.y * face.fit + face.pad * 0.35
        width: outline.width * face.fit
        height: outline.height * face.fit
        opacity: 0.5
        Rectangle {
            anchors.fill: parent
            radius: shadow.round ? width / 2 : width * 0.05
            color: "black"
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 32
                autoPaddingEnabled: true
            }
        }
    }

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
            // Before the cover: setting it drops the Polaroid's photo, and
            // the stack under it starts from the last track's.
            if (item.previousArt !== undefined) {
                item.previousArt = Qt.binding(() => face.previousArt);
                item.previousTitle = Qt.binding(() => face.previousTitle);
            }
            item.artUrl = Qt.binding(() => face.art);
            item.playing = Qt.binding(() => face.playing);
            if (item.title !== undefined)
                item.title = Qt.binding(() => face.title);
            if (item.progress !== undefined)
                item.progress = Qt.binding(() => face.progress);
            if (item.accent !== undefined)
                item.accent = Qt.binding(() => face.accent);
            for (const option of MediaSkin.options) {
                if (option.needs || option.unless || item[option.key] === undefined)
                    continue;
                const fallback = item[option.key];
                item[option.key] = Qt.binding(() => MediaSkin.option(face.skin, option.key) ?? fallback);
            }
        }
    }

    // The skin's accent, per its Tint: the LEDs' colour, one picked out of
    // the cover (NowSpinning's ArtAccent, loaded by URL so a missing
    // submodule only loses this), or plain white.
    readonly property string tint: MediaSkin.option(skin, "tint") ?? "leds"
    readonly property color accent: tint === "album" ? (artAccent.item?.accent ?? "white")
        : tint === "off" ? "white" : BarTheme.accent
    Loader {
        id: artAccent
        active: face.tint === "album"
        source: Qt.resolvedUrl("../nowspinning/ArtAccent.qml")
        onLoaded: item.source = Qt.binding(() => face.art)
    }

    // A new track: the CD skin swaps discs.
    onArtChanged: if (item && item.trackChangeToken !== undefined) item.trackChangeToken += 1
}
