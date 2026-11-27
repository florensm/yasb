pragma Singleton

import QtQuick
import QtCore

// The palette read from the wallpaper; with Follow wallpaper on, the theme takes its accent from it. With `followWallpaper` on, Wallpapers hands in a
// palette made from the wallpaper (see WallpaperPalette.qml) and every colour here slides to it; off, the fixed
// palette below is used. The last palette is saved to theme.ini in the config folder, so it is back after a restart.
QtObject {
    id: palette

    // The fixed palette, used when followWallpaper is off and before any wallpaper has been read
    readonly property var fixed: ({
        bar: "#0e0e12", surface: "#17171d", raised: "#22222b", outline: "#2e2e38",
        accent: "#c9ccf7", accent2: "#c9ccf7", onAccent: "#1b1b4b", text: "#e6e6f0", textDim: "#a9a9bb"
    })
    readonly property var roles: ["bar", "surface", "raised", "outline", "accent", "accent2", "onAccent", "text", "textDim"]

    property bool followWallpaper: store.followWallpaper
    // How long the colours take to change, in milliseconds
    property int fadeDuration: 600

    // The colours. Lightness is fixed per role, so the bar stays dark and the text readable whatever the wallpaper.
    //   bar: the frame, the bar and the panel. surface: cards on it. raised: buttons and fields, and hover.
    //   outline: thin lines. accent: what is on or selected. accent2: a second colour from the wallpaper.
    //   onAccent: text on the accent. text, textDim: text and quieter text.
    readonly property color bar: blend("bar", mix)
    readonly property color surface: blend("surface", mix)
    readonly property color raised: blend("raised", mix)
    readonly property color outline: blend("outline", mix)
    readonly property color accent: blend("accent", mix)
    readonly property color accent2: blend("accent2", mix)
    readonly property color onAccent: blend("onAccent", mix)
    readonly property color text: blend("text", mix)
    readonly property color textDim: blend("textDim", mix)

    // The palette from the last wallpaper read, saved as JSON
    property var wallpaperPalette: null
    // The image on screen, as the Wallpapers widget knows it; empty when it isn't one of its images
    property string wallpaperPath: ""

    // From the palette shown before a change to the one after; `mix` runs from 0 to 1 between them
    property var from: fixed
    property var to: fixed
    property real mix: 1

    function target(): var {
        return followWallpaper && wallpaperPalette ? wallpaperPalette : fixed
    }

    function blend(role: string, amount: real): color {
        const a = Qt.color(from[role] ?? fixed[role])
        const b = Qt.color(to[role] ?? fixed[role])
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1)
    }

    function snapshot(): var {
        const now = {}
        for (const role of roles)
            now[role] = blend(role, mix).toString()
        return now
    }

    function fadeTo(palette: var) {
        from = snapshot()
        to = palette
        fade.stop()
        mix = 0
        fade.start()
    }

    // A palette from WallpaperPalette (or any object with the roles as colours)
    function setWallpaperPalette(palette: var) {
        const copy = {}
        for (const role of roles)
            copy[role] = Qt.color(palette[role] ?? fixed[role]).toString()
        wallpaperPalette = copy
        store.palette = JSON.stringify(copy)
        if (followWallpaper)
            fadeTo(copy)
    }

    function setFollowWallpaper(on: bool) {
        store.followWallpaper = on
    }

    onFollowWallpaperChanged: fadeTo(target())

    Component.onCompleted: {
        try {
            const saved = JSON.parse(store.palette)
            if (saved && typeof saved === "object" && saved.bar)
                wallpaperPalette = saved
        } catch (error) {
            wallpaperPalette = null
        }
        from = target()
        to = target()
        mix = 1
    }

    property Settings store: Settings {
        location: Qt.resolvedUrl("../theme.ini")
        category: "theme"
        property bool followWallpaper: true
        property string palette: ""
    }

    property NumberAnimation fade: NumberAnimation {
        target: palette
        property: "mix"
        from: 0
        to: 1
        duration: palette.fadeDuration
        easing.type: Easing.InOutQuad
    }
}
