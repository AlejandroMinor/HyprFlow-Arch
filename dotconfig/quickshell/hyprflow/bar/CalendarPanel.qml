// The clock's panel: the month, today marked and a dot on each day with
// events; under it, only when there are any, the events coming up or a
// picked day's (scrolling past a few, so the card never grows too tall).
// The events are the monthly files lib/calendar-events.py keeps
// (~/.local/share/hyprflow/calendar/YYYY-MM.json, [{title, start, end,
// where}]), read here directly and redrawn when they change. An event stays
// in the list until its end: one in progress shows "now".
// "+" adds one on the picked day (today if none), the pencil on a row edits
// it in the same form, × deletes it (a second click confirms); both go through calendar-events.py, the same
// command that works over SSH. An event with a link (a call) opens it on a
// second click, the first asking "Join?".
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs

Item {
    id: panel

    property date now: new Date()  // the clock's, by the minute
    property var look
    readonly property string root: Quickshell.env("HOME") + "/.local/share/hyprflow/calendar/"
    readonly property string command: Quickshell.env("HOME") + "/.local/lib/hyprflow/calendar-events.py"

    property date shownMonth: new Date(now.getFullYear(), now.getMonth(), 1)
    property var picked: null  // a day clicked; null: what comes up
    function step(months) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + months, 1);
        picked = null;
    }

    // ---- Adding and deleting ----

    property bool adding: false
    property var editing: null  // the event the form edits; null: a new one
    onAddingChanged: if (!adding) editing = null
    property string error: ""
    // The day the form's event goes on.
    readonly property date addDay: editing ? at(editing.start) : (picked ?? now)
    function hours(text) { return text.slice(11, 16) === "00:00" ? "" : text.slice(11, 16); }
    // The form, empty for a new event or filled with the one to edit.
    function openForm(e) {
        editing = e ?? null;
        error = "";
        title.text = e?.title ?? "";
        from.text = e ? hours(e.start) : "";
        to.text = e ? hours(e.end) : "";
        where.text = e?.where ?? "";
        link.text = e?.link ?? "";
        adding = true;
        title.field.forceActiveFocus();
    }
    // A call's icon by its link's host; any other link, a camera.
    readonly property var callIcons: [
        ["teams.microsoft.com", "\u{F02BB}"], ["teams.live.com", "\u{F02BB}"],  // Teams
        ["meet.google.com", "\u{F02AD}"],                                       // Google
        ["discord.", "\u{F1FF}"], ["slack.com", "\u{F198}"], ["whatsapp.com", "\u{F05A3}"],
    ]  // Zoom has no glyph in the font: the camera
    function callIcon(link) {
        const host = (link.match(/^\w+:\/\/([^\/?#]+)/) ?? ["", ""])[1].toLowerCase();
        const known = callIcons.find(([part]) => host.includes(part));
        return known ? known[1] : "\u{F0567}";  // video
    }

    // The key calendar-events.py gives an event: md5 of "START TITLE".
    function key(e) { return Qt.md5(e.start + " " + e.title).slice(0, 6); }

    Process {
        id: edit
        stderr: StdioCollector { id: editErr }
        onExited: code => {
            panel.error = code === 0 ? "" : editErr.text.trim();
            if (code === 0) panel.adding = false;
        }
    }
    function save(title, from, to, where, link) {
        if (!title.trim()) { error = "A title"; return; }
        from = from.trim(); to = to.trim();
        const day = Qt.formatDate(addDay, "yyyy-MM-dd");
        // No start: all day.
        const start = from ? day + "T" + from : day;
        let argv;
        if (editing) {
            // The times only if changed: an event over several days keeps its end.
            argv = [command, "edit", key(editing), "--title", title.trim(),
                    "--where", where.trim(), "--link", link.trim()];
            if (from !== hours(editing.start)) argv.push("--start", start);
            if (to !== hours(editing.end) && from && to) argv.push("--end", day + "T" + to);
        } else {
            argv = [command, "add", title.trim(), start];
            if (from && to) argv.push(day + "T" + to);
            if (where.trim()) argv.push("--where", where.trim());
            if (link.trim()) argv.push("--link", link.trim());
        }
        edit.command = argv;
        edit.running = true;
    }
    function remove(e) {
        edit.command = [command, "remove", key(e)];
        edit.running = true;
    }

    implicitHeight: column.implicitHeight + 28

    // A text box like the rows: Tab to the next, Enter saves, Esc closes.
    component Field: Rectangle {
        id: box
        property string hint
        property alias text: input.text
        property alias field: input
        property Item next
        implicitHeight: 28
        radius: 8
        color: Qt.alpha(Colors.foreground, input.activeFocus ? 0.12 : 0.06)
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Colors.foreground
            selectionColor: Qt.alpha(Colors.foreground, 0.3)
            font { family: panel.look.font; pixelSize: 12 }
            KeyNavigation.tab: box.next?.field ?? null
            Keys.onReturnPressed: form.submit()
            Keys.onEnterPressed: form.submit()
            Keys.onEscapePressed: panel.adding = false
        }
        Text {
            visible: input.text === "" && !input.activeFocus
            anchors { fill: parent; leftMargin: 10 }
            verticalAlignment: Text.AlignVCenter
            text: box.hint
            color: Qt.alpha(Colors.foreground, 0.45)
            font { family: panel.look.font; pixelSize: 12 }
        }
    }

    // The form's buttons; the strong one filled, like today in the month.
    component FormButton: Rectangle {
        id: button
        property string label
        property bool strong: false
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 24
        implicitHeight: 28
        radius: 8
        color: strong ? Colors.foreground : Qt.alpha(Colors.foreground, buttonArea.containsMouse ? 0.12 : 0.06)
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.strong ? Colors.background : Colors.foreground
            font { family: panel.look.font; pixelSize: 12; bold: button.strong }
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.clicked()
        }
    }

    // ---- The events ----

    function monthKey(d) { return Qt.formatDate(d, "yyyy-MM"); }
    function at(text) { return new Date(text); }  // local ISO time
    function sameDay(a, b) { return a.toDateString() === b.toDateString(); }
    // An event on a day: it starts that day, or spans it.
    function onDay(e, day) {
        const start = at(e.start), end = at(e.end);
        const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const dayEnd = new Date(dayStart.getTime() + 86400000);
        return start < dayEnd && end > dayStart;
    }

    // A month's file; each one redraws when written.
    component MonthFile: FileView {
        property var events: []
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { events = JSON.parse(text()); } catch (e) { events = []; } }
        onLoadFailed: events = []
    }
    // Last, this and next month: where an event not over yet can be filed.
    MonthFile { id: before; path: panel.root + panel.monthKey(new Date(panel.now.getFullYear(), panel.now.getMonth() - 1, 1)) + ".json" }
    MonthFile { id: current; path: panel.root + panel.monthKey(panel.now) + ".json" }
    MonthFile { id: after; path: panel.root + panel.monthKey(new Date(panel.now.getFullYear(), panel.now.getMonth() + 1, 1)) + ".json" }
    // The month on screen, for its dots and its days (the history).
    MonthFile { id: browsed; path: panel.root + panel.monthKey(panel.shownMonth) + ".json" }

    readonly property var upcoming: before.events.concat(current.events, after.events)
        .filter(e => at(e.end) > now)
        .sort((a, b) => ((at(a.start) > now) - (at(b.start) > now)) || (at(a.start) - at(b.start)))
        .slice(0, 6)
    readonly property var listed: picked
        ? browsed.events.concat(before.events, current.events, after.events)
            .filter((e, i, all) => onDay(e, picked) && all.findIndex(o => o.start === e.start && o.title === e.title) === i)
            .sort((a, b) => at(a.start) - at(b.start))
        : upcoming

    function when(e) {
        const start = at(e.start), end = at(e.end);
        const allDay = Qt.formatTime(start, "HH:mm") === "00:00" && Qt.formatTime(end, "HH:mm") === "00:00";
        const hours = allDay ? "All day" : Qt.formatTime(start, "HH:mm") + "–" + Qt.formatTime(end, "HH:mm");
        if (picked || sameDay(start, now)) return hours;
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        return (sameDay(start, tomorrow) ? "Tomorrow" : Qt.formatDate(start, "ddd d MMM")) + " · " + hours;
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 14

        // ---- The month ----
        ColumnLayout {
            id: month
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: false
            Layout.preferredWidth: grid.implicitWidth
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "\u{F0141}"
                    color: Colors.foreground
                    font { family: panel.look.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: panel.step(-1) }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(panel.shownMonth, "MMMM yyyy")
                    color: Colors.foreground
                    font { family: panel.look.font; pixelSize: 13; weight: Font.DemiBold }
                }
                Text {
                    text: "\u{F0142}"
                    color: Colors.foreground
                    font { family: panel.look.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: panel.step(1) }
                }
            }

            WheelHandler { onWheel: e => panel.step(e.angleDelta.y > 0 ? -1 : 1) }

            GridLayout {
                id: grid
                columns: 7
                rowSpacing: 2
                columnSpacing: 2

                // Monday first.
                readonly property var days: {
                    const first = panel.shownMonth;
                    const lead = (first.getDay() + 6) % 7;
                    const cells = [];
                    for (let i = 0; i < 42; i++)
                        cells.push(new Date(first.getFullYear(), first.getMonth(), i - lead + 1));
                    return cells;
                }

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    delegate: Text {
                        required property string modelData
                        Layout.preferredWidth: 32
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Qt.alpha(Colors.foreground, 0.45)
                        font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold }
                    }
                }
                Repeater {
                    model: grid.days
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === panel.shownMonth.getMonth()
                        readonly property bool today: panel.sameDay(modelData, panel.now)
                        readonly property bool isPicked: panel.picked !== null && panel.sameDay(modelData, panel.picked)
                        readonly property bool busy: browsed.events.some(e => panel.onDay(e, modelData))
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 28
                        radius: 8
                        color: today ? Colors.foreground
                             : isPicked ? Qt.alpha(Colors.foreground, 0.18)
                             : dayHover.containsMouse ? Qt.alpha(Colors.foreground, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.today ? Colors.background
                                 : Qt.alpha(Colors.foreground, cell.inMonth ? 1 : 0.25)
                            font { family: panel.look.font; pixelSize: 12; bold: cell.today }
                        }
                        // A day with events.
                        Rectangle {
                            visible: cell.busy && cell.inMonth
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                            width: 4; height: 4; radius: 2
                            color: cell.today ? Colors.background : Colors.foreground
                        }
                        MouseArea {
                            id: dayHover
                            anchors.fill: parent
                            hoverEnabled: true
                            // A second click on the same day goes back to what comes up.
                            onClicked: panel.picked = cell.isPicked ? null : cell.modelData
                        }
                        // Each month fades in day by day.
                        opacity: 0
                        Component.onCompleted: appear.start()
                        NumberAnimation on opacity { id: appear; running: false; to: 1; duration: Motion.normal }
                    }
                }
            }
        }

        // ---- The events ----
        ColumnLayout {
            id: events
            visible: panel.picked !== null || panel.listed.length > 0 || panel.adding
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: panel.picked ? Qt.formatDate(panel.picked, "dddd d MMMM").toUpperCase() : "UPCOMING"
                    color: Qt.alpha(Colors.foreground, 0.45)
                    font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
                }
                Text {
                    text: panel.adding ? "\u{F0156}" : "\u{F0415}"  // close, plus
                    color: Qt.alpha(Colors.foreground, plus.containsMouse ? 1 : 0.6)
                    font { family: panel.look.font; pixelSize: 14 }
                    MouseArea {
                        id: plus
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: panel.adding ? panel.adding = false : panel.openForm(null)
                    }
                }
            }

            // ---- A new event ----
            ColumnLayout {
                id: form
                visible: panel.adding
                Layout.fillWidth: true
                spacing: 6

                function submit() { panel.save(title.text, from.text, to.text, where.text, link.text); }

                Text {
                    text: (panel.editing ? "Editing · " : "") + Qt.formatDate(panel.addDay, "dddd d MMMM")
                        + (from.text ? "" : " · all day")
                    color: Qt.alpha(Colors.foreground, 0.6)
                    font { family: panel.look.font; pixelSize: 11 }
                }
                Field { id: title; Layout.fillWidth: true; hint: "Title"; next: from }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Field { id: from; Layout.fillWidth: true; hint: "From 10:00"; next: to }
                    Field { id: to; Layout.fillWidth: true; hint: "To 11:00"; next: where }
                }
                Field { id: where; Layout.fillWidth: true; hint: "Where (optional)"; next: link }
                Field { id: link; Layout.fillWidth: true; hint: "Call link (optional)"; next: title }
                Text {
                    visible: panel.error !== ""
                    Layout.fillWidth: true
                    text: panel.error
                    wrapMode: Text.Wrap
                    color: "#f7768e"
                    font { family: panel.look.font; pixelSize: 11 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    FormButton { label: "Cancel"; onClicked: panel.adding = false }
                    FormButton { label: "Save"; strong: true; onClicked: form.submit() }
                }
            }

            Text {
                visible: panel.listed.length === 0 && !panel.adding
                Layout.topMargin: 4
                text: panel.picked ? "Nothing that day" : "Nothing coming up"
                color: Qt.alpha(Colors.foreground, 0.45)
                font { family: panel.look.font; pixelSize: 12 }
            }

            // At most about four rows tall; past that it scrolls.
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(list.implicitHeight, 236)
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 6
                    Repeater {
                        // The one being edited is in the form, not here.
                        model: panel.editing ? panel.listed.filter(e => panel.key(e) !== panel.key(panel.editing)) : panel.listed
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool live: panel.at(modelData.start) <= panel.now && panel.at(modelData.end) > panel.now
                            readonly property bool past: panel.at(modelData.end) <= panel.now
                            Layout.fillWidth: true
                            implicitHeight: lines.implicitHeight + 14
                            radius: 8
                            color: Qt.alpha(Colors.foreground, live ? 0.14 : 0.06)
                            // Deleting: × on hover, then a second click.
                            property bool armed: false
                            property bool joining: false
                            HoverHandler { id: rowHover; onHoveredChanged: if (!hovered) { row.armed = false; row.joining = false; } }
                            // A call: a click on the row asks, a second opens it
                            // (the pencil and × still work, on top).
                            readonly property string link: modelData.link ?? ""
                            MouseArea {
                                anchors.fill: parent
                                enabled: row.link !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (row.joining) Quickshell.execDetached(["xdg-open", row.link]);
                                    row.joining = !row.joining;
                                }
                            }

                            // A line down the left, as a timeline.
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 7 }
                                width: 3; radius: 1.5
                                color: Qt.alpha(Colors.foreground, row.live ? 1 : row.past ? 0.25 : 0.6)
                            }
                            ColumnLayout {
                                id: lines
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 10 }
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        visible: row.link !== ""
                                        text: panel.callIcon(row.link)
                                        color: Qt.alpha(Colors.foreground, row.past ? 0.5 : 1)
                                        font { family: panel.look.font; pixelSize: 13 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.title
                                        elide: Text.ElideRight
                                        color: Qt.alpha(Colors.foreground, row.past ? 0.5 : 1)
                                        font { family: panel.look.font; pixelSize: 12; bold: true }
                                    }
                                    // In progress.
                                    Rectangle {
                                        visible: row.live && !rowHover.hovered
                                        implicitWidth: nowText.implicitWidth + 12
                                        implicitHeight: 16
                                        radius: 8
                                        color: Colors.foreground
                                        Text {
                                            id: nowText
                                            anchors.centerIn: parent
                                            text: "now"
                                            color: Colors.background
                                            font { family: panel.look.font; pixelSize: 9; bold: true }
                                        }
                                    }
                                    Text {
                                        visible: row.joining
                                        text: "Join?"
                                        color: Colors.foreground
                                        font { family: panel.look.font; pixelSize: 11; bold: true }
                                    }
                                    Text {
                                        visible: rowHover.hovered && !row.armed && !row.joining
                                        text: "\u{F03EB}"  // pencil
                                        color: Qt.alpha(Colors.foreground, 0.6)
                                        font { family: panel.look.font; pixelSize: 14 }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: panel.openForm(row.modelData)
                                        }
                                    }
                                    Text {
                                        visible: rowHover.hovered && !row.joining
                                        text: row.armed ? "Delete?" : "\u{F0156}"
                                        color: row.armed ? "#f7768e" : Qt.alpha(Colors.foreground, 0.6)
                                        font { family: panel.look.font; pixelSize: row.armed ? 11 : 14; bold: row.armed }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: row.armed ? panel.remove(row.modelData) : row.armed = true
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.when(row.modelData) + (row.modelData.where ? "  ·  " + row.modelData.where : "")
                                    elide: Text.ElideRight
                                    color: Qt.alpha(Colors.foreground, 0.6)
                                    font { family: panel.look.font; pixelSize: 11 }
                                }
                            }

                            // One after the other.
                            opacity: 0
                            Component.onCompleted: show.start()
                            SequentialAnimation {
                                id: show
                                PauseAnimation { duration: row.index * 40 }
                                Anim { target: row; property: "opacity"; to: 1; duration: Motion.normal }
                            }
                        }
                    }
                }
            }
        }
    }
}
