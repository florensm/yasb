import QtQuick
import Yasb.Themes

// Minimal: only what is needed. Neutral, compact, no lines under titles, thin controls. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
// light mode. The `tokens` at the end are this setup's shapes (see panel/PanelBus.qml); YASB itself ignores them.
Theme {
    colors {
        text: dark ? "#F5F5F5" : "#111111"
        textSecondary: dark ? Qt.alpha("#F5F5F5", 0.77) : Qt.alpha("#111111", 0.66)
        textTertiary: dark ? Qt.alpha("#F5F5F5", 0.53) : Qt.alpha("#111111", 0.5)
        textDisabled: dark ? Qt.alpha("#F5F5F5", 0.36) : Qt.alpha("#111111", 0.36)
        textOnAccent: dark ? "#111111" : "#FAFAFA"
        background: dark ? "#111111" : "#FAFAFA"
        backgroundSecondary: dark ? Qt.alpha("#000000", 0.12) : Qt.alpha("#000000", 0.03)
        card: dark ? Qt.alpha("#F5F5F5", 0.04) : Qt.alpha("#FFFFFF", 0.7)
        cardBorder: dark ? Qt.alpha("#000000", 0.14) : Qt.alpha("#000000", 0.06)
        border: dark ? "#2E2E2E" : "#DADADA"
        divider: dark ? Qt.alpha("#F5F5F5", 0.08) : Qt.alpha("#111111", 0.07)
        hover: dark ? Qt.alpha("#F5F5F5", 0.06) : Qt.alpha("#111111", 0.04)
        pressed: dark ? Qt.alpha("#F5F5F5", 0.04) : Qt.alpha("#111111", 0.03)
        selected: dark ? Qt.alpha("#F5F5F5", 0.08) : Qt.alpha("#111111", 0.06)
        control: dark ? Qt.alpha("#F5F5F5", 0.06) : Qt.alpha("#FFFFFF", 0.7)
        controlBorder: dark ? Qt.alpha("#F5F5F5", 0.08) : Qt.alpha("#111111", 0.1)
        accent: dark ? "#F5F5F5" : "#111111"
    }

    bar {
        background: Qt.alpha(colors.background, 0.92)
        border: colors.border
        font.family: "Segoe UI"
        font.pixelSize: 13
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: Qt.alpha(colors.background, 0.94)
        border: colors.divider
        radius: 10
        gap: 8
        openDuration: 160
        closeDuration: 120
        font.family: "Segoe UI"
    }

    readonly property QtObject tokens: QtObject {
        property real radiusScale: 1
        property real borderWidth: 1
        property real cardBorderWidth: 0
        property real dividerWidth: 0
        property real openScale: 1
        property int openEasing: Easing.OutQuart
        property real trackHeight: 4
        property real handleSize: 14
    }
}
