import QtQuick
import Yasb.Themes

// iOS: soft and roomy: big corners, frosted glass and no lines under titles. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
// light mode. The `tokens` at the end are this setup's shapes (see panel/PanelBus.qml); YASB itself ignores them.
Theme {
    colors {
        text: dark ? "#E7EAF0" : "#18202E"
        textSecondary: dark ? Qt.alpha("#E7EAF0", 0.77) : Qt.alpha("#18202E", 0.66)
        textTertiary: dark ? Qt.alpha("#E7EAF0", 0.53) : Qt.alpha("#18202E", 0.5)
        textDisabled: dark ? Qt.alpha("#E7EAF0", 0.36) : Qt.alpha("#18202E", 0.36)
        textOnAccent: dark ? "#0E1420" : "#FFFFFF"
        background: dark ? "#1A1D24" : "#EDF0F4"
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.12) : Qt.alpha("#000000", 0.03)
        card: dark ? Qt.alpha("#E7EAF0", 0.04) : Qt.alpha("#FFFFFF", 0.7)
        cardBorder: dark ? Qt.alpha("#000000", 0.14) : Qt.alpha("#000000", 0.06)
        border: dark ? "#2F3440" : "#CDD3DC"
        divider: dark ? Qt.alpha("#E7EAF0", 0.08) : Qt.alpha("#18202E", 0.07)
        hover: dark ? Qt.alpha("#E7EAF0", 0.06) : Qt.alpha("#18202E", 0.04)
        pressed: dark ? Qt.alpha("#E7EAF0", 0.04) : Qt.alpha("#18202E", 0.03)
        selected: dark ? Qt.alpha("#E7EAF0", 0.08) : Qt.alpha("#18202E", 0.06)
        control: dark ? Qt.alpha("#E7EAF0", 0.06) : Qt.alpha("#FFFFFF", 0.7)
        controlBorder: dark ? Qt.alpha("#E7EAF0", 0.08) : Qt.alpha("#18202E", 0.1)
        accent: dark ? "#8AB4F8" : "#2F5BB7"
    }

    bar {
        background: Qt.alpha(colors.background, 0.72)
        border: colors.border
        font.family: "Segoe UI"
        font.pixelSize: 13
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: Qt.alpha(colors.background, 0.72)
        border: Qt.alpha(colors.border, 0.6)
        radius: 22
        gap: 8
        openDuration: 340
        closeDuration: 200
        font.family: "Segoe UI"
    }

    readonly property QtObject tokens: QtObject {
        property real radiusScale: 1.8
        property real borderWidth: 1
        property real cardBorderWidth: 0
        property real dividerWidth: 0
        property real openScale: 0.9
        property int openEasing: Easing.OutBack
        property real trackHeight: 6
        property real handleSize: 24
    }
}
