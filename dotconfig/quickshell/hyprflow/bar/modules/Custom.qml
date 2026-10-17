// Waybar's custom module, same keys:
//   exec       a command printing a line per update: Waybar's JSON
//              ({text, tooltip, alt, class}) or plain text
//   interval   seconds between runs; without it the command keeps running
//   format     "{}" is the text (default "{}"); without exec, a fixed label
//   tooltip    a fixed tooltip, when the JSON brings none
//   on-click, on-click-right, on-click-middle, on-scroll-up, on-scroll-down
//   icon       a glyph instead of the one the script puts first
//   ring       true: a ring filled to the JSON's "percentage" instead of the icon
//   font, font-size   for a glyph font (runcat)
//   classes    per class the script reports, its own format and dim, as
//              Waybar's #custom-x.class CSS: {"off": {"format": "…", "dim": true}}
// Pango's <span color=…> becomes Qt's <font color=…>.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.bar

Module {
    id: mod

    property string reported: ""  // the JSON's class
    readonly property var byClass: settings.classes?.[reported] ?? {}
    readonly property string format: byClass.format ?? settings.format ?? "{}"
    readonly property bool continuous: !!settings.exec && !settings.interval
    property string output: ""
    property real percentage: 0

    // A leading Nerd Font glyph ("󰚩 46%") is shown as the icon, so the gap
    // to the text is the module's, not a space's.
    readonly property string shown: format.replace("{}", output)
    readonly property var split: shown.match(/^([\uE000-\uF8FF]|[\uDB80-\uDBFF][\uDC00-\uDFFF])(?:\s+([\s\S]*))?$/)

    visible: !settings.exec || output !== ""
    icon: settings.font ? output : settings.icon ?? (split ? split[1] : "")
    iconFont: settings.font ?? look.font
    iconSize: settings["font-size"] ?? look.iconSize
    text: settings.font ? "" : split ? (split[2] ?? "") : shown
    tooltip: settings.tooltip ?? ""

    function pango(markup) {
        return markup
            .replace(/<span[^>]*color=(['"])(.*?)\1[^>]*>/g, "<font color='$2'>")
            .replace(/<span[^>]*>/g, "<font>")
            .replace(/<\/span>/g, "</font>");
    }

    function show(line) {
        let data;
        try { data = JSON.parse(line); } catch (e) { data = { text: line }; }
        if (typeof data !== "object" || data === null) data = { text: String(data) };
        output = pango(String(data.text ?? "").trim());
        if (data.tooltip) tooltip = pango(String(data.tooltip));
        if (data.percentage !== undefined) percentage = Number(data.percentage) || 0;
        reported = String(data.class ?? "");
        dim = byClass.dim ?? /idle|inactive|paused/.test(reported);
    }

    // Continuous: one long-running command, a line per update.
    LongProcess {
        id: stream
        running: mod.continuous
        argv: ["sh", "-c", mod.settings.exec ?? ""]
        stdout: SplitParser { onRead: line => mod.show(line) }
        onExited: restart.start()  // a script that died comes back
    }
    Timer { id: restart; interval: 5000; onTriggered: stream.running = true }

    // Interval: Module's polling, its last line shown.
    poll: settings.exec && settings.interval ? ["sh", "-c", settings.exec] : []
    interval: settings.interval ?? 5
    onPolled: out => { const lines = out.trim().split("\n"); show(lines[lines.length - 1]); }

    onClicked: { run(settings["on-click"]); if (settings.interval) refreshSoon.start(); }
    onRightClicked: run(settings["on-click-right"])
    onMiddleClicked: run(settings["on-click-middle"])
    onScrolled: steps => run(settings[steps > 0 ? "on-scroll-up" : "on-scroll-down"])
    Timer { id: refreshSoon; interval: 1500; onTriggered: mod.pollNow() }

    // The ring in place of the icon.
    RowLayout {
        visible: !!mod.settings.ring
        spacing: 6
        height: 30
        Ring {
            Layout.alignment: Qt.AlignVCenter
            size: mod.iconSize
            value: mod.percentage / 100
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: mod.text
            textFormat: Text.StyledText
            color: Qt.alpha(Colors.foreground, mod.dim ? mod.look.dim : 1)
            font { family: mod.look.font; pixelSize: mod.look.fontSize }
        }
    }
}
