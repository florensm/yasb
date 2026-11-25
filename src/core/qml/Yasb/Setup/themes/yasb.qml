import QtQuick
import Yasb.Themes

// Your theme: every color, font and shape of the bar, its widgets, popups and menus, set to YASB's defaults.
// Change what you like; the bar updates when you save. A value written as "dark ? A : B" is A in dark mode
// and B in light mode. Fonts are Qt fonts, so any part of one can be set, such as weight or letterSpacing.
Theme {
    colors {
        // Text, from the strongest to the weakest
        text: dark ? "#FFFFFF" : Qt.alpha("#000000", 0.894)
        textSecondary: dark ? Qt.alpha("#FFFFFF", 0.773) : Qt.alpha("#000000", 0.62)
        textTertiary: dark ? Qt.alpha("#FFFFFF", 0.53) : Qt.alpha("#000000", 0.447)
        textDisabled: dark ? Qt.alpha("#FFFFFF", 0.365) : Qt.alpha("#000000", 0.36)
        // Text and icons on an accent fill
        textOnAccent: dark ? "#000000" : "#FFFFFF"
        // The base the bar and popups start from, and an area a step darker laid over it
        background: dark ? "#202020" : "#F3F3F3"
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.1) : Qt.alpha("#000000", 0.024)
        // Boxes that hold a group of things, and their outline
        card: dark ? Qt.alpha("#FFFFFF", 0.05) : Qt.alpha("#FFFFFF", 0.7)
        cardBorder: dark ? Qt.alpha("#000000", 0.1) : Qt.alpha("#000000", 0.06)
        // Outer edges of the bar, popups and menus, and lines between the parts of a popup
        border: dark ? "#3A3A3A" : "#D9D9D9"
        divider: dark ? Qt.alpha("#FFFFFF", 0.08) : Qt.alpha("#000000", 0.06)
        // Fills laid over any background: under the pointer, while pressed, and behind the selected item
        hover: dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#000000", 0.035)
        pressed: dark ? Qt.alpha("#FFFFFF", 0.04) : Qt.alpha("#000000", 0.024)
        selected: dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#000000", 0.035)
        // Text and icons on the selected fill
        selectedText: colors.text
        // Buttons: their fill at rest, under the pointer and while pressed, and their outline
        control: dark ? Qt.alpha("#FFFFFF", 0.06) : Qt.alpha("#FFFFFF", 0.7)
        controlHover: dark ? Qt.alpha("#FFFFFF", 0.08) : Qt.alpha("#F9F9F9", 0.5)
        controlPressed: dark ? Qt.alpha("#FFFFFF", 0.03) : Qt.alpha("#F9F9F9", 0.3)
        controlBorder: dark ? Qt.alpha("#FFFFFF", 0.07) : Qt.alpha("#000000", 0.06)
        smoke: Qt.alpha("#000000", 0.3)
        // The accent color set in Windows; a color such as "#4CC2FF" replaces it
        accent: system.accent
        success: dark ? "#6CCB5F" : "#0F7B0F"
        warning: dark ? "#FCE100" : "#9D5D00"
        critical: dark ? "#FF99A4" : "#C42B1C"
    }

    bar {
        background: Qt.alpha(colors.background, 0.85)
        border: colors.border
        // Widget labels on the bar
        font.family: "Segoe UI"
        font.pixelSize: 13
        // Widget icons on the bar
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: Qt.alpha(colors.background, 0.85)
        border: colors.border
        radius: 8
        borderWidth: 1
        // Between the bar and the popup
        gap: 8
        // A hard shadow without blur, moved this far right and down; 0 draws none
        shadowOffset: 0
        shadowColor: colors.border
        // The title bar: its fill, its text and icons, and the line under it
        headerBackground: "transparent"
        headerText: colors.text
        dividerWidth: 1
        // Outlines of cards and of the selected row, and the hard shadow under cards
        cardBorderWidth: 1
        cardShadowOffset: 0
        selectedBorderWidth: 0
        // Milliseconds, the curves, and how small the popup starts as it opens (1 for no scaling)
        openDuration: 180
        closeDuration: 140
        openEasing: Easing.OutCubic
        closeEasing: Easing.InCubic
        openScale: 0.85
        font.family: "Segoe UI"
        // Icons in popups
        iconFont.family: "Segoe Fluent Icons"
    }

    // Corners in popups: chips, rows and buttons, cards, and circles. Set them all to 0 for square corners
    radius {
        xs: 2
        sm: 4
        md: 8
        pill: 999
    }

    // Sliders and switches: the slider's track and handle, and an ink outline and hard shadow (0 for none)
    control {
        trackHeight: 4
        handleSize: 18
        borderWidth: 0
        shadowOffset: 0
    }

    // Text in popups: small print, normal text, a popup's title, and big numbers
    type {
        caption.family: popup.font.family
        caption.pixelSize: 12
        body.family: popup.font.family
        body.pixelSize: 13
        heading.family: popup.font.family
        heading.pixelSize: 16
        heading.weight: Font.DemiBold
        display.family: popup.font.family
        display.pixelSize: 28
        display.weight: Font.DemiBold
    }

    // Right-click menus
    menu {
        background: dark ? "#2C2C2C" : "#F9F9F9"
        border: colors.border
        radius: 8
        font.family: "Segoe UI"
        font.pixelSize: 13
        // Milliseconds the menu takes to fade in
        openDuration: 150
    }
}
