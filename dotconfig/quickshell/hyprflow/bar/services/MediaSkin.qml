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

    // "cover" and "pixel" are ours; the rest are NowSpinning's skins/<File>.qml.
    readonly property var skins: [
        { name: "cover", label: "Cover", file: "" },
        { name: "pixel", label: "Pixel", file: "" },
        { name: "vinyl", label: "Vinyl", file: "VinylSkin.qml" },
        { name: "cd", label: "CD", file: "CdSkin.qml" },
        { name: "disc", label: "Disc", file: "DiscSkin.qml" },
        { name: "cassette", label: "Cassette", file: "CassetteSkin.qml" }
    ]

    // The options a skin can have; a skin shows the ones it declares.
    readonly property var options: [
        { key: "showArm", label: "Tonearm", values: [false, true], names: ["Off", "On"] },
        { key: "showDeck", label: "Turntable", values: [false, true], names: ["Off", "On"] },
        { key: "peekSide", label: "Disc side", values: ["right", "left", "top", "bottom"], names: ["Right", "Left", "Top", "Bottom"] },
        { key: "pixels", label: "Pixels", values: [64, 32, 24, 16], names: ["64", "32", "24", "16"] },
        { key: "shellOpacity", label: "Shell", values: [1, 0.45], names: ["Solid", "Clear"] }
    ]

    property string skin: "cover"
    property var settings: ({})  // skin name → { option: value }
    // The blurred cover behind the full player, 0..backdropMax.
    readonly property real backdropMax: 0.8
    property real backdrop: 0.35
    property real backdropBlur: 1  // MultiEffect's blur, 0..1

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
        file.setText(JSON.stringify({ skin: root.skin, settings: root.settings, backdrop: root.backdrop, backdropBlur: root.backdropBlur }, null, 2) + "\n");
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
            } catch (e) {
                root.skin = "cover";
            }
        }
        onLoadFailed: root.skin = "cover"
    }
}
