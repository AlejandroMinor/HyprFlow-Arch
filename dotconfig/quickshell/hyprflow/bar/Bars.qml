// Every bar: one per screen, of the type monitors.sh chose for it
// (~/.local/state/hyprflow/bars.json, {port: type}), laid out by bar.json.
// Off until enabled, while Waybar is still the bar; the flag file qs-bar
// says which one is (bar-restart.sh reads it too):
//   qs -c hyprflow ipc call bar enable | disable   switch to this bar or back
//   qs -c hyprflow ipc call bar toggle | hide | unhide   Super+B, game mode
// (not "show": `qs ipc call bar show` lists the functions instead)
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string state: Quickshell.env("HOME") + "/.local/state/hyprflow/"
    property bool enabled: false
    property bool shown: true  // toggle hides without closing (Super+B)
    property var config: ({})
    // Theme accents on or off (BarTheme): "colors" in bar.json, on unless false.
    Binding { target: BarTheme; property: "enabled"; value: root.config.colors !== false }
    property var types: ({})
    property var baseStyle: ({})
    property var chosenStyle: ({})
    // The chosen style over the base: one level deep, so a style can change
    // one value of "card" and keep the others.
    readonly property var style: {
        const out = Object.assign({}, baseStyle);
        for (const key in chosenStyle) {
            const a = baseStyle[key], b = chosenStyle[key];
            out[key] = (a && typeof a === "object" && b && typeof b === "object") ? Object.assign({}, a, b) : b;
        }
        return out;
    }

    // Waybar's config allows // comments, at a line's end too; JSON does not.
    // Drop them, but not inside a string ("https://…").
    function parse(text) {
        let out = "", quoted = false;
        for (let i = 0; i < text.length; i++) {
            const c = text[i];
            if (quoted) {
                out += c;
                if (c === "\\") out += text[++i];
                else if (c === '"') quoted = false;
            } else if (c === '"') {
                quoted = true;
                out += c;
            } else if (c === "/" && text[i + 1] === "/") {
                while (i + 1 < text.length && text[i + 1] !== "\n") i++;
            } else {
                out += c;
            }
        }
        return JSON.parse(out);
    }

    FileView {
        path: Qt.resolvedUrl("bar.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.config = root.parse(text()); }
            catch (e) { console.warn("bar.json:", e); }
        }
    }

    readonly property string styles: Qt.resolvedUrl("styles/").toString().replace("file://", "")
    FileView {
        path: root.styles + "clusters.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.baseStyle = root.parse(text()); } catch (e) { console.warn("styles/clusters.json:", e); }
        }
    }
    FileView {
        path: root.styles + (root.config.style ?? "clusters") + ".json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.chosenStyle = root.parse(text()); } catch (e) { console.warn("bar style:", e); }
        }
    }

    FileView {
        path: root.state + "bars.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.types = JSON.parse(text()); } catch (e) {}
        }
    }

    FileView {
        path: root.state + "qs-bar"
        printErrors: false
        onLoaded: root.enabled = true
    }

    // Started during game mode (qs restarted): stay hidden like Waybar.
    FileView {
        path: root.state + "game-mode"
        printErrors: false
        onLoaded: root.shown = false
    }

    IpcHandler {
        target: "bar"
        function enable(): void {
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && touch "$1/qs-bar" && killall waybar', "sh", root.state]);
            root.enabled = true;
            root.shown = true;
        }
        function disable(): void {
            Quickshell.execDetached(["sh", "-c", 'rm -f "$1/qs-bar" && "$2"', "sh", root.state,
                                     Quickshell.env("HOME") + "/.local/lib/hyprflow/bar-restart.sh"]);
            root.enabled = false;
        }
        function toggle(): void { if (root.enabled) root.shown = !root.shown; }
        function hide(): void { root.shown = false; }
        function unhide(): void { root.shown = true; }
    }

    Variants {
        // A screen monitors.sh has not listed yet gets the full bar.
        model: root.enabled && root.style.card
            ? Quickshell.screens.filter(s => (root.types[s.name] ?? "full") !== "none"
                                             && root.config.bars?.[root.types[s.name] ?? "full"])
            : []

        delegate: Component {
            Bar {
                required property var modelData
                screen: modelData
                layout: root.config.bars[root.types[modelData.name] ?? "full"]
                settings: root.config.modules ?? {}
                style: root.style
                shown: root.shown
            }
        }
    }
}
