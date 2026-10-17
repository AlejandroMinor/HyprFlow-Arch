// Who is watching or listening, as Waybar's privacy group showed it: the
// camera (camera_status.py, the same script Waybar ran), the microphone
// while an app records audio and the screen while the portal shares it (both
// from Pipewire, where Waybar's own privacy module looked). One pill, red
// icons that blink; the tooltip lists each app by its icon. Who records
// comes from AudioState (cava, always listening, never counts).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.bar

Module {
    id: mod

    readonly property string icons: Qt.resolvedUrl("../icons/")

    // The camera: camera_status.py prints {class: active|inactive, tooltip}.
    property bool camera: false
    property string cameraNote: ""
    LongProcess {
        id: watch
        running: true
        argv: [Quickshell.env("HOME") + "/.local/lib/hyprflow/camera_status.py"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    mod.camera = data.class === "active";
                    mod.cameraNote = data.tooltip ?? "";
                } catch (e) {}
            }
        }
        onExited: again.start()
    }
    Timer { id: again; interval: 5000; onTriggered: watch.running = true }

    // The microphone and the screen: Pipewire's streams.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    PwObjectTracker { objects: mod.streams }

    function label(node) {
        const p = node.properties ?? {};
        return p["media.name"] || p["application.name"] || p["application.process.binary"] || node.name;
    }
    function inClass(kind) {
        return streams.filter(n => (n.properties?.["media.class"] ?? "") === kind);
    }

    readonly property var recording: AudioState.recording
    readonly property bool sharing: Pipewire.nodes.values.some(n => n.name === "xdg-desktop-portal-hyprland")

    readonly property var shown: [
        mod.camera ? "camera" : "",
        mod.recording.length ? "microphone" : "",
        mod.sharing ? "screen-share" : ""
    ].filter(s => s)

    visible: shown.length > 0

    tooltip: {
        const line = (icon, text) => "<img src='" + icons + icon + ".svg' width='14' height='14'> " + text;
        const lines = [];
        if (camera) lines.push(line("camera", cameraNote || "Camera"));
        for (const name of new Set(recording.map(n => label(n)))) lines.push(line("microphone", name));
        if (sharing) {
            const names = new Set(inClass("Stream/Input/Video").map(n => label(n)));
            if (names.size === 0) names.add("Screen shared");
            for (const name of names) lines.push(line("screen-share", name));
        }
        return lines.join("<br>");
    }

    RowLayout {
        spacing: 6  // one group, as an icon and its text
        height: 30
        Repeater {
            model: mod.shown
            delegate: Image {
                required property string modelData
                Layout.alignment: Qt.AlignVCenter
                source: mod.icons + modelData + ".svg"
                sourceSize { width: mod.iconSize; height: mod.iconSize }
                // Adwaita's camera looks left; mirrored it faces the way the
                // screen's arrow points.
                mirror: modelData === "camera"

                // Arrives with a pop, then blinks while in use.
                scale: 0
                Component.onCompleted: scale = 1
                Behavior on scale { Anim { duration: Motion.normal; curve: Motion.enter } }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    Anim { to: 0.3; duration: 900 }
                    Anim { to: 1; duration: 900 }
                }
            }
        }
    }
}
