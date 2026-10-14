// Level OSD: a HUD card that shows what just changed and hides itself.
// Pushed: qs -c hyprflow ipc call osd level ICON TITLE CAPTION VALUE
// (VALUE < 0: no bar). Audio comes from Pipewire, the layout from Hyprland.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Scope {
    id: root

    readonly property string font: "JetBrainsMono Nerd Font"
    property bool open: false
    property string icon: ""
    property string title: ""
    property string caption: ""
    property int value: 0
    readonly property bool hasBar: value >= 0

    // Fixed width with a bar; without one, as wide as the row.
    readonly property int maxCardWidth: 360
    readonly property int minCardWidth: 160
    readonly property int cardPadding: 32

    // Bumped on a change while open: the glyph nudges.
    property int pulse: 0

    // Node the shown bar drives, so it can be scrubbed with the mouse.
    property var audioNode: null
    property bool micTarget: false
    property bool dragging: false

    // Nerd Font (Material Design) glyphs.
    readonly property string glyphVolumeHigh: String.fromCodePoint(0xF057E)
    readonly property string glyphVolumeMedium: String.fromCodePoint(0xF0580)
    readonly property string glyphVolumeLow: String.fromCodePoint(0xF057F)
    readonly property string glyphVolumeOff: String.fromCodePoint(0xF0581)
    readonly property string glyphMic: String.fromCodePoint(0xF036C)
    readonly property string glyphMicOff: String.fromCodePoint(0xF036D)
    readonly property string glyphKeyboard: String.fromCodePoint(0xF030C)

    function present(glyph, name, text, level) {
        const reopening = root.open;
        root.icon = glyph;
        root.title = name;
        root.caption = text;
        root.value = level;  // under 0 draws no bar
        root.open = true;
        if (reopening) root.pulse = root.pulse + 1;
        hide.restart();
    }

    function volumeGlyph(percent) {
        if (percent >= 66) return glyphVolumeHigh;
        if (percent >= 33) return glyphVolumeMedium;
        return glyphVolumeLow;
    }

    // Map a pointer x along the bar to a level and apply it to the shown node.
    function scrubVolume(x, barWidth) {
        if (!audioNode || !audioNode.audio || barWidth <= 0) return;
        const clamped = Math.max(0, Math.min(barWidth, x));
        const percent = Math.round(100 * clamped / barWidth);
        audioNode.audio.muted = false;
        audioNode.audio.volume = percent / 100;
        root.value = percent;
        root.icon = micTarget ? glyphMic : volumeGlyph(percent);
        root.caption = micTarget ? "On  ·  " + percent + "%" : percent + "%";
    }

    IpcHandler {
        target: "osd"
        // Not `show`: it clashes with the `qs ipc show` subcommand.
        function level(icon: string, title: string, caption: string, value: int): void {
            root.present(icon, title, caption, value);
        }
    }

    // Last seen node and value: only a real change pops the card.
    property int sinkNode: -1
    property bool sinkMuted: false
    property int sinkPercent: 0
    property int sourceNode: -1
    property bool sourceMuted: false
    property int sourcePercent: 0

    // Quickshell leaves defaultAudioSource null while the chosen mic is away
    // (AirPods off), though Pipewire falls back to another: follow the one
    // Pipewire actually uses, from its metadata.
    property string usedSourceName: ""
    readonly property var micNode: Pipewire.defaultAudioSource
        || Pipewire.nodes.values.find(n => n.name === usedSourceName) || null
    onMicNodeChanged: seedAudio()

    Process {
        running: true
        command: ["pw-metadata", "-m", "0", "default.audio.source"]
        stdout: SplitParser {
            onRead: line => {
                const found = line.match(/key:'default\.audio\.source' value:'\{ *"name": *"([^"]+)"/);
                if (found) root.usedSourceName = found[1];
            }
        }
    }

    // Without a tracker the volume and mute signals never arrive.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, root.micNode].filter(n => n)
    }

    // Remember the starting values when the default node changes.
    function seedAudio() {
        const sink = Pipewire.defaultAudioSink;
        if (sink && sink.audio) {
            sinkNode = sink.id; sinkMuted = sink.audio.muted;
            sinkPercent = Math.round(sink.audio.volume * 100);
        }
        const source = root.micNode;
        if (source && source.audio) {
            sourceNode = source.id; sourceMuted = source.audio.muted;
            sourcePercent = Math.round(source.audio.volume * 100);
        }
    }

    function audioSink() {
        const node = Pipewire.defaultAudioSink;
        if (!node || !node.audio) return;
        const muted = node.audio.muted;
        const percent = Math.round(node.audio.volume * 100);
        if (node.id !== sinkNode) {  // new node: remember, do not show
            sinkNode = node.id; sinkMuted = muted; sinkPercent = percent;
            root.audioNode = node; root.micTarget = false; return;
        }
        if (muted === sinkMuted && percent === sinkPercent) return;
        sinkMuted = muted; sinkPercent = percent;
        root.audioNode = node; root.micTarget = false;
        if (root.dragging) return;  // the drag already reflects the level
        if (muted) present(glyphVolumeOff, "Volume", "Muted", 0);
        else present(volumeGlyph(percent), "Volume", percent + "%", percent);
    }

    function audioSource() {
        const node = root.micNode;
        if (!node || !node.audio) return;
        const muted = node.audio.muted;
        const percent = Math.round(node.audio.volume * 100);
        if (node.id !== sourceNode) {
            sourceNode = node.id; sourceMuted = muted; sourcePercent = percent;
            root.audioNode = node; root.micTarget = true; return;
        }
        if (muted === sourceMuted && percent === sourcePercent) return;
        sourceMuted = muted; sourcePercent = percent;
        root.audioNode = node; root.micTarget = true;
        if (root.dragging) return;
        if (muted) present(glyphMicOff, "Microphone", "Muted", 0);
        else present(glyphMic, "Microphone", "On  ·  " + percent + "%", percent);
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() { root.seedAudio(); }
        function onDefaultAudioSourceChanged() { root.seedAudio(); }
        function onReadyChanged() { root.seedAudio(); }
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumesChanged() { root.audioSink(); }
        function onMutedChanged() { root.audioSink(); }
    }

    Connections {
        target: root.micNode ? root.micNode.audio : null
        function onVolumesChanged() { root.audioSource(); }
        function onMutedChanged() { root.audioSource(); }
    }

    // activelayout>>keyboard,Layout Name
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            const layout = event.data.split(",")[1] || "";
            root.audioNode = null;
            root.present(glyphKeyboard, "Keyboard layout", layout, -1);
        }
    }

    Timer {
        id: hide
        interval: 1400
        onTriggered: root.open = false
    }

    // A small kick on each change.
    SequentialAnimation {
        id: kick
        NumberAnimation { target: iconText; property: "scale"; to: 1.22; duration: Motion.fast; easing.type: Easing.OutQuad }
        NumberAnimation { target: iconText; property: "scale"; to: 1.0;  duration: Motion.normal; easing.type: Easing.OutCubic }
    }

    Connections {
        target: root
        function onPulseChanged() { kick.restart(); }
    }

    Overlay {
        name: "hyprflow-osd"
        open: root.open
        hud: true
        interactive: false
        cardWidth: root.hasBar
            ? root.maxCardWidth
            : Math.round(Math.min(root.maxCardWidth,
                                  Math.max(root.minCardWidth,
                                           column.implicitWidth + root.cardPadding)))
        cardHeight: column.implicitHeight + 32

        ColumnLayout {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    id: iconText
                    text: root.icon
                    color: Colors.foreground
                    font { family: root.font; pixelSize: 22 }
                    Layout.preferredWidth: 26
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: root.title
                    color: Colors.foreground
                    font { family: root.font; pixelSize: 14 }
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: root.caption
                    color: Qt.alpha(Colors.foreground, 0.6)
                    font { family: root.font; pixelSize: 12 }
                    Layout.maximumWidth: 140
                    elide: Text.ElideRight
                }
            }

            // Hand-drawn: no QtQuick.Controls.
            Rectangle {
                id: track
                visible: root.hasBar
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Qt.alpha(Colors.foreground, 0.12)

                Rectangle {
                    width: track.width * Math.max(0, Math.min(100, root.value)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: Qt.alpha(Colors.foreground, 0.85)
                    Behavior on width { Anim {} }
                }

                // A taller hit area than the 6px track, so it is easy to grab.
                MouseArea {
                    id: scrub
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 28
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    enabled: root.audioNode !== null
                    cursorShape: Qt.PointingHandCursor

                    // Hold the card while the pointer is on the bar.
                    onEntered: hide.stop()
                    onExited: if (!root.dragging) hide.restart()
                    onPressed: {
                        root.dragging = true;
                        hide.stop();
                        root.scrubVolume(mouse.x, width);
                    }
                    onPositionChanged: if (pressed) root.scrubVolume(mouse.x, width)
                    onReleased: {
                        root.dragging = false;
                        if (!containsMouse) hide.restart();
                    }
                }
            }
        }
    }
}
