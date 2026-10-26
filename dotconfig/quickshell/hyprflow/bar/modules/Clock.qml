// The time (`format`, Qt's: "dd/MM HH:mm"); click opens the bar down into
// the calendar (CalendarPanel): the month and the events coming up. A dot
// by the icon while today has events not over yet; it pulses while one runs
// or starts within fifteen minutes. The tooltip names the next one.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.bar
import qs.bar.panels
import qs.bar.services

Module {
    id: mod

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool expanded: bar.expansion?.owner === mod
    onClicked: bar.expand(mod, calendar, 0)  // the card's whole width

    // ---- Today's events ----

    readonly property date now: clock.date
    readonly property date tomorrow: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
    // Not over yet and starting today (or running since before).
    readonly property var today: CalendarEvents.upcoming.filter(e => CalendarEvents.at(e.start) < tomorrow)
    readonly property var next: today[0] ?? null
    readonly property bool soon: next !== null
        && CalendarEvents.at(next.start) - now <= 15 * 60 * 1000
    function hours(e) {
        return Qt.formatTime(CalendarEvents.at(e.start), "HH:mm") + "–" + Qt.formatTime(CalendarEvents.at(e.end), "HH:mm");
    }
    tooltip: expanded ? "" : Qt.formatDateTime(now, "dddd d MMMM yyyy")
        + (next ? "\nNext: " + next.title + " · " + hours(next) : "")

    Component {
        id: calendar
        CalendarPanel { now: clock.date; look: mod.look }
    }

    // Drawn here, not by Module's row: the dot sits on the icon.
    RowLayout {
        height: 30
        spacing: 6
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: icon.implicitWidth
            implicitHeight: icon.implicitHeight
            Text {
                id: icon
                text: "\u{F00ED}"
                color: mod.expanded ? BarTheme.accent : Colors.foreground
                font { family: mod.look.font; pixelSize: mod.iconSize }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
            // Something left today.
            Rectangle {
                id: dot
                visible: mod.today.length > 0
                x: icon.implicitWidth - 3; y: -1
                width: 6; height: 6; radius: 3
                color: BarTheme.accent
                SequentialAnimation on scale {
                    running: mod.soon
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.5; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) dot.scale = 1
                }
            }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clock.date, mod.settings.format ?? "dd/MM HH:mm")
            color: Colors.foreground
            font { family: mod.look.font; pixelSize: mod.look.fontSize }
        }
    }
}
