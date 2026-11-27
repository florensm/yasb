import QtQuick

// One of this setup's line icons, drawn in `color` at `size` px, with square ends and corners in a square theme
// such as neobrutalism. Each icon is SVG path data on a 16 px grid, so at 16 px its 1 px lines land on whole pixels
// and stay sharp.
Item {
    id: icon

    property string name
    property color color: PanelBus.textColor
    property real size: 16

    readonly property bool square: PanelBus.pill === 0
    // One pixel on screen, like Windows' own icons at this size
    readonly property real stroke: 1

    // Drawn on a 16 px grid in whole pixels, so at 16 px nothing is scaled and every line lands on the pixel grid
    readonly property string cloud: "M5 13H12A3 3 0 0 0 12 7A4.1 4.1 0 0 0 4 8A2.6 2.6 0 0 0 5 13Z"
    // The cloud moved up, with room under it for rain, snow or lightning
    readonly property string highCloud: "M5 10H12A3 3 0 0 0 12 4A4.1 4.1 0 0 0 4 5A2.6 2.6 0 0 0 5 10Z"
    readonly property string speaker: "M2 6H5L8 3V13L5 10H2Z"
    readonly property var paths: ({
        search: "M11 7A4 4 0 1 1 3 7A4 4 0 1 1 11 7Z M10 10L14 14",
        image: "M2 3H14V13H2Z M2 11L6 7L9 10L11 8L14 11 M11 6A1 1 0 1 1 9 6A1 1 0 1 1 11 6Z",
        bell: "M4 11V7A4 4 0 0 1 12 7V11L13 12H3Z M6 14H10",
        moon: "M13 10A6 6 0 1 1 6 3A5 5 0 0 0 13 10Z",
        power: "M8 2V8 M5 4A5.5 5.5 0 1 0 11 4",
        sliders: "M2 4H9 M13 4H14 M2 12H4 M8 12H14 M13 4A2 2 0 1 1 9 4A2 2 0 1 1 13 4Z M8 12A2 2 0 1 1 4 12A2 2 0 1 1 8 12Z",
        contrast: "M14 8A6 6 0 1 1 2 8A6 6 0 1 1 14 8Z M8 2V14",
        wifi: "M2 6A9 9 0 0 1 14 6 M4 9A6 6 0 0 1 12 9 M6 12A3 3 0 0 1 10 12 M8 14L8 14.1",
        bluetooth: "M4 5L12 11L8 14V2L12 5L4 11",
        nightlight: "M5 12A3 3 0 0 1 11 12 M2 12H14 M8 5V7 M3 8L4 9 M13 8L12 9",
        lock: "M4 7H12V14H4Z M5 7V5A3 3 0 0 1 11 5V7",
        signout: "M9 3H3V13H9 M7 8H14 M11 5L14 8L11 11",
        restart: "M13 8A5 5 0 1 1 11 4 M13 2V5H10",
        shuffle: "M2 4H5C8 4 8 12 11 12H14 M12 10L14 12L12 14 M2 12H5C6 12 6.5 11 7 10 M9 6C9.5 5 10 4 11 4H14 M12 2L14 4L12 6",
        play: "M5 3V13L13 8Z",
        pause: "M5 3V13 M11 3V13",
        previous: "M12 4V12L6 8Z M4 4V12",
        next: "M4 4V12L10 8Z M12 4V12",
        "volume-mute": speaker + " M10 6L14 10 M14 6L10 10",
        "volume-0": speaker,
        "volume-1": speaker + " M10 6A2.5 2.5 0 0 1 10 10",
        "volume-2": speaker + " M10 6A2.5 2.5 0 0 1 10 10 M11 5A3.5 3.5 0 0 1 11 11",
        "volume-3": speaker + " M10 6A2.5 2.5 0 0 1 10 10 M11 5A3.5 3.5 0 0 1 11 11 M12 3A6 6 0 0 1 12 13",
        sun: "M11 8A3 3 0 1 1 5 8A3 3 0 1 1 11 8Z M8 1V3 M8 13V15 M1 8H3 M13 8H15 M3 3L4 4 M12 12L13 13 M3 13L4 12 M12 4L13 3",
        cloud: cloud,
        fog: "M2 5H14 M2 8H14 M2 11H11",
        drizzle: highCloud + " M6 12V13 M10 12V13",
        rain: highCloud + " M6 12L5 15 M10 12L9 15",
        snow: highCloud + " M5 13H7 M6 12V14 M9 13H11 M10 12V14",
        storm: highCloud + " M9 10L7 13H9L8 15",
        "chevron-left": "M10 3L5 8L10 13",
        "chevron-right": "M6 3L11 8L6 13",
        calendar: "M2 3H14V14H2Z M2 6H14 M5 1V4 M11 1V4",
        plus: "M8 3V13 M3 8H13",
        close: "M4 4L12 12 M12 4L4 12",
        pin: "M12 6A4 4 0 1 0 4 6C4 9 8 14 8 14C8 14 12 9 12 6Z M9 6A1 1 0 1 1 7 6A1 1 0 1 1 9 6Z",
        refresh: "M13 8A5 5 0 1 1 11 4 M13 2V5H10",
        "chevron-down": "M3 6L8 11L13 6",
        check: "M3 8L6.5 11.5L13 5",
        headphones: "M3 10V8A5 5 0 0 1 13 8V10 M3 10H5V14H3Z M11 10H13V14H11Z",
        monitor: "M2 3H14V11H2Z M5 14H11 M8 11V14",
        "speaker-box": "M4 2H12V14H4Z M10 10A2 2 0 1 1 6 10A2 2 0 1 1 10 10Z M8 5V5.1",
        app: "M2 3H14V13H2Z M2 6H14",
        // The overview: workspaces side by side
        overview: "M1 4H7V9H1Z M9 4H15V9H9Z M3 12H13",
        repeat: "M2 7V6A2 2 0 0 1 4 4H13 M11 2L13 4L11 6 M14 9V10A2 2 0 0 1 12 12H3 M5 10L3 12L5 14",
        "repeat-one": "M2 7V6A2 2 0 0 1 4 4H13 M11 2L13 4L11 6 M14 9V10A2 2 0 0 1 12 12H3 M5 10L3 12L5 14 M8 6.5V9.5",
        music: "M6 12V3L13 2V11 M6 12A2 2 0 1 1 2 12A2 2 0 1 1 6 12Z M13 11A2 2 0 1 1 9 11A2 2 0 1 1 13 11Z",
        // For a Teams call in the island
        mic: "M6 4A2 2 0 0 1 10 4V8A2 2 0 0 1 6 8Z M4 7V8A4 4 0 0 0 12 8V7 M8 12V14 M6 14H10",
        "mic-off": "M6 4A2 2 0 0 1 10 4V8A2 2 0 0 1 6 8Z M4 7V8A4 4 0 0 0 12 8V7 M8 12V14 M6 14H10 M2 2L14 14",
        "call-end": "M2 10V8.5A9 6 0 0 1 14 8.5V10L11 11V9A7 3 0 0 0 5 9V11Z"
    })

    // The path at `size`: points scaled from the 16 px grid and, for a whole-pixel stroke, set where the stroke
    // covers whole pixels (an odd width on half pixels); arc radii are scaled, flags kept
    readonly property string path: fit(paths[name] ?? "", size / 16, stroke)

    function fit(data: string, factor: real, width: real): string {
        const whole = Math.abs(width - Math.round(width)) < 0.01
        const offset = Math.round(width) % 2 === 1 ? 0.5 : 0
        const place = value => whole ? Math.round(value * factor - offset) + offset : value * factor
        const parts = data.match(/[MLHVAZ]|-?\d*\.?\d+/g) ?? []
        const out = []
        let command = ""
        let index = 0
        for (const part of parts) {
            if (/[MLHVAZ]/.test(part)) {
                command = part
                index = 0
                out.push(part)
                continue
            }
            const value = Number(part)
            if (command === "A") {
                // rx ry rotation large-arc sweep x y
                const slot = index % 7
                out.push(slot < 2 ? (value * factor).toFixed(3) : slot < 5 ? part : place(value).toFixed(3))
            } else {
                out.push(place(value).toFixed(3))
            }
            index++
        }
        return out.join(" ")
    }

    implicitWidth: size
    implicitHeight: size

    // An SVG picture rather than a Shape: Qt draws it the same in every window, popups included, and at the screen's
    // own pixel density
    readonly property real density: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property string svg: {
        const ink = `rgb(${Math.round(color.r * 255)},${Math.round(color.g * 255)},${Math.round(color.b * 255)})`
        const ends = square ? 'stroke-linecap="square" stroke-linejoin="miter"' : 'stroke-linecap="round" stroke-linejoin="round"'
        return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">`
            + `<path d="${path}" fill="none" stroke="${ink}" stroke-opacity="${color.a}" stroke-width="${stroke}" ${ends}/></svg>`
    }

    Image {
        anchors.fill: parent
        visible: icon.path !== ""
        source: icon.path !== "" ? "data:image/svg+xml;utf8," + encodeURIComponent(icon.svg) : ""
        sourceSize: Qt.size(Math.ceil(icon.size * icon.density), Math.ceil(icon.size * icon.density))
        smooth: true
        cache: false
    }
}
