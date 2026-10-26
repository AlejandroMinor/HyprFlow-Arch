// The output volume (AudioState), as its icon. Click: the full view
// (SoundView: outputs, each app's volume, the microphone, the mixer); right
// click: the output switcher; middle: mute; scroll: ±5 %.
import QtQuick
import Quickshell
import qs
import qs.bar
import qs.bar.panels
import qs.bar.services

Module {
    id: mod

    readonly property var node: AudioState.sink
    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    visible: node !== null
    icon: muted ? "\u{F0581}" : volume < 0.34 ? "\u{F057F}" : volume < 0.67 ? "\u{F0580}" : "\u{F057E}"
    dim: muted
    readonly property bool expanded: bar.expansion?.owner === mod
    tooltip: expanded ? "" : (node?.description ?? "") + " · " + Math.round(volume * 100) + "%"
        + "\nClick: more  ·  right click: output  ·  middle: mute"

    onClicked: bar.expand(mod, view, 0)  // the card's whole width
    onRightClicked: Quickshell.execDetached([Paths.lib + "sink-switch.py", "--toggle"])
    onMiddleClicked: AudioState.toggleMute(node)
    onScrolled: steps => AudioState.setVolume(node, volume + steps * 0.05)

    Component { id: view; SoundView { module: mod; kind: "output" } }
}
