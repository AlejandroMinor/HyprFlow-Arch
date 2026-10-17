// The sound the bar shows, in one place: the output, the microphone, the
// inputs to pick from and the apps playing or recording. The microphone is the one Pipewire actually uses (as the
// OSD): Quickshell leaves the default source empty while a configured one,
// the AirPods, is away.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    property string usedSource: ""
    readonly property var source: Pipewire.defaultAudioSource
        || Pipewire.nodes.values.find(n => n.name === usedSource) || null
    // Apps playing: their own streams, each with its volume.
    readonly property var playing: Pipewire.nodes.values.filter(n =>
        n.isStream && (n.properties?.["media.class"] ?? "") === "Stream/Output/Audio")

    // Apps recording (the microphone in use); cava always listens, so it
    // never counts.
    readonly property var ignoredRecorders: ["cava"]
    readonly property var recording: Pipewire.nodes.values.filter(n =>
        n.isStream && (n.properties?.["media.class"] ?? "") === "Stream/Input/Audio"
        && !ignoredRecorders.includes(appName(n).toLowerCase()))
    // The microphones and other inputs.
    readonly property var sources: Pipewire.nodes.values.filter(n =>
        !n.isStream && (n.properties?.["media.class"] ?? "").startsWith("Audio/Source"))

    PwObjectTracker { objects: [root.sink, root.source].filter(n => n).concat(root.playing, root.recording) }
    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => !n.isStream && !n.isSink) }  // inputs: their properties
    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.isStream) }  // their properties

    LongProcess {
        running: true
        argv: ["pw-metadata", "-m", "0", "default.audio.source"]
        stdout: SplitParser {
            onRead: line => {
                const found = line.match(/"name":\s*"([^"]+)"/);
                if (found) root.usedSource = found[1];
            }
        }
    }

    function setVolume(node, value) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, value));
    }
    function useSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
    function toggleMute(node) {
        if (node?.audio) node.audio.muted = !node.audio.muted;
    }
    function appName(node) {
        const p = node.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || node.description || node.name;
    }
}
