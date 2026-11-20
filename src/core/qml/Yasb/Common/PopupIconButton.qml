import QtQuick
import QtQuick.Controls
import Yasb.Themes

// A glyph button in a popup, such as the arrow that opens a list. It is filled under the pointer and while checked,
// and outlined the theme's way.
Item {
    id: button

    required property Theme theme
    property string glyph
    property int iconSize: 14
    property bool checked: false
    property string tip
    property color color: theme.colors.text
    // The theme's icon font, each part unless set here
    property font iconFont
    iconFont.family: theme.bar.iconFont.family
    iconFont.weight: theme.bar.iconFont.weight
    iconFont.variableAxes: theme.bar.iconFont.variableAxes
    readonly property bool hovered: area.containsMouse

    signal clicked

    implicitWidth: iconSize + 12
    implicitHeight: iconSize + 12
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.onPressAction: button.clicked()
    ToolTip.visible: area.containsMouse && tip !== ""
    ToolTip.delay: 500
    ToolTip.text: tip

    Rectangle {
        anchors.fill: parent
        radius: button.theme.radius.sm
        color: button.hovered ? button.theme.colors.hover : button.checked ? button.theme.colors.selected : "transparent"
        border.width: button.hovered || button.checked ? button.theme.popup.selectedBorderWidth : 0
        border.color: button.theme.popup.border
    }

    Text {
        anchors.centerIn: parent
        text: button.glyph
        // On the selected fill, the theme's text for it
        color: button.checked && !button.hovered ? button.theme.colors.selectedText : button.color
        opacity: button.checked || button.hovered ? 1 : 0.6
        font.family: button.iconFont.family
        font.weight: button.iconFont.weight
        font.variableAxes: button.iconFont.variableAxes
        font.pixelSize: button.iconSize
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
