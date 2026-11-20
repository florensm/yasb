import QtQuick
import Yasb.Themes

// Neobrutalism: square corners, thick ink outlines, hard shadows without blur and loud accent headers. It follows
// Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in light mode. In dark
// mode the outlines are black on lifted surfaces and the popup's shadow takes the accent colour.
// To use it, copy this file to your themes folder (~/.config/yasb/themes) and set `theme: neobrutalism` on a bar
// in config.yaml. The font is Space Grotesk (free at fonts.google.com); without it Windows uses its own font.
Theme {
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
        selectedText: colors.textOnAccent
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
        font.family: "Space Grotesk"
        font.pixelSize: 13
        font.weight: Font.Medium
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: colors.background
        border: colors.border
        radius: 0
        borderWidth: 2
        gap: 10
        // Black under a light popup, the accent under a dark one
        shadowOffset: 5
        shadowColor: dark ? colors.accent : colors.border
        headerBackground: colors.accent
        headerText: colors.textOnAccent
        dividerWidth: 2
        cardBorderWidth: 2
        cardShadowOffset: 3
        selectedBorderWidth: 2
        // Quick, with a small overshoot, and no shrinking
        openDuration: 160
        closeDuration: 90
        openEasing: Easing.OutBack
        closeEasing: Easing.InQuad
        openScale: 0.96
        font.family: "Space Grotesk"
    }

    menu {
        background: colors.background
        border: colors.border
        radius: 0
        font.family: "Space Grotesk"
        font.pixelSize: 13
        openDuration: 100
    }

    // Square everywhere; raise them (for example 2, 4, 6) for softer blocks
    radius {
        xs: 0
        sm: 0
        md: 0
        pill: 0
    }

    // Chunky blocks: a thick outlined track and a square handle with a hard shadow
    control {
        trackHeight: 10
        handleSize: 18
        borderWidth: 2
        shadowOffset: 2
    }

    type {
        caption.family: popup.font.family
        caption.pixelSize: 12
        caption.weight: Font.Medium
        body.family: popup.font.family
        body.pixelSize: 13
        body.weight: Font.Medium
        heading.family: popup.font.family
        heading.pixelSize: 15
        heading.weight: Font.Bold
        heading.capitalization: Font.AllUppercase
        display.family: popup.font.family
        display.pixelSize: 28
        display.weight: Font.Bold
    }
}
