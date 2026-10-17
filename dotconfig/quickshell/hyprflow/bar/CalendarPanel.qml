// The clock's panel: the month, today marked and a dot on each day with
// events; under it, only when there are any, the events coming up or a
// picked day's (scrolling past a few, so the card never grows too tall).
// The events are the monthly files lib/calendar-events.py keeps
// (~/.local/share/hyprflow/calendar/YYYY-MM.json, [{title, start, end,
// where}]), read here directly and redrawn when they change. An event stays
// in the list until its end: one in progress shows "now".
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

    property date shownMonth: new Date(now.getFullYear(), now.getMonth(), 1)
    property var picked: null  // a day clicked; null: what comes up
    function step(months) {
        shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth() + months, 1);
        picked = null;
    }

    implicitHeight: column.implicitHeight + 28

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
            visible: panel.picked !== null || panel.listed.length > 0
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: panel.picked ? Qt.formatDate(panel.picked, "dddd d MMMM").toUpperCase() : "UPCOMING"
                color: Qt.alpha(Colors.foreground, 0.45)
                font { family: panel.look.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
            }

            Text {
                visible: panel.listed.length === 0
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
                        model: panel.listed
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
                                        Layout.fillWidth: true
                                        text: row.modelData.title
                                        elide: Text.ElideRight
                                        color: Qt.alpha(Colors.foreground, row.past ? 0.5 : 1)
                                        font { family: panel.look.font; pixelSize: 12; bold: true }
                                    }
                                    // In progress.
                                    Rectangle {
                                        visible: row.live
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
