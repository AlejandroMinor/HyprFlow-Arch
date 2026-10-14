// A card-sized layer on the focused monitor. Every panel is one of these: it
// brings the content, this brings the window, the fold open and closed and,
// when interactive, the keyboard and closing on a click elsewhere
// (dismissed()). Hyprland adds a fade (windowrules.lua: quickshell-anim).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: overlay

    property bool open: false
    property string name: "hyprflow"  // layer namespace: blur and glass rules match it
    property int cardWidth: 420
    property bool interactive: true  // false: a HUD, keys stay with Hyprland
    property bool atBottom: false    // false: centred
    property bool hud: false         // a level OSD: pops, does not fold
    property real cardHeight: 0
    default property alias content: card.data
    signal dismissed()

    readonly property int margin: 32  // room for the fold's perspective

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    visible: open || folding.running  // stays up until folded away
    color: "transparent"
    implicitWidth: cardWidth + 2 * margin
    implicitHeight: card.height + 2 * margin
    anchors.bottom: atBottom
    margins.bottom: atBottom ? 24 : 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: interactive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: name

    // A click on any other surface ends the grab.
    HyprlandFocusGrab {
        windows: [overlay]
        active: overlay.open && overlay.interactive
        onCleared: overlay.dismissed()
    }

    Rectangle {
        id: card
        x: overlay.margin
        // The HUD drops in from a little higher.
        y: overlay.hud ? overlay.margin - 18 : overlay.margin
        width: overlay.cardWidth
        height: overlay.cardHeight
        radius: 16
        // rofi's bg-window: see-through enough for the blur and glass behind.
        color: Qt.alpha(Colors.background, 0.38)
        border.width: 1
        border.color: Qt.alpha(Colors.foreground, 0.08)

        // Filtering changes the height: follow it instead of jumping.
        Behavior on height { Anim {} }

        // Unfolds from its top edge; the HUD also pops and drops.
        opacity: 0
        transform: [
            Rotation {
                id: fold
                origin { x: card.width / 2; y: 0 }
                axis { x: 1; y: 0; z: 0 }
                angle: overlay.hud ? -100 : -90
            },
            Scale {
                id: pop
                origin { x: card.width / 2; y: card.height / 2 }
                xScale: overlay.hud ? 0.88 : 1
                yScale: overlay.hud ? 0.88 : 1
            }
        ]

        states: State {
            name: "open"
            when: overlay.open
            PropertyChanges { card.opacity: 1 }
            PropertyChanges { card.y: overlay.margin }
            PropertyChanges { fold.angle: 0 }
            PropertyChanges { pop.xScale: 1 }
            PropertyChanges { pop.yScale: 1 }
        }
        transitions: [
            Transition {
                to: "open"
                Anim {
                    properties: "opacity,y,angle,xScale,yScale"
                    duration: overlay.hud ? Motion.hud : Motion.normal
                    curve: Motion.enter
                }
            },
            Transition {
                from: "open"
                Anim { id: folding; properties: "opacity,y,angle,xScale,yScale"; duration: Motion.exit; curve: Motion.leave }
            }
        ]
    }
}
