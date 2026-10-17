// CPU use, from /proc/stat every `interval` seconds (default 5); the tooltip
// has every core's, four to a row.
import QtQuick
import qs.bar

Module {
    id: mod

    property var last: []  // per line of /proc/stat: {idle, total}
    icon: "\u{F0EE0}"
    text: "–"
    tooltip: "CPU"
    poll: ["grep", "^cpu", "/proc/stat"]
    interval: settings.interval ?? 5

    // Fixed width columns: the tooltip's text collapses plain spaces.
    function pad(text, width) {
        return "&nbsp;".repeat(Math.max(0, width - String(text).length)) + text;
    }

    onPolled: out => {
        const now = out.trim().split("\n").map(line => {
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            return { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) };
        });
        const use = now.map((s, i) => {
            const before = last[i];
            if (!before) return null;
            return Math.round(100 * (1 - (s.idle - before.idle) / Math.max(1, s.total - before.total)));
        });
        last = now;
        if (use[0] === null) return;

        text = use[0] + "%";
        const cores = use.slice(1);
        const rows = [];
        for (let i = 0; i < cores.length; i += 4)
            rows.push(cores.slice(i, i + 4)
                .map((u, j) => pad(i + j, 2) + "&nbsp;" + pad(u + "%", 4))
                .join("&nbsp;&nbsp;&nbsp;"));
        tooltip = "<b>CPU " + use[0] + "%</b><br>" + rows.join("<br>");
    }
}
