// Memory in use, from /proc/meminfo. While hovered, the tooltip lists the ten
// apps using the most, each with everything it started: a process counts
// toward its ancestor that Hyprland or systemd launched (Zen's content
// processes toward zen-bin, a terminal's programs toward kitty).
import QtQuick
import Quickshell.Io
import qs.bar

Module {
    id: mod

    property string summary: "Memory"
    property string ranking: ""
    icon: "\u{EFC5}"
    tooltip: ranking ? summary + "<br>" + ranking : summary
    poll: ["grep", "-E", "^Mem(Total|Available):", "/proc/meminfo"]
    interval: settings.interval ?? 5
    onPolled: out => {
        const kb = out.trim().split("\n").map(l => Number(l.split(/\s+/)[1]));
        const used = (kb[0] - kb[1]) / 1048576;
        text = used.toFixed(1) + "GiB";
        summary = "<b>Memory " + used.toFixed(1) + " / " + (kb[0] / 1048576).toFixed(1) + " GiB</b>";
    }

    // Only while the tooltip can be seen.
    Timer {
        running: mod.hovered
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: ps.running = true
    }
    Process {
        id: ps
        command: ["ps", "-eo", "pid=,ppid=,rss=,comm="]
        stdout: StdioCollector { onStreamFinished: mod.ranking = mod.rank(text) }
    }

    readonly property var launchers: ["Hyprland", "systemd", "init"]
    readonly property var shells: ["sh", "bash", "zsh", "fish", "dash"]

    function pad(text, width) {
        return String(text) + "&nbsp;".repeat(Math.max(1, width - String(text).length));
    }
    function rank(text) {
        const procs = {};
        for (const line of text.trim().split("\n")) {
            const m = line.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
            if (m) procs[m[1]] = { ppid: m[2], rss: Number(m[3]), comm: m[4] };
        }
        // Climb to the process its launcher started; a shell in between
        // (Hyprland's exec) gives way to the program it ran.
        const app = pid => {
            let path = [pid];
            while (true) {
                const p = procs[path[path.length - 1]];
                const parent = p && procs[p.ppid];
                if (!parent || mod.launchers.includes(parent.comm) || p.ppid === "1") break;
                path.push(p.ppid);
            }
            let i = path.length - 1;
            while (i > 0 && mod.shells.includes(procs[path[i]].comm)) i--;
            return procs[path[i]].comm;
        };
        const totals = {};
        for (const pid in procs) {
            const name = app(pid);
            totals[name] = (totals[name] ?? 0) + procs[pid].rss;
        }
        return Object.entries(totals)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 10)
            .map(([name, kb]) => {
                const size = kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GiB" : Math.round(kb / 1024) + " MiB";
                return mod.pad(name.slice(0, 16), 18) + "&nbsp;".repeat(Math.max(0, 8 - size.length)) + size;
            })
            .join("<br>");
    }
}
