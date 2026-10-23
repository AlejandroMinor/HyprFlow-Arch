// The full player popped out: NowSpinning on its own, like picture-in-
// picture, wearing the bar's look. Its config is written from MediaSkin
// (the skin, its options, the shadow, the tint) into a folder of its own,
// NOWSPINNING_CONFIG_DIR, so the standalone widget keeps its own; what
// NowSpinning saves there itself (where it sits, docking) is kept.
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
        return out;
    }

    // Read before writing, to keep what NowSpinning saved there itself.
    FileView {
        id: file
        path: root.configDir + "/config.json"
        blockLoading: true
        printErrors: false
    }

    function toggle() {
        if (running) {
            Quickshell.execDetached(["qs", "kill", "-p", root.path]);
            running = false;
            return;
        }
        let saved = {};
        try {
            file.reload();
            saved = JSON.parse(file.text());
        } catch (e) {}
        // In order, in one go: the folder, the config, then NowSpinning.
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/config.json" && NOWSPINNING_CONFIG_DIR="$1" exec qs -d -p "$3"',
            "sh", root.configDir, JSON.stringify(config(saved), null, 4), root.path]);
        running = true;
    }
}
