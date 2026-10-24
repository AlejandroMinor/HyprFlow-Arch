// The clock's panel: the month, today marked and a dot on each day with
// events; under it, only when there are any, the events coming up or a
// picked day's (scrolling past a few, so the card never grows too tall).
// The events come from CalendarEvents, redrawn when their files change. An
// event stays in the list until its end: one in progress shows "now".
// "+" adds one on the picked day (today if none), the pencil on a row edits
// it in the same form, × deletes it (a second click confirms). An event
// with a link (a call) opens it on a second click, the first asking "Join?".
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.bar.services
import qs.bar.widgets

Item {
    id: panel

    property date now: new Date()  // the clock's, by the minute
    property var look

    property date shownMonth: new Date(now.getFullYear(), now.getMonth(), 1)
    property var picked: null  // a day clicked; null: what comes up
    function step(months) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + months, 1);
        picked = null;
    }

    // ---- The form: adding and editing ----

    property bool adding: false
    property var editing: null  // the event the form edits; null: a new one
    onAddingChanged: if (!adding) editing = null
    // The day the form's event goes on.
    readonly property date addDay: editing ? at(editing.start) : (picked ?? now)
    function hours(text) { return text.slice(11, 16) === "00:00" ? "" : text.slice(11, 16); }
    // The form, empty for a new event or filled with the one to edit.
    function openForm(e) {
        editing = e ?? null;
        CalendarEvents.error = "";
        title.text = e?.title ?? "";
        from.text = e ? hours(e.start) : "";
        to.text = e ? hours(e.end) : "";
        where.text = e?.where ?? "";
        link.text = e?.link ?? "";
        adding = true;
        title.field.forceActiveFocus();
    }
    function save() {
        const name = title.text.trim(), start = from.text.trim(), end = to.text.trim();
        if (!name) { CalendarEvents.error = "A title"; return; }
        const day = Qt.formatDate(addDay, "yyyy-MM-dd");
        // No start: all day.
        const begins = start ? day + "T" + start : day;
        if (editing) {
            const changes = { title: name, where: where.text.trim(), link: link.text.trim() };
            // The times only if changed: an event over several days keeps its end.
            if (start !== hours(editing.start)) changes.start = begins;
            if (end !== hours(editing.end) && start && end) changes.end = day + "T" + end;
            CalendarEvents.edit(editing, changes);
        } else {
            CalendarEvents.add({ title: name, start: begins, end: start && end ? day + "T" + end : "",
                                 where: where.text.trim(), link: link.text.trim() });
        }
    }
    Connections {
        target: CalendarEvents
        function onWritten() { panel.adding = false; }
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

    implicitHeight: column.implicitHeight + 28

    // The form's text boxes: TextField with the panel's font, Enter saves.
    component Field: TextField {
        Layout.fillWidth: true
        fontFamily: panel.look.font
        onAccepted: panel.save()
        onCancelled: panel.adding = false
    }

    // ---- The events ----

    function at(text) { return new Date(text); }  // local ISO time
    function sameDay(a, b) { return a.toDateString() === b.toDateString(); }
    // An event on a day: it starts that day, or spans it.
    function onDay(e, day) {
        const start = at(e.start), end = at(e.end);
        const dayStart = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const dayEnd = new Date(dayStart.getTime() + 86400000);
        return start < dayEnd && end > dayStart;
    }

    // The month on screen, for its dots and its days (the history).
    MonthFile { id: browsed; month: panel.shownMonth }

    readonly property var listed: picked
        ? browsed.events.concat(CalendarEvents.around)
            .filter((e, i, all) => onDay(e, picked) && all.findIndex(o => o.start === e.start && o.title === e.title) === i)
            .sort((a, b) => at(a.start) - at(b.start))
        : CalendarEvents.upcoming

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
                        color: Colors.fg(0.45)
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
                        color: today ? BarTheme.accent
                             : isPicked ? BarTheme.tint(0.18)
                             : dayHover.containsMouse ? BarTheme.tint(0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.today ? Colors.background
                                 : Colors.fg(cell.inMonth ? 1 : 0.25)
                            font { family: panel.look.font; pixelSize: 12; bold: cell.today }
                        }
                        // A day with events.
                        Rectangle {
                            visible: cell.busy && cell.inMonth
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 }
                            width: 4; height: 4; radius: 2
                            color: cell.today ? Colors.background : BarTheme.accent
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
                    color: Colors.fg(0.45)
                    font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
                }
                Text {
                    text: panel.adding ? "\u{F0156}" : "\u{F0415}"  // close, plus
                    color: Colors.fg(plus.containsMouse ? 1 : 0.6)
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


                Text {
                    text: (panel.editing ? "Editing · " : "") + Qt.formatDate(panel.addDay, "dddd d MMMM")
                        + (from.text ? "" : " · all day")
                    color: Colors.fg(0.6)
                    font { family: panel.look.font; pixelSize: 11 }
                }
                Field { id: title; hint: "Title"; next: from }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Field { id: from; hint: "From 10:00"; next: to }
                    Field { id: to; hint: "To 11:00"; next: where }
                }
                Field { id: where; hint: "Where (optional)"; next: link }
                Field { id: link; hint: "Call link (optional)"; next: title }
                Text {
                    visible: CalendarEvents.error !== ""
                    Layout.fillWidth: true
                    text: CalendarEvents.error
                    wrapMode: Text.Wrap
                    color: "#f7768e"
                    font { family: panel.look.font; pixelSize: 11 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Item { Layout.fillWidth: true }
                    PanelButton { label: "Cancel"; fontFamily: panel.look.font; onClicked: panel.adding = false }
                    PanelButton { label: "Save"; strong: true; fontFamily: panel.look.font; onClicked: panel.save() }
                }
            }

            Text {
                visible: panel.listed.length === 0 && !panel.adding
                Layout.topMargin: 4
                text: panel.picked ? "Nothing that day" : "Nothing coming up"
                color: Colors.fg(0.45)
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
                        model: panel.editing ? panel.listed.filter(e => CalendarEvents.key(e) !== CalendarEvents.key(panel.editing)) : panel.listed
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool live: panel.at(modelData.start) <= panel.now && panel.at(modelData.end) > panel.now
                            readonly property bool past: panel.at(modelData.end) <= panel.now
                            Layout.fillWidth: true
                            implicitHeight: lines.implicitHeight + 14
                            radius: 8
                            color: Colors.fg(live ? 0.14 : 0.06)
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
                                color: row.live ? BarTheme.accent : Colors.fg(row.past ? 0.25 : 0.6)
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
                                        color: Colors.fg(row.past ? 0.5 : 1)
                                        font { family: panel.look.font; pixelSize: 13 }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.title
                                        elide: Text.ElideRight
                                        color: Colors.fg(row.past ? 0.5 : 1)
                                        font { family: panel.look.font; pixelSize: 12; bold: true }
                                    }
                                    // In progress.
                                    Rectangle {
                                        visible: row.live && !rowHover.hovered
                                        implicitWidth: nowText.implicitWidth + 12
                                        implicitHeight: 16
                                        radius: 8
                                        color: BarTheme.accent
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
                                        color: Colors.fg(0.6)
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
                                        color: row.armed ? "#f7768e" : Colors.fg(0.6)
                                        font { family: panel.look.font; pixelSize: row.armed ? 11 : 14; bold: row.armed }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: row.armed ? CalendarEvents.remove(row.modelData) : row.armed = true
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: panel.when(row.modelData) + (row.modelData.where ? "  ·  " + row.modelData.where : "")
                                    elide: Text.ElideRight
                                    color: Colors.fg(0.6)
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
