import QtQuick
import QtQuick.Templates as T

// An on/off switch in this setup's shape: a thin pill, or an outlined block with a hard shadow in a theme whose
// tokens set controlBorderWidth and controlShadowOffset. On, it fills with the palette's accent.
T.Switch {
    id: control

    readonly property real ink: PanelBus.controlBorderWidth
    readonly property real shadow: PanelBus.controlShadowOffset
    readonly property color outline: PanelBus.theme?.popup.border ?? PanelBus.outline
    readonly property color base: PanelBus.theme?.colors.background ?? PanelBus.color

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
            color: control.outline
        }

        Rectangle {
            id: track

            anchors.fill: parent
            radius: Math.min(height / 2, PanelBus.pill)
            color: control.checked ? control.palette.accent : control.ink > 0 ? control.base : "transparent"
            border.width: control.ink > 0 ? control.ink : control.checked ? 0 : 1
            border.color: control.ink > 0 ? control.outline : PanelBus.textDim

            Rectangle {
                readonly property real inset: control.ink > 0 ? control.ink + 2 : 4

                x: control.checked ? parent.width - width - inset : inset
                anchors.verticalCenter: parent.verticalCenter
                width: control.ink > 0 ? parent.height - 2 * inset : 12
                height: width
                radius: Math.min(width / 2, PanelBus.pill)
                color: control.checked ? PanelBus.onAccent : control.ink > 0 ? control.outline : PanelBus.textDim

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
        color: PanelBus.textColor
        font: control.font
        verticalAlignment: Text.AlignVCenter
    }
}
