import QtQuick
import QtQuick.Controls

// A text-first button on the bar: any leading items (the default content), a glyph in the icon font and a label in
// the bar's font. A soft pill shows on hover; while its page is open the pill and text take the accent. `badge`
// adds a small count after the label.
Item {
    id: button

    property string glyph: ""
    // One of panel/Icon.qml's icons; a glyph that has one in PanelBus.glyphIcons is drawn as it too
    property string icon: ""
    readonly property string iconName: icon !== "" ? icon : (PanelBus.glyphIcons[glyph] ?? "")
    property int glyphSize: 14
    property string text: ""
    property bool open: false
    property int badge: 0
    property string tip: ""
    property color foreground: PanelBus.textColor
    // Dimmer label, for numbers that sit next to a brighter name
    property bool dim: false
    property int acceptedButtons: Qt.LeftButton
    property int padding: 8
    readonly property bool hovered: area.containsMouse
    readonly property color ink: open ? PanelBus.accent : foreground
    // The icon: in the accent unless the control center turns the bar's accent off
    readonly property color iconInk: open || (Qt.colorEqual(foreground, PanelBus.textColor) && PanelBus.barAccent !== "off") ? PanelBus.accent : foreground
    default property alias content: leading.data

    signal clicked(var mouse)
    signal wheel(var event)

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: 24
    Accessible.role: Accessible.Button
    Accessible.name: tip || text
    Accessible.onPressAction: clicked(null)

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 24
        radius: 12 * PanelBus.radiusScale
        color: button.open ? Qt.alpha(PanelBus.accent, 0.18)
            : PanelBus.barAccent === "tint" ? Qt.alpha(PanelBus.accent, area.containsMouse ? 0.22 : 0.12)
            : Qt.alpha(button.foreground, area.containsMouse ? 0.09 : 0)
        scale: area.pressed ? 0.94 : 1

        Behavior on color {
            ColorAnimation { duration: 180 }
        }
        Behavior on scale {
            NumberAnimation { duration: 100 }
        }
    }

    Row {
        id: row

        // On whole pixels, so the icons stay sharp
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        spacing: 6

        Row {
            id: leading

            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: children.length > 0
        }

        Icon {
            y: Math.round((parent.height - height) / 2)
            visible: button.iconName !== ""
            name: button.iconName
            size: Math.max(16, button.glyphSize)
            color: button.iconInk
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.glyph !== "" && button.iconName === ""
            text: button.glyph
            color: button.iconInk
            font.family: PanelBus.iconFont.family
            font.weight: PanelBus.iconFont.weight
            font.pixelSize: button.glyphSize

            Behavior on color {
                ColorAnimation { duration: 180 }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.text !== ""
            text: button.text
            textFormat: Text.PlainText
            color: button.dim && !button.open ? Qt.alpha(button.ink, 0.7) : button.ink
            font: PanelBus.font

            Behavior on color {
                ColorAnimation { duration: 180 }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: button.badge > 0
            width: Math.max(16, count.implicitWidth + 8)
            height: 16
            radius: 8 * PanelBus.radiusScale
            color: PanelBus.accent

            Text {
                id: count

                anchors.centerIn: parent
                text: button.badge > 99 ? "99+" : button.badge
                color: PanelBus.onAccent
                font.family: PanelBus.font.family
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: button.acceptedButtons
        onClicked: mouse => button.clicked(mouse)
        onWheel: event => button.wheel(event)
    }

    ToolTip.visible: area.containsMouse && !button.open && tip !== ""
    ToolTip.delay: 500
    ToolTip.text: tip
}
