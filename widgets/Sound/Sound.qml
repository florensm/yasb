pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Yasb
import Yasb.Common
import "../../panel"

// The volume on the bar and the Sound panel it opens.
//   The button: the speaker and the level. Left click: the Sound panel. Middle click: play / pause. Right click:
//   mute. Scroll: master volume.
//   The panel: what's playing with its controls, the master volume and every app's volume, and the output devices.
//   Switching output takes a second click to confirm.
Item {
    id: sound

    property Item bar: null
    // Hotkey that opens the panel, and its screen: active, cursor or primary
    property string keys: "ctrl+alt+m"
    property string hotkeyScreen: "active"
    // Percentage points per wheel step over the button
    property int scrollStep: 2
    property bool invertWheel: false
    // Windows' default sound when a volume slider is let go, to hear the new level
    property bool beepOnRelease: true
    // How long a picked output device waits for its confirming click, in milliseconds
    property int confirmTimeout: 5000
    property color accentColor: PanelBus.accent

    readonly property color textColor: bar?.theme.colors.text ?? "#e6e6f0"
    readonly property color secondary: Qt.alpha(textColor, 0.55)
    property font iconFont
    iconFont.family: bar?.iconFont?.family ?? "Segoe Fluent Icons"
    iconFont.weight: bar?.iconFont?.weight ?? Font.Normal
    readonly property real progress: player.duration > 0 ? Math.max(0, Math.min(1, player.position / player.duration)) : 0
    readonly property string label: [player.title, player.artist].filter(part => part).join(" — ")
    // The audio sessions of the app that is playing: Spotify's while Spotify plays, the browser's for YouTube
    readonly property var playingApps: player.available ? (audio.apps ?? []).filter(app =>
        (!!player.appId && app.appId === player.appId)
        || (!!player.process && (app.process ?? "").toLowerCase() === player.process.toLowerCase())) : []
    // The output device waiting for its confirming click, by id
    property string pendingDevice: ""
    // The list of output devices, under the current one
    property bool devicesOpen: false

    function volumeGlyph(level: int, muted: bool): string {
        return muted ? "" : level === 0 ? "" : level < 34 ? "" : level < 67 ? "" : ""
    }

    // The same, as this setup's line icons
    function volumeIcon(level: int, muted: bool): string {
        return muted ? "volume-mute" : level === 0 ? "volume-0" : level < 34 ? "volume-1" : level < 67 ? "volume-2" : "volume-3"
    }

    function deviceIcon(name: string): string {
        return /head(phone|set)|earbud|buds|airpods/i.test(name) ? "headphones"
            : /hdmi|monitor|display|\btv\b|displayport/i.test(name) ? "monitor" : "speaker-box"
    }

    function deviceGlyph(name: string): string {
        return /head(phone|set)|earbud|buds|airpods/i.test(name) ? ""
            : /hdmi|monitor|display|\btv\b|displayport/i.test(name) ? "" : ""
    }

    function time(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds))
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`
    }

    function toggle() {
        panelHost?.toggle("sound", sound)
    }

    function pickDevice(id: string) {
        pendingDevice = id
        confirmTimer.restart()
    }

    implicitWidth: volumeButton.implicitWidth
    implicitHeight: volumeButton.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Sound")
    Accessible.onPressAction: toggle()

    Component.onCompleted: PanelBus.register("sound", sound.keys)
    Component.onDestruction: panelHost?.withdraw("sound", sound)

    // The bar's one panel, which every page shares
    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("sound") ?? false

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("sound", panelContent, sound)
        }
    }

    NowPlaying {
        id: player
    }

    AudioOutput {
        id: audio
    }

    Hotkey {
        keys: sound.keys
        screen: sound.hotkeyScreen
        onActivated: sound.toggle()
    }

    // An unconfirmed output switch gives up by itself
    Timer {
        id: confirmTimer

        interval: sound.confirmTimeout
        onTriggered: sound.pendingDevice = ""
    }

    // A new player can be a different app, with its own volume
    Connections {
        target: player

        function onPlayerChanged() {
            if (sound.panelOpen)
                audio.refreshApps()
        }
    }

    Connections {
        target: sound.Window.window

        function onVisibleChanged() {
            if (!sound.Window.window?.visible && sound.panelOpen)
                sound.panelHost.hide()
        }
    }

    // ---------- The button on the bar ----------

    // The speaker and the level. What's playing is on the island, which opens this panel too.
    BarButton {
        id: volumeButton

        anchors.centerIn: parent
        glyph: sound.volumeGlyph(audio.volume, audio.muted)
        text: audio.muted ? qsTr("muted") : `${audio.volume}%`
        dim: audio.muted
        open: sound.panelOpen
        tip: (sound.label ? sound.label + "\n" : "") + (audio.muted ? qsTr("Muted") : qsTr("Volume %1%").arg(audio.volume))
            + "\n" + qsTr("Middle click: play / pause · right click: mute · scroll: volume")
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse?.button === Qt.MiddleButton) {
                if (player.canPlayPause)
                    player.playPause()
            } else if (mouse?.button === Qt.RightButton) {
                audio.toggleMute()
            } else {
                sound.toggle()
            }
        }
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.angleDelta.x
            if (delta !== 0)
                audio.setVolume(Math.max(0, Math.min(100,
                    audio.volume + ((delta > 0) !== sound.invertWheel ? sound.scrollStep : -sound.scrollStep))))
        }
    }

    // ---------- Pieces of the panel ----------

    // A card on the panel, in the theme's card shape: outline and hard shadow where the tokens set them
    component Card: Rectangle {
        radius: 10 * PanelBus.radiusScale
        color: PanelBus.surface
        border.width: PanelBus.cardBorderWidth
        border.color: PanelBus.outline

        Rectangle {
            z: -1
            visible: PanelBus.cardShadowOffset > 0
            x: PanelBus.cardShadowOffset
            y: PanelBus.cardShadowOffset
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: PanelBus.shadowColor
        }
    }

    // A button with one of this setup's icons. `primary`: filled with the accent, round unless the theme is square.
    // `checked`: tinted with the accent
    component IconButton: Rectangle {
        id: button

        property string icon
        property string tip
        property real size: 32
        property real iconSize: 16
        property bool primary: false
        property bool checked: false

        signal clicked

        implicitWidth: size
        implicitHeight: size
        radius: primary ? Math.min(size / 2, PanelBus.pill === 0 ? 0 : size / 2) : 7 * PanelBus.radiusScale
        opacity: enabled ? 1 : 0.35
        color: primary ? sound.accentColor
            : checked ? Qt.alpha(sound.accentColor, 0.16)
            : buttonArea.containsMouse ? Qt.alpha(sound.textColor, 0.1) : "transparent"
        border.width: primary ? PanelBus.cardBorderWidth : 0
        border.color: PanelBus.outline
        scale: buttonArea.pressed ? 0.94 : 1

        Behavior on scale {
            NumberAnimation { duration: 90 }
        }

        Icon {
            anchors.centerIn: parent
            name: button.icon
            size: button.iconSize
            color: button.primary ? PanelBus.onAccent : button.checked ? sound.accentColor : sound.textColor
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        ToolTip.visible: tip !== "" && buttonArea.containsMouse
        ToolTip.delay: 500
        ToolTip.text: tip
    }

    // A text button: plain, or filled with the accent
    component TextButton: Rectangle {
        id: textButton

        property string text
        property string icon
        property bool primary: false

        signal clicked

        implicitWidth: textRow.implicitWidth + 24
        implicitHeight: 30
        radius: 6 * PanelBus.radiusScale
        color: primary ? sound.accentColor : textArea.containsMouse ? PanelBus.raised : "transparent"
        border.width: primary ? PanelBus.cardBorderWidth : Math.max(1, PanelBus.cardBorderWidth)
        border.color: PanelBus.outline

        Row {
            id: textRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: textButton.icon !== ""
                name: textButton.icon
                color: textButton.primary ? PanelBus.onAccent : sound.textColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: textButton.text
                color: textButton.primary ? PanelBus.onAccent : sound.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 12
                font.weight: textButton.primary ? Font.DemiBold : Font.Normal
            }
        }

        MouseArea {
            id: textArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: textButton.clicked()
        }
    }

    component SectionLabel: Text {
        color: sound.secondary
        font.family: PanelBus.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    // One app's volume: its icon (a click mutes it), its name over its slider, and the level. The app that is
    // playing gets the accent bar on its left.
    component AppRow: Rectangle {
        id: app

        required property var modelData
        readonly property bool playing: sound.playingApps.some(own => own.key === modelData.key)

        implicitHeight: 48
        radius: 8 * PanelBus.radiusScale
        color: rowHover.hovered ? Qt.alpha(sound.textColor, 0.05) : "transparent"

        HoverHandler {
            id: rowHover
        }

        Rectangle {
            visible: app.playing
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 18
            radius: PanelBus.pill === 0 ? 0 : 1.5
            color: sound.accentColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 12

            Item {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24

                Image {
                    id: appIcon

                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: app.modelData.icon ?? ""
                    sourceSize: Qt.size(40, 40)
                    opacity: app.modelData.muted ? 0.45 : 1
                    layer.enabled: app.modelData.muted
                    layer.effect: MultiEffect {
                        saturation: -1
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    name: "app"
                    color: sound.secondary
                }
                MouseArea {
                    id: iconArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: audio.setAppMuted(app.modelData.key, !app.modelData.muted)
                }

                ToolTip.visible: iconArea.containsMouse
                ToolTip.delay: 500
                ToolTip.text: app.modelData.muted ? qsTr("Unmute") : qsTr("Mute")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: PanelBus.handleSize / 2
                    text: app.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: app.modelData.muted ? sound.secondary : sound.textColor
                    font.family: PanelBus.font.family
                    font.pixelSize: 11
                    font.weight: app.playing ? Font.DemiBold : Font.Normal
                }
                PanelSlider {
                    id: appSlider

                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: app.modelData.volume
                    opacity: app.modelData.muted ? 0.5 : 1
                    onMoved: audio.setAppVolume(app.modelData.key, Math.round(value))
                    onPressedChanged: {
                        if (!pressed && sound.beepOnRelease)
                            audio.beep()
                    }
                    Accessible.name: qsTr("%1 volume").arg(app.modelData.name)
                }
            }

            Text {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: app.modelData.muted ? qsTr("Off") : Math.round(appSlider.value)
                color: sound.secondary
                font.family: PanelBus.font.family
                font.pixelSize: 12
                font.features: { "tnum": 1 }
            }
        }
    }

    // One output device in the list under the current one. A click only asks; the switch happens on "Switch", or
    // not at all after confirmTimeout.
    component DeviceRow: Rectangle {
        id: device

        required property var modelData
        readonly property bool current: modelData.current ?? false
        readonly property bool pending: sound.pendingDevice !== "" && sound.pendingDevice === modelData.id

        Layout.fillWidth: true
        implicitHeight: pending ? 76 : 38
        radius: 8 * PanelBus.radiusScale
        clip: true
        color: pending ? Qt.alpha(sound.textColor, 0.07) : Qt.alpha(sound.textColor, rowArea.containsMouse ? 0.05 : 0)

        Behavior on implicitHeight {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        RowLayout {
            x: 10
            width: parent.width - 20
            height: 38
            spacing: 12

            Icon {
                name: sound.deviceIcon(device.modelData.name ?? "")
                color: device.current ? sound.accentColor : sound.secondary
            }
            Text {
                Layout.fillWidth: true
                text: device.modelData.name ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: sound.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 13
                font.weight: device.current ? Font.DemiBold : Font.Normal
            }
            Icon {
                visible: device.current
                name: "check"
                color: sound.accentColor
            }
        }

        MouseArea {
            id: rowArea

            width: parent.width
            height: 38
            enabled: !device.current
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sound.pickDevice(device.modelData.id)
        }

        RowLayout {
            x: 10
            y: 38
            width: parent.width - 20
            height: 32
            visible: device.pending
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: qsTr("Switch output here?")
                color: sound.secondary
                font.family: PanelBus.font.family
                font.pixelSize: 12
            }
            TextButton {
                text: qsTr("Cancel")
                onClicked: sound.pendingDevice = ""
            }
            TextButton {
                text: qsTr("Switch")
                primary: true
                onClicked: {
                    audio.setDevice(device.modelData.id)
                    sound.pendingDevice = ""
                    sound.devicesOpen = false
                }
            }
        }
    }

    // ---------- The panel ----------

    // What Sound shows in the panel: what's playing, the output device, the master volume and every app's
    property Component panelContent: Component {
        Item {
            id: soundView

            function panelShown(fresh) {
                sound.pendingDevice = ""
                sound.devicesOpen = false
                audio.refreshApps()
                soundView.forceActiveFocus()
            }

            function panelHidden() {
                sound.pendingDevice = ""
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // What's playing: the cover beside the track, then its position and controls
                Card {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.rightMargin: PanelBus.cardShadowOffset
                    Layout.bottomMargin: 18 + PanelBus.cardShadowOffset
                    implicitHeight: player.available ? playing.implicitHeight + 28 : 56

                    ColumnLayout {
                        id: playing

                        visible: player.available
                        x: 14
                        y: 14
                        width: parent.width - 28
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Item {
                                Layout.preferredWidth: 68
                                Layout.preferredHeight: 68

                                Item {
                                    id: cover

                                    anchors.fill: parent
                                    visible: art.status === Image.Ready
                                    layer.enabled: visible
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: coverMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1
                                    }

                                    Image {
                                        id: art

                                        anchors.fill: parent
                                        source: player.thumbnail
                                        sourceSize: Qt.size(136, 136)
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                                Rectangle {
                                    id: coverMask

                                    anchors.fill: parent
                                    radius: 8 * PanelBus.radiusScale
                                    visible: false
                                    layer.enabled: true
                                }
                                // No cover: the accent with a note
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !cover.visible
                                    radius: 8 * PanelBus.radiusScale
                                    color: Qt.alpha(sound.accentColor, 0.18)

                                    Icon {
                                        anchors.centerIn: parent
                                        name: "music"
                                        size: 24
                                        color: sound.accentColor
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: PanelBus.cardBorderWidth > 0
                                    radius: 8 * PanelBus.radiusScale
                                    color: "transparent"
                                    border.width: PanelBus.cardBorderWidth
                                    border.color: PanelBus.outline
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // The app it plays in
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: player.appName !== ""
                                    spacing: 6

                                    Image {
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        visible: source.toString() !== ""
                                        source: sound.playingApps[0]?.icon ?? ""
                                        sourceSize: Qt.size(24, 24)
                                    }
                                    SectionLabel {
                                        Layout.fillWidth: true
                                        text: player.appName
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: player.title || player.appName
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: sound.textColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: player.artist ?? ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: sound.secondary
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 12
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: player.albumTitle ?? ""
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Qt.alpha(sound.textColor, 0.45)
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: player.duration > 0
                            spacing: 0

                            PanelSlider {
                                id: seek

                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, player.duration)
                                enabled: player.canSeek
                                onMoved: player.seek(value)
                                Accessible.name: qsTr("Position")
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: PanelBus.handleSize / 2 - 2
                                Layout.rightMargin: PanelBus.handleSize / 2 - 2

                                Text {
                                    Layout.fillWidth: true
                                    text: sound.time(seek.pressed ? seek.value : player.position)
                                    color: sound.secondary
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                    font.features: { "tnum": 1 }
                                }
                                Text {
                                    text: sound.time(player.duration)
                                    color: sound.secondary
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                        // Follows the track, except while it is being dragged
                        Binding {
                            target: seek
                            property: "value"
                            value: player.position
                            when: !seek.pressed
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10

                            IconButton {
                                icon: "shuffle"
                                tip: player.shuffle ? qsTr("Shuffle on") : qsTr("Shuffle off")
                                checked: player.shuffle ?? false
                                visible: player.canShuffle ?? false
                                onClicked: player.toggleShuffle()
                            }
                            IconButton {
                                icon: "previous"
                                tip: qsTr("Previous")
                                enabled: player.canPrevious
                                onClicked: player.previous()
                            }
                            IconButton {
                                icon: player.playing ? "pause" : "play"
                                tip: player.playing ? qsTr("Pause") : qsTr("Play")
                                size: 40
                                primary: true
                                enabled: player.canPlayPause
                                onClicked: player.playPause()
                            }
                            IconButton {
                                icon: "next"
                                tip: qsTr("Next")
                                enabled: player.canNext
                                onClicked: player.next()
                            }
                            IconButton {
                                icon: player.repeat === "track" ? "repeat-one" : "repeat"
                                tip: player.repeat === "track" ? qsTr("Repeat one")
                                    : player.repeat === "list" ? qsTr("Repeat all") : qsTr("Repeat off")
                                checked: (player.repeat ?? "none") !== "none"
                                visible: player.canRepeat ?? false
                                onClicked: player.cycleRepeat()
                            }
                        }
                    }

                    RowLayout {
                        visible: !player.available
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Icon {
                            name: "music"
                            color: sound.secondary
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Nothing playing")
                            color: sound.secondary
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                        }
                    }
                }

                SectionLabel {
                    Layout.bottomMargin: 6
                    text: qsTr("Output")
                }

                // The output device; a click lists the others
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 8 * PanelBus.radiusScale
                    color: sound.devicesOpen ? Qt.alpha(sound.accentColor, 0.1)
                        : outputArea.containsMouse ? Qt.alpha(sound.textColor, 0.05) : "transparent"
                    border.width: Math.max(1, PanelBus.cardBorderWidth)
                    border.color: sound.devicesOpen ? sound.accentColor : PanelBus.outline

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Icon {
                            name: sound.deviceIcon(audio.deviceName ?? "")
                            color: sound.accentColor
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: audio.available ? audio.deviceName : qsTr("No output device")
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: sound.textColor
                                font.family: PanelBus.font.family
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: (audio.devices ?? []).length > 1
                                    ? qsTr("Output device · %1 more").arg(audio.devices.length - 1) : qsTr("Output device")
                                color: sound.secondary
                                font.family: PanelBus.font.family
                                font.pixelSize: 11
                            }
                        }
                        Icon {
                            name: "chevron-down"
                            color: sound.secondary
                            rotation: sound.devicesOpen ? 180 : 0

                            Behavior on rotation {
                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: outputArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sound.devicesOpen = !sound.devicesOpen
                            sound.pendingDevice = ""
                        }
                    }
                }

                // The other devices. A click asks first, so music doesn't start on the speakers by accident.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: sound.devicesOpen
                    spacing: 2

                    Repeater {
                        model: audio.devices

                        delegate: DeviceRow {}
                    }
                }

                // The master volume: a click on the speaker mutes
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 8

                    IconButton {
                        icon: sound.volumeIcon(audio.volume, audio.muted)
                        tip: audio.muted ? qsTr("Unmute") : qsTr("Mute")
                        checked: audio.muted
                        onClicked: audio.toggleMute()
                    }
                    PanelSlider {
                        id: master

                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: audio.volume
                        opacity: audio.muted ? 0.5 : 1
                        onMoved: audio.setVolume(Math.round(value))
                        onPressedChanged: {
                            if (!pressed && sound.beepOnRelease)
                                audio.beep()
                        }
                        Accessible.name: qsTr("Master volume")
                    }
                    Text {
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(master.pressed ? master.value : audio.volume)
                        color: sound.textColor
                        font.family: PanelBus.font.family
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }
                // Follows the level set elsewhere, except while it is being dragged
                Binding {
                    target: master
                    property: "value"
                    value: audio.volume
                    when: !master.pressed
                }

                SectionLabel {
                    Layout.topMargin: 18
                    Layout.bottomMargin: 4
                    text: qsTr("Apps")
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: audio.apps
                    ScrollBar.vertical: ScrollBar {}

                    delegate: AppRow {
                        width: ListView.view.width
                    }

                    Text {
                        visible: (audio.apps ?? []).length === 0
                        y: 8
                        text: qsTr("No apps are making sound.")
                        color: sound.secondary
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    implicitHeight: PanelBus.dividerWidth
                    color: PanelBus.divider
                }

                // How many apps, and Windows' own sound settings
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 12

                    Text {
                        Layout.fillWidth: true
                        readonly property int count: (audio.apps ?? []).length
                        text: count === 1 ? qsTr("1 app with sound") : qsTr("%1 apps with sound").arg(count)
                        color: sound.secondary
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                    TextButton {
                        text: qsTr("Sound settings")
                        icon: "sliders"
                        onClicked: {
                            sound.panelHost?.hide()
                            Qt.openUrlExternally("ms-settings:sound")
                        }
                    }
                }
            }
        }
    }
}
