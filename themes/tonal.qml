import QtQuick
import Yasb.Themes

// Tonal: Material You's colour with a minimal shape: surfaces tinted with the accent, no outlines. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
// light mode. The `tokens` at the end are this setup's shapes (see panel/PanelBus.qml); YASB itself ignores them.
Theme {
    colors {
        text: dark ? "#E5EEE8" : "#16241B"
        textSecondary: dark ? Qt.alpha("#E5EEE8", 0.77) : Qt.alpha("#16241B", 0.66)
        textTertiary: dark ? Qt.alpha("#E5EEE8", 0.53) : Qt.alpha("#16241B", 0.5)
        textDisabled: dark ? Qt.alpha("#E5EEE8", 0.36) : Qt.alpha("#16241B", 0.36)
        textOnAccent: dark ? "#0B1A11" : "#FFFFFF"
        background: Qt.tint(dark ? "#161B18" : "#EDF2EE", Qt.alpha(colors.accent, 0.06))
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.12) : Qt.alpha("#000000", 0.03)
        card: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.1))
        cardBorder: dark ? Qt.alpha("#000000", 0.14) : Qt.alpha("#000000", 0.06)
        border: dark ? "#2C3530" : "#CCD8CF"
        divider: dark ? Qt.alpha("#E5EEE8", 0.08) : Qt.alpha("#16241B", 0.07)
        hover: dark ? Qt.alpha("#E5EEE8", 0.06) : Qt.alpha("#16241B", 0.04)
        pressed: dark ? Qt.alpha("#E5EEE8", 0.04) : Qt.alpha("#16241B", 0.03)
        selected: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.24))
        control: dark ? Qt.alpha("#E5EEE8", 0.06) : Qt.alpha("#FFFFFF", 0.7)
        controlBorder: dark ? Qt.alpha("#E5EEE8", 0.08) : Qt.alpha("#16241B", 0.1)
        accent: dark ? "#7FCF9E" : "#24774B"
    }

    bar {
        background: colors.background
        border: colors.border
        font.family: "Segoe UI"
        font.pixelSize: 13
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: colors.background
        border: "transparent"
        radius: 16
        gap: 8
        openDuration: 200
        closeDuration: 140
        font.family: "Segoe UI"
    }

    readonly property QtObject tokens: QtObject {
        property real radiusScale: 1.3
        property real borderWidth: 0
        property real cardBorderWidth: 0
        property real dividerWidth: 0
        property real openScale: 0.98
        property int openEasing: Easing.OutExpo
        property real trackHeight: 6
        property real handleSize: 16
    }
}
