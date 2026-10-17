// The power menu: Waybar's power button. Lock and suspend run at once; log
// out, reboot and shut down ask for a second press on the same tile.
// qs -c hyprflow ipc call power toggle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    readonly property string lib: Quickshell.env("HOME") + "/.local/lib/hyprflow/"
    property bool open: false
    property int armed: -1  // the tile waiting for its second press
    readonly property int tileWidth: 104
    readonly property int gap: 8

    // Log out saves the session first, like Super+M; --yes: confirmed here.
    readonly property var actions: [
        { icon: "\u{F033E}", label: "Lock",      key: "l", confirm: false, argv: [root.bin + "hyprlock-flow.sh"] },
        { icon: "\u{F0343}", label: "Log out",   key: "e", confirm: true,  argv: [root.lib + "session-manager.py", "logout", "--yes"] },
        { icon: "\u{F0904}", label: "Suspend",   key: "u", confirm: false, argv: ["systemctl", "suspend"] },
        { icon: "\u{F0709}", label: "Reboot",    key: "r", confirm: true,  argv: ["systemctl", "reboot"] },
        { icon: "\u{F0425}", label: "Shut down", key: "s", confirm: true,  argv: ["systemctl", "poweroff"] }
    ]

    IpcHandler {
        target: "power"
        function toggle(): void {
            if (root.open) {
                root.open = false;
                return;
            }
            root.armed = -1;
            row.currentIndex = 0;
            root.open = true;
            row.forceActiveFocus();
        }
    }

    function press(index) {
        const action = root.actions[index];
        row.currentIndex = index;
        if (action.confirm && root.armed !== index) {
            root.armed = index;
            return;
        }
        root.open = false;
        Quickshell.execDetached(action.argv);
    }

    Overlay {
        name: "hyprflow-power"
        open: root.open
        cardWidth: row.width + 24
        cardHeight: row.height + 24
        onDismissed: root.open = false

        ListView {
            id: row
            x: 12
            y: 12
            width: root.actions.length * (root.tileWidth + root.gap) - root.gap
            height: 112
            orientation: ListView.Horizontal
            interactive: false
            spacing: root.gap
            model: root.actions
            keyNavigationWraps: true
            highlightMoveDuration: Motion.fast
            highlightResizeDuration: 0
            onCurrentIndexChanged: root.armed = -1  // moving away disarms

            highlight: Rectangle {
                radius: 10
                color: Colors.selection
            }

            Keys.onLeftPressed: decrementCurrentIndex()
            Keys.onRightPressed: incrementCurrentIndex()
            Keys.onTabPressed: incrementCurrentIndex()
            Keys.onReturnPressed: root.press(currentIndex)
            Keys.onEnterPressed: root.press(currentIndex)
            Keys.onEscapePressed: root.open = false
            Keys.onPressed: event => {
                const index = root.actions.findIndex(a => a.key === event.text.toLowerCase());
                if (index >= 0) {
                    root.press(index);
                    event.accepted = true;
                }
            }

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool current: ListView.isCurrentItem
                readonly property bool armed: root.armed === index
                width: root.tileWidth
                height: ListView.view.height

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: row.currentIndex = tile.index
                    onClicked: root.press(tile.index)
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.icon
                        color: Colors.foreground
                        font { family: root.font; pixelSize: 36 }
                        scale: tile.current ? 1.15 : 1
                        Behavior on scale { Anim {} }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.armed ? "Again" : tile.modelData.label
                        color: Colors.foreground
                        font { family: root.font; pixelSize: 13; weight: tile.armed ? Font.DemiBold : Font.Normal }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: tile.modelData.key.toUpperCase()
                        color: Qt.alpha(Colors.foreground, 0.45)
                        font { family: root.font; pixelSize: 10; weight: Font.DemiBold }
                    }
                }
            }
        }
    }
}
