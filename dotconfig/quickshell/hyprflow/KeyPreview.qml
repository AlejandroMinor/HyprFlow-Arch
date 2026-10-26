// A small keyboard playing one of the BY Tech keyboard's effects, for
// KeyboardEffects.qml. Each effect is a rough copy of the real one (checked
// on camera): how lit every key is at time t, and its hue for the three that
// are multicolour whatever the colour. Typed-key effects make up presses.
import QtQuick

Canvas {
    id: root

    property int effect: 1
    property color color: "white"
    property real t: 0  // seconds, from the panel's clock

    readonly property int columns: 14
    readonly property int rows: 5
    readonly property real key: 7
    readonly property real gap: 2
    readonly property var rainbow: [3, 15, 16]

    width: columns * (key + gap) - gap
    height: rows * (key + gap) - gap
    onTChanged: requestPaint()
    onEffectChanged: requestPaint()
    onColorChanged: requestPaint()

    // Repeatable noise in 0..1.
    function rnd(n) {
        const s = Math.sin(n * 12.9898) * 43758.5453;
        return s - Math.floor(s);
    }

    function wave(phase) {
        return 0.5 + 0.5 * Math.sin(phase);
    }

    // A made-up press every 0.35 s: the newest few, as {x, y, age, n}.
    function presses(t) {
        const step = 0.35, last = Math.floor(t / step), out = [];
        for (let n = last; n > last - 4; n--)
            out.push({ x: Math.floor(rnd(n) * columns), y: Math.floor(rnd(n + 0.5) * rows),
                       age: t - n * step, n: n });
        return out;
    }

    // [how lit 0..1, hue 0..1 or -1 for the effect's own colour]
    function level(x, y, t, typed) {
        const cx = (columns - 1) / 2, cy = (rows - 1) / 2;
        const centre = Math.hypot(x - cx, (y - cy) * 1.4);
        switch (effect) {
        case 1: case 9: return [1, -1];
        case 2: return [wave(t * 2.1 - 1.57), -1];
        case 3: return [1, (t * 0.3) % 1];
        case 4: {
            let lit = 0;
            for (const p of typed)
                if (p.x === x && p.y === y) lit = Math.max(lit, 1 - p.age);
            return [lit, -1];
        }
        case 5: {
            const head = (t * 6 + rnd(x) * 9) % (rows + 4);
            const behind = head - y;
            return [behind >= 0 && behind < 2.5 ? 1 - behind / 2.5 : 0, -1];
        }
        case 6: {
            const n = x * 31 + y * 7 + Math.floor(t * 3) * 101;
            return [rnd(n) > 0.6 ? 1 : 0, -1];
        }
        case 7: case 20: {
            let lit = 0;
            for (const p of typed) {
                const d = Math.hypot(x - p.x, (y - p.y) * 1.4);
                lit = Math.max(lit, (1 - Math.abs(d - p.age * 8) / 1.2) * (1 - p.age / 1.4));
            }
            return [Math.max(0, lit), -1];
        }
        case 8: return [wave(t * 3 - Math.floor(x / 3.5) * 1.6), -1];
        case 10: {
            // Along the rows, back and forth.
            const index = y * columns + (y % 2 ? columns - 1 - x : x);
            const behind = (t * 14) % (columns * rows) - index;
            return [behind >= 0 && behind < 7 ? 1 - behind / 7 : 0, -1];
        }
        case 11: return [wave(x * 0.6 - t * 5), -1];
        case 12: return [0, -1];
        case 13: return [wave(centre * 1.2 - t * 5), -1];
        case 14: {
            const along = t * 10 / (columns + 3);
            const d = Math.abs(x - (along % 1) * (columns + 3) + 1.5);
            return [Math.max(0, 1 - d / 2), -1];
        }
        case 15: return [1, ((x / columns * 0.8 - t * 0.25) % 1 + 1) % 1];
        case 16: return [1, ((rows - y) / rows * 0.5 + t * 0.4) % 1];
        case 17: return [0.6 + 0.4 * wave(centre * 0.9 - t * 5), -1];
        case 18: case 19: {
            const p = (t * 7) % (cx + 3);
            const d = Math.min(Math.abs(x - p), Math.abs(columns - 1 - x - p));
            return [Math.max(0, 1 - d / 1.5), -1];
        }
        }
        return [0, -1];
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const typed = presses(t);
        for (let y = 0; y < rows; y++) {
            for (let x = 0; x < columns; x++) {
                const px = x * (key + gap), py = y * (key + gap);
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.08);
                ctx.beginPath();
                ctx.roundedRect(px, py, key, key, 1.5, 1.5);
                ctx.fill();
                const [lit, hue] = level(x, y, t, typed);
                if (lit <= 0.02)
                    continue;
                ctx.fillStyle = hue >= 0 && rainbow.includes(effect)
                    ? Qt.hsva(hue, 1, 1, lit)
                    : Qt.rgba(color.r, color.g, color.b, lit);
                ctx.beginPath();
                ctx.roundedRect(px, py, key, key, 1.5, 1.5);
                ctx.fill();
            }
        }
    }
}
