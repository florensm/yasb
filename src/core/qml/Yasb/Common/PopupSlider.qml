import QtQuick
import QtQuick.Templates as T
import Yasb.Themes

// A horizontal slider in the theme's shape: a thin track with a round handle by default, or an outlined block with
// a square handle and a hard shadow in a theme that sets control.borderWidth and control.shadowOffset. The filled
// part takes the palette's accent, so a popup or widget that sets palette.accent colours it.
T.Slider {
    id: control

    required property Theme theme
    readonly property real ink: theme.control.borderWidth
    readonly property real shadow: theme.control.shadowOffset
    readonly property real handleSize: theme.control.handleSize

    implicitWidth: 200
    implicitHeight: handleSize + shadow + 4
    leftPadding: handleSize / 2
    rightPadding: handleSize / 2 + shadow
    opacity: enabled ? 1 : 0.5

    background: Item {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: control.theme.control.trackHeight

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, control.theme.radius.pill)
            color: control.ink > 0 ? control.theme.colors.background : Qt.alpha(control.theme.colors.text, 0.25)
            border.width: control.ink
            border.color: control.theme.popup.border
        }

        Rectangle {
            width: Math.max(control.ink * 2, control.visualPosition * parent.width)
            height: parent.height
            radius: Math.min(height / 2, control.theme.radius.pill)
            color: control.palette.accent
            border.width: control.ink
            border.color: control.theme.popup.border
        }
    }

    handle: Item {
        x: control.leftPadding + control.visualPosition * control.availableWidth - width / 2
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.handleSize
        height: control.handleSize

        // Drawn first, so it shows only where it sticks out
        Rectangle {
            visible: control.shadow > 0
            x: control.shadow
            y: control.shadow
            width: parent.width
            height: parent.height
            radius: knob.radius
            color: control.theme.popup.border
        }

        Rectangle {
            id: knob

            anchors.fill: parent
            radius: Math.min(width / 2, control.theme.radius.pill)
            color: control.ink > 0 ? (control.pressed ? control.palette.accent : control.theme.colors.background)
                : Qt.tint(control.theme.colors.background, control.theme.colors.control)
            border.width: control.ink > 0 ? control.ink : 1
            border.color: control.ink > 0 ? control.theme.popup.border : control.theme.colors.controlBorder

            // The accent dot of the thin look, which grows under the pointer and shrinks while dragged
            Rectangle {
                visible: control.ink === 0
                anchors.centerIn: parent
                width: control.pressed ? 10 : control.hovered ? 14 : 12
                height: width
                radius: Math.min(width / 2, control.theme.radius.pill)
                color: control.palette.accent

                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
}
