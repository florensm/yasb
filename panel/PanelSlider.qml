import QtQuick
import QtQuick.Templates as T

// A horizontal slider in this setup's shape: a thin track with a round handle, or an outlined block with a square
// handle and a hard shadow in a theme whose tokens set controlBorderWidth and controlShadowOffset. The filled part
// takes the palette's accent.
T.Slider {
    id: control

    readonly property real ink: PanelBus.controlBorderWidth
    readonly property real shadow: PanelBus.controlShadowOffset
    readonly property real handleSize: PanelBus.handleSize
    readonly property color outline: PanelBus.theme?.popup.border ?? PanelBus.outline
    readonly property color base: PanelBus.theme?.colors.background ?? PanelBus.color

    implicitWidth: 200
    implicitHeight: handleSize + shadow + 4
    leftPadding: handleSize / 2
    rightPadding: handleSize / 2 + shadow
    opacity: enabled ? 1 : 0.5

    background: Item {
        x: control.leftPadding
        y: control.topPadding + (control.availableHeight - height) / 2
        width: control.availableWidth
        height: PanelBus.trackHeight

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, PanelBus.pill)
            color: control.ink > 0 ? control.base : Qt.alpha(PanelBus.textColor, 0.25)
            border.width: control.ink
            border.color: control.outline
        }

        Rectangle {
            width: Math.max(control.ink * 2, control.visualPosition * parent.width)
            height: parent.height
            radius: Math.min(height / 2, PanelBus.pill)
            color: control.palette.accent
            border.width: control.ink
            border.color: control.outline
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
            color: control.outline
        }

        Rectangle {
            id: knob

            anchors.fill: parent
            radius: Math.min(width / 2, PanelBus.pill)
            color: control.ink > 0 ? (control.pressed ? control.palette.accent : control.base)
                : Qt.tint(control.base, PanelBus.theme?.colors.control ?? "transparent")
            border.width: control.ink > 0 ? control.ink : 1
            border.color: control.ink > 0 ? control.outline : (PanelBus.theme?.colors.controlBorder ?? PanelBus.outline)

            // The accent dot of the thin look, which grows under the pointer and shrinks while dragged
            Rectangle {
                visible: control.ink === 0
                anchors.centerIn: parent
                width: control.pressed ? 10 : control.hovered ? 14 : 12
                height: width
                radius: Math.min(width / 2, PanelBus.pill)
                color: control.palette.accent

                Behavior on width {
                    NumberAnimation { duration: 100 }
                }
            }
        }
    }
}
