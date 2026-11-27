import QtQuick
import Yasb.Themes

// Terminal: square, monospace and technical: hard lines, titles in capitals, no glass. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
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
        background: colors.background
        border: colors.border
        font.family: "Cascadia Mono"
        font.pixelSize: 12
        iconFont.family: "Segoe Fluent Icons"
        iconFont.pixelSize: 16
    }

    popup {
        background: colors.background
        border: colors.border
        radius: 0
        gap: 6
        openDuration: 90
        closeDuration: 60
        font.family: "Cascadia Mono"
    }

    menu {
        background: colors.background
        border: colors.border
        radius: 0
        font.family: "Cascadia Mono"
        font.pixelSize: 12
    }

    readonly property QtObject tokens: QtObject {
        property real radiusScale: 0
        property real pill: 0
        property real borderWidth: 1
        property real cardBorderWidth: 1
        property real dividerWidth: 1
        property real selectedBorderWidth: 1
        property int headingCapitalization: Font.AllUppercase
        property real openScale: 1
        property int openEasing: Easing.Linear
        property real trackHeight: 2
        property real handleSize: 12
        property real controlBorderWidth: 1
    }
}
