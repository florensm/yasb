import QtQuick
import "../../panel"

// A dim "//" between groups of widgets.
Text {
    property Item bar: null
    property string mark: "//"

    text: mark
    textFormat: Text.PlainText
    color: Qt.alpha(PanelBus.textDim, 0.6)
    font: PanelBus.font
    leftPadding: 4
    rightPadding: 4
    verticalAlignment: Text.AlignVCenter
}
