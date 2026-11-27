pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtWebSockets
import Yasb
import Yasb.Common
import "../../panel"

// Every GlazeWM workspace on this monitor side by side, each a small screen with its windows where GlazeWM put them,
// live: DWM draws each window into its place, the way Windows' Task View does, so nothing is captured or kept.
//
//   Click a window        go to it (its workspace, then the window)
//   Click a workspace     go to that workspace
//   Drag a window         onto another workspace, to move it there
//   Middle click          closes the window
//   Arrows, Tab, Enter    pick a workspace and go there; 1 to 9 go straight to that one; Esc closes
//
// It stays open while other windows take the focus, as after closing or moving one; Esc, its hotkey, its button or a
// click beside the cards closes it. Opening, the workspace on screen shrinks from full size into its card; going
// somewhere, that card grows back to full size over the real one, so the switch looks like zooming in.
//
// Windows GlazeWM hides with `hide_method: hide` rather than cloaking show no picture: their icon and title stand in.
Item {
    id: overview

    property Item bar: null
    property string serverUri: "ws://localhost:6123"
    // Alt+Shift+`; Alt+` is the window walker in Search
    property string hotkey: "alt+shift+grave"
    // active, cursor or primary: which screen's widget opens on the hotkey
    property string hotkeyScreen: "active"
    // Every monitor's workspaces instead of only this one's
    property bool allMonitors: false
    property bool showEmptyWorkspaces: true
    // false draws each window as its icon and title instead of a live picture
    property bool livePreviews: true
    // The wallpaper behind each workspace's windows
    property bool showWallpaper: true
    property int maxColumns: 4
    // Writes each window's place (GlazeWM's) and its picture's size (DWM's) to YASB's log as the overview opens,
    // lines starting with "Overview:", to see why a picture doesn't line up with its window
    property bool logGeometry: true
    // The zoom in and out, in milliseconds
    property int openDuration: 380
    property int closeDuration: 320
    // How long windows take to slide when one moves, closes or arrives
    property int glideDuration: 240

    readonly property bool connected: socket.status === WebSocket.Open
    // [{ name, label, focused, displayed, monitor: {x, y, width, height}, windows: [...], minimized: [...], count }]
    property var cards: []
    property int selected: 0
    // You moved the selection since opening, so fresh data from GlazeWM doesn't move it back
    property bool touched: false
    readonly property bool opened: popup.visible && !popup.closing
    // 0 closed, 1 open
    property real reveal: 0
    // The card that grows to full screen as the overview closes: the one you picked, else the one on screen
    property int zoomTarget: -1
    readonly property int homeCard: Math.max(0, cards.findIndex(card => card.displayed && (allMonitors ? card.focused : true)))
    readonly property int zoomCard: zoomTarget >= 0 ? zoomTarget : homeCard
    // The window being dragged, the card under it, and where the pointer is in the overlay
    property var dragging: null
    property int dropTarget: -1
    property point dragPoint: Qt.point(0, 0)
    property real pendingKeyboard: 0

    readonly property var icons: {
        const map = {}
        for (const window of windowList.windows ?? [])
            map[window.hwnd] = window.icon
        return map
    }
    function iconOf(hwnd: real): string {
        return hwnd ? (icons[hwnd] ?? `image://icon/window/${hwnd}/0`) : ""
    }
    readonly property string wallpaperUrl: {
        const path = WallpaperColors.wallpaperPath ?? ""
        if (!showWallpaper || path === "")
            return ""
        return /^[a-z]+:\/\//i.test(path) ? path : "file:///" + path.replace(/\\/g, "/")
    }

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    function send(message: string) {
        if (connected)
            socket.sendTextMessage(message)
    }

    function toggle() {
        if (popup.visible && !popup.closing)
            popup.close()
        else
            open()
    }

    function open() {
        if (!bar)
            return
        PanelBus.hostFor(bar).hide()
        const screen = overview.Screen
        popup.x = screen.virtualX
        popup.y = screen.virtualY + PanelBus.barHeight
        popup.width = screen.width
        popup.height = screen.height - PanelBus.barHeight
        touched = false
        dragging = null
        zoomTarget = -1
        selected = Math.max(0, cards.findIndex(card => card.focused || card.displayed))
        popup.open()
        if (logGeometry)
            console.log(`Overview: screen ${screen.width}x${screen.height} at ${screen.virtualX},${screen.virtualY}, scale ${screen.devicePixelRatio}, `
                        + `overlay ${popup.width}x${popup.height} at ${popup.x},${popup.y}, bar ${PanelBus.barHeight}, monitor `
                        + JSON.stringify(cards[0]?.monitor ?? null))
        windowList.takeFocus(popup.window)
        keys.forceActiveFocus()
        send("query monitors")
    }

    // ---- GlazeWM's tree into cards

    function naturalCompare(a: string, b: string): int {
        const split = name => String(name).split(/(\d+)/).map(part => /^\d+$/.test(part) ? Number(part) : part.toLowerCase())
        const left = split(a)
        const right = split(b)
        for (let i = 0; i < Math.min(left.length, right.length); i++) {
            if (left[i] === right[i])
                continue
            if (typeof left[i] === typeof right[i])
                return left[i] < right[i] ? -1 : 1
            return typeof left[i] === "number" ? -1 : 1
        }
        return left.length - right.length
    }

    function collect(container: var, into: var): var {
        for (const child of container?.children ?? []) {
            if (child.type === "window")
                into.push(child)
            else
                collect(child, into)
        }
        return into
    }

    // GlazeWM gives monitor positions in physical pixels; Qt keeps a screen's top-left in them too
    function ownMonitor(monitors: var): var {
        const screen = overview.Screen
        return monitors.find(monitor => monitor.x === screen.virtualX && monitor.y === screen.virtualY)
            ?? monitors.find(monitor => monitor.hasFocus) ?? monitors[0]
    }

    function readMonitors(monitors: var) {
        const own = ownMonitor(monitors)
        const layer = { tiling: 0, floating: 1, fullscreen: 2 }
        const list = []
        for (const monitor of monitors) {
            if (!allMonitors && monitor !== own)
                continue
            const geometry = { x: monitor.x ?? 0, y: monitor.y ?? 0, width: monitor.width || 1920, height: monitor.height || 1080 }
            for (const workspace of monitor.children ?? []) {
                if (workspace.type !== "workspace")
                    continue
                const all = collect(workspace, []).map(window => ({
                    id: window.id,
                    hwnd: window.handle ?? 0,
                    title: window.title || String(window.processName ?? "").replace(/\.exe$/i, ""),
                    state: window.state?.type ?? "tiling",
                    focused: window.hasFocus === true,
                    x: (window.x ?? geometry.x) - geometry.x,
                    y: (window.y ?? geometry.y) - geometry.y,
                    width: window.width ?? 0,
                    height: window.height ?? 0
                }))
                const shown = all.filter(window => window.state !== "minimized" && window.width > 0 && window.height > 0)
                shown.sort((a, b) => (layer[a.state] ?? 1) - (layer[b.state] ?? 1))
                if (!showEmptyWorkspaces && all.length === 0 && !workspace.hasFocus && !workspace.isDisplayed)
                    continue
                list.push({
                    name: String(workspace.name ?? ""),
                    label: workspace.displayName && workspace.displayName !== workspace.name ? String(workspace.displayName) : "",
                    focused: workspace.hasFocus === true,
                    displayed: workspace.isDisplayed === true,
                    monitor: geometry,
                    windows: shown,
                    minimized: all.filter(window => window.state === "minimized"),
                    count: all.length
                })
            }
        }
        list.sort((a, b) => naturalCompare(a.name, b.name))
        cards = list
        if (!touched)
            selected = Math.max(0, list.findIndex(card => card.focused || card.displayed))
        selected = Math.min(selected, Math.max(0, list.length - 1))
    }

    // ---- What clicks and keys do

    function goToWorkspace(card: var) {
        if (!card)
            return
        zoomTarget = cards.indexOf(card)
        popup.close()
        send(`command focus --workspace ${card.name}`)
    }

    function goToWindow(card: var, window: var) {
        zoomTarget = cards.indexOf(card)
        popup.close()
        if (!connected) {
            windowList.switchTo(window.hwnd)
            return
        }
        if (window.state === "minimized")
            send(`command --id ${window.id} toggle-minimized`)
        if (!card.focused)
            send(`command focus --workspace ${card.name}`)
        send(`command focus --container-id ${window.id}`)
        // GlazeWM shows and focuses it, but Windows may leave the keyboard where it was
        pendingKeyboard = window.hwnd
        keyboardFocus.restart()
    }

    function closeWindow(window: var) {
        if (connected)
            send(`command --id ${window.id} close`)
        else
            windowList.close(window.hwnd)
        refocus.restart()
    }

    function moveWindow(window: var, card: var) {
        if (card && connected)
            send(`command --id ${window.id} move --workspace ${card.name}`)
        refocus.restart()
    }

    function step(delta: int) {
        if (cards.length === 0)
            return
        selected = Math.max(0, Math.min(cards.length - 1, selected + delta))
        touched = true
    }

    // The card under a point in the overlay, or -1
    function cardAt(point: point): int {
        for (let index = 0; index < grid.count; index++) {
            const card = grid.itemAt(index)
            if (card && card.contains(card.mapFromItem(stage, point.x, point.y)))
                return index
        }
        return -1
    }

    // ---- Services

    WindowList {
        id: windowList
    }

    WebSocket {
        id: socket

        url: overview.serverUri
        active: true
        onStatusChanged: {
            if (socket.status === WebSocket.Open) {
                socket.sendTextMessage("sub -e all")
                if (popup.visible)
                    refresh.restart()
            } else if (socket.status === WebSocket.Closed || socket.status === WebSocket.Error) {
                overview.cards = []
                reconnect.start()
            }
        }
        onTextMessageReceived: message => {
            let response
            try {
                response = JSON.parse(message)
            } catch (error) {
                return
            }
            if (response.messageType === "event_subscription") {
                // Only asked for while the overview shows, and again on opening
                if (popup.visible)
                    refresh.restart()
                return
            }
            if (response.messageType !== "client_response")
                return
            if (response.success === false) {
                console.warn(`Overview: GlazeWM said no to "${response.clientMessage}": ${response.error}`)
                return
            }
            if (response.clientMessage === "query monitors")
                overview.readMonitors(response.data?.monitors ?? [])
        }
    }

    // One query for a burst of events, as GlazeWM sends several for one change
    Timer {
        id: refresh

        interval: 60
        onTriggered: overview.send("query monitors")
    }

    // GlazeWM may start after YASB, or restart
    Timer {
        id: reconnect

        interval: 3000
        onTriggered: {
            socket.active = false
            socket.active = true
        }
    }

    // GlazeWM focuses another window after one closes or moves away; the keys come back to the overview
    Timer {
        id: refocus

        interval: 150
        onTriggered: {
            if (popup.visible && !popup.closing) {
                windowList.takeFocus(popup.window)
                keys.forceActiveFocus()
            }
        }
    }

    Timer {
        id: keyboardFocus

        interval: 350
        onTriggered: {
            const hwnd = overview.pendingKeyboard
            overview.pendingKeyboard = 0
            if (hwnd && !windowList.inFront(hwnd))
                windowList.switchTo(hwnd)
        }
    }

    // ---- The bar

    BarButton {
        id: barButton

        anchors.centerIn: parent
        icon: "overview"
        open: overview.opened
        tip: `Overview (${PanelBus.label(overview.hotkey)})`
        onClicked: overview.toggle()
    }

    Hotkey {
        keys: overview.hotkey
        screen: overview.hotkeyScreen
        onActivated: overview.toggle()
    }

    // ---- The overlay

    BackdropPopup {
        id: popup

        title: "Overview"
        theme: overview.bar?.theme ?? PanelBus.theme
        anchor: overview
        font: PanelBus.font
        backdropItem: shade
        // Stays while other windows take the focus; Esc, the hotkey, the button or a click beside the cards closes it
        pinned: true
        enter: NumberAnimation { target: overview; property: "reveal"; to: 1; duration: overview.openDuration; easing.type: Easing.OutQuart }
        exit: NumberAnimation { target: overview; property: "reveal"; to: 0; duration: overview.closeDuration; easing.type: Easing.InOutQuart }
        onVisibleChanged: {
            if (!visible) {
                overview.reveal = 0
                overview.dragging = null
            }
        }

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                id: shade

                anchors.fill: parent
                color: Qt.alpha(PanelBus.color, 0.6)
                opacity: overview.reveal
            }

            // A click beside the cards closes
            MouseArea {
                anchors.fill: parent
                onClicked: popup.close()
            }

            Item {
                id: keys

                focus: true
                Keys.onPressed: event => {
                    const columns = layout.columns
                    if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)))
                        overview.step(1)
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                        overview.step(-1)
                    else if (event.key === Qt.Key_Down)
                        overview.step(columns)
                    else if (event.key === Qt.Key_Up)
                        overview.step(-columns)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        overview.goToWorkspace(overview.cards[overview.selected])
                    else if (/^[1-9]$/.test(event.text) && Number(event.text) <= overview.cards.length)
                        overview.goToWorkspace(overview.cards[Number(event.text) - 1])
                    else
                        return
                    event.accepted = true
                }
            }

            // Columns and card size that make the cards as big as they can be, at the monitor's shape
            QtObject {
                id: layout

                readonly property real gap: 28
                readonly property real labelHeight: 34
                readonly property real availableWidth: stage.width - 2 * 56
                readonly property real availableHeight: stage.height - 2 * 48 - hints.height
                readonly property real aspect: {
                    const monitor = overview.cards[0]?.monitor
                    return monitor ? monitor.width / monitor.height : 16 / 9
                }
                readonly property var best: {
                    const count = Math.max(1, overview.cards.length)
                    let result = { columns: 1, width: 0 }
                    for (let columns = 1; columns <= Math.min(count, overview.maxColumns); columns++) {
                        const rows = Math.ceil(count / columns)
                        const byWidth = (availableWidth - (columns - 1) * gap) / columns
                        const byHeight = ((availableHeight - (rows - 1) * gap) / rows - labelHeight) * aspect
                        // Never more than about a third of the screen across, so one workspace isn't the whole screen
                        const width = Math.min(byWidth, byHeight, stage.width * 0.36)
                        if (width > result.width)
                            result = { columns: columns, width: width }
                    }
                    return result
                }
                readonly property int columns: best.columns
                readonly property real cardWidth: Math.floor(best.width)
                readonly property real cardHeight: Math.floor(best.width / aspect)
            }

            Grid {
                id: cardGrid

                anchors.centerIn: parent
                anchors.verticalCenterOffset: -hints.height / 2
                columns: layout.columns
                spacing: layout.gap

                Repeater {
                    id: grid

                    // By count, so a card stays the same item while GlazeWM's data changes and its windows can glide
                    model: overview.cards.length

                    delegate: Item {
                        id: card

                        required property int index
                        readonly property var modelData: overview.cards[index] ?? ({ name: "", label: "", monitor: { width: 1920, height: 1080 },
                                                                                       windows: [], minimized: [], count: 0 })
                        // 1 while this card covers the screen as the real workspace does, 0 in its place in the grid
                        readonly property real full: index === overview.zoomCard ? 1 - overview.reveal : 0
                        // The others glide in from a little further out as the overview opens
                        readonly property real away: index === overview.zoomCard ? 0 : 1 - overview.reveal
                        readonly property real fullScale: stage.width / Math.max(1, layout.cardWidth)
                        // The ring and the caption are gone early in the zoom, before they'd be scaled up
                        readonly property real chrome: Math.max(0, 1 - full * 4)
                        readonly property bool isSelected: index === overview.selected
                        readonly property bool isDropTarget: overview.dragging !== null && overview.dropTarget === index
                        readonly property real ratio: layout.cardWidth / Math.max(1, modelData.monitor.width)
                        property var hoveredWindow: null

                        width: layout.cardWidth
                        height: layout.cardHeight + layout.labelHeight
                        z: full > 0 ? 1 : 0
                        opacity: 1 - away
                        // The screen's top-left is the monitor's, above the overlay by the bar's height
                        transform: [
                            Scale {
                                origin.x: card.width / 2
                                origin.y: layout.cardHeight / 2
                                xScale: 1 - 0.08 * card.away
                                yScale: xScale
                            },
                            Scale {
                                xScale: 1 + (card.fullScale - 1) * card.full
                                yScale: xScale
                            },
                            Translate {
                                x: -(cardGrid.x + card.x) * card.full
                                y: (-PanelBus.barHeight - cardGrid.y - card.y) * card.full
                            }
                        ]

                        onModelDataChanged: tiles.sync(modelData.windows)
                        Component.onCompleted: tiles.sync(modelData.windows)

                        // The windows by id, so each stays the same item and slides when it moves
                        ListModel {
                            id: tiles

                            function sync(rows: var) {
                                const wanted = new Set(rows.map(row => row.id))
                                for (let index = count - 1; index >= 0; --index) {
                                    if (!wanted.has(get(index).id))
                                        remove(index)
                                }
                                rows.forEach((row, index) => {
                                    let at = -1
                                    for (let other = index; other < count; ++other) {
                                        if (get(other).id === row.id) {
                                            at = other
                                            break
                                        }
                                    }
                                    if (at === -1) {
                                        insert(index, row)
                                        return
                                    }
                                    if (at !== index)
                                        move(at, index, 1)
                                    set(index, row)
                                })
                            }
                        }

                        // The ring around the selected card, outside it, as the live pictures cover the card itself
                        Rectangle {
                            x: -4
                            y: -4
                            width: screen.width + 8
                            height: screen.height + 8
                            radius: screen.radius + 4
                            color: "transparent"
                            opacity: card.chrome
                            border.width: card.isSelected || card.isDropTarget ? 2 : 0
                            border.color: card.isDropTarget ? PanelBus.accent2 : PanelBus.accent
                        }

                        Rectangle {
                            id: screen

                            width: layout.cardWidth
                            height: layout.cardHeight
                            radius: 10 * PanelBus.radiusScale * (1 - card.full)
                            color: Qt.alpha(PanelBus.surface, 1 - card.full)
                            border.width: card.full > 0 ? 0 : 1
                            border.color: Qt.alpha(PanelBus.textColor, cardArea.containsMouse ? 0.3 : 0.12)
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: overview.wallpaperUrl !== ""
                                source: overview.wallpaperUrl
                                sourceSize.width: layout.cardWidth * 2
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: 0.85 * (1 - card.full)
                            }

                            MouseArea {
                                id: cardArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overview.goToWorkspace(card.modelData)
                            }

                            Label {
                                anchors.centerIn: parent
                                visible: card.modelData.count === 0
                                opacity: 1 - card.full
                                text: qsTr("Empty")
                                color: Qt.alpha(PanelBus.textColor, 0.55)
                                font.pixelSize: 13
                            }

                            Repeater {
                                model: tiles

                                delegate: Item {
                                    id: tile

                                    required property var model
                                    // A window's fields, as the rest reads them
                                    readonly property var modelData: model
                                    // Arrived while the overview was open: grows in where it lands
                                    property real arrival: 1
                                    readonly property bool hovered: tileArea.containsMouse && overview.dragging === null
                                    readonly property bool lifted: overview.dragging?.id === modelData.id

                                    // Not rounded: the card grows to full screen, and a rounded half pixel here would be
                                    // several pixels there, a jump as the picture hands over to the real window
                                    x: modelData.x * card.ratio
                                    y: modelData.y * card.ratio
                                    width: Math.max(8, modelData.width * card.ratio)
                                    height: Math.max(8, modelData.height * card.ratio)
                                    opacity: (lifted ? 0.35 : 1) * arrival
                                    scale: 0.85 + 0.15 * arrival

                                    Behavior on x {
                                        enabled: overview.reveal === 1
                                        NumberAnimation { duration: overview.glideDuration; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on y {
                                        enabled: overview.reveal === 1
                                        NumberAnimation { duration: overview.glideDuration; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on width {
                                        enabled: overview.reveal === 1
                                        NumberAnimation { duration: overview.glideDuration; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on height {
                                        enabled: overview.reveal === 1
                                        NumberAnimation { duration: overview.glideDuration; easing.type: Easing.OutCubic }
                                    }
                                    NumberAnimation on arrival {
                                        id: arrive

                                        running: false
                                        from: 0
                                        to: 1
                                        duration: overview.glideDuration
                                        easing.type: Easing.OutBack
                                    }
                                    Component.onCompleted: {
                                        if (overview.reveal === 1)
                                            arrive.start()
                                    }

                                    // Its outline when pointed at, just outside the picture
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -2
                                        radius: 4
                                        color: "transparent"
                                        border.width: tile.hovered || tile.modelData.focused ? 2 : 0
                                        border.color: tile.hovered ? PanelBus.textColor : PanelBus.accent
                                    }

                                    // What shows without a picture: before DWM draws, for a hidden window, or while
                                    // dragging (DWM's pictures would cover the window being dragged)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 3
                                        color: PanelBus.raised
                                        border.width: 1
                                        border.color: Qt.alpha(PanelBus.textColor, 0.15)

                                        Column {
                                            anchors.centerIn: parent
                                            width: parent.width - 8
                                            spacing: 3

                                            Image {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                readonly property int size: Math.min(28, tile.height * 0.4, tile.width * 0.4)
                                                visible: size >= 10
                                                width: size
                                                height: size
                                                source: overview.iconOf(tile.modelData.hwnd)
                                                sourceSize: Qt.size(32, 32)
                                                asynchronous: true
                                            }
                                            Label {
                                                width: parent.width
                                                visible: tile.height > 44
                                                horizontalAlignment: Text.AlignHCenter
                                                text: tile.modelData.title
                                                textFormat: Text.PlainText
                                                elide: Text.ElideRight
                                                color: PanelBus.textColor
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    WindowThumbnail {
                                        id: picture

                                        // DWM's picture is the whole window, with the invisible resize borders Windows
                                        // puts left, right and below it (about 7 px each); GlazeWM's place is the
                                        // visible frame. So the picture reaches past the frame by those borders, to
                                        // line up with the real window
                                        readonly property real extraWidth: sourceWidth - tile.modelData.width
                                        readonly property real extraHeight: sourceHeight - tile.modelData.height
                                        readonly property bool bordered: sourceWidth > 0 && extraWidth > 0 && extraWidth <= 48
                                                                         && extraHeight >= 0 && extraHeight <= 48

                                        x: bordered ? -extraWidth / 2 * card.ratio : 0
                                        y: 0
                                        width: bordered ? sourceWidth * card.ratio : tile.width
                                        height: bordered ? sourceHeight * card.ratio : tile.height
                                        hwnd: tile.modelData.hwnd
                                        onSourceWidthChanged: Qt.callLater(logPlace)
                                        function logPlace() {
                                            if (overview.logGeometry && sourceWidth > 0)
                                                console.log(`Overview: "${tile.modelData.title}" on ${card.modelData.name}: GlazeWM `
                                                            + `${tile.modelData.x},${tile.modelData.y} ${tile.modelData.width}x${tile.modelData.height}, `
                                                            + `picture ${sourceWidth}x${sourceHeight}, borders ${sourceWidth - tile.modelData.width}x`
                                                            + `${sourceHeight - tile.modelData.height}` + (bordered ? "" : " (not used)"))
                                        }
                                        // While a card zooms out to the screen, only its own pictures are placed each
                                        // frame; the others are fading anyway
                                        visible: overview.livePreviews && overview.dragging === null && popup.visible
                                                 && (!popup.closing || card.index === overview.zoomCard)
                                    }

                                    MouseArea {
                                        id: tileArea

                                        property point pressedAt
                                        property bool moved: false

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        cursorShape: overview.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        onContainsMouseChanged: {
                                            if (containsMouse)
                                                card.hoveredWindow = tile.modelData
                                            else if (card.hoveredWindow?.id === tile.modelData.id)
                                                card.hoveredWindow = null
                                        }
                                        onPressed: mouse => {
                                            pressedAt = Qt.point(mouse.x, mouse.y)
                                            moved = false
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed || !(mouse.buttons & Qt.LeftButton))
                                                return
                                            if (!moved && Math.hypot(mouse.x - pressedAt.x, mouse.y - pressedAt.y) < 8)
                                                return
                                            moved = true
                                            if (!overview.dragging)
                                                overview.dragging = { id: tile.model.id, hwnd: tile.model.hwnd, title: tile.model.title }
                                            overview.dragPoint = mapToItem(stage, mouse.x, mouse.y)
                                            overview.dropTarget = overview.cardAt(overview.dragPoint)
                                        }
                                        onReleased: mouse => {
                                            if (moved) {
                                                const target = overview.cardAt(mapToItem(stage, mouse.x, mouse.y))
                                                if (target >= 0 && target !== card.index)
                                                    overview.moveWindow(tile.modelData, overview.cards[target])
                                                overview.dragging = null
                                                overview.dropTarget = -1
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                overview.closeWindow(tile.modelData)
                                            } else {
                                                overview.goToWindow(card.modelData, tile.modelData)
                                            }
                                            moved = false
                                        }
                                        onCanceled: {
                                            overview.dragging = null
                                            overview.dropTarget = -1
                                        }
                                    }
                                }
                            }
                        }

                        // Its number, its name, and what's on it, or the title of the window pointed at
                        Row {
                            y: layout.cardHeight + 10
                            width: parent.width
                            spacing: 8
                            opacity: card.chrome

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(20, number.implicitWidth + 10)
                                height: 20
                                radius: 6 * PanelBus.radiusScale
                                color: card.modelData.focused ? PanelBus.accent : Qt.alpha(PanelBus.textColor, 0.12)

                                Label {
                                    id: number

                                    anchors.centerIn: parent
                                    text: card.modelData.name
                                    color: card.modelData.focused ? PanelBus.onAccent : PanelBus.textColor
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }

                            Label {
                                id: caption

                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, card.width - 40 - minimizedRow.width)
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: card.hoveredWindow ? card.hoveredWindow.title
                                    : [card.modelData.label,
                                       card.modelData.count === 0 ? "" : card.modelData.count === 1 ? qsTr("1 window")
                                           : qsTr("%1 windows").arg(card.modelData.count)].filter(part => part).join("  ·  ")
                                color: card.hoveredWindow ? PanelBus.textColor : Qt.alpha(PanelBus.textColor, 0.7)
                                font.pixelSize: 13
                                font.weight: card.hoveredWindow ? Font.DemiBold : Font.Normal
                            }

                            // Minimized windows have no place on the screen, so they sit here; a click restores one
                            Row {
                                id: minimizedRow

                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Repeater {
                                    model: card.modelData.minimized

                                    delegate: Image {
                                        required property var modelData

                                        width: 18
                                        height: 18
                                        opacity: minimizedArea.containsMouse ? 1 : 0.6
                                        source: overview.iconOf(modelData.hwnd)
                                        sourceSize: Qt.size(18, 18)
                                        asynchronous: true

                                        MouseArea {
                                            id: minimizedArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: overview.goToWindow(card.modelData, parent.modelData)
                                        }

                                        ToolTip.visible: minimizedArea.containsMouse
                                        ToolTip.text: qsTr("%1 (minimized)").arg(modelData.title)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The window being dragged, under the pointer
            Rectangle {
                visible: overview.dragging !== null
                x: overview.dragPoint.x - width / 2
                y: overview.dragPoint.y - height / 2
                width: Math.min(260, dragRow.implicitWidth + 20)
                height: 36
                radius: 10 * PanelBus.radiusScale
                color: PanelBus.raised
                border.width: 1
                border.color: PanelBus.accent

                Row {
                    id: dragRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    spacing: 8

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        source: overview.dragging ? overview.iconOf(overview.dragging.hwnd) : ""
                        sourceSize: Qt.size(20, 20)
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 210)
                        elide: Text.ElideRight
                        text: overview.dragging?.title ?? ""
                        color: PanelBus.textColor
                        font.pixelSize: 13
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: overview.cards.length === 0
                opacity: overview.reveal
                text: overview.connected ? qsTr("No workspaces") : qsTr("GlazeWM isn't running")
                color: Qt.alpha(PanelBus.textColor, 0.7)
                font.pixelSize: 16
            }

            Label {
                id: hints

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                opacity: overview.reveal * 0.6
                text: overview.dragging ? qsTr("Drop on a workspace to move it there")
                    : qsTr("Click a window to go to it   ·   drag it to another workspace   ·   middle click closes   ·   1–9 jump")
                color: PanelBus.textColor
                font.pixelSize: 12
            }
        }
    }
}
