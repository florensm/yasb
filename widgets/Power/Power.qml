import QtQuick
import Yasb.Widgets as Builtin
import "../../panel"

// yasb's PowerMenu with the same hover pill as the other bar buttons (panel/BarButton.qml). The built-in widget is
// only as big as its 16 px icon.
Item {
    id: power

    property Item bar: null
    property int cellSize: 30
    readonly property color textColor: bar?.theme.colors.text ?? "#ffffff"

    implicitWidth: cellSize
    implicitHeight: 24
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Power menu")
    Accessible.onPressAction: menu.open()

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 24
        radius: 12 * PanelBus.radiusScale
        color: Qt.alpha(power.textColor, area.containsMouse ? 0.1 : 0)
        scale: area.pressed ? 0.88 : 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation { duration: 100 }
        }
    }

    Builtin.PowerMenu {
        id: menu

        anchors.centerIn: parent
        bar: power.bar
        // This setup draws its own icon below, so the built-in glyph stays empty (yasb keeps the widget's options in
        // `settings` since 2fead96)
        settings.icon: ""
    }

    Icon {
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        name: "power"
        size: 16
        color: power.textColor
    }

    // The whole cell opens the menu, not only the icon
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.open()
    }
}
