import QtQuick
import Yasb.Themes

// Neobrutalism: square corners, thick ink outlines, hard shadows without blur and loud accent headers. It follows
// Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in light mode. In dark
// mode the outlines are black on lifted surfaces and the popup's shadow takes the accent colour.
// The font, Space Grotesk, ships in the fonts folder (SIL Open Font License, fonts/OFL-SpaceGrotesk.txt), so it needs
// no install.
Theme {
    readonly property FontLoader grotesk: FontLoader { source: "../fonts/SpaceGrotesk.ttf" }
    readonly property string family: grotesk.status === FontLoader.Ready ? grotesk.name : "Space Grotesk"

    colors {
        // Text, from the strongest to the weakest
        text: dark ? "#F4F1EC" : "#111111"
        textSecondary: dark ? Qt.alpha("#F4F1EC", 0.76) : Qt.alpha("#111111", 0.74)
        textTertiary: dark ? Qt.alpha("#F4F1EC", 0.56) : Qt.alpha("#111111", 0.56)
        textDisabled: dark ? Qt.alpha("#F4F1EC", 0.38) : Qt.alpha("#111111", 0.38)
        // Text and icons on an accent fill
        textOnAccent: "#111111"
        // Lifted a step above the desktop in dark mode, so black outlines show against it
        background: dark ? "#2A2622" : "#FFFBF2"
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.22) : Qt.alpha("#000000", 0.04)
        // Cards: the background tinted with the accent, outlined in ink
        card: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.14))
        cardBorder: dark ? "#000000" : "#111111"
        // Ink: the outlines of the bar, popups and menus, and the lines inside them
        border: dark ? "#000000" : "#111111"
        divider: colors.border
        hover: dark ? Qt.alpha("#FFFFFF", 0.08) : Qt.alpha("#000000", 0.06)
        pressed: dark ? Qt.alpha("#FFFFFF", 0.04) : Qt.alpha("#000000", 0.1)
        // The selected row is an accent block
        selected: colors.accent
        control: colors.background
        controlHover: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.2))
        controlPressed: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.35))
        controlBorder: colors.border
        smoke: Qt.alpha("#000000", 0.4)
        // An orange that works on both; set system.accent to follow Windows instead
        accent: dark ? "#F2A65A" : "#FF9F43"
        success: dark ? "#7BE07B" : "#1F9D3A"
        warning: dark ? "#FFD43B" : "#B37400"
        critical: dark ? "#FF8A8A" : "#D7263D"
    }

    bar {
        // Solid: blur does not suit hard outlines
        background: colors.background
        border: colors.border
        font.family: family
        font.pixelSize: 13
        font.weight: Font.Medium
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: colors.background
        border: colors.border
        radius: 0
        gap: 10
        // Quick, with no shrinking
        openDuration: 160
        closeDuration: 90
        font.family: family
    }

    menu {
        background: colors.background
        border: colors.border
        radius: 0
        font.family: family
        font.pixelSize: 13
        openDuration: 100
    }

    // This setup's shapes, which YASB's Theme has no place for: panel/PanelBus.qml reads them, and a theme without
    // them keeps the panels' usual look
    readonly property QtObject tokens: QtObject {
        // Corners: 0 makes every radius square; 1 is the usual corners
        property real radiusScale: 0
        property real pill: 0
        // Ink outlines on popups, cards and the selected row, and the line under a popup's title
        property real borderWidth: 2
        property real cardBorderWidth: 2
        property real selectedBorderWidth: 2
        property real dividerWidth: 2
        // A hard shadow without blur: black under a light popup, the accent under a dark one
        property real shadowOffset: 5
        property color shadowColor: dark ? colors.accent : colors.border
        property real cardShadowOffset: 3
        // The popup's title on an accent block, in capitals
        property color headerBackground: colors.accent
        property color headerText: colors.textOnAccent
        property color selectedText: colors.textOnAccent
        property int headingCapitalization: Font.AllUppercase
        // Opening: a small overshoot, no shrinking
        property real openScale: 0.96
        property int openEasing: Easing.OutBack
        property int closeEasing: Easing.InQuad
        // Sliders and switches: a thick outlined track and a square handle with a hard shadow
        property real trackHeight: 10
        property real handleSize: 18
        property real controlBorderWidth: 2
        property real controlShadowOffset: 2
    }
}
