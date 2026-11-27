pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import "../../panel"

// The control center: one button on the bar that opens a panel with quick tiles (dark mode, do not disturb, night
// light, Wi-Fi, Bluetooth, mute), brightness for each display and the volume, every theme in the themes
// folder, the corners on top of the theme, and the power options. Picking a theme writes `theme:` in config.yaml, so
// YASB reloads with it; corners are set at once and remembered. Sign out, restart and shut down ask for a second
// click. Everything uses YASB's own services, so nothing in YASB itself changes.
Item {
    id: center

    property Item bar: null
    property string keys: "ctrl+alt+c"
    // Night light has no API in Windows: the tile opens its settings page
    property string nightLightPage: "ms-settings:nightlight"

    // The config folder, from this file's place in it (widgets/ControlCenter)
    readonly property url configFolder: Qt.resolvedUrl("../../")
    readonly property string configFile: decodeURIComponent(Qt.resolvedUrl("../../config.yaml").toString().replace(/^file:\/{2,3}/, ""))
    readonly property string themesFolder: decodeURIComponent(Qt.resolvedUrl("../../themes").toString().replace(/^file:\/{2,3}/, ""))
    // The theme config.yaml names, and the theme files in the themes folder (without those starting with "_"), read
    // when the panel opens
    property string currentTheme: ""
    property list<string> themes: []

    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("control") ?? false

    function toggle() {
        panelHost?.toggle("control", center)
    }

    function pickTheme(name: string) {
        if (name === currentTheme)
            return
        currentTheme = name
        // Replaces the top-level theme: line, or adds one at the top
        const file = configFile.replace(/'/g, "''")
        const script = `$p = '${file}'; $t = [System.IO.File]::ReadAllText($p); `
            + `if ($t -match '(?m)^theme:') { $t = $t -replace '(?m)^theme:[^\\r\\n]*', 'theme: ${name}' } `
            + `else { $t = "theme: ${name}" + [Environment]::NewLine + $t }; `
            // .NET writes UTF-8 without the byte-order mark Windows PowerShell's Set-Content would add
            + `[System.IO.File]::WriteAllText($p, $t)`
        themeWriter.command = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script]
        themeWriter.run()
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("control", page, center)
        }
    }
    onPanelOpenChanged: {
        if (panelOpen) {
            session.refresh()
            themeReader.run()
        }
    }
    Component.onCompleted: PanelBus.register("control", keys)
    Component.onDestruction: panelHost?.withdraw("control", center)

    Hotkey {
        keys: center.keys
        onActivated: center.toggle()
    }

    WindowsTheme {
        id: windows
    }

    DoNotDisturb {
        id: dnd
    }

    WifiNetworks {
        id: wifi
    }

    NetworkConnections {
        id: connections
    }

    BluetoothMonitor {
        id: bluetooth
    }

    AudioOutput {
        id: audio
    }

    PowerSession {
        id: session
    }

    DisplayBrightness {
        id: displays

        window: center.Window.window
    }

    // Prints "current:" and the theme config.yaml names, then each theme file's name
    Process {
        id: themeReader

        command: ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
            `$c = (Select-String -LiteralPath '${center.configFile.replace(/'/g, "''")}' -Pattern '^theme:\\s*(\\S+)').Matches.Groups[1].Value; `
            + `"current:$c"; Get-ChildItem -LiteralPath '${center.themesFolder.replace(/'/g, "''")}' -Filter *.qml | ForEach-Object { $_.BaseName }`]
        onFinished: {
            const lines = String(output ?? "").split(/\r?\n/).map(line => line.trim()).filter(line => line !== "")
            center.currentTheme = (lines.find(line => line.startsWith("current:")) ?? "current:").slice(8)
            center.themes = lines.filter(line => !line.startsWith("current:") && !line.startsWith("_")).sort()
        }
    }

    Process {
        id: themeWriter
    }

    BarButton {
        id: button

        anchors.centerIn: parent
        icon: "sliders"
        open: center.panelOpen
        tip: qsTr("Control center")
        onClicked: center.toggle()
    }

    Component {
        id: page

        Flickable {
            id: view

            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content

                width: view.width
                spacing: 12

                Text {
                    text: [session.userName, session.uptime > 0 ? qsTr("up %1").arg(center.duration(session.uptime)) : ""]
                        .filter(part => part !== "").join("  ·  ")
                    color: PanelBus.textDim
                    font.family: PanelBus.font.family
                    font.pixelSize: 12
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 8
                    rowSpacing: 8

                    Tile {
                        icon: "contrast"
                        title: qsTr("Dark")
                        on: windows.dark
                        detail: on ? qsTr("On") : qsTr("Off")
                        onClicked: windows.setDark(!windows.dark)
                    }
                    Tile {
                        icon: "moon"
                        title: qsTr("Do not disturb")
                        on: dnd.active
                        enabled: dnd.available
                        detail: on ? qsTr("On") : qsTr("Off")
                        onClicked: dnd.toggle("priority")
                    }
                    Tile {
                        icon: "nightlight"
                        title: qsTr("Night light")
                        detail: qsTr("Settings")
                        onClicked: Qt.openUrlExternally(center.nightLightPage)
                    }
                    Tile {
                        icon: "wifi"
                        title: qsTr("Wi-Fi")
                        on: wifi.enabled
                        enabled: wifi.available
                        detail: !wifi.enabled ? qsTr("Off")
                            : connections.primary?.kind === "wifi" ? (connections.primary?.name ?? qsTr("On")) : qsTr("On")
                        onClicked: wifi.setEnabled(!wifi.enabled)
                    }
                    Tile {
                        icon: "bluetooth"
                        title: qsTr("Bluetooth")
                        on: bluetooth.radioOn
                        detail: !bluetooth.radioOn ? qsTr("Off") : (bluetooth.connected ?? [])[0] ?? qsTr("On")
                        onClicked: bluetooth.setRadio(!bluetooth.radioOn)
                    }
                    Tile {
                        icon: audio.muted ? "volume-mute" : "volume-3"
                        title: qsTr("Mute")
                        on: audio.muted
                        detail: on ? qsTr("Muted") : qsTr("Sound on")
                        onClicked: audio.toggleMute()
                    }
                }

                Section {
                    text: qsTr("Brightness and sound")
                }

                Repeater {
                    model: displays.displays

                    delegate: Level {
                        required property int monitor
                        required property string name
                        required property int brightness

                        Layout.fillWidth: true
                        icon: "sun"
                        label: name
                        value: brightness
                        onMoved: value => displays.setDisplayBrightness(monitor, value)
                    }
                }

                Level {
                    Layout.fillWidth: true
                    icon: audio.muted ? "volume-mute" : audio.volume === 0 ? "volume-0"
                        : audio.volume < 34 ? "volume-1" : audio.volume < 67 ? "volume-2" : "volume-3"
                    label: audio.deviceName
                    value: audio.volume
                    dimmed: audio.muted
                    onMoved: value => audio.setVolume(value)
                    onIconClicked: audio.toggleMute()
                }

                Section {
                    text: qsTr("Style")
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: center.themes

                        delegate: Chip {
                            required property string modelData

                            Layout.fillWidth: true
                            text: center.themeLabel(modelData)
                            on: modelData.toLowerCase() === center.currentTheme.toLowerCase()
                            onClicked: center.pickTheme(modelData)
                        }
                    }
                }

                Section {
                    text: qsTr("Colours")
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: [{ name: "", label: qsTr("Theme") }, { name: "wallpaper", label: qsTr("Wallpaper") },
                                ...ColorSchemes.list.map(scheme => ({ name: scheme.name, label: scheme.label }))]

                        delegate: Chip {
                            required property var modelData

                            Layout.fillWidth: true
                            text: modelData.label
                            swatch: ColorSchemes.swatch(modelData.name, windows.dark, WallpaperColors) ?? []
                            on: PanelBus.scheme === modelData.name
                            onClicked: PanelBus.setScheme(modelData.name)
                        }
                    }
                }

                Section {
                    text: qsTr("Bar")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [["full", qsTr("Full")], ["floating", qsTr("Floating")], ["islands", qsTr("Islands")]]

                        delegate: Chip {
                            required property var modelData

                            Layout.fillWidth: true
                            text: modelData[1]
                            on: PanelBus.barStyle === modelData[0]
                            onClicked: PanelBus.setBarStyle(modelData[0])
                        }
                    }
                }

                Section {
                    text: qsTr("Bar accent")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [["off", qsTr("Off")], ["icons", qsTr("Icons")], ["tint", qsTr("Tinted")]]

                        delegate: Chip {
                            required property var modelData

                            Layout.fillWidth: true
                            text: modelData[1]
                            on: PanelBus.barAccent === modelData[0]
                            onClicked: PanelBus.setBarAccent(modelData[0])
                        }
                    }
                }

                Section {
                    text: qsTr("Corners")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [["", qsTr("Theme")], ["square", qsTr("Square")], ["sharp", qsTr("Sharp")],
                                ["soft", qsTr("Soft")], ["round", qsTr("Round")]]

                        delegate: Chip {
                            required property var modelData

                            Layout.fillWidth: true
                            text: modelData[1]
                            on: PanelBus.corners === modelData[0]
                            onClicked: PanelBus.setCorners(modelData[0])
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: PanelBus.dividerWidth
                    color: PanelBus.divider
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { action: "lock", icon: "lock", label: qsTr("Lock"), confirm: false },
                            { action: "sleep", icon: "moon", label: qsTr("Sleep"), confirm: false },
                            { action: "signout", icon: "signout", label: qsTr("Sign out"), confirm: true },
                            { action: "restart", icon: "restart", label: qsTr("Restart"), confirm: true },
                            { action: "shutdown", icon: "power", label: qsTr("Shut down"), confirm: true }
                        ]

                        delegate: PowerButton {
                            required property var modelData

                            Layout.fillWidth: true
                            icon: modelData.icon
                            label: modelData.label
                            confirm: modelData.confirm
                            onActivated: session.run(modelData.action)
                        }
                    }
                }
            }
        }
    }

    // A theme file's name as shown: known names spelled their own way, others with a capital first letter
    function themeLabel(name: string): string {
        return ({ ios: "iOS", material: "Material You" })[name.toLowerCase()]
            ?? name.charAt(0).toUpperCase() + name.slice(1)
    }

    function duration(seconds: int): string {
        const days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600)
        return days > 0 ? `${days} d ${hours} h` : `${hours} h ${Math.floor(seconds % 3600 / 60)} m`
    }

    component Section: Text {
        Layout.topMargin: 2
        color: PanelBus.textDim
        font.family: PanelBus.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    // A quick setting: an icon, its name and its state, filled with the accent while on
    component Tile: Rectangle {
        id: tile

        property string icon
        property string title
        property string detail
        property bool on: false

        signal clicked

        Layout.fillWidth: true
        implicitHeight: 76
        radius: 8 * PanelBus.radiusScale
        color: on ? PanelBus.accent : tileArea.containsMouse ? PanelBus.raised : PanelBus.surface
        border.width: PanelBus.cardBorderWidth
        border.color: PanelBus.outline
        opacity: enabled ? 1 : 0.45

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        // The theme's hard shadow under a tile that is on
        Rectangle {
            z: -1
            visible: tile.on && PanelBus.cardShadowOffset > 0
            x: PanelBus.cardShadowOffset
            y: PanelBus.cardShadowOffset
            width: tile.width
            height: tile.height
            radius: tile.radius
            color: PanelBus.outline
        }

        Icon {
            x: 12
            y: 12
            name: tile.icon
            color: tile.on ? PanelBus.onAccent : PanelBus.textColor
        }
        Column {
            x: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width - 20

            Text {
                width: parent.width
                text: tile.title
                elide: Text.ElideRight
                color: tile.on ? PanelBus.onAccent : PanelBus.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: tile.detail
                elide: Text.ElideRight
                color: tile.on ? Qt.alpha(PanelBus.onAccent, 0.75) : PanelBus.textDim
                font.family: PanelBus.font.family
                font.pixelSize: 11
            }
        }
        MouseArea {
            id: tileArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    // A level such as a display's brightness or the volume: its icon, its name over a slider, and the number
    component Level: RowLayout {
        id: level

        property string icon
        property string label
        property int value: 0
        property bool dimmed: false

        signal moved(int value)
        signal iconClicked

        spacing: 10

        Item {
            implicitWidth: 24
            implicitHeight: 24

            Icon {
                anchors.centerIn: parent
                name: level.icon
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: level.iconClicked()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: level.label
                elide: Text.ElideRight
                color: PanelBus.textDim
                font.family: PanelBus.font.family
                font.pixelSize: 11
            }
            PanelSlider {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: level.value
                opacity: level.dimmed ? 0.5 : 1
                onMoved: level.moved(Math.round(value))
            }
        }
        Text {
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignRight
            text: level.value
            color: PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 12
        }
    }

    // A choice such as a theme or the corners, outlined in the accent while picked
    component Chip: Rectangle {
        id: chip

        property string text
        property bool on: false
        // A colour scheme's background and accent, shown as a small split square before the text
        property var swatch: []

        signal clicked

        implicitHeight: 30
        radius: 6 * PanelBus.radiusScale
        color: on && PanelBus.cardBorderWidth > 0 ? PanelBus.accent : chipArea.containsMouse ? PanelBus.raised : "transparent"
        border.width: on ? Math.max(1.5, PanelBus.cardBorderWidth) : Math.max(1, PanelBus.cardBorderWidth)
        border.color: on ? (PanelBus.cardBorderWidth > 0 ? PanelBus.outline : PanelBus.accent) : PanelBus.outline

        Row {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 12)
            spacing: 6

            Rectangle {
                visible: chip.swatch.length === 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 3 * PanelBus.radiusScale
                color: chip.swatch[0] ?? "transparent"
                border.width: 1
                border.color: PanelBus.outline

                Rectangle {
                    x: parent.width / 2
                    y: 1
                    width: parent.width / 2 - 1
                    height: parent.height - 2
                    color: chip.swatch[1] ?? "transparent"
                }
            }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, chip.width - 12 - (chip.swatch.length === 2 ? 18 : 0))
            text: chip.text
            elide: Text.ElideRight
            color: chip.on && PanelBus.cardBorderWidth > 0 ? PanelBus.onAccent : PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 12
            font.weight: chip.on ? Font.DemiBold : Font.Normal
        }
        }
        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // A power option. One that asks to be sure turns red and says so on the first click, and acts on the second
    component PowerButton: Rectangle {
        id: power

        property string icon
        property string label
        property bool confirm: false
        property bool armed: false

        signal activated

        implicitHeight: 52
        radius: 6 * PanelBus.radiusScale
        color: armed ? PanelBus.theme?.colors.critical ?? "#c42b1c" : powerArea.containsMouse ? PanelBus.raised : "transparent"
        border.width: armed || powerArea.containsMouse ? PanelBus.cardBorderWidth : 0
        border.color: PanelBus.outline

        Column {
            anchors.centerIn: parent
            spacing: 4

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: power.icon
                color: power.armed ? "#ffffff" : PanelBus.textColor
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: power.armed ? qsTr("Again?") : power.label
                color: power.armed ? "#ffffff" : PanelBus.textDim
                font.family: PanelBus.font.family
                font.pixelSize: 11
            }
        }
        Timer {
            id: disarm

            interval: 3000
            onTriggered: power.armed = false
        }
        MouseArea {
            id: powerArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (power.confirm && !power.armed) {
                    power.armed = true
                    disarm.restart()
                    return
                }
                power.armed = false
                power.activated()
            }
        }
    }
}
