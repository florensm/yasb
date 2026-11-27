import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Yasb
import "../../panel"

// The bell on the bar and the Notifications page in the panel: the notifications grouped by app, newest
// first. A click on a notification opens it; right click on the bell opens Windows' notification center. New ones
// are handed to the island (PanelBus.notified).
Item {
    id: notifications

    property Item bar: null
    // Hotkey that opens the page; "" for none
    property string keys: "ctrl+alt+b"
    property bool hideEmpty: false

    readonly property color foreground: PanelBus.textColor
    readonly property color secondary: PanelBus.textDim
    property font iconFont: PanelBus.iconFont
    property real now: Date.now()
    readonly property int count: center.notifications.length
    readonly property var groups: {
        const groups = []
        const byApp = new Map()
        for (const item of center.notifications) {
            const key = `${item.appId}|${item.appName}`
            let group = byApp.get(key)
            if (!group) {
                group = { appId: item.appId, appName: item.appName, icon: item.icon, items: [] }
                byApp.set(key, group)
                groups.push(group)
            }
            group.items.push(item)
        }
        return groups
    }

    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("notifications") ?? false

    function age(time: real): string {
        const seconds = Math.max(0, (now - time) / 1000)
        if (seconds < 60) return "now"
        if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
        if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
        return `${Math.floor(seconds / 86400)}d`
    }

    function toggle() {
        panelHost?.toggle("notifications", notifications)
    }

    readonly property bool shown: !hideEmpty || count > 0

    implicitWidth: shown ? bell.implicitWidth : 0
    implicitHeight: shown ? bell.implicitHeight : 0
    visible: shown

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("notifications", page, notifications)
        }
    }
    Component.onCompleted: PanelBus.register("notifications", keys)
    Component.onDestruction: panelHost?.withdraw("notifications", notifications)

    // The newest notification's time once the list has been read, so only ones that come in later are announced
    property real newestSeen: -1

    NotificationCenter {
        id: center

        onNotificationsChanged: {
            const newest = center.notifications.reduce((most, item) => Math.max(most, item.time ?? 0), 0)
            if (notifications.newestSeen >= 0) {
                const fresh = center.notifications.filter(item => (item.time ?? 0) > notifications.newestSeen)
                if (fresh.length > 0 && !center.doNotDisturb)
                    PanelBus.notified(fresh[0])
            }
            notifications.newestSeen = Math.max(notifications.newestSeen, newest)
        }
    }

    Hotkey {
        keys: notifications.keys
        onActivated: notifications.toggle()
    }

    Timer {
        interval: 30000
        repeat: true
        running: notifications.panelOpen
        onTriggered: notifications.now = Date.now()
    }

    BarButton {
        id: bell

        anchors.centerIn: parent
        glyph: center.doNotDisturb ? "\ue7ed" : "\uea8f"
        open: notifications.panelOpen
        badge: notifications.count
        tip: `Notifications (${PanelBus.label(notifications.keys)}) · right click for Windows' notification center`
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse && mouse.button === Qt.RightButton)
                center.openNotificationCenter()
            else
                notifications.toggle()
        }
    }

    component IconButton: Item {
        id: button

        property string glyph
        property int iconSize: 14
        property bool checked: false
        property string tip

        signal clicked

        implicitWidth: iconSize + 16
        implicitHeight: iconSize + 16
        opacity: enabled ? 1 : 0.4
        Accessible.role: Accessible.Button
        Accessible.name: tip
        Accessible.onPressAction: button.clicked()
        ToolTip.visible: area.containsMouse && tip !== ""
        ToolTip.delay: 500
        ToolTip.text: tip

        Rectangle {
            anchors.fill: parent
            radius: 8 * PanelBus.radiusScale
            color: button.checked ? Qt.alpha(PanelBus.accent, 0.2) : Qt.alpha(notifications.foreground, area.containsMouse ? 0.08 : 0)
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            color: button.checked ? PanelBus.accent : notifications.foreground
            opacity: button.checked || area.containsMouse ? 1 : 0.7
            font.family: notifications.iconFont.family
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

    // ---------- The page ----------

    property Item page: Item {
        id: pageView

        function panelShown(fresh) {
            notifications.now = Date.now()
            center.refresh()
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: notifications.count === 0 ? "Nothing new" : notifications.count === 1 ? "1 notification" : `${notifications.count} notifications`
                    color: notifications.secondary
                    font.family: PanelBus.font.family
                    font.pixelSize: 12
                }
                IconButton {
                    visible: center.doNotDisturbAvailable
                    glyph: ""
                    checked: center.doNotDisturb
                    tip: center.doNotDisturb ? "Do not disturb is on" : "Do not disturb"
                    onClicked: center.setDoNotDisturb(!center.doNotDisturb)
                }
                IconButton {
                    glyph: ""
                    enabled: notifications.count > 0
                    tip: "Clear all"
                    onClicked: center.clearAll()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    spacing: 12
                    visible: notifications.groups.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ""
                        color: Qt.alpha(notifications.secondary, 0.6)
                        font.family: notifications.iconFont.family
                        font.pixelSize: 34
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: center.allowed ? "No new notifications"
                            : "Notification access is turned off in Windows privacy settings"
                        color: notifications.secondary
                        font.family: PanelBus.font.family
                        font.pixelSize: 13
                    }
                }

                Flickable {
                    id: list

                    anchors.fill: parent
                    visible: notifications.groups.length > 0
                    contentHeight: column.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    Column {
                        id: column

                        width: list.width
                        spacing: 16

                        Repeater {
                            model: notifications.groups

                            delegate: Column {
                                id: group

                                required property var modelData

                                width: column.width
                                spacing: 6

                                RowLayout {
                                    width: parent.width
                                    spacing: 8

                                    Image {
                                        Layout.leftMargin: 2
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        visible: group.modelData.icon !== ""
                                        source: group.modelData.icon
                                        sourceSize: Qt.size(32, 32)
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: group.modelData.appName
                                        textFormat: Text.PlainText
                                        color: notifications.secondary
                                        font.family: PanelBus.font.family
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    IconButton {
                                        visible: group.modelData.appId !== ""
                                        glyph: ""
                                        iconSize: 10
                                        tip: `Clear ${group.modelData.appName}`
                                        onClicked: center.clearApp(group.modelData.appId)
                                    }
                                }

                                Repeater {
                                    model: group.modelData.items

                                    delegate: Rectangle {
                                        id: card

                                        required property var modelData

                                        width: group.width
                                        height: body.implicitHeight + 24
                                        radius: 12 * PanelBus.radiusScale
                                        color: hover.hovered ? PanelBus.raised : PanelBus.surface
                                        border.width: PanelBus.cardBorderWidth
                                        border.color: PanelBus.outline
                                        Accessible.role: Accessible.Button
                                        Accessible.name: `${modelData.title}. ${modelData.body}`
                                        Accessible.onPressAction: {
                                            center.activate(modelData.id)
                                            notifications.panelHost?.hide()
                                        }

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        HoverHandler {
                                            id: hover
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                center.activate(card.modelData.id)
                                                notifications.panelHost?.hide()
                                            }
                                        }

                                        ColumnLayout {
                                            id: body

                                            x: 12
                                            y: 12
                                            width: parent.width - 24
                                            spacing: 8

                                            Image {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: Math.round(width / 2)
                                                visible: card.modelData.hero !== ""
                                                source: card.modelData.hero
                                                sourceSize.width: width * 2
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                clip: true
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                Item {
                                                    Layout.preferredWidth: 36
                                                    Layout.preferredHeight: 36
                                                    Layout.alignment: Qt.AlignTop
                                                    visible: card.modelData.logo !== ""

                                                    Image {
                                                        id: logo

                                                        anchors.fill: parent
                                                        visible: !card.modelData.logoCircle
                                                        source: card.modelData.logo
                                                        sourceSize: Qt.size(72, 72)
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }
                                                    MultiEffect {
                                                        anchors.fill: parent
                                                        visible: card.modelData.logoCircle
                                                        source: logo
                                                        maskEnabled: true
                                                        maskSource: circle
                                                    }
                                                    Rectangle {
                                                        id: circle

                                                        anchors.fill: parent
                                                        radius: Math.min(width / 2, PanelBus.pill)
                                                        visible: false
                                                        layer.enabled: true
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 6

                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: card.modelData.title
                                                            textFormat: Text.PlainText
                                                            color: notifications.foreground
                                                            font.family: PanelBus.font.family
                                                            font.pixelSize: 13
                                                            font.weight: Font.DemiBold
                                                            elide: Text.ElideRight
                                                        }
                                                        Item {
                                                            Layout.preferredWidth: 24
                                                            Layout.preferredHeight: 20

                                                            Text {
                                                                anchors.right: parent.right
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                visible: !hover.hovered
                                                                text: notifications.age(card.modelData.time)
                                                                color: notifications.secondary
                                                                font.family: PanelBus.font.family
                                                                font.pixelSize: 11
                                                            }
                                                            IconButton {
                                                                anchors.centerIn: parent
                                                                implicitWidth: 22
                                                                implicitHeight: 22
                                                                visible: hover.hovered
                                                                glyph: ""
                                                                iconSize: 10
                                                                tip: "Dismiss"
                                                                onClicked: center.dismiss(card.modelData.id)
                                                            }
                                                        }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: text !== ""
                                                        text: card.modelData.body
                                                        textFormat: Text.PlainText
                                                        color: Qt.alpha(notifications.foreground, 0.85)
                                                        font.family: PanelBus.font.family
                                                        font.pixelSize: 12
                                                        lineHeight: 1.15
                                                        wrapMode: Text.Wrap
                                                        maximumLineCount: 5
                                                        elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: text !== ""
                                                        text: card.modelData.attribution
                                                        textFormat: Text.PlainText
                                                        color: notifications.secondary
                                                        font.family: PanelBus.font.family
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            Image {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: Math.min(180, implicitHeight * width / Math.max(1, implicitWidth))
                                                visible: card.modelData.image !== ""
                                                source: card.modelData.image
                                                sourceSize.width: width * 2
                                                fillMode: Image.PreserveAspectFit
                                                horizontalAlignment: Image.AlignLeft
                                                asynchronous: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 10 * PanelBus.radiusScale
                color: footerArea.containsMouse ? PanelBus.raised : PanelBus.surface

                border.width: PanelBus.cardBorderWidth
                border.color: PanelBus.outline
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Open Windows' notification center"
                    color: footerArea.containsMouse ? notifications.foreground : notifications.secondary
                    font.family: PanelBus.font.family
                    font.pixelSize: 12
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: notifications.secondary
                    font.family: notifications.iconFont.family
                    font.pixelSize: 10
                }
                MouseArea {
                    id: footerArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        center.openNotificationCenter()
                        notifications.panelHost?.hide()
                    }
                }
            }
        }
    }
}
