import QtQuick
import QtQuick.Layouts
import Yasb.Themes

// A popup's title bar: the title on the theme's header fill, the items given to it on the right, and the line under
// it. It goes at the top of the popup's content, inside the popup's outline.
Rectangle {
    id: header

    required property Theme theme
    property string title
    property font font: theme.type.heading
    // Text and icons in the header; items given to the header can use it too
    property color textColor: theme.popup.headerText
    // The popup's corner radius, so the fill follows the popup's top corners
    property real popupRadius: theme.popup.radius
    property real leftPadding: 16
    property real rightPadding: 10
    property real topPadding: 12
    property real bottomPadding: 10
    default property alias actions: actions.data

    implicitHeight: topPadding + Math.max(titleText.implicitHeight, actions.implicitHeight) + bottomPadding + divider.height
    color: theme.popup.headerBackground
    topLeftRadius: Math.max(0, popupRadius - theme.popup.borderWidth)
    topRightRadius: Math.max(0, popupRadius - theme.popup.borderWidth)

    RowLayout {
        x: header.leftPadding
        y: header.topPadding
        width: header.width - header.leftPadding - header.rightPadding
        height: header.height - header.topPadding - header.bottomPadding - divider.height
        spacing: 2

        Text {
            id: titleText
            objectName: "title"
            Layout.fillWidth: true
            text: header.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: header.textColor
            font: header.font
        }

        RowLayout {
            id: actions
            spacing: 2
        }
    }

    Rectangle {
        id: divider
        anchors.bottom: parent.bottom
        width: parent.width
        height: header.theme.popup.dividerWidth
        color: header.theme.colors.divider
    }
}
