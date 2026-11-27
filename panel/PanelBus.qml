pragma Singleton

import QtCore
import QtQuick
import Yasb
import Yasb.Bar
import Yasb.Themes

// What the panel's pages share: the frame's sizes, the colours (from the bars' YASB theme), the page order,
// and one PanelHost per bar. Each widget on the bar hands its page to its bar's host, which keeps a single panel up
// while you switch between them.
QtObject {
    id: bus

    // Keep these equal to layouts/frame.qml
    readonly property int barHeight: 32   // the top bar's solid part
    readonly property int rail: 4         // the frame on the left, right and bottom

    // The theme of the first bar a page was handed from; every bar names the same one in config.yaml. Followed
    // through the bar, so a theme reloaded after its file changed is picked up.
    property BarBase themeBar: null
    readonly property Theme theme: themeBar ? themeBar.theme : null

    readonly property color color: theme ? theme.colors.background : "#0e0e12"
    readonly property color surface: theme ? theme.colors.card : "#17171d"
    readonly property color raised: theme ? theme.colors.control : "#22222b"
    readonly property color outline: theme ? theme.colors.border : "#2e2e38"
    readonly property color textColor: theme ? theme.colors.text : "#e6e6f0"
    readonly property color textDim: theme ? theme.colors.textSecondary : "#a9a9bb"
    readonly property color accent: theme ? theme.colors.accent : "#c9ccf7"
    // A second colour a theme may add, else the accent
    readonly property color accent2: theme ? (theme.accent2 ?? theme.colors.accent) : "#c9ccf7"
    readonly property color onAccent: theme ? theme.colors.textOnAccent : "#1b1b4b"
    readonly property font font: theme ? theme.bar.font : Qt.font({ family: "Segoe UI", pixelSize: 13 })
    readonly property font iconFont: theme ? theme.bar.iconFont : Qt.font({ family: "Segoe Fluent Icons" })

    property int openDuration: 280
    property int closeDuration: 180

    // Shapes from the theme file's own `tokens` object (see themes/neobrutalism.qml), so a theme decides how rounded,
    // outlined and shadowed everything is. YASB's Theme has no such shapes; a theme without `tokens` keeps this
    // setup's own look through the fallbacks below.
    readonly property QtObject tokens: theme?.tokens ?? null
    // Corners picked in the control center, on top of whichever theme is on: square, sharp, soft or round; "" keeps
    // the theme's own. Remembered in control-center.ini in the config folder
    readonly property string corners: store.corners
    readonly property var cornerScales: ({ square: 0, sharp: 0.5, soft: 1, round: 1.5 })
    function setCorners(name: string) {
        store.corners = name
    }
    property Settings store: Settings {
        location: Qt.resolvedUrl("../control-center.ini")
        property string corners: ""
        property string scheme: ""
        property string barStyle: "full"
        property string barAccent: "icons"
    }

    // The colours in use, written to yasb_colors.css in the config folder as CSS variables whenever they change (a theme,
    // a colour scheme, light or dark, the wallpaper's colours), for other apps to take: GlazeWM's window borders and
    // stack tab bars read them with `color: { file: ".../yasb_colors.css", key: "--yasb-accent" }`
    readonly property string paletteFile: decodeURIComponent(Qt.resolvedUrl("../yasb_colors.css").toString().replace(/^file:\/{2,3}/, ""))
    readonly property string paletteCss: theme ? paletteFor(theme.colors) : ""

    // A colour as #rrggbb, or #rrggbbaa when it is see-through
    function hex(colour: color): string {
        const part = value => Math.round(value * 255).toString(16).padStart(2, "0")
        return "#" + part(colour.r) + part(colour.g) + part(colour.b) + (colour.a < 1 ? part(colour.a) : "")
    }

    function paletteFor(colours: var): string {
        const solid = colour => Qt.tint(colours.background, colour)
        const entries = [
            ["background", colours.background], ["surface", solid(colours.card)], ["raised", solid(colours.control)],
            ["border", colours.border], ["divider", solid(colours.divider)], ["hover", solid(colours.hover)],
            ["selected", solid(colours.selected)], ["text", colours.text], ["text-dim", solid(colours.textSecondary)],
            ["text-faint", solid(colours.textTertiary)], ["accent", colours.accent], ["on-accent", colours.textOnAccent],
            ["success", colours.success], ["warning", colours.warning], ["critical", colours.critical]
        ]
        return ":root {\n" + entries.map(entry => `  --yasb-${entry[0]}: ${hex(entry[1])};`).join("\n") + "\n}\n"
    }

    onPaletteCssChanged: paletteWrite.restart()
    // Once the colours settle, as they fade to a new wallpaper's
    property Timer paletteWrite: Timer {
        interval: 800
        onTriggered: {
            if (bus.paletteCss === "")
                return
            const file = bus.paletteFile.replace(/'/g, "''")
            const css = bus.paletteCss.replace(/'/g, "''")
            paletteWriter.command = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                `[System.IO.File]::WriteAllText('${file}', '${css}')`]
            paletteWriter.run()
        }
    }
    property Process paletteWriter: Process {}

    // How the top bar looks, from the control center: "full" across the screen, "floating" as one card clear of the
    // screen's edges, or "islands" with a card around each group of widgets (layouts/frame.qml)
    readonly property string barStyle: store.barStyle
    function setBarStyle(name: string) {
        store.barStyle = name
    }

    // How much of the accent the bar shows: "off", "icons" (the icons and the clock's time in the accent) or "tint"
    // (also a light accent fill behind every button)
    readonly property string barAccent: store.barAccent
    readonly property color barIconColor: barAccent === "off" ? textColor : accent

    function setBarAccent(name: string) {
        store.barAccent = name
    }

    // The colour scheme picked in the control center, laid over whichever theme is on (panel/ColorSchemes.qml):
    // "" keeps the theme's own colours, "wallpaper" takes them from the wallpaper. It sets the theme's base colours;
    // the theme's own come back when the scheme is set to "". Follows Windows' light and dark mode
    readonly property string scheme: store.scheme
    readonly property bool followWallpaper: scheme === "wallpaper"
    readonly property var schemeKeys: ["background", "text", "textSecondary", "textTertiary", "textDisabled", "accent", "textOnAccent"]
    // The theme's own colours before a scheme changed them, as text so they stay as they were
    property var themeColours: null

    function setScheme(name: string) {
        store.scheme = name
        if (name === "wallpaper")
            WallpaperColors.setFollowWallpaper(true)
        applyScheme()
    }

    // Kept for the Wallpapers panel's switch and the control center's tile
    function setFollowWallpaper(on: bool) {
        setScheme(on ? "wallpaper" : "")
    }

    function applyScheme() {
        if (!theme)
            return
        if (themeColours && themeColours.theme !== theme)
            themeColours = null
        const colours = ColorSchemes.colours(scheme, theme.dark, WallpaperColors)
        if (colours) {
            if (!themeColours) {
                const own = { theme: theme }
                for (const key of schemeKeys)
                    own[key] = theme.colors[key].toString()
                themeColours = own
            }
            for (const key of schemeKeys)
                theme.colors[key] = colours[key]
        } else if (themeColours) {
            for (const key of schemeKeys)
                theme.colors[key] = themeColours[key]
            themeColours = null
        }
    }

    onThemeChanged: applyScheme()
    property Connections schemeFollows: Connections {
        target: WallpaperColors

        function onAccentChanged() {
            if (bus.followWallpaper)
                bus.applyScheme()
        }
        function onBarChanged() {
            if (bus.followWallpaper)
                bus.applyScheme()
        }
    }
    // Light or dark mode switched: the scheme's other version
    property Connections modeFollows: Connections {
        target: bus.theme

        function onDarkChanged() {
            bus.applyScheme()
        }
    }
    // Fixed radii in the widgets are multiplied by radiusScale: 1 for the usual corners, 0 for square ones
    readonly property real radiusScale: corners in cornerScales ? cornerScales[corners] : (tokens?.radiusScale ?? 1)
    // The largest radius for round things such as dots and pills; 0 when square
    readonly property real pill: corners === "square" ? 0 : corners !== "" ? 999 : (tokens?.pill ?? 999)
    // A popup's own corners: the theme's, or 12 px scaled by the corners picked
    readonly property real popupRadius: corners in cornerScales ? Math.round(12 * radiusScale) : (theme?.popup.radius ?? 12)
    readonly property real borderWidth: tokens?.borderWidth ?? 1
    readonly property real cardBorderWidth: tokens?.cardBorderWidth ?? 0
    readonly property real cardShadowOffset: tokens?.cardShadowOffset ?? 0
    readonly property real shadowOffset: tokens?.shadowOffset ?? 0
    readonly property color shadowColor: tokens?.shadowColor ?? "transparent"
    readonly property color headerBackground: tokens?.headerBackground ?? "transparent"
    readonly property color headerText: tokens?.headerText ?? textColor
    readonly property real dividerWidth: tokens?.dividerWidth ?? 1
    readonly property color divider: theme?.colors.divider ?? outline
    readonly property real selectedBorderWidth: tokens?.selectedBorderWidth ?? 0
    readonly property color selectedText: tokens?.selectedText ?? textColor
    readonly property real openScale: tokens?.openScale ?? 0.85
    readonly property int openEasing: tokens?.openEasing ?? Easing.OutCubic
    readonly property int closeEasing: tokens?.closeEasing ?? Easing.InCubic
    // Sliders and switches: the track, the handle, and their ink outline and hard shadow
    readonly property real trackHeight: tokens?.trackHeight ?? 4
    readonly property real handleSize: tokens?.handleSize ?? 18
    readonly property real controlBorderWidth: tokens?.controlBorderWidth ?? 0
    readonly property real controlShadowOffset: tokens?.controlShadowOffset ?? 0
    // Panel titles take the theme's heading capitalization, such as all caps
    readonly property int headingCapitalization: tokens?.headingCapitalization ?? Font.MixedCase

    // Another program coming to the front, such as after a click on it: open panels, the calendar and the island's
    // card close on it. YASB's own windows are left out by the tracker.
    signal otherAppActivated
    property real frontWindow: 0
    property ActiveWindowTracker front: ActiveWindowTracker {
        onWindowChanged: {
            const hwnd = window?.hwnd ?? 0
            if (hwnd !== 0 && bus.frontWindow !== 0 && hwnd !== bus.frontWindow)
                bus.otherAppActivated()
            if (hwnd !== 0)
                bus.frontWindow = hwnd
        }
    }

    // The Fluent glyphs the bar's buttons name, drawn as this setup's own line icons (panel/Icon.qml) instead
    readonly property var glyphIcons: ({
        "\ue721": "search",
        "\ue7aa": "image",
        "\ue74f": "volume-mute",
        "\ue992": "volume-0",
        "\ue993": "volume-1",
        "\ue994": "volume-2",
        "\ue995": "volume-3",
        "\uea8f": "bell",
        "\ue7ed": "moon"
    })

    // The pages. `width` and `height` are the panel's size while that page shows. The island opens Sound and
    // Notifications too.
    readonly property var panels: [
        // `centered` pages open in the middle of the screen instead of under their button
        { name: "search", title: "Search", width: 560, height: 600, centered: true },
        { name: "performance", title: "Performance", width: 440, height: 640 },
        { name: "weather", title: "Weather", width: 440, height: 720 },
        { name: "wallpapers", title: "Wallpapers", width: 780, height: 640, centered: true },
        { name: "sound", title: "Sound", width: 440, height: 660 },
        { name: "notifications", title: "Notifications", width: 440, height: 640 },
        { name: "control", title: "Control center", width: 440, height: 930 }
    ]
    property var keys: ({})

    // A notification that has just come in, for the island to show: emitted by the Notifications widget
    signal notified(var notification)

    function isCentered(name: string): bool {
        return panels.find(panel => panel.name === name)?.centered ?? false
    }

    function panelSize(name: string): size {
        const panel = panels.find(panel => panel.name === name)
        return Qt.size(panel?.width ?? 440, panel?.height ?? 600)
    }

    // [{ bar, host }]; one host, and so one panel window, per bar
    property var hosts: []
    property Component hostComponent: Component {
        PanelHost {}
    }

    function hostFor(bar: Item): QtObject {
        if (!themeBar && bar instanceof BarBase)
            themeBar = bar
        let entry = hosts.find(entry => entry.bar === bar)
        if (!entry) {
            entry = { bar: bar, host: hostComponent.createObject(null) }
            hosts.push(entry)
        }
        return entry.host
    }

    function register(name: string, hotkey: string) {
        const copy = Object.assign({}, keys)
        copy[name] = hotkey
        keys = copy
    }

    // "ctrl+alt+w" as "Ctrl+Alt+W", "alt+grave" as "Alt+`"
    readonly property var keySymbols: ({ grave: "`", slash: "/", backslash: "\\", minus: "-", equal: "=", comma: ",", period: "." })
    function label(hotkey: string): string {
        return (hotkey ?? "").split("+").filter(part => part !== "")
            .map(part => keySymbols[part.toLowerCase()] ?? (part.length <= 1 ? part.toUpperCase() : part[0].toUpperCase() + part.slice(1))).join("+")
    }
}
