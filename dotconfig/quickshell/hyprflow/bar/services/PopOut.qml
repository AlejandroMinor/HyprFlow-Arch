// The full player popped out: NowSpinning on its own, like picture-in-
// picture, wearing the bar's look. Its config is written from MediaSkin
// (the skin, its options, the shadow, the tint) into a folder of its own,
// NOWSPINNING_CONFIG_DIR, so the standalone widget keeps its own; what
// NowSpinning saves there itself (where it sits, docking) is kept. Both
// ways while it runs: the cog's changes are written to it, and what is
// picked on its own settings card comes back to the cog.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string path: Paths.config + "quickshell/hyprflow/bar/nowspinning"
    readonly property string configDir: Paths.state + "nowspinning"
    property bool running: false

    // Asked every couple of seconds while someone shows the button.
    property int watchers: 0
    Timer {
        running: root.watchers > 0
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: check.running = true
    }
    // Also once at start: it may still be open from before a restart.
    Component.onCompleted: check.running = true
    Process {
        id: check
        command: ["qs", "list", "-p", root.path]
        stdout: StdioCollector {
            onStreamFinished: root.running = text.includes("Process ID")
        }
    }

    // NowSpinning has no plain cover: the closest is the cased CD.
    function config(saved) {
        const out = Object.assign({}, saved);
        const skin = MediaSkin.skin === "cover" ? "cd" : MediaSkin.skin;
        const options = MediaSkin.settings[skin] ?? {};
        out.skin = skin;
        for (const key in options) {
            if (key !== "tint")
                out[key] = options[key];
        }
        // NowSpinning tints from the cover or not at all: the LEDs count as tinted.
        out.tintFromArt = (options.tint ?? "leds") !== "off";
        out.lyrics = MediaSkin.lyricsPanel;
        out.lyricsLines = MediaSkin.lyricsLines === 1 ? 1 : 3;  // it has 1 or 3
        return out;
    }

    // Read before writing, to keep what NowSpinning saved there itself.
    FileView {
        id: file
        path: root.configDir + "/config.json"
        blockLoading: true
        printErrors: false
    }

    function saved() {
        try {
            file.reload();
            return JSON.parse(file.text());
        } catch (e) {
            return {};
        }
    }
    // The folder, the config, and (when `launch`) NowSpinning, in order.
    // Swapped in whole: a half-written file reads as its defaults (ring, medium).
    property real quietUntil: 0  // our own write, not to be read back
    function write(launch) {
        quietUntil = Date.now() + 1000;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/config.json.tmp" && mv -f "$1/config.json.tmp" "$1/config.json"'
                + (launch ? ' && NOWSPINNING_CONFIG_DIR="$1" exec qs -d -p "$3"' : ""),
            "sh", root.configDir, JSON.stringify(config(saved()), null, 4), root.path]);
    }

    // While it runs, the cog's changes reach it at once: it reloads its
    // config on save. Batched, so a burst of changes writes once.
    Timer {
        id: sync
        interval: 300
        onTriggered: if (root.running) root.write(false)
    }
    Connections {
        target: MediaSkin
        function onSkinChanged() { sync.restart(); }
        function onSettingsChanged() { sync.restart(); }
        function onLyricsPanelChanged() { sync.restart(); }
        function onLyricsLinesChanged() { sync.restart(); }
    }

    // Its settings card saved: bring what differs back to the cog.
    FileView {
        path: root.configDir + "/config.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.pull(text())
    }
    // NowSpinning's config is flat (one value per option, for every skin):
    // only the options the current skin declares are its own.
    FileView {
        id: skinFile
        blockLoading: true
        printErrors: false
    }
    function declares(skin, key) {
        const entry = MediaSkin.skins.find(s => s.name === skin);
        if (!entry || !entry.file)
            return false;
        skinFile.path = root.path + "/skins/" + entry.file;
        return new RegExp("property \\w+ " + key + "\\b").test(skinFile.text());
    }

    function pull(text) {
        if (!running || Date.now() < quietUntil)
            return;
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return;
        }
        let changed = false;
        if (d.skin && d.skin !== MediaSkin.skin && MediaSkin.skins.some(s => s.name === d.skin)
                && !(MediaSkin.skin === "cover" && d.skin === "cd")) {
            MediaSkin.skin = d.skin;
            changed = true;
        }
        const skin = MediaSkin.skin;
        const options = Object.assign({}, MediaSkin.settings[skin] ?? {});
        for (const o of MediaSkin.options) {
            if (o.needs || o.unless || d[o.key] === undefined || !o.values.includes(d[o.key]) || !declares(skin, o.key))
                continue;
            if ((options[o.key] ?? o.values[0]) !== d[o.key]) {
                options[o.key] = d[o.key];
                changed = true;
            }
        }
        if (typeof d.shadow === "boolean" && (options.shadow ?? true) !== d.shadow) {
            options.shadow = d.shadow;
            changed = true;
        }
        // Its Tint is on or off; on keeps the cog's LEDs or Album.
        if (typeof d.tintFromArt === "boolean") {
            const tint = options.tint ?? "leds";
            const next = !d.tintFromArt ? "off" : tint === "off" ? "leds" : tint;
            if (next !== tint) {
                options.tint = next;
                changed = true;
            }
        }
        if (changed) {
            const all = Object.assign({}, MediaSkin.settings);
            all[skin] = options;
            MediaSkin.settings = all;
        }
        if (typeof d.lyrics === "boolean" && d.lyrics !== MediaSkin.lyricsPanel) {
            MediaSkin.lyricsPanel = d.lyrics;
            changed = true;
        }
        // It has 1 or 3; 3 keeps the cog's 2 to 4.
        const lines = d.lyricsLines === 1 ? 1 : MediaSkin.lyricsLines === 1 ? 3 : MediaSkin.lyricsLines;
        if ((d.lyricsLines === 1 || d.lyricsLines === 3) && lines !== MediaSkin.lyricsLines) {
            MediaSkin.lyricsLines = lines;
            changed = true;
        }
        if (changed)
            MediaSkin.save();
    }

    function toggle() {
        if (running) {
            Quickshell.execDetached(["qs", "kill", "-p", root.path]);
            running = false;
            return;
        }
        write(true);
        running = true;
    }
}
