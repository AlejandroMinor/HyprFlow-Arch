// The keyboard layout in use; click switches to the next. `names` maps
// Hyprland's layout names to what is shown ("Spanish": "ES").
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar

Module {
    id: mod

    property string layout: ""
    icon: "\u{F030C}"
    text: settings.names?.[layout] ?? layout.slice(0, 2).toUpperCase()
    tooltip: layout
    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])

    // activelayout>>keyboard,Layout Name
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout")
                mod.layout = event.data.split(",").slice(1).join(",");
        }
    }
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    mod.layout = (keyboards.find(k => k.main) ?? keyboards[0]).active_keymap;
                } catch (e) {}
            }
        }
    }
}
