pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtWebSockets
import Yasb
import Yasb.Common
import "../../panel"

// The dynamic island in the middle of the bar. Folded, it shows one thing at a time and springs to that thing's size:
//   - for a moment, a change: the volume (speaker, level and number) or the GlazeWM workspace (its number and name)
//   - a new notification, for a few seconds (handed over by the Notifications widget)
//   - a Microsoft Teams call while you're in one, ahead of what's playing: how long it has run, the microphone (muted
//     in Windows) and hanging up. A click brings Teams to the front; middle click mutes or unmutes
//   - what's playing: the cover, the title and artist, and an equalizer while it plays, with a line for the position
//   - else the focused window's icon and title
// Hovering what's playing, or a new notification coming in, unfolds it: a card drops out of the island under the bar,
// with the cover, the position and the controls, or the whole notification. It never takes the keyboard from the app
// in use, and folds back when the pointer leaves. A click on the island opens or closes the card, where everything is
// managed: seek, volume, previous, play or pause and next, or dismiss and open for a notification. Middle click plays
// or pauses.
Item {
    id: island

    property Item bar: null
    // The island never grows wider than this
    property int maxWidth: 460
    // How long a new notification stays, in milliseconds
    property int notifyDuration: 5000
    // How long a volume or workspace change shows, in milliseconds
    property int changeDuration: 1800
    // false leaves the island empty, rather than showing the focused window, while nothing plays
    property bool showWindow: true
    property bool showVolume: true
    property bool showWorkspaces: true
    // false keeps Teams calls out of the island
    property bool showCalls: true
    // A workspace change shows in a bubble of its own beside the island, which keeps what it shows (the call, the
    // music, the window or a notification): "right" or "left" of it
    property string bubbleSide: "right"
    // "beside": that bubble, whatever the island shows (it only takes the island's place while the island is empty).
    // "replace": the change takes the island's place for a moment, as before v24, except during a call
    property string workspaceChange: "beside"
    readonly property int bubbleGap: 6
    property string glazewmUri: "ws://localhost:6123"
    property list<string> ignoreProcesses: []
    // The unfolded card's width, and how long the pointer may be away before it folds
    property int cardWidth: 360
    property int hoverDelay: 220
    property int leaveDelay: 260

    property var notification: null
    // A volume or workspace change being shown: "volume", "workspace" or ""
    property string change: ""
    // Changes count only once the services have reported what they start with
    property bool settled: false
    property int lastVolume: -1
    property bool lastMuted: false
    property string lastWorkspace: ""
    // The time now, for the call's clock
    property date now: new Date()

    readonly property var focusedWorkspace: (workspaces.workspaces ?? []).find(workspace => workspace.focused) ?? null
    readonly property bool inCall: showCalls && teams.inCall
    // What the island shows when no change is being shown
    readonly property string base: notification ? "notification"
        : inCall ? "call"
        : player.available ? "media"
        : showWindow && tracker.hasWindow && tracker.text !== "" ? "window" : "idle"
    // A workspace change goes in the bubble beside the island rather than taking its place
    readonly property bool workspaceBeside: change === "workspace" && base !== "idle"
                                            && (inCall || workspaceChange === "beside")
    readonly property string mode: change !== "" && !workspaceBeside ? change : base
    readonly property bool unfoldable: mode === "media" || mode === "notification"
    readonly property real progress: player.duration > 0 ? Math.max(0, Math.min(1, player.position / player.duration)) : 0
    readonly property bool hovered: hover.hovered

    property QtObject panelHost: null
    readonly property bool panelOpen: (panelHost?.isOpen("sound") ?? false) || (panelHost?.isOpen("notifications") ?? false)

    readonly property Item content: ({ volume: volumeRow, workspace: workspaceRow, notification: notificationRow,
                                       call: callRow, media: mediaRow })[mode] ?? windowRow
    readonly property real wanted: mode === "idle" ? 0 : Math.min(maxWidth, content.implicitWidth + 24)

    // The bar lays the island out at the width it is heading for, once per change, not at every frame of the
    // animation: the pill grows or shrinks inside that room, centred, without moving the rest of the bar
    // Room for the side bubble on both sides, so the island itself stays in the middle of the bar
    readonly property real bubbleRoom: bubble.shown ? bubble.wanted + bubbleGap : 0
    implicitWidth: Math.ceil((wanted + 2 * bubbleRoom) / 2) * 2
    implicitHeight: 24
    visible: pill.width > 1

    onBarChanged: {
        if (bar)
            panelHost = PanelBus.hostFor(bar)
    }
    onHoveredChanged: {
        if (hovered && unfoldable && !panelOpen)
            hoverTimer.restart()
        else if (!hovered)
            leaveTimer.restart()
    }
    onPanelOpenChanged: {
        if (panelOpen)
            card.close()
    }

    function open() {
        card.close()
        if (mode === "notification") {
            notification = null
            panelHost?.show("notifications", island)
        } else if (mode === "media") {
            panelHost?.toggle("sound", island)
        } else if (mode === "call") {
            showTeams()
        }
    }

    // Brings the meeting window to the front, or else Teams' main window
    function showTeams(): var {
        const meeting = teams.window ?? teams.mainWindow
        if (meeting)
            focusWindow(meeting.hwnd)
        return meeting
    }

    // Focuses a window: GlazeWM first, which switches to its workspace, then Windows, which gives it the keyboard
    // (GlazeWM alone draws its border but may leave the keyboard where it was)
    property int pendingFocus: 0
    property int focusing: 0
    function focusWindow(hwnd: int) {
        focusing = hwnd
        if (glazewm.status === WebSocket.Open) {
            pendingFocus = hwnd
            glazewm.sendTextMessage("query workspaces")
            focusFallback.restart()
        } else {
            teams.switchTo(hwnd)
            keyboardFocus.restart()
        }
    }

    // The window with this handle somewhere under a GlazeWM container, or null
    function findHandle(container: var, hwnd: int): var {
        for (const child of container?.children ?? []) {
            if (child.type === "window" && child.handle === hwnd)
                return child
            const found = findHandle(child, hwnd)
            if (found)
                return found
        }
        return null
    }

    // Hangs up by closing the call's window, as its close button does
    function hangUp() {
        console.log("Island: hanging up:", teams.window?.title ?? "no call window")
        teams.hangUp()
    }

    // m:ss, or h:mm:ss past the hour
    function duration(since: date, now: date): string {
        const total = Math.max(0, Math.floor((now - since) / 1000))
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor(total / 60) % 60
        const seconds = String(total % 60).padStart(2, "0")
        return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`
    }

    function showChange(kind: string) {
        if (!settled)
            return
        change = kind
        changeTimer.restart()
        // A change beside the island leaves the open card as it is
        if (card.visible && card.form !== "notification" && !workspaceBeside)
            card.close()
    }

    function unfold(form: string) {
        if (panelOpen)
            return
        card.form = form
        const start = pill.mapToGlobal(0, 0)
        card.fromWidth = pill.width
        card.width = Math.max(cardWidth, pill.width)
        card.height = (form === "media" ? mediaCard.implicitHeight : notificationCard.implicitHeight) + 2 * card.inset
        card.x = Math.round(start.x + pill.width / 2 - card.width / 2)
        // Under the bar: a bar that stays on top would cover a card laid over it
        const barBottom = island.bar ? island.bar.mapToGlobal(0, island.bar.height).y : start.y + pill.height
        card.y = Math.round(barBottom + (PanelBus.theme?.popup.gap ?? 6))
        if (!card.visible)
            card.open()
    }

    NowPlaying {
        id: player
    }

    ActiveWindowTracker {
        id: tracker

        screenName: island.bar?.screenName ?? ""
        ignoreProcesses: island.ignoreProcesses
    }

    AudioOutput {
        id: audio
    }

    // The microphone, muted in Windows: nobody in the call hears you, whatever Teams shows
    AudioInput {
        id: microphone
    }

    TeamsCall {
        id: teams

        active: island.showCalls
        onInCallChanged: {
            hangUpConfirm.stop()
            if (teams.inCall)
                pulse.restart()
        }
    }

    // The call's clock, ticking only while it shows
    Timer {
        interval: 1000
        repeat: true
        running: island.mode === "call"
        triggeredOnStart: true
        onTriggered: island.now = new Date()
    }

    // Hanging up takes a second click within a few seconds, so a stray click doesn't end the call
    Timer {
        id: hangUpConfirm

        interval: 3000
    }

    // GlazeWM, to bring the call's window up on its own workspace
    WebSocket {
        id: glazewm

        url: island.glazewmUri
        active: island.showCalls
        onTextMessageReceived: message => {
            let response
            try {
                response = JSON.parse(message)
            } catch (error) {
                return
            }
            if (response.messageType !== "client_response" || response.clientMessage !== "query workspaces"
                    || island.pendingFocus === 0)
                return
            const hwnd = island.pendingFocus
            island.pendingFocus = 0
            focusFallback.stop()
            // The workspace the window is on: switch to it first, then focus the window on it
            let workspace = null
            let window = null
            for (const candidate of response.data?.workspaces ?? []) {
                window = island.findHandle(candidate, hwnd)
                if (window) {
                    workspace = candidate
                    break
                }
            }
            if (window) {
                console.log(`Island: to workspace ${workspace.name}, window ${window.id}`)
                glazewm.sendTextMessage(`command focus --workspace ${workspace.name}`)
                glazewm.sendTextMessage(`command focus --container-id ${window.id}`)
            } else {
                console.log("Island: GlazeWM doesn't manage the call window; focusing it through Windows")
                teams.switchTo(hwnd)
            }
            keyboardFocus.restart()
        }
        onStatusChanged: {
            if (glazewm.status === WebSocket.Error || glazewm.status === WebSocket.Closed) {
                glazewm.active = false
                if (island.showCalls)
                    glazewmRetry.restart()
            }
        }
    }

    Timer {
        id: glazewmRetry

        interval: 5000
        onTriggered: glazewm.active = true
    }

    // When GlazeWM doesn't answer in time, or doesn't manage the window (such as a floating pop-up it ignores)
    Timer {
        id: focusFallback

        interval: 400
        onTriggered: {
            if (island.pendingFocus !== 0)
                teams.switchTo(island.pendingFocus)
            island.pendingFocus = 0
        }
    }

    // Once GlazeWM has switched workspaces, the window gets the keyboard too
    Timer {
        id: keyboardFocus

        interval: 400
        onTriggered: {
            if (island.focusing !== 0 && !teams.inFront(island.focusing))
                teams.switchTo(island.focusing)
            island.focusing = 0
        }
    }

    GlazewmWorkspaceList {
        id: workspaces

        serverUri: island.glazewmUri
        screenName: island.bar?.screenName ?? ""
    }

    // What the services start with is not a change
    Timer {
        interval: 3000
        running: true
        onTriggered: {
            island.lastVolume = audio.volume
            island.lastMuted = audio.muted
            island.lastWorkspace = island.focusedWorkspace?.name ?? ""
            island.settled = true
        }
    }

    Connections {
        target: audio

        function onVolumeChanged() {
            if (island.showVolume && (audio.volume !== island.lastVolume || audio.muted !== island.lastMuted))
                island.showChange("volume")
            island.lastVolume = audio.volume
            island.lastMuted = audio.muted
        }
    }

    onFocusedWorkspaceChanged: {
        const name = focusedWorkspace?.name ?? ""
        if (showWorkspaces && name !== "" && name !== lastWorkspace)
            showChange("workspace")
        lastWorkspace = name
    }

    Connections {
        target: PanelBus

        function onOtherAppActivated() {
            card.close()
        }

        function onNotified(notification: var) {
            island.notification = notification
            pulse.restart()
            notificationTimer.restart()
            island.unfold("notification")
        }
    }

    Timer {
        id: notificationTimer

        interval: island.notifyDuration
        onTriggered: {
            if (island.hovered || card.hovered) {
                restart()
                return
            }
            island.notification = null
            if (card.form === "notification")
                card.close()
        }
    }

    Timer {
        id: changeTimer

        interval: island.changeDuration
        onTriggered: island.change = ""
    }

    Timer {
        id: hoverTimer

        interval: island.hoverDelay
        onTriggered: {
            if (island.hovered && island.unfoldable)
                island.unfold(island.mode)
        }
    }

    Timer {
        id: leaveTimer

        interval: island.leaveDelay
        onTriggered: {
            if (!island.hovered && !card.hovered && !(card.form === "notification" && island.notification))
                card.close()
        }
    }

    Rectangle {
        id: pill

        // On whole pixels, so what is inside it doesn't shiver while it animates
        x: Math.round((island.width - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        width: island.wanted
        height: 24
        // At rest (the window's title) it is part of the bar, with no shape of its own; something live (music, a
        // volume or workspace change, a notification) makes it a pill in the accent
        readonly property bool live: island.mode !== "window" || island.panelOpen || card.visible

        radius: 12 * PanelBus.radiusScale
        color: island.panelOpen || card.visible ? Qt.alpha(PanelBus.accent, 0.22)
            : live ? Qt.alpha(PanelBus.accent, island.hovered ? 0.2 : 0.13)
            : island.hovered ? Qt.alpha(PanelBus.textColor, 0.08) : Qt.alpha(PanelBus.accent, 0)
        border.width: live ? Math.max(1, PanelBus.borderWidth) : 0
        border.color: Qt.alpha(PanelBus.accent, island.panelOpen || card.visible ? 1 : 0.55)
        clip: true

        // One small overshoot. Timed rather than a spring, so a dropped frame doesn't make it jump
        Behavior on width {
            NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on color {
            ColorAnimation { duration: 180 }
        }
        // A ring of the accent that fades out as a notification comes in
        Rectangle {
            id: glow

            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: Math.max(1.5, PanelBus.borderWidth)
            border.color: PanelBus.accent
            opacity: 0
        }

        SequentialAnimation {
            id: pulse

            NumberAnimation { target: glow; property: "opacity"; to: 1; duration: 120 }
            NumberAnimation { target: glow; property: "opacity"; to: 0; duration: 1400; easing.type: Easing.InCubic }
        }

        // How far the track is, along the bottom
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 12
            anchors.bottomMargin: 2
            width: (parent.width - 24) * island.progress
            height: 1.5
            color: PanelBus.accent
            opacity: island.mode === "media" ? 0.8 : 0

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        // One thing the island can show. Centred, so it stays put while the island springs to its width; the one
        // leaving fades out quickly, the one arriving fades and grows in a moment later, so they never blur together
        component Layer: Row {
            id: layer

            required property string name
            readonly property bool active: island.mode === name

            // Centred on the island rather than the pill, so it stays on the same pixels as the pill changes width
            x: Math.round((island.width - width) / 2) - pill.x
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            opacity: active ? 1 : 0
            visible: opacity > 0.01
            scale: active ? 1 : 0.92

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: layer.active ? 90 : 0 }
                    NumberAnimation { duration: layer.active ? 220 : 100; easing.type: layer.active ? Easing.OutCubic : Easing.InQuad }
                }
            }
            Behavior on scale {
                NumberAnimation { duration: layer.active ? 340 : 120; easing.type: layer.active ? Easing.OutBack : Easing.InQuad }
            }
        }

        Layer {
            id: windowRow

            name: "window"

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: tracker.icon !== ""
                width: 14
                height: 14
                source: tracker.icon
                sourceSize: Qt.size(28, 28)
            }
            Label {
                text: tracker.text
                room: island.maxWidth - 48
            }
        }

        Layer {
            id: callRow

            name: "call"

            // Green while the microphone is live, dim while it's muted
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: microphone.muted ? PanelBus.textDim : island.success
            }
            // Who's in the call, or the meeting's name
            Label {
                text: teams.name || qsTr("Teams")
                strong: true
                room: island.maxWidth * 0.45
            }
            Label {
                text: island.duration(teams.since, island.now)
                font.features: ({ "tnum": 1 })
            }
            PillButton {
                icon: microphone.muted ? "mic-off" : "mic"
                alert: microphone.muted
                onClicked: microphone.toggleMute()
            }
            // Red, and "Hang up?" on the first click; the second hangs up
            PillButton {
                icon: "call-end"
                text: hangUpConfirm.running ? qsTr("Hang up?") : ""
                alert: true
                strong: hangUpConfirm.running
                onClicked: {
                    if (hangUpConfirm.running) {
                        hangUpConfirm.stop()
                        island.hangUp()
                    } else {
                        hangUpConfirm.start()
                    }
                }
            }
        }

        Layer {
            id: mediaRow

            name: "media"

            Cover {
                anchors.verticalCenter: parent.verticalCenter
                size: 16
            }
            Label {
                text: player.title
                strong: true
                room: island.maxWidth * 0.5
            }
            Label {
                visible: player.artist !== ""
                text: player.artist
                room: island.maxWidth * 0.3
            }
            Equalizer {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Layer {
            id: notificationRow

            name: "notification"

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: (island.notification?.icon ?? "") !== ""
                width: 14
                height: 14
                source: island.notification?.icon ?? ""
                sourceSize: Qt.size(28, 28)
            }
            Label {
                text: island.notification?.appName ?? ""
                strong: true
                room: island.maxWidth * 0.3
            }
            Label {
                text: island.notification?.title || island.notification?.body || ""
                room: island.maxWidth * 0.55
            }
        }

        Layer {
            id: volumeRow

            name: "volume"

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: audio.muted ? "volume-mute" : audio.volume === 0 ? "volume-0"
                    : audio.volume < 34 ? "volume-1" : audio.volume < 67 ? "volume-2" : "volume-3"
                size: 16
            }
            Level {
                anchors.verticalCenter: parent.verticalCenter
                width: 96
                value: audio.muted ? 0 : audio.volume / 100
            }
            Label {
                text: audio.muted ? qsTr("Muted") : audio.volume
                strong: true
            }
        }

        Layer {
            id: workspaceRow

            name: "workspace"

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(18, number.implicitWidth + 8)
                height: 18
                radius: 4 * PanelBus.radiusScale
                color: PanelBus.accent

                Text {
                    id: number

                    anchors.centerIn: parent
                    text: island.focusedWorkspace?.name ?? ""
                    color: PanelBus.onAccent
                    font.family: PanelBus.font.family
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
            Label {
                visible: text !== ""
                text: island.focusedWorkspace?.displayName ?? ""
                strong: true
                room: island.maxWidth * 0.5
            }
            Label {
                text: qsTr("workspace")
            }
        }
    }

    // A second, smaller island beside the first, for a workspace change: the island keeps what it shows
    Rectangle {
        id: bubble

        readonly property bool shown: island.workspaceBeside
        readonly property real wanted: bubbleRow.implicitWidth + 20

        // Grows out of the island's edge
        x: island.bubbleSide === "left" ? Math.round(pill.x - island.bubbleGap - width)
                                        : Math.round(pill.x + pill.width + island.bubbleGap)
        anchors.verticalCenter: parent.verticalCenter
        width: shown ? wanted : 0
        height: 24
        visible: width > 1
        radius: 12 * PanelBus.radiusScale
        color: Qt.alpha(PanelBus.accent, 0.13)
        border.width: Math.max(1, PanelBus.borderWidth)
        border.color: Qt.alpha(PanelBus.accent, 0.55)
        clip: true

        Behavior on width {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        Row {
            id: bubbleRow

            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            opacity: bubble.shown ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: bubble.shown ? 80 : 0 }
                    NumberAnimation { duration: bubble.shown ? 180 : 90 }
                }
            }

            Rectangle {
                id: bubbleChip

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(18, bubbleNumber.implicitWidth + 8)
                height: 18
                radius: 4 * PanelBus.radiusScale
                color: PanelBus.accent

                // Flicking on to the next workspace while the bubble shows: the number drops in and the chip pops
                Connections {
                    target: island

                    function onFocusedWorkspaceChanged() {
                        if (bubble.shown && bubble.width > 1)
                            numberPop.restart()
                    }
                }
                ParallelAnimation {
                    id: numberPop

                    SequentialAnimation {
                        NumberAnimation { target: bubbleChip; property: "scale"; to: 1.18; duration: 90; easing.type: Easing.OutQuad }
                        NumberAnimation { target: bubbleChip; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                    NumberAnimation { target: bubbleNumber; property: "anchors.verticalCenterOffset"; from: -8; to: 0; duration: 260; easing.type: Easing.OutBack }
                    NumberAnimation { target: bubbleNumber; property: "opacity"; from: 0; to: 1; duration: 160 }
                }

                Text {
                    id: bubbleNumber

                    anchors.centerIn: parent
                    text: island.focusedWorkspace?.name ?? ""
                    color: PanelBus.onAccent
                    font.family: PanelBus.font.family
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
            Label {
                visible: text !== ""
                text: island.focusedWorkspace?.displayName ?? ""
                strong: true
                room: island.maxWidth * 0.3
            }
        }
    }

    // Passive, so hovering the controls still counts as hovering the island
    HoverHandler {
        id: hover
    }

    // Under the island's own controls, so they take their own clicks
    MouseArea {
        z: -1
        anchors.fill: parent
        cursorShape: island.unfoldable || island.mode === "call" ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (island.mode === "call")
                    microphone.toggleMute()
                else if (player.canPlayPause)
                    player.playPause()
            } else if (island.mode === "call") {
                island.showTeams()
            } else if (card.visible) {
                card.close()
            } else if (island.unfoldable) {
                hoverTimer.stop()
                island.unfold(island.mode)
            }
        }
    }

    ToolTip.visible: hovered && mode === "window" && tracker.text !== ""
    ToolTip.delay: 800
    ToolTip.text: tracker.window?.title ?? ""

    // The unfolded island: a card under the bar that grows out of the pill's shape and size
    BackdropPopup {
        id: card

        // "media" or "notification"
        property string form: "media"
        property real fromWidth: 0
        // 0 folded, 1 unfolded; the curve may overshoot a little
        property real grow: 0
        readonly property real inset: 12
        readonly property bool hovered: cardHover.hovered

        title: "Island"
        theme: island.bar?.theme ?? PanelBus.theme
        anchor: island
        font: PanelBus.font
        backdropItem: face
        enter: NumberAnimation { target: card; property: "grow"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        exit: NumberAnimation { target: card; property: "grow"; to: 0; duration: 180; easing.type: Easing.InCubic }
        onVisibleChanged: {
            if (!visible)
                grow = 0
        }
        onHoveredChanged: {
            if (!hovered)
                leaveTimer.restart()
        }
        // Never takes the keyboard from the app in use: the window does not accept focus, so opening it does not
        // activate it
        Component.onCompleted: window.flags = window.flags | Qt.WindowDoesNotAcceptFocus

        Item {
            anchors.fill: parent

            HoverHandler {
                id: cardHover
            }

            PopupFace {
                id: face

                x: Math.round((parent.width - width) / 2)
                width: card.fromWidth + (parent.width - card.fromWidth) * card.grow
                height: 24 + (parent.height - 24) * Math.max(0, card.grow)
                radius: Math.min(12 * PanelBus.radiusScale + (PanelBus.theme?.popup.radius ?? 14) * card.grow,
                                 height / 2)

                // Clipped here rather than on the face, so the face's hard shadow still shows
                Item {
                    clip: true
                    x: card.inset
                    y: card.inset
                    width: card.width - 2 * card.inset
                    height: card.height - 2 * card.inset
                    // The content shows once the card is mostly open
                    opacity: Math.max(0, Math.min(1, (card.grow - 0.6) / 0.4))

                    Column {
                        id: mediaCard

                        width: parent.width
                        visible: card.form === "media"
                        spacing: 10

                        Row {
                            width: parent.width
                            spacing: 12

                            Cover {
                                size: 52
                            }
                            Column {
                                width: parent.width - 64 - equalizer.width - 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Label {
                                    width: parent.width
                                    anchors.verticalCenter: undefined
                                    text: player.title
                                    strong: true
                                    font.pixelSize: 14
                                }
                                Label {
                                    width: parent.width
                                    anchors.verticalCenter: undefined
                                    visible: text !== ""
                                    text: player.artist
                                }
                                Label {
                                    width: parent.width
                                    anchors.verticalCenter: undefined
                                    visible: text !== ""
                                    text: player.album ?? ""
                                    font.pixelSize: 11
                                }
                            }
                            Equalizer {
                                id: equalizer

                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4

                            PanelSlider {
                                width: parent.width + 2 * leftPadding
                                x: -leftPadding
                                from: 0
                                to: Math.max(1, player.duration)
                                value: player.position
                                enabled: player.canSeek ?? false
                                onMoved: player.seek(value)
                                Accessible.name: qsTr("Position")
                            }
                            Item {
                                width: parent.width
                                height: 14

                                Label {
                                    text: island.time(player.position)
                                    font.pixelSize: 11
                                }
                                Label {
                                    anchors.right: parent.right
                                    text: island.time(player.duration)
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 18

                            MediaButton {
                                icon: "previous"
                                enabled: player.canPrevious
                                onClicked: player.previous()
                            }
                            MediaButton {
                                icon: player.playing ? "pause" : "play"
                                primary: true
                                enabled: player.canPlayPause
                                onClicked: player.playPause()
                            }
                            MediaButton {
                                icon: "next"
                                enabled: player.canNext
                                onClicked: player.next()
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            MediaButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: audio.muted ? "volume-mute" : audio.volume === 0 ? "volume-0"
                                    : audio.volume < 34 ? "volume-1" : audio.volume < 67 ? "volume-2" : "volume-3"
                                onClicked: audio.toggleMute()
                            }
                            PanelSlider {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 - volumeText.width - 2 * parent.spacing
                                from: 0
                                to: 100
                                value: audio.volume
                                opacity: audio.muted ? 0.5 : 1
                                onMoved: audio.setVolume(Math.round(value))
                                Accessible.name: qsTr("Volume")
                            }
                            Label {
                                id: volumeText

                                width: 28
                                horizontalAlignment: Text.AlignRight
                                text: audio.volume
                            }
                        }

                        TextLink {
                            anchors.right: parent.right
                            text: qsTr("Sound panel")
                            onClicked: island.open()
                        }
                    }

                    Column {
                        id: notificationCard

                        width: parent.width
                        visible: card.form === "notification"
                        spacing: 10

                    Row {
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 8 * PanelBus.radiusScale
                            color: Qt.alpha(PanelBus.accent, 0.18)
                            border.width: PanelBus.cardBorderWidth
                            border.color: PanelBus.outline

                            Image {
                                anchors.centerIn: parent
                                visible: (island.notification?.icon ?? "") !== ""
                                width: 20
                                height: 20
                                source: island.notification?.icon ?? ""
                                sourceSize: Qt.size(40, 40)
                            }
                            Icon {
                                anchors.centerIn: parent
                                visible: (island.notification?.icon ?? "") === ""
                                name: "bell"
                                size: 18
                                color: PanelBus.accent
                            }
                        }
                        Column {
                            width: parent.width - 48
                            spacing: 2

                            Label {
                                width: parent.width
                                anchors.verticalCenter: undefined
                                text: island.notification?.appName ?? ""
                                font.pixelSize: 11
                            }
                            Label {
                                width: parent.width
                                anchors.verticalCenter: undefined
                                visible: text !== ""
                                text: island.notification?.title ?? ""
                                strong: true
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: island.notification?.body ?? ""
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: PanelBus.textDim
                                font.family: PanelBus.font.family
                                font.pixelSize: 12
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 14

                        TextLink {
                            text: qsTr("Dismiss")
                            onClicked: {
                                island.notification = null
                                card.close()
                            }
                        }
                        TextLink {
                            text: qsTr("Open")
                            strong: true
                            onClicked: island.open()
                        }
                    }
                    }
                }

                // Middle click on the card plays or pauses, like on the island
                MouseArea {
                    z: -1
                    anchors.fill: parent
                    acceptedButtons: Qt.MiddleButton
                    onClicked: {
                        if (player.canPlayPause)
                            player.playPause()
                    }
                }
            }
        }
    }

    readonly property color critical: PanelBus.theme?.colors.critical ?? "#e5484d"
    readonly property color success: PanelBus.theme?.colors.success ?? "#3fb950"

    function time(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`
    }

    component Label: Text {
        property bool strong: false
        // The room this text may take; it ends in "…" past it
        property real room: island.maxWidth

        anchors.verticalCenter: parent?.verticalCenter
        width: Math.min(implicitWidth, room)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: strong ? PanelBus.textColor : PanelBus.textDim
        font.family: PanelBus.font.family
        font.pixelSize: PanelBus.font.pixelSize
        font.weight: strong ? Font.Bold : Font.Normal
    }

    // The cover of what's playing, greyed while paused, or a note without one
    component Cover: Item {
        property real size: 16

        width: size
        height: size

        Image {
            id: art

            anchors.fill: parent
            visible: false
            source: player.thumbnail
            sourceSize: Qt.size(parent.size * 2, parent.size * 2)
            fillMode: Image.PreserveAspectCrop
        }
        Rectangle {
            id: artMask

            anchors.fill: parent
            radius: Math.min(parent.size > 24 ? 8 * PanelBus.radiusScale : width / 2, PanelBus.pill)
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: art.status === Image.Ready
            source: art
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            saturation: player.playing ? 0 : -0.85
        }
        Rectangle {
            anchors.fill: parent
            visible: art.status !== Image.Ready
            radius: artMask.radius
            color: Qt.alpha(PanelBus.accent, 0.18)
            border.width: parent.size > 24 ? PanelBus.cardBorderWidth : 0
            border.color: PanelBus.outline

            Icon {
                anchors.centerIn: parent
                name: "play"
                size: Math.round(parent.width * 0.55)
                color: PanelBus.accent
            }
        }
    }

    // Four bars that bounce while something plays and rest low while paused
    component Equalizer: Row {
        spacing: 2
        height: 12

        Repeater {
            model: 4

            delegate: Rectangle {
                id: band

                required property int index

                anchors.bottom: parent.bottom
                width: 3
                height: 4
                color: PanelBus.accent

                SequentialAnimation on height {
                    running: player.playing && island.visible
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) band.height = 4
                    PauseAnimation { duration: band.index * 90 }
                    NumberAnimation { to: 12; duration: 260 + band.index * 40; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 4; duration: 300 + band.index * 30; easing.type: Easing.InQuad }
                }
            }
        }
    }

    // A thin level, such as the volume or the position: the theme's slider track
    component Level: Rectangle {
        property real value: 0

        height: Math.max(4, PanelBus.trackHeight * 0.6)
        radius: Math.min(height / 2, PanelBus.pill)
        color: Qt.alpha(PanelBus.textColor, 0.18)
        border.width: Math.min(PanelBus.cardBorderWidth, 1)
        border.color: PanelBus.outline

        Rectangle {
            width: Math.max(0, Math.min(1, parent.value)) * parent.width
            height: parent.height
            radius: parent.radius
            color: PanelBus.accent

            Behavior on width {
                NumberAnimation { duration: 140 }
            }
        }
    }

    // A small text button: the accent under the pointer
    component TextLink: Text {
        id: link

        property bool strong: false

        signal clicked

        color: linkArea.containsMouse ? PanelBus.accent : strong ? PanelBus.textColor : PanelBus.textDim
        font.family: PanelBus.font.family
        font.pixelSize: 12
        font.weight: strong ? Font.Bold : Font.Normal
        font.underline: linkArea.containsMouse

        MouseArea {
            id: linkArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // A small button inside the pill: an icon, and words when it has any. Tinted in the theme's red for `alert`, filled
    // with it for `strong`
    component PillButton: Item {
        id: pillButton

        property string icon
        property string text
        property bool alert: false
        property bool strong: false

        signal clicked

        anchors.verticalCenter: parent?.verticalCenter
        width: pillButton.text === "" ? 20 : pillContent.implicitWidth + 14
        height: 20

        Behavior on width {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(height / 2, 6 * PanelBus.radiusScale + PanelBus.pill)
            color: pillButton.strong ? island.critical
                : pillButton.alert ? Qt.alpha(island.critical, pillArea.containsMouse ? 0.35 : 0.2)
                : Qt.alpha(PanelBus.textColor, pillArea.containsMouse ? 0.14 : 0)

            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }
        Row {
            id: pillContent

            anchors.centerIn: parent
            spacing: 4

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: pillButton.icon
                size: 14
                color: pillButton.strong ? "white" : pillButton.alert ? island.critical : PanelBus.textColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: pillButton.text !== ""
                text: pillButton.text
                color: "white"
                font.family: PanelBus.font.family
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
        MouseArea {
            id: pillArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillButton.clicked()
        }
    }

    // A media button: an icon that lights up under the pointer; the primary one sits on an accent block
    component MediaButton: Item {
        id: control

        property string icon
        property bool primary: false

        signal clicked

        width: primary ? 36 : 28
        height: width
        opacity: enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width / 2, 8 * PanelBus.radiusScale + (control.primary ? PanelBus.pill : 0))
            color: control.primary ? PanelBus.accent : Qt.alpha(PanelBus.textColor, controlArea.containsMouse ? 0.1 : 0)
            border.width: control.primary || controlArea.containsMouse ? PanelBus.cardBorderWidth : 0
            border.color: PanelBus.outline
        }
        Icon {
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            name: control.icon
            size: 16
            color: control.primary ? PanelBus.onAccent : controlArea.containsMouse ? PanelBus.accent : PanelBus.textColor
        }
        MouseArea {
            id: controlArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.clicked()
        }
    }
}
