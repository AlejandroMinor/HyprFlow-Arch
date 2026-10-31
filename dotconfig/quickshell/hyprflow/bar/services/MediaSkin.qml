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

    // "cover" is ours; the rest are NowSpinning's skins/<File>.qml, in its
    // groups (the cog shows one group at a time).
    readonly property var groups: [
        { name: "physical", label: "Physical" },
        { name: "flat", label: "Flat" },
        { name: "cyber", label: "Cyber" },
        { name: "print", label: "Print" },
        { name: "anime", label: "Anime" }
    ]
    readonly property var skins: [
        { name: "cover", label: "Cover", file: "", group: "physical" },
        { name: "vinyl", label: "Vinyl", file: "VinylSkin.qml", group: "physical" },
        { name: "cd", label: "CD", file: "CdSkin.qml", group: "physical" },
        { name: "disc", label: "Disc", file: "DiscSkin.qml", group: "physical" },
        { name: "cassette", label: "Cassette", file: "CassetteSkin.qml", group: "physical" },
        { name: "minidisc", label: "MiniDisc", file: "MiniDiscSkin.qml", group: "physical" },
        { name: "walkman", label: "Walkman", file: "WalkmanSkin.qml", group: "physical" },
        { name: "single", label: "7\" single", file: "SingleSkin.qml", group: "physical" },
        { name: "crt", label: "CRT", file: "CrtSkin.qml", group: "flat" },
        { name: "ascii", label: "ASCII", file: "AsciiSkin.qml", group: "flat" },
        { name: "pixel", label: "Pixel", file: "PixelSkin.qml", group: "flat" },
        { name: "polaroid", label: "Polaroid", file: "PolaroidSkin.qml", group: "flat" },
        { name: "hologram", label: "Hologram", file: "HologramSkin.qml", group: "flat" },
        { name: "foil", label: "Foil", file: "FoilSkin.qml", group: "flat" },
        { name: "riso", label: "Riso", file: "RisoSkin.qml", group: "flat" },
        { name: "lcd", label: "LCD", file: "LcdSkin.qml", group: "flat" },
        { name: "stainedglass", label: "Stained glass", file: "StainedGlassSkin.qml", group: "flat" },
        { name: "blueprint", label: "Blueprint", file: "BlueprintSkin.qml", group: "flat" },
        { name: "hud", label: "HUD", file: "HudSkin.qml", group: "cyber" },
        { name: "shard", label: "Shard", file: "ShardSkin.qml", group: "cyber" },
        { name: "neon", label: "Neon", file: "NeonSkin.qml", group: "cyber" },
        { name: "neondisc", label: "Neon disc", file: "NeonDiscSkin.qml", group: "cyber" },
        { name: "matrix", label: "Matrix", file: "MatrixSkin.qml", group: "cyber" },
        { name: "terminal", label: "Terminal", file: "TerminalSkin.qml", group: "cyber" },
        { name: "datamosh", label: "Datamosh", file: "DatamoshSkin.qml", group: "cyber" },
        { name: "sleeve", label: "Sleeve", file: "SleeveSkin.qml", group: "print" },
        { name: "deco", label: "Deco", file: "DecoSkin.qml", group: "print" },
        { name: "gallery", label: "Gallery", file: "GallerySkin.qml", group: "print" },
        { name: "ticket", label: "Ticket", file: "TicketSkin.qml", group: "print" },
        { name: "magazine", label: "Magazine", file: "MagazineSkin.qml", group: "print" },
        { name: "stamp", label: "Stamp", file: "StampSkin.qml", group: "print" },
        { name: "poster", label: "Poster", file: "PosterSkin.qml", group: "print" },
        { name: "session", label: "Session", file: "SessionSkin.qml", group: "anime" },
        { name: "episode", label: "Episode", file: "EpisodeSkin.qml", group: "anime" },
        { name: "phantom", label: "Phantom", file: "PhantomSkin.qml", group: "anime" }
    ]
    function groupOf(name) {
        return skins.find(s => s.name === name)?.group ?? "physical";
    }

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
        { key: "sleeveColor", label: "Colour", values: ["art", "palette"], names: ["Cover", "Palette"] },
        { key: "foilStyle", label: "Foil", values: ["rainbow", "gold", "silver", "art"],
          names: ["Rainbow", "Gold", "Silver", "Accent"] },
        // The light most skins carry: drifting on its own, following the pointer.
        { key: "lightMotion", label: "Drift", values: [true, false], names: ["On", "Off"] },
        { key: "lightTilt", label: "Hover", values: [true, false], names: ["On", "Off"] },
        { key: "showStack", label: "Stack", values: [true, false], names: ["On", "Off"] },
        { key: "stackDepth", label: "Pile", values: [3, 1], names: ["3", "1"] },
        { key: "risoInks", label: "Inks", values: [3, 2], names: ["3", "2"] },
        { key: "lcdColor", label: "Colour", values: ["green", "gray", "amber"], names: ["Green", "Grey", "Amber"] },
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
    property int lyricsLines: 3       // how many the full player shows, 1..4
    property string pickerTab: "skin"  // the cog's open tab; not saved
    property string pickerGroup: groupOf(skin)  // the cog's skin group; not saved
    property string popOutScreen: ""  // the pop-out's monitor; "" lets Hyprland pick
    property bool beat: true  // skins with a pulse of their own pulse with the bass
    property var galleryOwner: null  // the Media module whose gallery is open

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
                                     lyricsPanel: root.lyricsPanel, lyricsBar: root.lyricsBar,
                                     lyricsLines: root.lyricsLines, beat: root.beat,
                                     popOutScreen: root.popOutScreen }, null, 2) + "\n");
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
                root.lyricsLines = Math.max(1, Math.min(4, data.lyricsLines ?? 3));
                root.beat = data.beat !== false;
                root.popOutScreen = data.popOutScreen ?? "";
            } catch (e) {
                root.skin = "cover";
            }
        }
        onLoadFailed: root.skin = "cover"
    }
}
