// The time (`format`, Qt's: "dd/MM HH:mm"); click opens the bar down into
// the calendar (CalendarPanel): the month and the events coming up.
import QtQuick
import Quickshell
import qs
import qs.bar
import qs.bar.panels

Module {
    id: mod

    SystemClock { id: clock; precision: SystemClock.Minutes }
    icon: "\u{F00ED}"
    text: Qt.formatDateTime(clock.date, settings.format ?? "dd/MM HH:mm")
    readonly property bool expanded: bar.expansion?.owner === mod
    tooltip: expanded ? "" : Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
    onClicked: bar.expand(mod, calendar, 0)  // the card's whole width

    Component {
        id: calendar
        CalendarPanel { now: clock.date; look: mod.look }
    }
}
