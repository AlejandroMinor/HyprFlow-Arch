// Turns a module name from bar.json into the module: modules/<Type>.qml,
// where the type is the settings' "type" or else the name itself
// (clock → Clock.qml). Each module gets its bar and its settings.
import QtQuick
import QtQuick.Layouts
import qs
// The modules load by URL, so Quickshell never sees their imports: the
// folders they use are imported here, or qs.bar.panels is "not installed".
import qs.bar.panels
import qs.bar.widgets
import qs.bar.services

Loader {
    id: loader

    property string name
    property var bar

    readonly property var settings: bar.settings[name] ?? {}
    readonly property string type: settings.type ?? name

    // A module that hides itself takes no room. (Not the Loader's own
    // visible: the module's would follow it and never come back.)
    property bool animateWidth: true  // off when the parent animates it (a drawer)
    Layout.preferredWidth: item?.visible ? implicitWidth : 0
    Behavior on Layout.preferredWidth {
        enabled: loader.animateWidth
        Anim { duration: Motion.normal; curve: Motion.enter }
    }
    clip: true  // while it grows or shrinks

    Component.onCompleted: {
        if (!name) return;
        const file = type.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join("");
        setSource("modules/" + file + ".qml", { bar: bar, settings: settings, name: name });
    }
    // Saving bar.json reaches a module already loaded, not only new ones.
    onLoaded: {
        item.settings = Qt.binding(() => loader.settings);
        bar.loaded[name] = item;
    }
    onStatusChanged: if (status === Loader.Error) console.warn("bar: no module", type, "for", name)
}
