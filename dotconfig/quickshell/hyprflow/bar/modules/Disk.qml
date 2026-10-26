// Used space on `path` (default /); the tooltip lists every disk mounted,
// with how full it is.
import QtQuick
import qs.bar

Module {
    id: mod

    readonly property string path: settings.path ?? "/"
    icon: "\u{F02CA}"
    poll: ["df", "-h", "-l", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "squashfs",
           "-x", "overlay", "--output=target,used,size,pcent"]
    interval: settings.interval ?? 60

    function pad(text, width, left) {
        const gap = "&nbsp;".repeat(Math.max(1, width - String(text).length));
        return left ? gap + text : text + gap;
    }
    onPolled: out => {
        const rows = out.trim().split("\n").slice(1).map(l => l.trim().split(/\s+/));
        const main = rows.find(r => r[0] === mod.path);
        if (main) text = main[1];
        tooltip = "<b>Disks</b><br>" + rows.map(([target, used, size, pcent]) => {
            const name = target === "/" ? "/" : target.split("/").pop();
            return mod.pad(name, 12) + mod.pad(used, 6, true) + " / " + mod.pad(size, 5, true) + mod.pad(pcent, 5, true);
        }).join("<br>");
    }
}
