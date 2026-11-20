import QtQuick
import Yasb.Themes

// The fill behind a row in a popup's list, such as an output device or a network: the selected fill and outline for
// the current one, the hover fill under the pointer. Text on it takes textColor and secondaryTextColor.
Rectangle {
    id: row

    required property Theme theme
    property bool selected: false
    property bool hovered: false
    readonly property color textColor: selected ? theme.colors.selectedText : theme.colors.text
    readonly property color secondaryTextColor: selected ? theme.colors.selectedText : theme.colors.textSecondary

    radius: theme.radius.sm
    color: selected ? theme.colors.selected : hovered ? theme.colors.hover : "transparent"
    border.width: selected ? theme.popup.selectedBorderWidth : 0
    border.color: theme.popup.border
}
