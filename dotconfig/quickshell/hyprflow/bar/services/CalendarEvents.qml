// The calendar's events (Repository): the monthly files
// lib/calendar-events.py keeps (Paths.calendar/YYYY-MM.json, a list of
// title, start, end, where, link), read directly, and every change written
// through that same command, the one that works over SSH.
// (No braces in the comment above: Quickshell's scan then misses the pragma.)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string command: Paths.lib + "calendar-events.py"

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date

    // Last, this and next month: where an event not over yet can be filed.
    MonthFile { id: before; month: new Date(root.now.getFullYear(), root.now.getMonth() - 1, 1) }
    MonthFile { id: current; month: root.now }
    MonthFile { id: after; month: new Date(root.now.getFullYear(), root.now.getMonth() + 1, 1) }
    readonly property var around: before.events.concat(current.events, after.events)

    function at(text) { return new Date(text); }  // local ISO time
    // An event stays until its end: the ones in progress first, then by start.
    readonly property var upcoming: around
        .filter(e => at(e.end) > now)
        .sort((a, b) => ((at(a.start) > now) - (at(b.start) > now)) || (at(a.start) - at(b.start)))
        .slice(0, 6)

    // The key calendar-events.py gives an event: md5 of "START TITLE".
    function key(e) { return Qt.md5(e.start + " " + e.title).slice(0, 6); }

    // ---- Changes ----

    property string error: ""
    signal written()  // a change went through
    Process {
        id: run
        stderr: StdioCollector { id: runErr }
        onExited: code => {
            root.error = code === 0 ? "" : runErr.text.trim();
            if (code === 0) root.written();
        }
    }
    function send(argv) {
        run.command = [command].concat(argv);
        run.running = true;
    }
    // FIELDS: {title, start, end?, where?, link?}.
    function add(fields) {
        const argv = ["add", fields.title, fields.start];
        if (fields.end) argv.push(fields.end);
        if (fields.where) argv.push("--where", fields.where);
        if (fields.link) argv.push("--link", fields.link);
        send(argv);
    }
    // CHANGES: only what changes, by name ({title, start, end, where, link}).
    function edit(e, changes) {
        const argv = ["edit", key(e)];
        for (const name in changes) argv.push("--" + name, changes[name]);
        send(argv);
    }
    function remove(e) { send(["remove", key(e)]); }
}
