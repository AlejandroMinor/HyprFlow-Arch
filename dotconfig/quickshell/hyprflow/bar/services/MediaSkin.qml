// How the full player draws its cover: the plain cover, or one of the
// NowSpinning skins (the submodule, linked as bar/nowspinning). Picked
// with the cog in MediaPanel and kept in Paths.state/media-skin.json, with
// each skin's own options apart.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "cover" is ours; the rest are NowSpinning's skins/<File>.qml.
    readonly property var skins: [
        { name: "cover", label: "Cover", file: "" },
        { name: "vinyl", label: "Vinyl", file: "VinylSkin.qml" },
        { name: "cd", label: "CD", file: "CdSkin.qml" },
        { name: "disc", label: "Disc", file: "DiscSkin.qml" },
        { name: "cassette", label: "Cassette", file: "CassetteSkin.qml" },
        { name: "minidisc", label: "MiniDisc", file: "MiniDiscSkin.qml" },
        { name: "walkman", label: "Walkman", file: "WalkmanSkin.qml" },
        { name: "single", label: "7\" single", file: "SingleSkin.qml" },
        { name: "pixel", label: "Pixel", file: "PixelSkin.qml" },
        { name: "polaroid", label: "Polaroid", file: "PolaroidSkin.qml" },
        { name: "crt", label: "CRT", file: "CrtSkin.qml" },
        { name: "ascii", label: "ASCII", file: "AsciiSkin.qml" },
        { name: "hologram", label: "Hologram", file: "HologramSkin.qml" },
        { name: "foil", label: "Foil", file: "FoilSkin.qml" }
    ]

    // The options a skin can have; a skin shows the ones it declares (or,
    // with `needs`, the ones whose property it has: Tint sets `accent`;
    // with `unless`, the ones whose flag it lacks: Shadow, unless ownShadow).
    readonly property var options: [
        { key: "shadow", unless: "ownShadow", label: "Shadow", values: [true, false], names: ["On", "Off"] },
        { key: "tint", needs: "accent", label: "Tint", values: ["leds", "album", "off"], names: ["LEDs", "Album", "Off"] },
        { key: "showArm", label: "Tonearm", values: [false, true], names: ["Off", "On"] },
        { key: "showDeck", label: "Turntable", values: [false, true], names: ["Off", "On"] },
        { key: "peekSide", label: "Disc side", values: ["right", "left", "top", "bottom"], names: ["Right", "Left", "Top", "Bottom"] },
        { key: "pixels", label: "Pixels", values: [64, 32, 24, 16], names: ["64", "32", "24", "16"] },
        { key: "columns", label: "Columns", values: [32, 48, 64], names: ["32", "48", "64"] },
        { key: "colored", label: "Color", values: [true, false], names: ["On", "Off"] },
        { key: "effect", label: "Glitch", values: ["random", "slices", "roll", "static", "split", "channel"],
          names: ["Random", "Slices", "Roll", "Static", "Split", "Channel"] },
        { key: "showBezel", label: "Bezel", values: [true, false], names: ["On", "Off"] },
        { key: "holoColor", label: "Colour", values: ["cyan", "green", "pink", "amber", "art"],
          names: ["Cyan", "Green", "Pink", "Amber", "Accent"] },
        { key: "holoMotion", label: "Motion", values: [true, false], names: ["On", "Off"] },
        { key: "holoGlitch", label: "Glitch", values: [true, false], names: ["On", "Off"] },
        { key: "holoOpacity", label: "Alpha", values: [1, 0.75, 0.5], names: ["100%", "75%", "50%"] },
        { key: "holoBase", label: "Base", values: [true, false], names: ["On", "Off"] },
        { key: "foilStyle", label: "Foil", values: ["rainbow", "gold", "silver", "art"],
          names: ["Rainbow", "Gold", "Silver", "Accent"] },
        // The light most skins carry: drifting on its own, following the pointer.
        { key: "lightMotion", label: "Drift", values: [true, false], names: ["On", "Off"] },
        { key: "lightTilt", label: "Hover", values: [true, false], names: ["On", "Off"] },
        { key: "showStack", label: "Stack", values: [true, false], names: ["On", "Off"] },
        { key: "shellOpacity", label: "Shell", values: [1, 0.45], names: ["Solid", "Clear"] }
    ]

    property string skin: "cover"
    property var settings: ({})  // skin name → { option: value }
    // The blurred cover behind the full player, 0..backdropMax.
    readonly property real backdropMax: 0.8
    property real backdrop: 0.35
    property real backdropBlur: 1  // MultiEffect's blur, 0..1
    property bool lyricsPanel: false  // the full player shows lyrics instead of the track
    property bool lyricsBar: false    // the bar's module shows the current line

    function url(name) {
        const entry = skins.find(s => s.name === name);
        return entry && entry.file ? Qt.resolvedUrl("../nowspinning/skins/" + entry.file) : "";
    }
    function option(name, key) {
        return settings[name]?.[key];
    }

    function pick(name) {
        root.skin = name;
        save();
    }
    function setOption(name, key, value) {
        const next = Object.assign({}, settings);
        next[name] = Object.assign({}, next[name] ?? {}, { [key]: value });
        root.settings = next;
        save();
    }
    function save() {
        file.setText(JSON.stringify({ skin: root.skin, settings: root.settings, backdrop: root.backdrop, backdropBlur: root.backdropBlur,
                                     lyricsPanel: root.lyricsPanel, lyricsBar: root.lyricsBar }, null, 2) + "\n");
    }

    FileView {
        id: file
        path: Paths.state + "media-skin.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.skin = root.skins.some(s => s.name === data.skin) ? data.skin : "cover";
                root.settings = data.settings ?? {};
                root.backdrop = Math.max(0, Math.min(root.backdropMax, data.backdrop ?? 0.35));
                root.backdropBlur = Math.max(0, Math.min(1, data.backdropBlur ?? 1));
                root.lyricsPanel = data.lyricsPanel === true;
                root.lyricsBar = data.lyricsBar === true;
            } catch (e) {
                root.skin = "cover";
            }
        }
        onLoadFailed: root.skin = "cover"
    }
}
