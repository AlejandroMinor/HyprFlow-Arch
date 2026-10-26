// The spectrum, drawn one of seven ways (CavaLevels.styles): bars from the
// middle, an equalizer from the floor, the same with falling peak caps
// (peaks), stacked LEDs, floating dots on stems,
// a wave, or thin lines mirrored around the centre. LEVELS are 0..1, one per
// band; coloured by cava's gradient, the higher the warmer (white with
// `colored` false), faint while silent.
import QtQuick
import qs
import qs.bar.services

Item {
    id: spectrum

    property string style: CavaLevels.style
    property var levels: CavaLevels.levels
    property bool colored: true
    readonly property bool silent: levels.every(l => l === 0)
    readonly property int count: 10
    function level(i) { return levels[i] ?? 0; }

    function tint(level) {
        if (silent) return Colors.fg(0.25);
        const gradient = CavaLevels.gradient;
        if (!colored || !gradient.length) return Colors.fg(0.45 + level * 0.55);
        return gradient[Math.round(level * (gradient.length - 1))];
    }

    implicitWidth: count * 6 - 3
    implicitHeight: 30

    component Band: Rectangle {
        required property int index
        property real level: 0
        width: 3
        radius: 1.5
        color: spectrum.tint(level)
        Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    // bars: from the middle, up and down.
    Repeater {
        model: spectrum.style === "bars" ? spectrum.count : 0
        delegate: Band {
            level: spectrum.level(index)
            x: index * 6
            height: 3 + level * 17
            y: (spectrum.height - height) / 2
        }
    }

    // equalizer: from a floor 6 px under the middle, so the usual heights
    // (short bars, most of the time) sit centred like the other modules.
    Repeater {
        model: spectrum.style === "equalizer" ? spectrum.count : 0
        delegate: Band {
            level: spectrum.level(index)
            x: index * 6
            height: 3 + level * 14
            y: spectrum.height / 2 + 6 - height
        }
    }

    // peaks: the equalizer with a cap that holds the band's peak, then falls.
    Repeater {
        model: spectrum.style === "peaks" ? spectrum.count : 0
        delegate: Item {
            id: band
            required property int index
            readonly property real level: spectrum.level(index)
            readonly property real floor: spectrum.height / 2 + 6
            property real peak: 0
            onLevelChanged: if (level >= peak) { peak = level; hold.restart(); }
            Timer { id: hold; interval: 300 }
            Timer {
                interval: 50
                repeat: true
                running: !hold.running && band.peak > band.level
                onTriggered: band.peak = Math.max(band.level, band.peak - 0.04)
            }
            Band {
                index: band.index
                level: band.level
                x: band.index * 6
                height: 3 + level * 12
                y: band.floor - height
            }
            Rectangle {
                x: band.index * 6
                y: band.floor - (3 + band.peak * 12) - 3
                width: 3; height: 1.5; radius: 0.75
                color: spectrum.tint(band.peak)
            }
        }
    }

    // leds: up to seven segments a band, each segment its own colour.
    Repeater {
        model: spectrum.style === "leds" ? spectrum.count : 0
        delegate: Repeater {
            id: column
            required property int index
            readonly property int lit: 1 + Math.round(spectrum.level(index) * 6)
            model: 7
            delegate: Rectangle {
                required property int index
                x: column.index * 6
                // Seven segments, 22 px, centred like the bars.
                y: (spectrum.height + 22) / 2 - index * 3.2 - 2.2
                width: 3; height: 2.2; radius: 0.6
                visible: index < column.lit
                color: spectrum.silent ? Colors.fg(0.25)
                     : !spectrum.colored || !CavaLevels.gradient.length ? Colors.fg(0.45 + index / 6 * 0.55)
                     : CavaLevels.gradient[Math.min(index, CavaLevels.gradient.length - 1)]
            }
        }
    }

    // dots: a dot at the band's level, on a faint stem.
    Repeater {
        model: spectrum.style === "dots" ? spectrum.count : 0
        delegate: Item {
            id: dot
            required property int index
            readonly property real level: spectrum.level(index)
            property real peak: spectrum.height - 6 - level * 17
            Behavior on peak { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Rectangle {
                x: dot.index * 6 + 1
                y: dot.peak
                width: 1
                height: spectrum.height - 6 - dot.peak
                color: Qt.alpha(spectrum.tint(dot.level), 0.35)
            }
            Rectangle {
                x: dot.index * 6 - 0.3
                y: dot.peak - 1.8
                width: 3.6; height: 3.6; radius: 1.8
                color: spectrum.tint(dot.level)
            }
        }
    }

    // wave: one smooth line through the levels, eased like the bars (each
    // band's level animates here, and every step repaints the line).
    Repeater {
        id: eased
        model: spectrum.style === "wave" ? spectrum.count : 0
        delegate: Item {
            required property int index
            property real level: spectrum.level(index)
            Behavior on level { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            onLevelChanged: wave.requestPaint()
        }
    }
    Canvas {
        id: wave
        anchors.fill: parent
        visible: spectrum.style === "wave"
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const n = spectrum.count, level = i => eased.itemAt(i)?.level ?? 0;
            const at = i => spectrum.height / 2 + 8 - level(i) * 16;
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            for (let i = 0; i < n - 1; i++) {
                // A curve per band, coloured by the louder of its ends.
                const x1 = 1.5 + i * 6, x2 = x1 + 6, mid = (x1 + x2) / 2;
                ctx.strokeStyle = spectrum.tint(Math.max(level(i), level(i + 1)));
                ctx.beginPath();
                ctx.moveTo(x1, at(i));
                ctx.bezierCurveTo(mid, at(i), mid, at(i + 1), x2, at(i + 1));
                ctx.stroke();
            }
        }
    }

    // mirror: twenty thin lines, the lows in the middle.
    Repeater {
        model: spectrum.style === "mirror" ? spectrum.count * 2 : 0
        delegate: Rectangle {
            required property int index
            readonly property real level: spectrum.level(index < spectrum.count ? spectrum.count - 1 - index : index - spectrum.count)
            x: index * 2.85
            width: 1.8
            radius: 0.9
            height: 2 + level * 18
            y: (spectrum.height - height) / 2
            color: spectrum.tint(level)
            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        }
    }
}
