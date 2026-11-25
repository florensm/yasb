import QtQuick
import Yasb.Themes

// A link along the bottom of a popup, such as "Sound settings": the secondary background, the divider above it and
// an arrow on the right. It opens `url` and then sends activated(), so the popup can close.
Rectangle {
    id: footer

    required property Theme theme
    property string text
    property string url
    property font font: theme.type.caption
    // The popup's corner radius, so the fill follows the popup's bottom corners
    property real popupRadius: theme.popup.radius
    // The arrow on the right, in the theme's popup icon font unless set here
    property string arrow: "\ue76c"
    property font arrowFont
    arrowFont.family: theme.popup.iconFont.family
    arrowFont.weight: theme.popup.iconFont.weight
    arrowFont.variableAxes: theme.popup.iconFont.variableAxes
    property int arrowSize: 10
    readonly property bool hovered: area.containsMouse

    signal activated

    implicitHeight: 40
    bottomLeftRadius: Math.max(0, popupRadius - theme.popup.borderWidth)
    bottomRightRadius: Math.max(0, popupRadius - theme.popup.borderWidth)
    color: hovered ? Qt.tint(theme.colors.backgroundSecondary, theme.colors.hover) : theme.colors.backgroundSecondary
    Accessible.role: Accessible.Link
    Accessible.name: text
    Accessible.onPressAction: footer.open()

    function open() {
        if (url !== "")
            Qt.openUrlExternally(url)
        activated()
    }

    Rectangle {
        width: parent.width
        height: footer.theme.popup.dividerWidth
        color: footer.theme.colors.divider
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        text: footer.text
        textFormat: Text.PlainText
        color: footer.hovered ? footer.theme.colors.text : footer.theme.colors.textSecondary
        font: footer.font
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: footer.arrow
        color: footer.theme.colors.text
        opacity: footer.hovered ? 1 : 0.75
        font.family: footer.arrowFont.family
        font.weight: footer.arrowFont.weight
        font.variableAxes: footer.arrowFont.variableAxes
        font.pixelSize: footer.arrowSize
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: footer.open()
    }
}
