// Appearance's "Theme" tab: the wallust themes. The list comes from
// bin/theme-picker.sh --json (the wallpaper palette first, then the presets in
// ~/.config/wallust/themes/, by section, each with its colours and the one in
// use marked); picking one runs --set NAME and the panel stays open: only
// the mark moves, the rows stay as they are. Esc closes it (done()).
//
// The same script still runs as the fzf picker in a terminal or over SSH, and
// it is the fallback when Quickshell is not up.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root

    property string font
    readonly property string script: Quickshell.env("HOME") + "/.local/bin/theme-picker.sh"
    readonly property string palette: "\uee26"  // Nerd Font: a palette
    readonly property string check: "󰄬"
    readonly property int rowHeight: 46
    readonly property int maxRows: 7  // past this the list scrolls
    property var themes: []   // [{name, title, section, colors, current}]
    property string raw: ""   // the last --json, to skip an unchanged list
    property string applied: ""  // the one in use; a pick moves it without reloading the list
    property string query: ""  // typed in the search box: filters the list
    property int play: 0       // bumped on every show: the rows slide in again
    signal done()

    spacing: 6

    // Like rofi: every typed word somewhere in the title.
    readonly property var shown: root.themes.filter(t =>
        root.query.toLowerCase().split(" ").every(word => t.title.toLowerCase().includes(word)))

    function current() {
        const i = root.shown.findIndex(t => t.name === root.applied);
        return i < 0 ? 0 : i;
    }

    // The list kept from last time shows at once; it is read again behind
    // (a new theme file shows up on its own). The rows slide in only when
    // ANIMATE (the panel opening), not on a tab switch.
    function show(animate) {
        search.text = "";  // typing broke its binding to query
        root.query = "";
        list.running = true;
        if (animate) root.play = root.play + 1;
        search.forceActiveFocus();
    }

    Process {
        id: list
        command: [root.script, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root.raw) return;
                try {
                    root.themes = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.raw = text;
                root.applied = (root.themes.find(t => t.current) ?? {}).name ?? "";
                view.currentIndex = root.current();
            }
        }
    }

    Process { id: runner }

    function choose(theme) {
        root.applied = theme.name;
        runner.command = [root.script, "--set", String(theme.name)];
        runner.running = true;
    }

    function chooseCurrent() {
        const theme = root.shown[view.currentIndex];
        if (theme)
            root.choose(theme);
    }

    Text {
        Layout.alignment: Qt.AlignRight
        Layout.rightMargin: 10
        visible: root.themes.length > 1
        text: root.query !== ""
              ? root.shown.length + " shown"
              : (root.themes.length - 1) + " presets"
        color: Colors.fg(0.3)
        font { family: root.font; pixelSize: 11 }
    }

    // Typing filters; the arrows, Page Up/Down and Esc work from here too.
    TextInput {
        id: search
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.bottomMargin: 4
        onTextEdited: { root.query = text; view.currentIndex = 0; }
        color: Colors.foreground
        selectionColor: Qt.alpha(Colors.accent, 0.4)
        font { family: root.font; pixelSize: 13 }

        Text {
            visible: !search.text
            text: "Search themes"
            color: Colors.fg(0.45)
            font: search.font
        }

        Keys.onUpPressed: view.decrementCurrentIndex()
        Keys.onDownPressed: view.incrementCurrentIndex()
        Keys.onTabPressed: view.incrementCurrentIndex()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageDown)
                view.currentIndex = Math.min(view.currentIndex + root.maxRows, view.count - 1);
            else if (event.key === Qt.Key_PageUp)
                view.currentIndex = Math.max(view.currentIndex - root.maxRows, 0);
        }
        Keys.onReturnPressed: root.chooseCurrent()
        Keys.onEnterPressed: root.chooseCurrent()
        Keys.onEscapePressed: root.done()
    }

    ListView {
        id: view
        Layout.fillWidth: true
        implicitHeight: Math.min(contentHeight, root.maxRows * root.rowHeight)
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.shown
        keyNavigationWraps: true
        highlightMoveDuration: Motion.fast
        highlightResizeDuration: 0
        // Keep the picked row in sight while the list scrolls.
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        // The list comes already ordered by section: a heading before
        // each run, the same as Super+K's.
        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            width: view.width
            height: (section ? 26 : 0)
            Text {
                anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 4 }
                text: section
                color: Colors.fg(0.45)
                font { family: root.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.2 }
            }
        }

        highlight: Rectangle {
            radius: 10
            color: Colors.selection
        }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem
            width: ListView.view.width
            height: root.rowHeight

            // Rows drop in together, a step each; replay on every open.
            opacity: 0
            transform: Translate { id: slide; x: 14 }
            function enter() { entrance.restart(); }
            // Typing rebuilds a row while the panel is open: just show it.
            function appear() { slide.x = 0; row.opacity = 1; }
            Component.onCompleted: { if (root.query !== "") appear(); else enter(); }
            Connections {
                target: root
                function onPlayChanged() { row.enter(); }
            }
            SequentialAnimation {
                id: entrance
                PauseAnimation { duration: Math.min(row.index, 10) * 28 }
                ParallelAnimation {
                    NumberAnimation { target: row; property: "opacity"; to: 1
                                      duration: Motion.normal; easing.type: Easing.OutCubic }
                    NumberAnimation { target: slide; property: "x"; to: 0
                                      duration: Motion.normal; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: view.currentIndex = row.index
                onClicked: root.choose(row.modelData)
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12

                // The theme's own colours; the glyph when there are
                // none (the wallpaper while another theme is on).
                Item {
                    Layout.preferredWidth: 6 * 12 + 5 * 3
                    Layout.preferredHeight: 12

                    Row {
                        visible: row.modelData.colors.length > 0
                        spacing: 3
                        Repeater {
                            model: row.modelData.colors
                            Rectangle {
                                required property string modelData
                                width: 12
                                height: 12
                                radius: 3
                                color: modelData
                                // A black swatch on the black card needs an edge.
                                border { width: 1; color: Colors.fg(0.15) }
                            }
                        }
                    }
                    Text {
                        visible: row.modelData.colors.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.palette
                        color: row.current ? Colors.accent : Colors.fg(0.75)
                        font { family: root.font; pixelSize: 16 }
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                }
                Text {
                    text: row.modelData.title
                    color: Colors.foreground
                    font { family: root.font; pixelSize: 14 }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: (row.modelData.name === root.applied)
                    radius: height / 2
                    implicitWidth: stateText.implicitWidth + 16
                    implicitHeight: 22
                    color: Colors.accent
                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: root.check + "  current"
                        color: Colors.background
                        font { family: root.font; pixelSize: 11; weight: Font.DemiBold }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: root.query !== "" && root.shown.length === 0
        text: "No matches"
        color: Colors.fg(0.35)
        font { family: root.font; pixelSize: 12 }
        horizontalAlignment: Text.AlignHCenter
    }
}
