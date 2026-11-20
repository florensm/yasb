import QtQuick

// The colours, fonts and shapes the bar and its widgets share. A theme file starts from Theme and sets only what it
// changes, for example colors.accent, menu.radius or popup.font.family. Fonts are Qt fonts, so any part of one can be
// set, variableAxes included.
QtObject {
    id: theme

    readonly property bool dark: Application.styleHints.colorScheme === Qt.ColorScheme.Dark
    // Windows' own colours, such as its accent colour
    readonly property SystemPalette system: SystemPalette {}

    component Colors: QtObject {
        // Text, from the strongest to the weakest
        property color text
        property color textSecondary
        property color textTertiary
        property color textDisabled
        // Text and icons on an accent fill
        property color textOnAccent
        // The base the bar and popups start from
        property color background
        // An area a step darker, laid over the background
        property color backgroundSecondary
        // Boxes that hold a group of things, and their outline
        property color card
        property color cardBorder
        // Outer edges of the bar, popups and menus
        property color border
        // Lines between the parts of a popup, such as under its header
        property color divider
        // Fills laid over any background: under the pointer, while pressed, and behind the selected or current item
        property color hover
        property color pressed
        property color selected
        // Text and icons on the selected fill
        property color selectedText
        // Buttons: their fill at rest, under the pointer and while pressed, and their outline
        property color control
        property color controlHover
        property color controlPressed
        property color controlBorder
        // Laid over a popup's content to set it back behind something opened on top, such as a group
        property color smoke
        property color accent
        property color success
        property color warning
        property color critical
    }

    component Bar: QtObject {
        property color background
        property color border
        // Widget labels on the bar
        property font font
        // Widget icons, on the bar and in popups; a widget's iconSize sets the size on the bar
        property font iconFont
    }

    component Popup: QtObject {
        property color background
        property color border
        property real radius
        property real borderWidth
        // Between the bar and the popup
        property real gap
        // A hard shadow without blur, moved this far right and down; 0 draws none
        property real shadowOffset
        property color shadowColor
        // The popup's title bar: its fill, its text and icons, and the line under it
        property color headerBackground
        property color headerText
        property real dividerWidth
        // Outlines of the cards in a popup and of the selected row, and the hard shadow under cards
        property real cardBorderWidth
        property real cardShadowOffset
        property real selectedBorderWidth
        // Milliseconds
        property int openDuration
        property int closeDuration
        // Easing.Type curves, and how small the popup starts as it opens, 1 for no scaling
        property int openEasing
        property int closeEasing
        property real openScale
        // Only its family is used: each widget sets the sizes and weights of its own popup text
        property font font
    }

    // Corner radii in popups, from small to round: chips and marks, rows and buttons, cards, and circles such as
    // today in the calendar. A theme with square corners sets them all to 0
    component Radius: QtObject {
        property real xs
        property real sm
        property real md
        property real pill
    }

    // Text roles in popups, each a whole font, so a theme can change its family, size, weight or capitalization
    component Type: QtObject {
        // Small print: sublabels, footers, weekdays
        property font caption
        property font body
        // A popup's title in its header
        property font heading
        // Big numbers, such as a level or a temperature
        property font display
    }

    // Right-click menus
    component Menu: QtObject {
        property color background
        property color border
        property real radius
        property font font
        // Milliseconds the menu takes to fade in
        property int openDuration
    }

    readonly property Colors colors: Colors {
        text: theme.dark ? "#FFFFFF" : Qt.alpha("#000000", 0.894)
        textSecondary: theme.dark ? Qt.alpha("#FFFFFF", 0.773) : Qt.alpha("#000000", 0.62)
        textTertiary: theme.dark ? Qt.alpha("#FFFFFF", 0.53) : Qt.alpha("#000000", 0.447)
        textDisabled: theme.dark ? Qt.alpha("#FFFFFF", 0.365) : Qt.alpha("#000000", 0.36)
        textOnAccent: theme.dark ? "#000000" : "#FFFFFF"
        background: theme.dark ? "#202020" : "#F3F3F3"
        backgroundSecondary: theme.dark ? Qt.alpha("#000000", 0.1) : Qt.alpha("#000000", 0.024)
        card: theme.dark ? Qt.alpha("#FFFFFF", 0.05) : Qt.alpha("#FFFFFF", 0.7)
        cardBorder: theme.dark ? Qt.alpha("#000000", 0.1) : Qt.alpha("#000000", 0.06)
        border: theme.dark ? "#3A3A3A" : "#D9D9D9"
        divider: theme.dark ? Qt.alpha("#FFFFFF", 0.08) : Qt.alpha("#000000", 0.06)
        hover: theme.dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#000000", 0.035)
        pressed: theme.dark ? Qt.alpha("#FFFFFF", 0.04) : Qt.alpha("#000000", 0.024)
        selected: theme.dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#000000", 0.035)
        selectedText: theme.colors.text
        control: theme.dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#FFFFFF", 0.7)
        controlHover: theme.dark ? Qt.alpha("#FFFFFF", 0.08) : Qt.alpha("#F9F9F9", 0.5)
        controlPressed: theme.dark ? Qt.alpha("#FFFFFF", 0.03) : Qt.alpha("#F9F9F9", 0.3)
        controlBorder: theme.dark ? Qt.alpha("#FFFFFF", 0.07) : Qt.alpha("#000000", 0.06)
        smoke: Qt.alpha("#000000", 0.3)
        // The accent colour set in Windows
        accent: theme.system.accent
        success: theme.dark ? "#6CCB5F" : "#0F7B0F"
        warning: theme.dark ? "#FCE100" : "#9D5D00"
        critical: theme.dark ? "#FF99A4" : "#C42B1C"
    }

    // Fonts are given part by part: a theme file that sets one part keeps the others
    readonly property Bar bar: Bar {
        background: Qt.alpha(theme.colors.background, 0.85)
        border: theme.colors.border
        font.family: "Segoe UI"
        font.pixelSize: 13
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    readonly property Popup popup: Popup {
        background: Qt.alpha(theme.colors.background, 0.85)
        border: theme.colors.border
        radius: 8
        borderWidth: 1
        gap: 8
        shadowOffset: 0
        shadowColor: theme.colors.border
        headerBackground: "transparent"
        headerText: theme.colors.text
        dividerWidth: 1
        cardBorderWidth: 1
        cardShadowOffset: 0
        selectedBorderWidth: 0
        openDuration: 180
        closeDuration: 140
        openEasing: Easing.OutCubic
        closeEasing: Easing.InCubic
        openScale: 0.85
        font.family: "Segoe UI"
    }

    readonly property Radius radius: Radius {
        xs: 2
        sm: 4
        md: 8
        pill: 999
    }

    readonly property Type type: Type {
        caption.family: theme.popup.font.family
        caption.pixelSize: 12
        body.family: theme.popup.font.family
        body.pixelSize: 13
        heading.family: theme.popup.font.family
        heading.pixelSize: 16
        heading.weight: Font.DemiBold
        display.family: theme.popup.font.family
        display.pixelSize: 28
        display.weight: Font.DemiBold
    }

    readonly property Menu menu: Menu {
        background: theme.dark ? "#2C2C2C" : "#F9F9F9"
        border: theme.colors.border
        radius: 8
        font.family: "Segoe UI"
        font.pixelSize: 13
        openDuration: 150
    }
}
