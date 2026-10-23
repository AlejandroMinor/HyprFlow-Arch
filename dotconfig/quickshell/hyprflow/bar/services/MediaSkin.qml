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
        { name: "cassette", label: "Cassette", file: "CassetteSkin.qml" }
    ]

    // The options a skin can have; a skin shows the ones it declares.
    readonly property var options: [
        { key: "showArm", label: "Tonearm", values: [false, true], names: ["Off", "On"] },
        { key: "showDeck", label: "Turntable", values: [false, true], names: ["Off", "On"] },
        { key: "peekSide", label: "Disc side", values: ["right", "left", "top", "bottom"], names: ["Right", "Left", "Top", "Bottom"] },
        { key: "shellOpacity", label: "Shell", values: [1, 0.45], names: ["Solid", "Clear"] }
    ]

    property string skin: "cover"
    property var settings: ({})  // skin name → { option: value }

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
        file.setText(JSON.stringify({ skin: root.skin, settings: root.settings }, null, 2) + "\n");
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
            } catch (e) {
                root.skin = "cover";
            }
        }
        onLoadFailed: root.skin = "cover"
    }
}
