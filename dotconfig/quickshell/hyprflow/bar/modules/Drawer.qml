// Waybar's drawer: the first module (or `icon`) stays; a click slides the
// rest out beside it, one after the other, and another click folds them.
//   modules   the names inside, the first one the handle unless `icon`
//   icon      a glyph for the handle instead
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar

Item {
    id: drawer

    property var bar
    property var settings: ({})
    property string name
    property bool open: false

    readonly property var names: settings.modules ?? []
    readonly property var inside: settings.icon ? names : names.slice(1)

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        // The handle: its own module, or the icon.
        Module {
            visible: !!drawer.settings.icon
            bar: drawer.bar
            icon: drawer.settings.icon ?? ""
            onClicked: drawer.open = !drawer.open
            iconRotation: drawer.open ? 180 : 0
        }
        ModuleLoader {
            id: handle
            visible: !drawer.settings.icon && drawer.names.length > 0
            name: drawer.settings.icon ? "" : drawer.names[0] ?? ""
            bar: drawer.bar
        }
        // A click on the handle does its own thing and also toggles.
        Connections {
            target: handle.item
            ignoreUnknownSignals: true
            function onClicked() { drawer.open = !drawer.open; }
        }

        // The rest. Opening, each grows from nothing in its place, one a beat
        // after the other, and its content fades in once there is room;
        // closing, the last folds first, quicker.
        Repeater {
            model: drawer.inside
            delegate: ModuleLoader {
                id: child
                required property string modelData
                required property int index
                name: modelData
                bar: drawer.bar
                animateWidth: false

                // Started by hand on each change: a Behavior would read the
                // delays from the state before it, and run them backwards.
                property real reveal: 0
                SequentialAnimation {
                    id: unfold
                    PauseAnimation { id: wait }
                    Anim { id: grow; target: child; property: "reveal" }
                }
                Connections {
                    target: drawer
                    function onOpenChanged() {
                        unfold.stop();
                        wait.duration = drawer.open ? child.index * 45
                                                    : (drawer.inside.length - 1 - child.index) * 30;
                        grow.to = drawer.open ? 1 : 0;
                        grow.duration = drawer.open ? Motion.normal : Motion.exit + 40;
                        grow.curve = drawer.open ? Motion.enter : Motion.leave;
                        unfold.start();
                    }
                }
                Layout.preferredWidth: item?.visible ? implicitWidth * reveal : 0
                visible: reveal > 0
                // The content comes in once most of its room is there.
                opacity: Math.max(0, (reveal - 0.55) / 0.45)
                scale: 0.85 + 0.15 * reveal
            }
        }
    }
}
