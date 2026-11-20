import QtQuick
import QtQuick.Templates as T
import Yasb.Themes

// An on/off switch in the theme's shape: a thin pill by default, or an outlined block with a hard shadow in a theme
// that sets control.borderWidth and control.shadowOffset. On, it fills with the palette's accent.
T.Switch {
    id: control

    required property Theme theme
    readonly property real ink: theme.control.borderWidth
    readonly property real shadow: theme.control.shadowOffset

    implicitWidth: indicator.width + shadow + (text !== "" ? spacing + contentItem.implicitWidth : 0)
    implicitHeight: indicator.height + shadow
    spacing: 8
    opacity: enabled ? 1 : 0.5

    indicator: Item {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - control.shadow - height) / 2
        width: control.ink > 0 ? 44 : 40
        height: control.ink > 0 ? 24 : 20

        Rectangle {
            visible: control.shadow > 0
            x: control.shadow
            y: control.shadow
            width: parent.width
            height: parent.height
            radius: track.radius
            color: control.theme.popup.border
        }

        Rectangle {
            id: track

            anchors.fill: parent
            radius: Math.min(height / 2, control.theme.radius.pill)
            color: control.checked ? control.palette.accent
                : control.ink > 0 ? control.theme.colors.background : "transparent"
            border.width: control.ink > 0 ? control.ink : control.checked ? 0 : 1
            border.color: control.ink > 0 ? control.theme.popup.border : control.theme.colors.textSecondary

            Rectangle {
                readonly property real inset: control.ink > 0 ? control.ink + 2 : 4

                x: control.checked ? parent.width - width - inset : inset
                anchors.verticalCenter: parent.verticalCenter
                width: control.ink > 0 ? parent.height - 2 * inset : 12
                height: width
                radius: Math.min(width / 2, control.theme.radius.pill)
                color: control.checked ? control.theme.colors.textOnAccent
                    : control.ink > 0 ? control.theme.popup.border : control.theme.colors.textSecondary

                Behavior on x {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    contentItem: Text {
        leftPadding: control.indicator.width + control.shadow + control.spacing
        visible: control.text !== ""
        text: control.text
        color: control.theme.colors.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
    }
}
