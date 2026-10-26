// Where things live, in one place: the XDG folders (with their usual
// defaults) and HyprFlow's own under them.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    function xdg(variable, fallback) { return Quickshell.env(variable) || home + "/" + fallback; }

    readonly property string config: xdg("XDG_CONFIG_HOME", ".config") + "/"
    readonly property string cache: xdg("XDG_CACHE_HOME", ".cache") + "/"
    readonly property string state: xdg("XDG_STATE_HOME", ".local/state") + "/hyprflow/"
    readonly property string data: xdg("XDG_DATA_HOME", ".local/share") + "/hyprflow/"
    readonly property string lib: home + "/.local/lib/hyprflow/"  // what install.sh links
    readonly property string calendar: data + "calendar/"            // calendar-events.py's months
}
