// The submap in use, for the HUD and the bar. toggle_submap (hyprland.lua)
// sends its name, title and exit key from SUBMAP_MODES; leaving it, any way,
// empties `name`.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string name: ""
    property string title: ""
    property string exitKey: ""
    readonly property bool active: name !== ""
    signal entered()

    IpcHandler {
        target: "submap"
        function enter(name: string, title: string, exitKey: string): void {
            root.title = title;
            root.exitKey = exitKey;
            root.name = name;
            root.entered();
        }
        // Right away, before a screenshot freezes the screen.
        function leave(): void {
            root.name = "";
        }
    }

    // Hyprland 0.56 sends no event when a Lua bind leaves the submap, so ask
    // while in one: "default" means back to the normal binds.
    Timer {
        interval: 250
        repeat: true
        running: root.active
        onTriggered: current.running = true
    }

    Process {
        id: current
        command: ["hyprctl", "submap"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== root.name)
                    root.name = "";
            }
        }
    }
}
