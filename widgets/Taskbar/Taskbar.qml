pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtWebSockets
import "../../panel"

// Windows managed by GlazeWM, read from its IPC server. Left click focuses a window, or minimizes it when it
// already has focus; middle click closes it.
Item {
    id: taskbar

    property string serverUri: "ws://localhost:6123"
    // "workspace": windows on the workspace this bar's monitor shows. "monitor": all of that monitor's
    // workspaces. "all": every window.
    property string scope: "workspace"
    property int iconSize: 20
    property bool showTitles: false
    property int titleWidth: 120
    property color accentColor: PanelBus.accent
    property color urgentColor: PanelBus.accent2
    // Milliseconds for buttons coming, going and moving; 0 turns them off.
    property int animationDuration: 200
    property Item bar: null

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property color textColor: bar?.theme.colors.text ?? (dark ? "#ffffff" : "#000000")
    readonly property bool vertical: bar?.vertical ?? false
    readonly property int buttonSize: iconSize + 12

    function send(message: string): void {
        if (socket.status === WebSocket.Open)
            socket.sendTextMessage(message)
    }

    function collect(container: var, into: var): var {
        for (const child of container.children ?? []) {
            if (child.type === "window") {
                into.push({
                    windowId: child.id,
                    hwnd: child.handle ?? 0,
                    title: child.title || child.processName || "",
                    focused: child.hasFocus === true,
                    minimized: child.state?.type === "minimized",
                    urgent: child.isUrgent === true
                })
            } else {
                collect(child, into)
            }
        }
        return into
    }

    // GlazeWM gives monitor positions in physical pixels; Qt keeps a screen's top-left in them too.
    function ownMonitor(monitors: var): var {
        const screen = taskbar.Screen
        return monitors.find(monitor => monitor.x === screen.virtualX && monitor.y === screen.virtualY)
            ?? monitors.find(monitor => monitor.hasFocus) ?? monitors[0]
    }

    function rowsOf(monitors: var): var {
        if (scope === "all")
            return monitors.flatMap(monitor => collect(monitor, []))
        const monitor = ownMonitor(monitors)
        if (!monitor)
            return []
        if (scope === "monitor")
            return collect(monitor, [])
        const shown = (monitor.children ?? []).find(workspace => workspace.isDisplayed)
        return shown ? collect(shown, []) : []
    }

    // Updates the model in place, keyed by window id, so buttons animate instead of being rebuilt.
    function sync(rows: var): void {
        const wanted = new Set(rows.map(row => row.windowId))
        for (let index = windows.count - 1; index >= 0; --index) {
            if (!wanted.has(windows.get(index).windowId))
                windows.remove(index)
        }
        rows.forEach((row, index) => {
            let at = -1
            for (let other = index; other < windows.count; ++other) {
                if (windows.get(other).windowId === row.windowId) {
                    at = other
                    break
                }
            }
            if (at === -1) {
                windows.insert(index, row)
                return
            }
            if (at !== index)
                windows.move(at, index, 1)
            windows.set(index, row)
        })
    }

    function receive(message: string): void {
        let response
        try {
            response = JSON.parse(message)
        } catch (error) {
            return
        }
        if (response.messageType === "event_subscription") {
            refresh.restart()
            return
        }
        if (response.messageType !== "client_response" || response.clientMessage !== "query monitors")
            return
        if (response.success === false) {
            console.warn(`Taskbar: GlazeWM query failed: ${response.error}`)
            return
        }
        sync(rowsOf(response.data?.monitors ?? []))
    }

    function activate(window: var): void {
        if (window.minimized) {
            send(`command --id ${window.windowId} toggle-minimized`)
            send(`command focus --container-id ${window.windowId}`)
        } else if (window.focused) {
            send(`command --id ${window.windowId} toggle-minimized`)
        } else {
            send(`command focus --container-id ${window.windowId}`)
        }
    }

    // On the strip: room and a thin line between the workspaces above and the windows
    readonly property int lead: vertical ? 22 : 0

    implicitWidth: windows.count === 0 ? 0 : vertical ? buttonSize : list.contentWidth
    implicitHeight: windows.count === 0 ? 0 : vertical ? list.contentHeight + lead : buttonSize
    visible: windows.count > 0
    onScopeChanged: refresh.restart()

    ListModel {
        id: windows
    }

    WebSocket {
        id: socket

        url: taskbar.serverUri
        active: true
        onStatusChanged: {
            if (socket.status === WebSocket.Open) {
                // One query per burst of events, as GlazeWM sends several for one change.
                taskbar.send("sub -e all")
                refresh.restart()
            } else if (socket.status === WebSocket.Closed || socket.status === WebSocket.Error) {
                windows.clear()
                reconnect.start()
            }
        }
        onTextMessageReceived: message => taskbar.receive(message)
    }

    Timer {
        id: refresh

        interval: 40
        onTriggered: taskbar.send("query monitors")
    }

    // GlazeWM may start after YASB or restart.
    Timer {
        id: reconnect

        interval: 3000
        onTriggered: {
            socket.active = false
            socket.active = true
        }
    }

    Rectangle {
        visible: taskbar.lead > 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(taskbar.lead / 2) - 1
        width: 18
        height: 1
        radius: 0.5 * PanelBus.radiusScale
        color: Qt.alpha(taskbar.textColor, 0.16)
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: taskbar.lead
        orientation: taskbar.vertical ? ListView.Vertical : ListView.Horizontal
        interactive: false
        spacing: taskbar.vertical ? 4 : 2
        model: windows

        add: Transition {
            enabled: taskbar.animationDuration > 0
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: taskbar.animationDuration }
            NumberAnimation { property: "scale"; from: 0.6; to: 1; duration: taskbar.animationDuration; easing.type: Easing.OutBack }
        }
        remove: Transition {
            enabled: taskbar.animationDuration > 0
            NumberAnimation { property: "opacity"; to: 0; duration: taskbar.animationDuration }
            NumberAnimation { property: "scale"; to: 0.6; duration: taskbar.animationDuration }
        }
        displaced: Transition {
            enabled: taskbar.animationDuration > 0
            NumberAnimation { properties: "x,y"; duration: taskbar.animationDuration; easing.type: Easing.OutCubic }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: taskbar.animationDuration }
        }
        move: Transition {
            enabled: taskbar.animationDuration > 0
            NumberAnimation { properties: "x,y"; duration: taskbar.animationDuration; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: button

            required property int index
            required property string windowId
            required property real hwnd
            required property string title
            required property bool focused
            required property bool minimized
            required property bool urgent
            // Asks for the icon again a few times, as YASB loads it in the background and first hands out a blank.
            property int revision: 0

            width: taskbar.vertical ? list.width : content.implicitWidth + 12
            height: taskbar.buttonSize
            Accessible.role: Accessible.Button
            Accessible.name: title

            Timer {
                interval: 400 * (button.revision + 1)
                running: button.revision < 3
                onTriggered: ++button.revision
            }

            Rectangle {
                anchors.centerIn: parent
                width: taskbar.vertical ? taskbar.buttonSize : parent.width - 2
                height: parent.height - 2
                radius: 8 * PanelBus.radiusScale
                color: area.containsMouse ? Qt.alpha(taskbar.textColor, 0.1)
                    : button.focused ? Qt.alpha(taskbar.accentColor, 0.12) : Qt.alpha(taskbar.textColor, 0)

                Behavior on color {
                    ColorAnimation { duration: taskbar.animationDuration }
                }
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: 6
                opacity: button.minimized ? 0.45 : 1
                scale: area.pressed ? 0.88 : 1

                Behavior on opacity {
                    NumberAnimation { duration: taskbar.animationDuration }
                }
                Behavior on scale {
                    NumberAnimation { duration: taskbar.animationDuration / 2; easing.type: Easing.OutCubic }
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: taskbar.iconSize
                    height: taskbar.iconSize
                    sourceSize: Qt.size(taskbar.iconSize * Screen.devicePixelRatio, taskbar.iconSize * Screen.devicePixelRatio)
                    source: `image://icon/window/${button.hwnd}/${button.revision}`
                    smooth: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: taskbar.showTitles && !taskbar.vertical
                    width: Math.min(implicitWidth, taskbar.titleWidth)
                    text: button.title
                    elide: Text.ElideRight
                    color: taskbar.textColor
                    font.family: taskbar.bar?.theme.bar.font.family ?? Qt.application.font.family
                    font.pixelSize: taskbar.bar?.theme.bar.font.pixelSize ?? 12
                }
            }

            // Focus indicator along the bar's inner edge: a wide pill for the focused window, a dot for the rest.
            Rectangle {
                id: indicator

                readonly property real length: button.focused ? 14 : 4

                x: taskbar.vertical ? 0 : (parent.width - width) / 2
                y: taskbar.vertical ? (parent.height - height) / 2 : parent.height - height
                width: taskbar.vertical ? 3 : length
                height: taskbar.vertical ? length : 3
                radius: 1.5 * PanelBus.radiusScale
                color: button.urgent ? taskbar.urgentColor : button.focused ? taskbar.accentColor : Qt.alpha(taskbar.textColor, 0.45)

                Behavior on width {
                    NumberAnimation { duration: taskbar.animationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on height {
                    NumberAnimation { duration: taskbar.animationDuration; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: taskbar.animationDuration }
                }

                SequentialAnimation on opacity {
                    running: button.urgent
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        taskbar.send(`command --id ${button.windowId} close`)
                    else
                        taskbar.activate(button)
                }
            }

            ToolTip.visible: area.containsMouse && !taskbar.showTitles
            ToolTip.delay: 500
            ToolTip.text: title
        }
    }
}
