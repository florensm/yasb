import QtQuick

// Reads an image and builds a dark palette from it, in plain QML: the image is drawn small on a Canvas, its pixels
// are read with getImageData, and the colour that stands out most (by hue, weighted by how colourful each pixel is)
// becomes the seed. Every colour is then made from that seed at a fixed lightness, in OKLCH, so the bar stays dark
// and the text stays readable whatever the wallpaper is. A grey wallpaper gives a neutral palette.
Item {
    id: root

    property url source
    // How many pixels across the image is read at; 64 is plenty for colours and takes a few milliseconds
    property int sampleSize: 64

    readonly property bool ready: _ready
    readonly property bool neutral: _seed.c < 0.02
    readonly property real seedHue: _seed.h
    readonly property real seedChroma: _seed.c

    // The palette. Lightness is fixed per role; only hue and chroma follow the wallpaper.
    readonly property color bar: tone(0.16, Math.min(0.035, _seed.c * 0.30))
    readonly property color surface: tone(0.21, Math.min(0.040, _seed.c * 0.35))
    readonly property color raised: tone(0.26, Math.min(0.045, _seed.c * 0.40))
    readonly property color outline: tone(0.33, Math.min(0.050, _seed.c * 0.40))
    readonly property color accent: tone(0.82, neutral ? 0.0 : Math.max(0.06, Math.min(0.13, _seed.c)))
    readonly property color onAccent: tone(0.24, Math.min(0.06, _seed.c * 0.5))
    readonly property color text: tone(0.95, Math.min(0.015, _seed.c * 0.12))
    readonly property color textDim: tone(0.74, Math.min(0.030, _seed.c * 0.20))
    // A second colour from another part of the wallpaper, for a highlight that isn't the accent
    readonly property color accent2: _second.c > 0 ? toneAt(0.78, _second.h, Math.max(0.06, Math.min(0.12, _second.c))) : accent

    signal extracted()

    property bool _ready: false
    property var _seed: ({ h: 270, c: 0.03 })
    property var _second: ({ h: 0, c: 0 })

    width: 0
    height: 0
    clip: true

    onSourceChanged: {
        _ready = false
        if (source.toString() === "")
            return
        canvas.loadImage(source)
        // A picture already in Qt's cache, as when the wallpaper gallery shows it, can be ready without
        // imageLoaded ever coming, so this also checks for it a few times
        retry.count = 0
        retry.restart()
    }

    Timer {
        id: retry

        property int count: 0

        interval: 120
        repeat: true
        onTriggered: {
            if (canvas.isImageLoaded(root.source)) {
                stop()
                canvas.requestPaint()
            } else if (++count > 40) {
                stop()
            }
        }
    }

    function tone(l: real, c: real): color {
        return toneAt(l, _seed.h, c)
    }

    // ---- OKLCH to sRGB, lowering chroma until the colour fits ----
    function toneAt(l: real, h: real, c: real): color {
        let lo = 0, hi = c
        let rgb = oklchToRgb(l, c, h)
        if (inGamut(rgb))
            return Qt.rgba(rgb[0], rgb[1], rgb[2], 1)
        for (let i = 0; i < 14; ++i) {
            const mid = (lo + hi) / 2
            const test = oklchToRgb(l, mid, h)
            if (inGamut(test)) { lo = mid; rgb = test } else { hi = mid }
        }
        rgb = oklchToRgb(l, lo, h)
        return Qt.rgba(clamp(rgb[0]), clamp(rgb[1]), clamp(rgb[2]), 1)
    }

    function clamp(v: real): real { return Math.max(0, Math.min(1, v)) }
    function inGamut(rgb: var): bool { return rgb.every(v => v >= -0.0005 && v <= 1.0005) }

    function oklchToRgb(L: real, C: real, h: real): var {
        const a = C * Math.cos(h * Math.PI / 180), b = C * Math.sin(h * Math.PI / 180)
        const l_ = L + 0.3963377774 * a + 0.2158037573 * b
        const m_ = L - 0.1055613458 * a - 0.0638541728 * b
        const s_ = L - 0.0894841775 * a - 1.2914855480 * b
        const l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        const lin = [
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        ]
        return lin.map(v => v <= 0.0031308 ? 12.92 * v : 1.055 * Math.pow(Math.max(v, 0), 1 / 2.4) - 0.055)
    }

    function toLinear(v: real): real {
        v /= 255
        return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }

    // ---- Picking the seed ----
    function analyse(data: var) {
        const bins = 36
        const weight = new Array(bins).fill(0)
        const chroma = new Array(bins).fill(0)
        const sumA = new Array(bins).fill(0)
        const sumB = new Array(bins).fill(0)
        let pixels = 0, colourful = 0
        for (let i = 0; i < data.length; i += 4) {
            if (data[i + 3] < 128)
                continue
            const r = toLinear(data[i]), g = toLinear(data[i + 1]), bl = toLinear(data[i + 2])
            const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bl)
            const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bl)
            const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bl)
            const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
            const a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
            const b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
            const C = Math.sqrt(a * a + b * b)
            pixels++
            if (C < 0.02)
                continue
            // Colourful pixels count more; very dark and blown-out ones less
            const w = C * C * (L > 0.15 && L < 0.95 ? 1 : 0.3)
            const h = (Math.atan2(b, a) * 180 / Math.PI + 360) % 360
            const bin = Math.floor(h / (360 / bins)) % bins
            weight[bin] += w
            chroma[bin] += C * w
            sumA[bin] += a * w
            sumB[bin] += b * w
            colourful += w / C
        }
        if (pixels === 0)
            return
        // Neighbouring hues count together, so one colour split over two bins still wins
        const score = weight.map((w, i) => w + 0.5 * (weight[(i + bins - 1) % bins] + weight[(i + 1) % bins]))
        const pick = (exclude) => {
            let best = -1
            for (let i = 0; i < bins; ++i) {
                if (exclude >= 0) {
                    const d = Math.abs(i - exclude) * (360 / bins)
                    if (Math.min(d, 360 - d) < 60)
                        continue
                }
                if (best < 0 || score[i] > score[best])
                    best = i
            }
            return best
        }
        const describe = (bin) => {
            const ids = [(bin + bins - 1) % bins, bin, (bin + 1) % bins]
            const a = ids.reduce((sum, i) => sum + sumA[i], 0)
            const b = ids.reduce((sum, i) => sum + sumB[i], 0)
            const w = ids.reduce((sum, i) => sum + weight[i], 0)
            const c = ids.reduce((sum, i) => sum + chroma[i], 0)
            return { h: (Math.atan2(b, a) * 180 / Math.PI + 360) % 360, c: w > 0 ? c / w : 0 }
        }
        const first = pick(-1)
        // Too little colour in the whole image: a neutral palette with only a hint of its tint
        if (colourful / pixels < 0.004 || first < 0) {
            _seed = { h: first >= 0 ? describe(first).h : 270, c: 0.012 }
            _second = { h: 0, c: 0 }
        } else {
            _seed = describe(first)
            const other = pick(first)
            _second = other >= 0 && score[other] > 0.25 * score[first] ? describe(other) : { h: 0, c: 0 }
        }
    }

    Canvas {
        id: canvas

        width: root.sampleSize
        height: root.sampleSize
        renderStrategy: Canvas.Immediate
        renderTarget: Canvas.Image

        onImageLoaded: requestPaint()

        onPaint: {
            if (root.source.toString() === "" || !isImageLoaded(root.source))
                return
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(root.source, 0, 0, width, height)
            root.analyse(ctx.getImageData(0, 0, width, height).data)
            retry.stop()
            root._ready = true
            root.extracted()
        }
    }
}
