// battery-hub: a custom module (the same exec and JSON as Waybar's) whose
// click opens the card into every device's battery (panels/BatteryPanel)
// instead of switching the bar's view; that moved to the middle click.
import QtQuick
import qs.bar.modules
import qs.bar.panels

Custom {
    id: mod

    readonly property bool expanded: bar.expansion?.owner === mod
    onClicked: bar.expand(mod, panel, 0, 0, 260)

    Component {
        id: panel
        BatteryPanel { devices: mod.latest.devices ?? []; look: mod.look }
    }
}
