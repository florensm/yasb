import QtQuick
import QtQuick.Effects
import Yasb
import Yasb.Bar
import Yasb.Themes

// An overview of the virtual desktops: a curved panorama to turn through, or a grid, opened from the bar or a hotkey.
// Windows draws nothing for a desktop out of view, so each card shows the screen as it last looked on that desktop.
Item {
    id: overview

    component Settings: QtObject {
        required property Theme theme

        property string hotkey: "alt+grave"
        // active, cursor or primary: which screen's widget opens on the hotkey
        property string hotkeyScreen: "active"
        // panorama or grid: how the overview opens; G or Tab switches while it is open
        property string mode: "panorama"
        // The colour of the frames, their glow and the desktop numbers
        property color accent: "#4fd1a5"
        property bool glow: true
        // How wide the card in front is, as a share of the screen's width
        property real cardSize: 0.52
        // How strongly the panorama bends around you, 0 for flat
        property real curvature: 0.8
        // Turn past the last desktop to reach the first, with three or more desktops
        property bool wrap: true
        property int gridColumns: 5
        // How often to retake the picture of the desktop in view, in milliseconds, 0 to take it only when the
        // overview opens and a moment after each switch. The pictures stay in memory only.
        property int snapshotInterval: 5000
        // How dark the screen gets behind the panorama, 0 to 1
        property real dim: 0.55
        property int animationDuration: 380
        // The glyph on the bar, in iconFont and textColor
        property string icon: ""
        property int iconSize: theme.bar.iconFont.pixelSize
        property color textColor: theme.colors.text
        // Glyphs take the theme's icon font, each part unless the widget file sets it
        property font iconFont
        iconFont.family: theme.bar.iconFont.family
        iconFont.weight: theme.bar.iconFont.weight
        iconFont.variableAxes: theme.bar.iconFont.variableAxes
        // Text on the overview, which is always over a darkened screen; of font, only the family is used
        property color overviewColor: "#e8ece9"
        property font font
        font.family: theme.popup.font.family
    }

    required property BarBase bar
    readonly property Theme theme: bar.theme
    readonly property Settings settings: Settings {
        theme: overview.theme
    }

    // Held so the garbage collector doesn't destroy the open overview
    property Window opened: null
    // A point on this widget's screen, which is where pictures are taken and the overview opens
    readonly property point screenPoint: Qt.point(Screen.virtualX + 1, Screen.virtualY + 1)

    implicitWidth: settings.iconSize
    implicitHeight: settings.iconSize
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Desktop overview")
    Accessible.onPressAction: toggle()

    function capture() {
        if (desktops.current > 0 && !opened)
            snapshots.capture(desktops.current, screenPoint.x, screenPoint.y)
    }

    function snapshotUrl(number: int): string {
        return snapshots.url(number, screenPoint.x, screenPoint.y, snapshots.revision)
    }

    function toggle() {
        if (opened)
            opened.back()
        else
            open(settings.mode)
    }

    function open(startMode: string) {
        if (opened)
            return
        // Taken before the overview covers the screen
        capture()
        const screen = overview.Screen
        opened = window.createObject(null, {
            area: Qt.rect(screen.virtualX, screen.virtualY, screen.width, screen.height),
            viewMode: startMode === "grid" ? "grid" : "panorama"
        })
    }

    VirtualDesktops {
        id: desktops

        property int lastCurrent: 0
        property int lastCount: 0

        onDesktopsChanged: {
            // Deleting a desktop renumbers the ones after it, so their pictures would land on the wrong cards
            if (desktops.desktops.length !== lastCount) {
                if (lastCount > 0)
                    snapshots.forget()
                lastCount = desktops.desktops.length
            }
            if (current !== lastCurrent) {
                lastCurrent = current
                // After Windows' own slide has finished
                settle.restart()
            }
        }
    }

    DesktopSnapshots {
        id: snapshots
    }

    Hotkey {
        keys: overview.settings.hotkey
        screen: overview.settings.hotkeyScreen
        onActivated: overview.toggle()
    }

    Timer {
        id: settle

        interval: 900
        onTriggered: overview.capture()
    }

    Timer {
        interval: Math.max(overview.settings.snapshotInterval, 500)
        running: overview.settings.snapshotInterval > 0 && !overview.opened
        repeat: true
        onTriggered: overview.capture()
    }

    Text {
        anchors.centerIn: parent
        text: overview.settings.icon
        color: overview.settings.textColor
        font.family: overview.settings.iconFont.family
        font.weight: overview.settings.iconFont.weight
        font.variableAxes: overview.settings.iconFont.variableAxes
        font.pixelSize: overview.settings.iconSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => overview.open(mouse.button === Qt.RightButton
            ? (overview.settings.mode === "grid" ? "panorama" : "grid") : overview.settings.mode)
    }

    // One desktop's picture with its frame, as flat as it is before the panorama bends it
    component CardFace: Item {
        id: face

        required property var desktop
        required property bool selected
        required property real margin
        property string source: overview.snapshotUrl(desktop.number)

        RectangularShadow {
            anchors.fill: frame
            visible: overview.settings.glow
            radius: frame.radius
            blur: face.margin * 0.8
            spread: 1
            color: Qt.alpha(overview.settings.accent, face.selected ? 0.75 : 0.3)
        }

        Rectangle {
            id: frame

            anchors.fill: parent
            anchors.margins: face.margin
            radius: 6
            color: "#1c2220"

            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: face.source
                visible: face.source !== ""
                fillMode: Image.PreserveAspectCrop
                // Shared by every strip of the card, so it is loaded once
                cache: true
                smooth: true
            }

            Column {
                anchors.centerIn: parent
                visible: face.source === ""
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: face.desktop.name || qsTr("Desktop %1").arg(face.desktop.number)
                    color: Qt.alpha(overview.settings.overviewColor, 0.6)
                    font.family: overview.settings.font.family
                    font.pixelSize: Math.max(14, frame.height / 14)
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: face.desktop.populated ? qsTr("Visit once to see it here") : qsTr("Empty")
                    color: Qt.alpha(overview.settings.overviewColor, 0.35)
                    font.family: overview.settings.font.family
                    font.pixelSize: Math.max(11, frame.height / 26)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 2
                border.color: face.selected ? overview.settings.accent : Qt.alpha(overview.settings.accent, 0.55)
            }
        }
    }

    Component {
        id: window

        Window {
            id: view

            required property rect area
            property string viewMode: "panorama"
            readonly property var list: desktops.desktops
            readonly property int count: list.length
            readonly property int currentIndex: Math.max(0, list.findIndex(d => d.number === desktops.current))
            readonly property bool ring: overview.settings.wrap && count >= 3
            // The desktop in front or under the keyboard, from 0
            property int selected: currentIndex
            // The panorama's turn, in cards from the first; past the last card it goes on round the ring
            property real turn: currentIndex
            // Where turn is heading
            property real turnTarget: currentIndex
            property bool dragging: false
            // 0 is the desktop filling the screen, 1 the overview open
            property real zoom: 0
            property real reveal: 0
            // Set once a desktop is chosen, while the overview zooms into it and Windows switches
            property bool leaving: false

            // How far card index sits from the front, in cards; round the ring, the shorter way
            function offsetOf(index: real, from: real): real {
                const offset = index - from
                return ring ? ((offset % count + count + count / 2) % count) - count / 2 : offset
            }

            function select(index: int) {
                if (leaving || count === 0)
                    return
                const next = ring ? (index % count + count) % count : Math.max(0, Math.min(count - 1, index))
                // Round the ring the shorter way, so stepping past the last card carries on to the first
                turnTarget = ring ? turnTarget + offsetOf(next, selected) : next
                selected = next
                if (!dragging)
                    turn = turnTarget
            }

            function go(index: int) {
                if (leaving || count === 0)
                    return
                select(index)
                leaving = true
                if (viewMode === "panorama") {
                    zoomIn.start()
                } else {
                    finish()
                }
            }

            // Escape: back to the desktop it opened on
            function back() {
                if (leaving)
                    return
                if (viewMode === "panorama") {
                    select(currentIndex)
                    leaving = true
                    zoomIn.start()
                } else {
                    leaving = true
                    fadeOut.start()
                }
            }

            function finish() {
                const target = list[selected]?.number ?? 0
                if (target && target !== desktops.current)
                    desktops.switchTo(target)
                // Covers Windows' own slide when switching, then gets out of the way
                closeLater.start()
            }

            function toggleMode() {
                if (!leaving)
                    viewMode = viewMode === "panorama" ? "grid" : "panorama"
            }

            flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.NoDropShadowWindowHint
            color: "transparent"
            x: area.x
            y: area.y
            width: area.width
            height: area.height
            title: qsTr("Desktop overview")

            Component.onCompleted: {
                visible = true
                requestActivate()
                zoomOut.start()
            }

            onActiveChanged: {
                if (!active && !leaving)
                    back()
            }

            onVisibleChanged: {
                if (visible)
                    return
                overview.opened = null
                destroy()
            }

            Behavior on turn {
                enabled: !view.dragging
                NumberAnimation {
                    duration: overview.settings.animationDuration
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: zoomOut

                NumberAnimation {
                    target: view
                    property: "zoom"
                    from: view.viewMode === "panorama" ? 0 : 1
                    to: 1
                    duration: overview.settings.animationDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: view
                    property: "reveal"
                    to: 1
                    duration: overview.settings.animationDuration
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: zoomIn

                PauseAnimation {
                    duration: Math.abs(view.turn - view.turnTarget) > 0.01 ? overview.settings.animationDuration * 0.6 : 0
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: view
                        property: "zoom"
                        to: 0
                        duration: overview.settings.animationDuration
                        easing.type: Easing.InOutCubic
                    }
                    NumberAnimation {
                        target: view
                        property: "reveal"
                        to: 0
                        duration: overview.settings.animationDuration
                        easing.type: Easing.InCubic
                    }
                }
                ScriptAction {
                    script: view.finish()
                }
            }

            SequentialAnimation {
                id: fadeOut

                NumberAnimation {
                    target: view
                    property: "reveal"
                    to: 0
                    duration: overview.settings.animationDuration * 0.6
                    easing.type: Easing.InCubic
                }
                ScriptAction {
                    script: view.finish()
                }
            }

            Timer {
                id: closeLater

                interval: view.list[view.selected]?.number === desktops.current ? 0 : 350
                onTriggered: fade.start()
            }

            NumberAnimation {
                id: fade

                target: root
                property: "opacity"
                to: 0
                duration: 160
                onFinished: view.close()
            }

            Item {
                id: root

                anchors.fill: parent

                // The screen as it looks now, blurred and darkened behind the panorama
                Image {
                    id: backdrop

                    anchors.fill: parent
                    source: overview.snapshotUrl(desktops.current)
                    // Small, so the blur goes further for less
                    sourceSize: Qt.size(Math.round(width / 6), Math.round(height / 6))
                    fillMode: Image.PreserveAspectCrop
                    visible: view.viewMode === "panorama" && source !== ""
                    opacity: view.reveal
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1
                        blurMax: 64
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: view.reveal * (view.viewMode === "panorama" ? overview.settings.dim : overview.settings.dim * 0.45)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: view.viewMode === "panorama"
                    sourceComponent: panorama
                }

                Loader {
                    anchors.fill: parent
                    active: view.viewMode === "grid"
                    sourceComponent: grid
                }

                FocusScope {
                    anchors.fill: parent
                    focus: true

                    Keys.onEscapePressed: view.back()
                    Keys.onReturnPressed: view.go(view.selected)
                    Keys.onEnterPressed: view.go(view.selected)
                    Keys.onSpacePressed: view.go(view.selected)
                    Keys.onLeftPressed: view.select(view.selected - 1)
                    Keys.onRightPressed: view.select(view.selected + 1)
                    Keys.onUpPressed: view.select(view.selected - (view.viewMode === "grid" ? gridColumns() : 1))
                    Keys.onDownPressed: view.select(view.selected + (view.viewMode === "grid" ? gridColumns() : 1))
                    Keys.onTabPressed: view.toggleMode()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_G) {
                            view.toggleMode()
                        } else if (event.key === Qt.Key_Home) {
                            view.select(0)
                        } else if (event.key === Qt.Key_End) {
                            view.select(view.count - 1)
                        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                            const index = event.key - Qt.Key_1
                            if (index < view.count)
                                view.go(index)
                        } else {
                            return
                        }
                        event.accepted = true
                    }

                    function gridColumns(): int {
                        return Math.max(1, Math.min(overview.settings.gridColumns, view.count + 1))
                    }
                }

                // What the keys do, along the bottom
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    spacing: 22
                    opacity: view.reveal * 0.55
                    visible: view.viewMode === "panorama"

                    Repeater {
                        model: [["← →", qsTr("turn")], ["⏎", qsTr("go")], ["esc", qsTr("back")],
                            ["G", qsTr("grid")]]

                        Row {
                            required property var modelData

                            spacing: 6

                            Text {
                                text: parent.modelData[0]
                                color: overview.settings.accent
                                font.family: overview.settings.font.family
                                font.pixelSize: 12
                            }

                            Text {
                                text: parent.modelData[1]
                                color: overview.settings.overviewColor
                                font.family: overview.settings.font.family
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            Component {
                id: panorama

                Item {
                    id: stage

                    // The front card's picture and frame, before bending
                    readonly property real margin: Math.round(width * 0.012)
                    readonly property real cardWidth: width * overview.settings.cardSize
                    readonly property real faceWidth: cardWidth + 2 * margin
                    readonly property real faceHeight: cardWidth * height / width + 2 * margin
                    readonly property real gap: cardWidth * 0.1
                    readonly property real pitch: faceWidth + gap
                    // The cylinder the cards sit on, seen from its axis; it flattens while zooming in
                    readonly property real radius: cardWidth / Math.max(0.05, overview.settings.curvature)
                        / Math.max(0.001, view.zoom)
                    readonly property real centerX: width / 2
                    readonly property real centerY: height * (0.5 - 0.04 * view.zoom)
                    // The front card fills the screen at zoom 0
                    readonly property real fullScale: width / cardWidth
                    readonly property int strips: 24

                    // Places strip i of a card turned by theta on the cylinder, seen in perspective from its axis
                    function stripMatrix(theta: real, stripWidth: real): matrix4x4 {
                        const r = radius
                        const s = Math.sin(theta)
                        const c = Math.cos(theta)
                        const e = -s / r
                        const f = c + stripWidth * s / (2 * r)
                        return Qt.matrix4x4(
                            c + centerX * e, 0, 0, r * s - stripWidth / 2 * c + centerX * f,
                            centerY * e, 1, 0, centerY * f - faceHeight / 2,
                            0, 0, 1, 0,
                            e, 0, 0, f)
                    }

                    Item {
                        id: world

                        anchors.fill: parent
                        transformOrigin: Item.TopLeft
                        transform: Scale {
                            origin.x: stage.centerX
                            origin.y: stage.centerY
                            xScale: stage.fullScale + (1 - stage.fullScale) * view.zoom
                            yScale: xScale
                        }

                        Repeater {
                            model: view.list

                            Item {
                                id: card

                                required property var modelData
                                required property int index
                                readonly property real offset: view.offsetOf(index, view.turn)
                                readonly property real arc: offset * stage.pitch

                                anchors.fill: parent
                                visible: Math.abs(offset) < 2.2
                                z: -Math.abs(offset)

                                Repeater {
                                    model: card.visible ? stage.strips : 0

                                    Item {
                                        id: strip

                                        required property int index
                                        readonly property real stripWidth: stage.faceWidth / stage.strips
                                        readonly property real theta: (card.arc - stage.faceWidth / 2
                                            + (index + 0.5) * stripWidth) / stage.radius
                                        // Not drawn once it swings round towards the viewer
                                        readonly property real nearest: Math.min(Math.cos(theta),
                                            Math.cos(Math.abs(theta) + stripWidth / stage.radius))

                                        width: stripWidth
                                        height: stage.faceHeight
                                        clip: true
                                        visible: nearest > 0.18
                                        transform: Matrix4x4 {
                                            matrix: stage.stripMatrix(strip.theta, strip.stripWidth)
                                        }

                                        CardFace {
                                            x: -strip.index * strip.stripWidth
                                            width: stage.faceWidth
                                            height: stage.faceHeight
                                            desktop: card.modelData
                                            selected: card.index === view.selected
                                            margin: stage.margin
                                        }
                                    }
                                }

                                // The number and what is open under the card
                                Column {
                                    readonly property real theta: card.arc / stage.radius

                                    x: stage.centerX + stage.radius * Math.tan(theta) - width / 2
                                    y: stage.centerY + stage.faceHeight / 2 / Math.cos(theta) + 12
                                    visible: Math.abs(theta) < 0.9
                                    opacity: view.zoom * view.zoom * Math.max(0, 1 - Math.abs(card.offset) * 0.6)
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: card.modelData.number
                                        color: overview.settings.accent
                                        font.family: overview.settings.font.family
                                        font.pixelSize: 26
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: [card.modelData.name, card.modelData.app,
                                            card.modelData.number === desktops.current ? qsTr("here") : ""]
                                            .filter(part => part).join(" · ")
                                        color: Qt.alpha(overview.settings.overviewColor, 0.6)
                                        font.family: overview.settings.font.family
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }

                    // Click a card to bring it round, the one in front to go there; drag or scroll to turn
                    MouseArea {
                        property real pressX: 0
                        property real pressTurn: 0

                        anchors.fill: parent
                        enabled: !view.leaving && view.zoom > 0.98
                        onPressed: mouse => {
                            pressX = mouse.x
                            pressTurn = view.turn
                        }
                        onPositionChanged: mouse => {
                            if (!view.dragging && Math.abs(mouse.x - pressX) > 8)
                                view.dragging = true
                            if (view.dragging)
                                view.turn = view.ring ? pressTurn - (mouse.x - pressX) / stage.pitch
                                    : Math.max(-0.4, Math.min(view.count - 0.6, pressTurn - (mouse.x - pressX) / stage.pitch))
                        }
                        onReleased: {
                            if (view.dragging) {
                                const nearest = Math.round(view.turn)
                                view.turnTarget = nearest
                                view.selected = view.ring ? (nearest % view.count + view.count) % view.count
                                    : Math.max(0, Math.min(view.count - 1, nearest))
                                view.dragging = false
                                view.turn = view.ring ? nearest : view.selected
                                view.turnTarget = view.turn
                            }
                        }
                        onClicked: mouse => {
                            if (Math.abs(mouse.x - pressX) > 8)
                                return
                            const theta = Math.atan((mouse.x - stage.centerX) / stage.radius)
                            const steps = Math.round(view.turn - view.turnTarget + theta * stage.radius / stage.pitch)
                            const index = view.selected + steps
                            if (!view.ring && (index < 0 || index >= view.count))
                                view.back()
                            else if (steps === 0)
                                view.go(view.selected)
                            else
                                view.select(index)
                        }
                        onWheel: wheel => {
                            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x
                            view.select(view.selected + (delta < 0 ? 1 : -1))
                        }
                    }
                }
            }

            Component {
                id: grid

                Item {
                    id: dock

                    readonly property int columns: Math.max(1, Math.min(overview.settings.gridColumns, view.count + 1))
                    readonly property real tileWidth: Math.min(width * 0.56 / columns, 260)
                    readonly property real tileHeight: tileWidth * height / width
                    readonly property real spacing: 8

                    // A click outside the tiles closes
                    MouseArea {
                        anchors.fill: parent
                        onClicked: view.back()
                    }

                    Item {
                        id: panel

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.06 - (1 - view.reveal) * 40
                        width: tiles.width + 24
                        height: tiles.height + 24
                        opacity: view.reveal

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: Qt.alpha("#101513", 0.82)
                            border.color: Qt.alpha(overview.settings.overviewColor, 0.08)
                        }

                        // Switches back to the panorama
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 6
                            width: modeLabel.implicitWidth + 16
                            height: modeLabel.implicitHeight + 8
                            radius: 5
                            color: modeArea.containsMouse ? Qt.alpha(overview.settings.overviewColor, 0.14)
                                : Qt.alpha("#101513", 0.82)

                            Text {
                                id: modeLabel

                                anchors.centerIn: parent
                                text: qsTr("panorama ▾")
                                color: overview.settings.overviewColor
                                font.family: overview.settings.font.family
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: modeArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.toggleMode()
                            }
                        }

                        Grid {
                            id: tiles

                            anchors.centerIn: parent
                            columns: dock.columns
                            spacing: dock.spacing

                            Repeater {
                                model: view.list

                                Rectangle {
                                    id: tile

                                    required property var modelData
                                    required property int index
                                    readonly property string source: overview.snapshotUrl(modelData.number)
                                    readonly property bool current: modelData.number === desktops.current

                                    width: dock.tileWidth
                                    height: dock.tileHeight
                                    radius: 4
                                    color: Qt.alpha("#ffffff", 0.04)
                                    border.width: tile.index === view.selected || tileArea.containsMouse ? 2 : 1
                                    border.color: tile.index === view.selected ? overview.settings.accent
                                        : tileArea.containsMouse ? Qt.alpha(overview.settings.accent, 0.6)
                                        : Qt.alpha(overview.settings.overviewColor, 0.12)

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: tile.source
                                        visible: tile.source !== ""
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize: Qt.size(dock.tileWidth * 2, dock.tileHeight * 2)
                                        asynchronous: true
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: tile.source === ""
                                        text: tile.modelData.name || qsTr("WS %1").arg(tile.modelData.number)
                                        color: Qt.alpha(overview.settings.overviewColor, 0.45)
                                        font.family: overview.settings.font.family
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }

                                    // The number, and what is open, in the corner
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 5
                                        visible: tile.source !== ""
                                        width: caption.implicitWidth + 10
                                        height: caption.implicitHeight + 4
                                        radius: 3
                                        color: Qt.alpha("#000000", 0.6)

                                        Text {
                                            id: caption

                                            anchors.centerIn: parent
                                            text: [tile.modelData.number, tile.modelData.app]
                                                .filter(part => part).join(" · ")
                                            color: tile.current ? overview.settings.accent : overview.settings.overviewColor
                                            font.family: overview.settings.font.family
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        id: tileArea

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: view.select(tile.index)
                                        onClicked: view.go(tile.index)
                                    }
                                }
                            }

                            // A new desktop
                            Rectangle {
                                width: dock.tileWidth
                                height: dock.tileHeight
                                radius: 4
                                color: addArea.containsMouse ? Qt.alpha(overview.settings.accent, 0.1) : "transparent"
                                border.width: 1
                                border.color: Qt.alpha(overview.settings.overviewColor, addArea.containsMouse ? 0.3 : 0.12)

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: Qt.alpha(overview.settings.overviewColor, 0.5)
                                    font.family: overview.settings.font.family
                                    font.pixelSize: 22
                                }

                                MouseArea {
                                    id: addArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: desktops.create()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
