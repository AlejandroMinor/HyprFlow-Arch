// The submap in use (Super+G, Super+R…): pops in while one is active.
import QtQuick
import Quickshell.Hyprland
import qs
import qs.bar

Module {
    id: mod

    property string submap: ""
    visible: submap !== "" || shrink.running
    icon: "\u{F0633}"
    iconColor: Colors.foreground
    text: submap

    scale: submap ? 1 : 0.6
    opacity: submap ? 1 : 0
    Behavior on scale { Anim { duration: Motion.normal; curve: Motion.enter } }
    Behavior on opacity { Anim { id: shrink; duration: Motion.fast } }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap")
                mod.submap = event.data;
        }
    }
}
