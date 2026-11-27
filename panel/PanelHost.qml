import QtQuick
import QtQuick.Controls
import Yasb.Common

// The panels of a bar's widgets. Every bar widget with a page hands it here with provide(); its button opens it as a
// card under the button, a gap below the bar like the calendar. One shows at a time: opening another closes the
// first and opens the new one in its own place. Esc, a click outside, or the page's own button closes it.
//
// A page is a Component (made the first time it opens) or an Item (moved into the panel as it is). It can have
// panelShown(fresh) and panelHidden(); fresh is always true, as every page opens on its own.
QtObject {
    id: host

    // Pages by name: { component, item, widget }
    property var contents: ({})
    property string current: ""
    // Which Component pages have been opened, so they stay made and open again at once
    property var made: ({})
    // An item over the bar's solid part: presses on it don't count as presses outside the panel, so another
    // button on the bar opens its own page instead of only closing this one
    property Item anchor: null
    // The panel's size, and the screen x it centres on (under its page's button)
    property real panelWidth: 440
    property real panelHeight: 600
    property real panelCenter: 0
    // The space between the bar and the card: the theme's, as for the calendar
    readonly property real gap: PanelBus.theme?.popup.gap ?? 6
    // The tallest the panel can be on this screen, under the bar
    property real maxHeight: 600
    // The screen's left and right edge, inside the frame
    property real screenLeft: 0
    property real screenRight: 1920
    readonly property real panelLeft: Math.round(Math.max(screenLeft,
        Math.min(screenRight - panelWidth, panelCenter - panelWidth / 2)))

    readonly property bool shown: popup.visible && !popup.closing
    readonly property alias pinned: popup.pinned

    function provide(name: string, page: var, widget: Item) {
        const copy = Object.assign({}, contents)
        const isComponent = typeof page?.createObject === "function"
        copy[name] = { component: isComponent ? page : null, item: isComponent ? null : page, widget: widget }
        if (!isComponent && page)
            page.visible = false
        contents = copy
    }

    // When a widget goes away, as on a config reload
    function withdraw(name: string, widget: Item) {
        const entry = contents[name]
        if (entry?.widget !== widget)
            return
        if (current === name)
            popup.hide()
        if (entry.item)
            entry.item.parent = null
        const copy = Object.assign({}, contents)
        delete copy[name]
        contents = copy
        const done = Object.assign({}, made)
        delete done[name]
        made = done
    }

    function viewFor(name: string): Item {
        const index = PanelBus.panels.findIndex(panel => panel.name === name)
        return index >= 0 ? (pages.itemAt(index)?.view ?? null) : null
    }

    function isOpen(name: string): bool {
        return shown && current === name
    }

    function setPinned(on: bool) {
        popup.pinned = on
    }

    property Component anchorComponent: Component {
        Item {
            width: parent ? parent.width : 0
            height: PanelBus.barHeight
        }
    }

    // The screen x of a widget's middle, which its page centres under
    function centerOf(widget: Item): real {
        return widget ? widget.mapToGlobal(widget.width / 2, 0).x : panelCenter
    }

    function show(name: string, widget: Item) {
        const entry = contents[name]
        if (!entry)
            return
        if (shown && current === name)
            return
        // Another page is open: it goes at once, and this one opens in its own place
        if (popup.visible)
            popup.hide()
        const owner = widget ?? entry.widget
        const root = owner?.Window.window?.contentItem ?? null
        if (root && anchor?.parent !== root) {
            anchor?.destroy()
            anchor = anchorComponent.createObject(root)
        }
        if (entry.component && !made[name]) {
            const done = Object.assign({}, made)
            done[name] = true
            made = done
        }
        current = name
        const screen = owner.Screen
        const margin = PanelBus.rail + 8
        const size = PanelBus.panelSize(name)
        maxHeight = screen.height - PanelBus.barHeight - host.gap - margin - 16
        screenLeft = screen.virtualX + margin
        screenRight = screen.virtualX + screen.width - margin
        panelWidth = size.width
        panelHeight = Math.min(size.height, maxHeight)
        if (PanelBus.isCentered(name)) {
            // In the middle of the screen, like a launcher
            panelCenter = screen.virtualX + screen.width / 2
            popup.y = Math.round(screen.virtualY + Math.max(PanelBus.barHeight + host.gap, (screen.height - panelHeight) / 2))
        } else {
            panelCenter = centerOf(owner)
            popup.y = screen.virtualY + PanelBus.barHeight + host.gap
        }
        popup.open()
        viewFor(name)?.panelShown?.(true)
    }

    function toggle(name: string, widget: Item) {
        if (isOpen(name))
            hide()
        else
            show(name, widget)
    }

    function hide() {
        popup.close()
    }

    Component.onCompleted: PanelBus.otherAppActivated.connect(() => {
        if (popup.visible && !popup.pinned)
            hide()
    })

    property BackdropPopup popup: BackdropPopup {
        id: popup

        property real reveal: 0

        title: "Panel"
        theme: PanelBus.theme
        // Every Label and control in the panel takes the theme's font
        font: PanelBus.font
        x: host.panelLeft
        width: host.panelWidth
        height: host.panelHeight
        anchor: host.anchor
        // Blurred behind, like the calendar, on a bar with `backdrop: true`
        backdropItem: surface.card
        enter: NumberAnimation { target: popup; property: "reveal"; to: 1; duration: PanelBus.openDuration; easing.type: PanelBus.openEasing }
        exit: NumberAnimation { target: popup; property: "reveal"; to: 0; duration: PanelBus.closeDuration; easing.type: PanelBus.closeEasing }
        onVisibleChanged: {
            if (!visible) {
                host.viewFor(host.current)?.panelHidden?.()
                reveal = 0
                pinned = false
                host.current = ""
            }
        }

        PanelSurface {
            id: surface

            anchors.fill: parent
            reveal: popup.reveal
            // The panel is always dark, so its controls take the panel's text colour whatever Windows' own light
            // or dark mode is
            palette.window: PanelBus.color
            palette.base: PanelBus.surface
            palette.button: PanelBus.raised
            palette.windowText: PanelBus.textColor
            palette.text: PanelBus.textColor
            palette.buttonText: PanelBus.textColor
            palette.placeholderText: Qt.alpha(PanelBus.textColor, 0.4)
            palette.highlight: PanelBus.accent
            palette.highlightedText: PanelBus.onAccent
            palette.accent: PanelBus.accent

            // The title's band, for a theme with a header fill, such as an accent block; none in this setup's own
            // theme. As tall as the title row with the space around it, inside the card's outline
            Rectangle {
                readonly property real inset: PanelBus.borderWidth

                visible: PanelBus.headerBackground.a > 0
                x: inset
                y: inset
                width: surface.width - 2 * inset
                height: stage.y + 30 + 14 - inset
                topLeftRadius: Math.max(0, surface.card.radius - inset)
                topRightRadius: Math.max(0, surface.card.radius - inset)
                color: PanelBus.headerBackground

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: PanelBus.dividerWidth
                    color: PanelBus.divider
                }
            }

            // Every page sits here; only the current one shows
            Item {
                id: stage

                x: 20
                y: 14
                width: surface.panelWidth - 40
                height: surface.height - y - 20
                clip: true

                Repeater {
                    id: pages

                    model: PanelBus.panels

                    delegate: Item {
                        id: page

                        required property var modelData
                        readonly property string name: modelData.name
                        readonly property var entry: host.contents[name] ?? null
                        readonly property bool isCurrent: host.current === name
                        readonly property Item view: entry?.item ?? loader.item ?? null

                        anchors.fill: parent
                        visible: !!entry && isCurrent

                        function attach() {
                            const item = entry?.item
                            if (!item || item.parent === holder)
                                return
                            item.parent = holder
                            item.anchors.fill = holder
                            item.visible = true
                        }

                        onEntryChanged: attach()
                        Component.onCompleted: attach()

                        // The page's name and hotkey
                        Item {
                            id: header

                            width: parent.width
                            height: 30

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.modelData.title
                                color: PanelBus.headerBackground.a > 0 ? PanelBus.headerText : PanelBus.textColor
                                font.family: PanelBus.font.family
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                font.capitalization: PanelBus.headingCapitalization
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: text !== ""
                                text: PanelBus.label(PanelBus.keys[page.name] ?? "")
                                color: PanelBus.headerBackground.a > 0 ? Qt.alpha(PanelBus.headerText, 0.7) : PanelBus.textDim
                                font.family: PanelBus.font.family
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            id: holder

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: header.bottom
                            anchors.topMargin: 14
                            anchors.bottom: parent.bottom
                        }

                        Loader {
                            id: loader

                            anchors.fill: holder
                            active: !!page.entry?.component && !!host.made[page.name]
                            sourceComponent: page.entry?.component ?? null
                        }
                    }
                }
            }
        }
    }
}
