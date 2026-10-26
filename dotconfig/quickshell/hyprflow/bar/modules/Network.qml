// Download and upload speed over every interface but lo.
import QtQuick
import qs.bar

Module {
    property var last: null
    icon: "\u{F06F3}"
    poll: ["cat", "/proc/net/dev"]
    interval: settings.interval ?? 5

    function human(bytes) {
        const bits = bytes * 8;
        if (bits >= 1e6) return (bits / 1e6).toFixed(1) + "Mb";
        return Math.round(bits / 1e3) + "kb";
    }
    onPolled: out => {
        let rx = 0, tx = 0;
        for (const line of out.split("\n").slice(2)) {
            const [iface, rest] = line.split(":");
            if (!rest || iface.trim() === "lo") continue;
            const f = rest.trim().split(/\s+/).map(Number);
            rx += f[0]; tx += f[8];
        }
        const now = Date.now();
        if (last) {
            const s = (now - last.t) / 1000;
            text = human((rx - last.rx) / s) + " ↓ " + human((tx - last.tx) / s) + " ↑";
        }
        last = { rx, tx, t: now };
    }
}
