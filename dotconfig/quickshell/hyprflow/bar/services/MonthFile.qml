// One month of the calendar (Paths.calendar/YYYY-MM.json), redrawn when
// written. Its folder from Paths, not CalendarEvents: that one creates
// these, and asking it back while it builds left the path undefined.
import QtQuick
import Quickshell.Io

FileView {
    property date month
    property var events: []
    path: Paths.calendar + Qt.formatDate(month, "yyyy-MM") + ".json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { events = JSON.parse(text()); } catch (e) { events = []; } }
    onLoadFailed: events = []
}
