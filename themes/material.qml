import QtQuick
import Yasb.Themes

// Material You: opaque surfaces tinted with the accent, big round corners and chunky controls. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
// light mode. The `tokens` at the end are this setup's shapes (see panel/PanelBus.qml); YASB itself ignores them.
Theme {
    colors {
        text: dark ? "#E5EEE8" : "#16241B"
        textSecondary: dark ? Qt.alpha("#E5EEE8", 0.77) : Qt.alpha("#16241B", 0.66)
        textTertiary: dark ? Qt.alpha("#E5EEE8", 0.53) : Qt.alpha("#16241B", 0.5)
        textDisabled: dark ? Qt.alpha("#E5EEE8", 0.36) : Qt.alpha("#16241B", 0.36)
        textOnAccent: dark ? "#0B1A11" : "#FFFFFF"
        background: Qt.tint(dark ? "#161B18" : "#EDF2EE", Qt.alpha(colors.accent, 0.08))
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.12) : Qt.alpha("#000000", 0.03)
        card: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.14))
        cardBorder: dark ? Qt.alpha("#000000", 0.14) : Qt.alpha("#000000", 0.06)
        border: dark ? "#2C3530" : "#CCD8CF"
        divider: dark ? Qt.alpha("#E5EEE8", 0.08) : Qt.alpha("#16241B", 0.07)
        hover: dark ? Qt.alpha("#E5EEE8", 0.06) : Qt.alpha("#16241B", 0.04)
        pressed: dark ? Qt.alpha("#E5EEE8", 0.04) : Qt.alpha("#16241B", 0.03)
        selected: Qt.tint(colors.background, Qt.alpha(colors.accent, 0.3))
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
        radius: 28
        gap: 8
        openDuration: 300
        closeDuration: 200
        font.family: "Segoe UI"
    }

    readonly property QtObject tokens: QtObject {
        property real radiusScale: 2
        property real borderWidth: 0
        property real cardBorderWidth: 0
        property real dividerWidth: 0
        property real openScale: 0.9
        property int openEasing: Easing.OutExpo
        property real trackHeight: 12
        property real handleSize: 22
    }
}
