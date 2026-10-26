// The panels' colours, shared by every panel. Fixed on purpose: they do not
// follow wallust. The tones are palettes.json; the one in use and its tweaks
// are state/appearance.json (lib/appearance.py writes it), and every panel
// follows at once. A tone "from": "wallust" takes its background and text
// from the wallust palette and its accent from the LED colour.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var tones: ({})
    property var saved: ({})  // state/appearance.json
    readonly property string tone: tones[saved.tone] ? saved.tone : (Object.keys(tones)[0] ?? "")
    readonly property var palette: resolved(tone)
    property var wallust: ({})  // background, foreground, colorN, led

    // A tone's colours, the wallust ones filled in.
    function resolved(name) {
        const t = tones[name];
        if (!t || t.from !== "wallust") return t ?? {};
        return Object.assign({}, t, {
            background: wallust.background ?? t.background,
            foreground: wallust.foreground ?? t.foreground,
            accent: wallust.led ?? wallust.color5 ?? t.accent,
        });
    }
    readonly property var tweaks: saved[tone] ?? {}

    function pair(p, fallback) { return p ? Qt.alpha(p[0], p[1]) : fallback; }

    readonly property color background: palette.background ?? "#000000"
    readonly property color foreground: tweaks.text ?? palette.foreground ?? "#FFFFFF"
    readonly property color accent:     palette.accent ?? "#3DFF3D"  // a switch that is on
    readonly property color selection:  pair(palette.selection, Qt.rgba(0, 0, 0, 0.55))  // the selected row
    readonly property color border:     pair(palette.border, Qt.rgba(1, 1, 1, 0.08))  // the card's rim
    readonly property real lift:        palette.lift ?? 0
    // The card's background opacity; the Appearance panel previews a drag in `preview`.
    property real preview: -1
    readonly property real card: preview >= 0 ? preview : (tweaks.card ?? palette.card ?? 0.38)
    readonly property real blur: tweaks.blur ?? palette.glass?.blur ?? 1.5
    readonly property bool glass: saved.glass ?? true  // hyprglass on the panels, every tone

    // The foreground at ALPHA. On a light tone grey on white fades much faster
    // than white on black, so secondary text (0.3 and up) is drawn stronger.
    function fg(alpha) {
        return Qt.alpha(foreground, alpha >= 0.3 ? Math.min(1, alpha + lift) : alpha);
    }

    readonly property string cache: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    property var wallustPalette: ({})
    property string led: ""
    onWallustPaletteChanged: wallust = Object.assign({}, wallustPalette, led ? { led: led } : {})
    onLedChanged: wallust = Object.assign({}, wallustPalette, led ? { led: led } : {})

    FileView {
        path: Quickshell.env("WALLUST_SH_PALETTE") || root.cache + "/wallust/colors/colors-rofi-sh.conf"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const found = {};
            const line = /^(\w+)='(#[0-9A-Fa-f]{6})'/gm;
            let m;
            while ((m = line.exec(text())) !== null) found[m[1]] = m[2];
            root.wallustPalette = found;
        }
    }
    FileView {
        path: root.cache + "/wallust/led-color"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const found = text().trim().match(/^[0-9A-Fa-f]{6}$/);
            root.led = found ? "#" + found[0] : "";
        }
    }
    FileView {
        path: Qt.resolvedUrl("palettes.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.tones = JSON.parse(text()); } catch (e) {}
        }
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
              + "/hyprflow/appearance.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.saved = JSON.parse(text()) ?? {}; } catch (e) { root.saved = {}; }
        }
        onLoadFailed: root.saved = {}
    }
}
