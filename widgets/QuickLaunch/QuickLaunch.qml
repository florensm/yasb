import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts
import Yasb
import Yasb.Common
import "../../panel"

Item {
    id: launcher

    property Item bar: null
    property string hotkey: "alt+slash"
    // active, cursor or primary: which screen's widget opens on the hotkey
    property string hotkeyScreen: "active"
    // What each search provider does: on or off, the prefix typed before a space to use it ("*" for none),
    // its order among the others, and its own options. Apps, colour, file search and GitHub notifications are on;
    // turn another on with `calculator.enabled: true`.
    component Provider: QtObject {
        property bool enabled: false
        property string prefix: "*"
        property int priority: 0
        property var options: ({})
    }

    property Provider apps: Provider {
        enabled: true
        options: ({ show_recent: true, max_recent: 10, show_description: true })
    }

    property Provider bookmarks: Provider {
        enabled: false
        options: ({ browser: "all", profile: "Default" })
    }

    property Provider calculator: Provider {
        enabled: false
        prefix: "="
    }

    property Provider clipboardHistory: Provider {
        enabled: false
        prefix: "cb"
        options: ({ max_items: 30, show_preview: true })
    }

    property Provider color: Provider {
        enabled: true
        prefix: "c:"
    }

    property Provider binance: Provider {
        enabled: false
        prefix: "crypto"
        options: ({ pairs: ["BTC/USDT"], round: 2, open_url: false, domain: "api-gcp.binance.com" })
    }

    property Provider currency: Provider {
        enabled: false
        prefix: "$"
    }

    property Provider devTools: Provider {
        enabled: false
        prefix: "dev"
    }

    property Provider emoji: Provider {
        enabled: false
        prefix: ":"
    }

    property Provider fileSearch: Provider {
        enabled: true
        prefix: "/"
        options: ({ backend: "disk", show_path: true, show_preview: false })
    }

    property Provider githubNotifications: Provider {
        enabled: true
        prefix: "gh"
        options: ({ token: "env" })
    }

    property Provider hackerNews: Provider {
        enabled: false
        prefix: "hn"
        options: ({ cache_ttl: 300, max_items: 30 })
    }

    property Provider ipInfo: Provider {
        enabled: false
        prefix: "ip"
    }

    property Provider killProcess: Provider {
        enabled: false
        prefix: "!"
    }

    property Provider portViewer: Provider {
        enabled: false
        prefix: "pv"
        options: ({ tcp_listening_only: true, include_established: false })
    }

    property Provider settings: Provider {
        enabled: false
        prefix: "@"
    }

    property Provider snippets: Provider {
        enabled: false
        prefix: ";"
        options: ({ type_delay: 200 })
    }

    property Provider ssh: Provider {
        enabled: false
        prefix: "ssh"
        options: ({ ssh_config_path: "" })
    }

    property Provider systemCommands: Provider {
        enabled: true
        prefix: ">"
    }

    property Provider unitConverter: Provider {
        enabled: false
        prefix: "~"
    }

    property Provider vscode: Provider {
        enabled: false
        prefix: "vsc"
        options: ({ state_storage_path: "" })
    }

    property Provider webSearch: Provider {
        enabled: false
        prefix: "?"
        options: ({ engine: "google", custom_engines: [], remove_engines: [] })
    }

    // GlazeWM's workspaces and windows, from this setup rather than YASB (GlazeWalker.qml): type the prefix and a
    // space, or press walkerHotkey. Enter goes there, Shift+Enter brings the window to your workspace (on a workspace:
    // sends your window there), Ctrl+W closes it. "" for no hotkey; walkerPrefix "" turns it off.
    property string walkerPrefix: "ws"
    property string walkerHotkey: "alt+grave"
    property string walkerPlaceholder: "Search GlazeWM windows and workspaces..."
    property string glazewmUri: "ws://localhost:6123"
    readonly property bool walking: walkerPrefix !== "" && prefix === walkerPrefix

    // YASB's own window switcher, which knows nothing of GlazeWM's workspaces; the `ws` prefix above does
    property Provider windowSwitcher: Provider {
        enabled: false
        prefix: "win"
    }

    property Provider windowsTerminal: Provider {
        enabled: false
        prefix: "wt"
    }

    property Provider worldClock: Provider {
        enabled: false
        prefix: "tz"
    }

    property Provider wsl: Provider {
        enabled: false
        prefix: "wsl"
        options: ({ show_online: true })
    }

    // The most results the launcher lists, and the most each provider looks for
    property int maxResults: 50
    // With nothing typed, list the providers that have a prefix instead of the apps
    property bool homePage: false
    property string placeholder: "Search applications..."
    property bool rememberLastQuery: false
    property bool showIcons: true
    property int resultIconSize: 24
    property int popupWidth: 720
    property int popupHeight: 480
    // The glyph on the bar, drawn in iconFont and the text colour
    property string icon: "\ue721"
    property int iconSize: 14

    readonly property bool dark: bar ? bar.dark : Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    property color textColor: bar?.theme.colors.text ?? (dark ? "#ffffff" : "#000000")
    // Glyphs take the family and weight of the bar's icon font unless the widget file sets them
    property font iconFont
    iconFont.family: bar?.iconFont?.family ?? "Segoe Fluent Icons"
    iconFont.weight: bar?.iconFont?.weight ?? Font.Normal
    readonly property color foreground: dark ? "#f3f3f3" : "#1b1b1b"
    readonly property color secondary: dark ? "#9a9a9a" : "#5f5f5f"
    readonly property color hover: Qt.alpha(foreground, 0.06)
    readonly property color selected: Qt.alpha(foreground, 0.1)

    property string prefix: ""
    property bool previewShown: false

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    // The bar's one bottom panel, which Search shares with Wallpapers and Sound, and this panel's content in it
    property QtObject panelHost: null
    property Item view: null
    readonly property bool panelOpen: panelHost?.isOpen("search") ?? false

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("search", panelContent, launcher)
        }
    }

    function toggle() {
        panelHost?.toggle("search", launcher)
    }

    // A prefix typed with its space at the start of the text: the walker's or a search provider's
    function typedPrefix(text: string): string {
        if (walkerPrefix !== "" && text.startsWith(`${walkerPrefix} `))
            return walkerPrefix
        return search.prefixes.find(p => text.startsWith(`${p.prefix} `))?.prefix ?? ""
    }

    function showQuery(text: string) {
        if (!panelOpen)
            panelHost?.show("search", launcher)
        const typed = typedPrefix(text) !== "" ? { prefix: typedPrefix(text) } : null
        if (typed) {
            setPrefix(typed.prefix, text.slice(typed.prefix.length + 1))
        } else {
            prefix = ""
            if (view)
                view.field.text = text
            runSearch()
        }
    }

    function runSearch() {
        view?.runSearch()
    }

    function setPrefix(value: string, text: string) {
        prefix = value
        view?.setText(text)
    }

    function select(step: int) {
        if (walking)
            walker.select(step)
        else
            view?.select(step)
    }

    // Opens Search on GlazeWM's windows, or closes it when it already shows them
    function toggleWalker() {
        if (panelOpen && walking) {
            panelHost?.hide()
            return
        }
        if (!panelOpen)
            panelHost?.show("search", launcher)
        setPrefix(walkerPrefix, "")
    }

    function showMenu(row: int, item: Item) {
        view?.showMenu(row, item)
    }

    component SvgIcon: IconImage {
        sourceSize: Qt.size(width, height)
    }

    BarButton {
        id: barButton

        anchors.centerIn: parent
        glyph: launcher.icon
        glyphSize: launcher.iconSize
        open: launcher.panelOpen
        tip: `Search (${PanelBus.label(launcher.hotkey)})`
        onClicked: launcher.toggle()
    }

    Hotkey {
        keys: launcher.hotkey
        screen: launcher.hotkeyScreen
        onActivated: launcher.toggle()
    }

    Component.onCompleted: PanelBus.register("search", launcher.hotkey)

    Hotkey {
        // No keys, no hotkey
        keys: launcher.walkerPrefix !== "" ? launcher.walkerHotkey : ""
        screen: launcher.hotkeyScreen
        onActivated: launcher.toggleWalker()
    }

    GlazeWalker {
        id: walker

        serverUri: launcher.glazewmUri
        open: launcher.panelOpen && launcher.walking
        onCloseRequested: launcher.panelHost?.hide()
        onOpenChanged: {
            if (open)
                start()
        }
    }

    QuickLaunchSearch {
        id: search

        maxResults: launcher.maxResults
        homePage: launcher.homePage
        providers: ({
            apps: settingsOf(launcher.apps),
            bookmarks: settingsOf(launcher.bookmarks),
            calculator: settingsOf(launcher.calculator),
            clipboard_history: settingsOf(launcher.clipboardHistory),
            color: settingsOf(launcher.color),
            binance: settingsOf(launcher.binance),
            currency: settingsOf(launcher.currency),
            dev_tools: settingsOf(launcher.devTools),
            emoji: settingsOf(launcher.emoji),
            file_search: settingsOf(launcher.fileSearch),
            github_notifications: settingsOf(launcher.githubNotifications),
            hacker_news: settingsOf(launcher.hackerNews),
            ip_info: settingsOf(launcher.ipInfo),
            kill_process: settingsOf(launcher.killProcess),
            port_viewer: settingsOf(launcher.portViewer),
            settings: settingsOf(launcher.settings),
            snippets: settingsOf(launcher.snippets),
            ssh: settingsOf(launcher.ssh),
            system_commands: settingsOf(launcher.systemCommands),
            unit_converter: settingsOf(launcher.unitConverter),
            vscode: settingsOf(launcher.vscode),
            web_search: settingsOf(launcher.webSearch),
            window_switcher: settingsOf(launcher.windowSwitcher),
            windows_terminal: settingsOf(launcher.windowsTerminal),
            world_clock: settingsOf(launcher.worldClock),
            wsl: settingsOf(launcher.wsl)
        })

        function settingsOf(provider: Provider): var {
            return Object.assign({ enabled: provider.enabled, prefix: provider.prefix, priority: provider.priority },
                provider.options)
        }

        onCloseRequested: launcher.panelHost?.hide()
        onQueryRequested: text => launcher.showQuery(text)
        onColorPickRequested: prefix => {
            launcher.panelHost?.hide()
            colorPicker.prefix = prefix
            colorPicker.start()
        }
    }

    ColorPicker {
        id: colorPicker

        property string prefix

        quickLaunch: search
        onPicked: color => launcher.showQuery(prefix + color)
    }

    Component.onDestruction: panelHost?.withdraw("search", launcher)

    // What Search shows in the bottom panel: the field and results on the left, and on the right the preview,
    // or the time, weather, music and load
    property Component panelContent: Component {
        Item {
            id: searchView

            property alias field: field

            function runSearch() {
                if (launcher.walking)
                    walker.search(field.text)
                else
                    search.search(launcher.prefix ? `${launcher.prefix} ${field.text}` : field.text)
            }

            function setText(text) {
                field.text = text
                field.forceActiveFocus()
                runSearch()
            }

            function select(step) {
                let row = list.currentIndex
                for (let i = 0; i < list.count; i++) {
                    row = Math.max(0, Math.min(list.count - 1, row + step))
                    if (!list.itemAtIndex(row)?.separator)
                        break
                }
                list.currentIndex = row
            }

            function showMenu(row, item) {
                const actions = search.contextActions(row)
                if (!actions.length)
                    return
                list.currentIndex = row
                menu.row = row
                menu.actions = actions
                menu.popup(item)
            }

            // fresh: the panel has just slid up, rather than been switched to from another tab
            function panelShown(fresh) {
                if (fresh && !launcher.rememberLastQuery) {
                    launcher.prefix = ""
                    field.text = ""
                }
                search.activate(searchView.Window.window)
                if (launcher.walking)
                    walker.start()
                field.forceActiveFocus()
                field.selectAll()
                runSearch()
            }

            function panelHidden() {
                search.deactivate()
            }

            Component.onCompleted: launcher.view = searchView
            Component.onDestruction: {
                if (launcher.view === searchView)
                    launcher.view = null
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // The search field and the results
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    TextField {
                        id: field

                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        leftPadding: prefixChip.visible ? prefixChip.x + prefixChip.width + 6 : 46
                        rightPadding: 16
                        background: Rectangle {
                            radius: 12 * PanelBus.radiusScale
                            color: Qt.alpha(launcher.textColor, 0.045)
                            border.width: 1
                            border.color: Qt.alpha(PanelBus.accent, field.activeFocus ? 0.45 : 0.2)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: launcher.textColor
                            font.family: launcher.iconFont.family
                            font.weight: launcher.iconFont.weight
                            font.pixelSize: 18
                        }

                        Label {
                            id: prefixChip

                            // Its text starts where the prefix was typed, so it stays in place
                            x: 46 - leftPadding
                            anchors.verticalCenter: parent.verticalCenter
                            visible: launcher.prefix !== ""
                            text: launcher.prefix
                            font.family: PanelBus.font.family
                            font.pixelSize: field.font.pixelSize
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 3
                            bottomPadding: 3
                            background: Rectangle {
                                radius: 4 * PanelBus.radiusScale
                                color: Qt.alpha(launcher.textColor, 0.1)
                            }
                        }

                        placeholderText: launcher.walking ? launcher.walkerPlaceholder
                            : launcher.prefix ? search.prefixes.find(p => p.prefix === launcher.prefix)?.placeholder ?? ""
                            : launcher.placeholder
                        font.family: PanelBus.font.family
                        font.pixelSize: 18
                        verticalAlignment: TextInput.AlignVCenter

                        onTextEdited: {
                            const typed = launcher.typedPrefix(text)
                            if (!launcher.prefix && typed)
                                launcher.setPrefix(typed, text.slice(typed.length + 1))
                            else
                                launcher.runSearch()
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                                launcher.select(event.key === Qt.Key_Down ? 1 : -1)
                            } else if (launcher.walking && (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)) {
                                walker.select(event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier) ? 1 : -1)
                            } else if (launcher.walking && (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
                                walker.select(event.key === Qt.Key_PageDown ? 8 : -8)
                            } else if (launcher.walking && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    walker.bringHere(walker.selected)
                                else
                                    walker.activate(walker.selected)
                            } else if (launcher.walking && event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
                                walker.closeWindow(walker.selected)
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                search.execute(list.currentIndex)
                            } else if (event.key === Qt.Key_Right && !launcher.walking && search.prediction && cursorPosition === text.length) {
                                text = search.prediction
                                launcher.runSearch()
                            } else if (event.key === Qt.Key_Backspace && launcher.prefix && cursorPosition === 0
                                       && selectedText === "") {
                                launcher.prefix = ""
                                launcher.runSearch()
                            } else if (event.key === Qt.Key_P && event.modifiers === Qt.AltModifier) {
                                launcher.previewShown = !launcher.previewShown
                            } else {
                                return
                            }
                            event.accepted = true
                        }

                        Label {
                            x: field.leftPadding + field.contentWidth
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !launcher.walking && search.prediction !== "" && field.cursorPosition === field.text.length
                            text: search.prediction.slice(field.text.length)
                            font: field.font
                            opacity: 0.4
                        }
                    }

                    LoadingLine {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        running: search.loading && !launcher.walking
                        trackColor: "transparent"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        WalkerList {
                            anchors.fill: parent
                            visible: launcher.walking
                            glaze: walker
                            iconSize: launcher.resultIconSize
                        }

                        ListView {
                            id: list

                            anchors.fill: parent
                            visible: !launcher.walking
                            clip: true
                            spacing: 2
                            model: search.results
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            ScrollBar.vertical: ScrollBar {}

                            Connections {
                                target: search.results

                                function onModelReset() {
                                    list.currentIndex = -1
                                    Qt.callLater(launcher.select, 1)
                                }
                            }

                            // One line per result: icon, title, then the description dimmer
                            delegate: Item {
                                id: row

                                required property int index
                                required property string title
                                required property string description
                                required property string icon
                                required property string iconText
                                required property bool separator
                                required property string path

                                width: ListView.view.width
                                height: separator ? 26 : 38

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 9 * PanelBus.radiusScale
                                    visible: !row.separator
                                    color: row.ListView.isCurrentItem ? Qt.alpha(PanelBus.accent, 0.12)
                                        : mouse.containsMouse ? Qt.alpha(launcher.textColor, 0.06) : "transparent"
                                }

                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    visible: row.separator
                                    text: row.title
                                    color: Qt.alpha(launcher.textColor, 0.55)
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Item {
                                    id: iconBox

                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: launcher.resultIconSize
                                    height: launcher.resultIconSize
                                    visible: launcher.showIcons && !row.separator

                                    Image {
                                        anchors.fill: parent
                                        visible: row.icon !== ""
                                        source: row.icon
                                        sourceSize: Qt.size(launcher.resultIconSize, launcher.resultIconSize)
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: row.icon === ""
                                        text: row.iconText
                                        font.family: "Segoe UI Emoji"
                                        font.pixelSize: launcher.resultIconSize * 0.75
                                    }
                                }

                                RowLayout {
                                    anchors.left: iconBox.visible ? iconBox.right : parent.left
                                    anchors.leftMargin: 12
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !row.separator
                                    spacing: 10

                                    Label {
                                        Layout.maximumWidth: Math.round(row.width * 0.5)
                                        text: row.title
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        font.family: PanelBus.font.family
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: row.description
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                        color: Qt.alpha(launcher.textColor, 0.55)
                                        font.family: PanelBus.font.family
                                        font.pixelSize: 12
                                    }

                                    Label {
                                        visible: row.ListView.isCurrentItem
                                        text: "Enter"
                                        color: Qt.alpha(launcher.textColor, 0.55)
                                        font.family: "Consolas"
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: mouse

                                    anchors.fill: parent
                                    enabled: !row.separator
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    drag.target: row.path ? dragItem : null

                                    onClicked: event => {
                                        if (event.button === Qt.RightButton)
                                            launcher.showMenu(row.index, row)
                                        else {
                                            list.currentIndex = row.index
                                            search.execute(row.index)
                                        }
                                    }
                                }

                                Item {
                                    id: dragItem

                                    Drag.active: mouse.drag.active
                                    Drag.dragType: Drag.Automatic
                                    Drag.supportedActions: Qt.CopyAction | Qt.LinkAction
                                    Drag.mimeData: ({ "text/uri-list": `file:///${row.path.replace(/\\/g, "/")}` })
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            visible: list.count === 0 && !search.loading && !launcher.walking

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Qt.resolvedUrl("icons/search-main.svg")
                                sourceSize: Qt.size(48, 48)
                            }

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: field.text || launcher.prefix ? "No results" : "Type to search..."
                                color: Qt.alpha(launcher.textColor, 0.55)
                            }
                        }
                    }
                }

                // What the keys do for the selected workspace or window
                Label {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    visible: launcher.walking
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideLeft
                    color: Qt.alpha(launcher.textColor, 0.55)
                    font.family: PanelBus.font.family
                    font.pixelSize: 11
                    text: {
                        const row = walker.selected
                        const parts = []
                        if (!walker.connected)
                            parts.push(qsTr("GlazeWM isn't running: windows from Windows only"))
                        if (row?.kind === "workspace") {
                            parts.push(qsTr("Enter go there"))
                            if (walker.connected && walker.focusedWindow !== "" && row.name !== walker.focusedWorkspace)
                                parts.push(qsTr("Shift+Enter send your window there"))
                        } else if (row?.kind === "window") {
                            parts.push(qsTr("Enter go to it"))
                            if (walker.connected && row.managed && row.workspace !== walker.focusedWorkspace)
                                parts.push(qsTr("Shift+Enter bring it here"))
                            parts.push(qsTr("Ctrl+W close"))
                        }
                        return parts.join("   ·   ")
                    }
                }

                // The selected result's preview, below the results (Alt+P shows it for any result)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 14
                    Layout.bottomMargin: 14
                    visible: preview.visible
                    color: Qt.alpha(launcher.textColor, 0.08)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: preview.visible ? Math.min(340, searchView.height * 0.45) : 0
                    visible: preview.visible

                    Preview {
                        id: preview

                        anchors.fill: parent
                        dark: true
                        secondary: Qt.alpha(launcher.textColor, 0.55)
                        content: !launcher.walking && list.currentIndex >= 0 ? search.preview(list.currentIndex) : ({})
                        forced: launcher.previewShown
                        onAction: (id, values) => search.previewAction(list.currentIndex, id, values)
                        onCancelled: search.cancelEdit()
                    }
                }
            }

            Menu {
                id: menu

                property int row: -1
                property var actions: []

                Instantiator {
                    model: menu.actions

                    delegate: MenuItem {
                        required property var modelData

                        text: modelData.label
                        enabled: modelData.enabled
                        onTriggered: search.runContextAction(menu.row, modelData.id)
                    }

                    onObjectAdded: (index, object) => menu.insertItem(index, object)
                    onObjectRemoved: (index, object) => menu.removeItem(object)
                }
            }
        }
    }
}
