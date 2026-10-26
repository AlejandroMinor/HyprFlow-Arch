// Super+K's "Appearance", in two tabs: Panels (the tone, its transparency,
// blur and text colour: ToneSettings) and Theme (the wallust themes:
// ThemeList). Ctrl+Tab switches; a pick applies and the panel stays open. Opened through IPC on either tab:
// qs -c hyprflow ipc call appearance toggle
// qs -c hyprflow ipc call themepicker toggle   (bin/theme-picker.sh --toggle)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property var tabs: [["panels", "Panels"], ["theme", "Theme"]]
    property bool open: false
    property string tab: "panels"

    function toggle(which) {
        if (root.open && root.tab === which) {
            root.open = false;
            return;
        }
        const opening = !root.open;
        root.tab = which;
        root.open = true;
        root.focusTab(opening);
    }
    function focusTab(opening) {
        if (root.tab === "theme") themes.show(opening);
        else keys.forceActiveFocus();
    }

    IpcHandler {
        target: "appearance"
        function toggle(): void { root.toggle("panels"); }
    }
    IpcHandler {
        target: "themepicker"
        function toggle(): void { root.toggle("theme"); }
    }

    Overlay {
        id: overlay
        name: "hyprflow-appearance"
        open: root.open
        cardWidth: 420
        cardHeight: column.implicitHeight + 28
        onDismissed: root.open = false
        // The layer maps after open: take the keys once it is up.
        onVisibleChanged: if (visible && root.open) root.focusTab()

        Shortcut {
            sequence: "Ctrl+Tab"
            onActivated: {
                root.tab = root.tab === "panels" ? "theme" : "panels";
                root.focusTab();
            }
        }

        Item {
            id: keys
            Keys.onLeftPressed: tones.step(-1)
            Keys.onRightPressed: tones.step(1)
            Keys.onEscapePressed: root.open = false
        }

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 12

            // The tabs: the one shown underlined.
            RowLayout {
                Layout.leftMargin: 8
                spacing: 4
                Repeater {
                    model: root.tabs
                    delegate: Item {
                        id: tabItem
                        required property var modelData
                        readonly property bool current: root.tab === modelData[0]
                        implicitWidth: tabText.implicitWidth + 16
                        implicitHeight: 24
                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: tabItem.modelData[1]
                            color: Colors.fg(tabItem.current ? 1 : tabArea.containsMouse ? 0.8 : 0.45)
                            font { family: root.font; pixelSize: 13; bold: tabItem.current }
                        }
                        Rectangle {
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            width: tabText.implicitWidth
                            height: 2
                            radius: 1
                            color: Colors.accent
                            opacity: tabItem.current ? 1 : 0
                            Behavior on opacity { Anim {} }
                        }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.tab = tabItem.modelData[0];
                                root.focusTab();
                            }
                        }
                    }
                }
            }

            ToneSettings {
                id: tones
                visible: root.tab === "panels"
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                font: root.font
            }

            ThemeList {
                id: themes
                visible: root.tab === "theme"
                Layout.fillWidth: true
                font: root.font
                onDone: root.open = false
            }
        }
    }
}
