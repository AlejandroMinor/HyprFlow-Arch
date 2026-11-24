// The submap in use (Super+G, Super+R…): a pill in the theme's accent with
// its title and exit key while one is active.
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar
import qs.bar.services

Module {
    id: mod

    readonly property bool active: SubmapState.active
    // Kept while it shrinks away.
    property string label: ""
    property string exitKey: ""
    onActiveChanged: {
        if (!active) return;
        label = SubmapState.title.replace(/ mode$/i, "") || SubmapState.name;
        exitKey = SubmapState.exitKey.replace(/ \+ /g, "+");
    }

    readonly property color fill: BarTheme.accent
    // Dark text on a light accent, white on a dark one.
    readonly property color ink: fill.r * 0.299 + fill.g * 0.587 + fill.b * 0.114 > 0.5
                                 ? Colors.background : Colors.foreground

    visible: active || shrink.running
    hoverable: false
    scale: active ? 1 : 0.6
    opacity: active ? 1 : 0
    Behavior on scale { Anim { duration: Motion.normal; curve: Motion.enter } }
    Behavior on opacity { Anim { id: shrink; duration: Motion.fast } }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: row.implicitWidth + 20
        height: 26
        radius: mod.look.radius
        color: mod.fill
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: "\u{F0633}"
                color: mod.ink
                font { family: mod.iconFont; pixelSize: mod.iconSize }
            }
            Text {
                text: mod.label
                color: mod.ink
                font { family: mod.look.font; pixelSize: mod.look.fontSize; weight: Font.Bold }
            }
            Text {
                visible: mod.exitKey !== ""
                text: "· " + mod.exitKey
                color: Qt.alpha(mod.ink, 0.65)
                font { family: mod.look.font; pixelSize: 11 }
            }
        }
    }
}
