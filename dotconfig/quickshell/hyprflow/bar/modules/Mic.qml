// The microphone in use (AudioState), as its icon. Click: the full view
// (SoundView: microphones, the apps recording, the mixer); right or middle
// click: mute (as the volume's middle; there is no input switcher besides
// the view); scroll: ±5 %.
import QtQuick
import qs
import qs.bar
import qs.bar.panels
import qs.bar.services

Module {
    id: mod

    readonly property var node: AudioState.source
    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    visible: node !== null
    icon: muted ? "\u{F036D}" : "\u{F036C}"
    dim: muted
    readonly property bool expanded: bar.expansion?.owner === mod
    tooltip: expanded ? "" : (node?.description ?? "Microphone") + " · " + Math.round(volume * 100) + "%"
        + "\nClick: more  ·  right / middle click: mute"

    onClicked: bar.expand(mod, view, 0)  // the card's whole width
    onRightClicked: AudioState.toggleMute(node)
    onMiddleClicked: AudioState.toggleMute(node)
    onScrolled: steps => AudioState.setVolume(node, volume + steps * 0.05)

    Component { id: view; SoundView { module: mod; kind: "input" } }
}
