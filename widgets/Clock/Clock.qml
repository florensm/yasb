pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes
import "../../panel"
import "ics.js" as Ics

Label {
    id: clock

    // A left or right bar stacks the parts, as it is too narrow for them side by side
    property string format: vertical ? "HH\nmm" : "ddd d MMM  HH:mm"
    // On a top or bottom bar: the date a little dimmer (`dateFormat`), then the time in bold (`timeFormat`). false
    // shows `format` as plain text instead. Names follow `locale`: "Fri 6 Nov" in English, "vr 6 nov." in Dutch.
    property bool styledParts: !vertical
    property string dateFormat: "ddd d MMM"
    property string timeFormat: "HH:mm"
    property string alternateFormat: vertical ? "ddd\nd\nMMM" : "ddd d MMM yyyy  HH:mm"
    property string locale: ""
    property var timeZones: []
    property bool showWeekNumbers: false
    required property BarBase bar
    readonly property Theme theme: bar.theme

    property bool showAlternate: false
    property int timeZoneIndex: 0

    readonly property string activeFormat: showAlternate ? alternateFormat : format
    readonly property string timeZone: timeZones.length > 0 ? timeZones[timeZoneIndex % timeZones.length] : ""
    readonly property bool dark: theme.dark
    property color accentColor: theme.colors.accent
    // Today's number in the calendar, on the accent colour
    property color todayTextColor: theme.colors.textOnAccent
    // The popup: the theme's, unless set here
    property color popupColor: theme.popup.background
    property color popupBorderColor: theme.popup.border
    property color popupTextColor: theme.colors.text
    property real popupRadius: PanelBus.popupRadius
    property real popupGap: theme.popup.gap
    // Text in the popup: the theme's font family, in this widget's sizes
    property font popupFont
    popupFont.family: theme.popup.font.family
    popupFont.pixelSize: 13
    property font popupSmallFont
    popupSmallFont.family: theme.popup.font.family
    popupSmallFont.pixelSize: 12
    property int popupOpenDuration: theme.popup.openDuration
    property int popupCloseDuration: theme.popup.closeDuration
    property font popupTitleFont
    popupTitleFont.family: theme.popup.font.family
    popupTitleFont.pixelSize: 16
    popupTitleFont.weight: Font.DemiBold
    // The arrows that change the month, the weekday names and the week numbers
    property font arrowFont
    arrowFont.family: theme.popup.font.family
    arrowFont.pixelSize: 18
    property font weekdayFont
    weekdayFont.family: theme.popup.font.family
    weekdayFont.pixelSize: 11
    property font weekNumberFont
    weekNumberFont.family: theme.popup.font.family
    weekNumberFont.pixelSize: 11
    property color popupDividerColor: theme.colors.divider
    readonly property string edge: bar.edge
    readonly property bool vertical: bar.vertical

    function nextTick(): int {
        const time = new Date()
        if (activeFormat.includes("s"))
            return 1000 - time.getMilliseconds()
        return 60000 - time.getSeconds() * 1000 - time.getMilliseconds()
    }

    function refresh() {
        const part = pattern => zones.format(timeZone, pattern, locale)
        text = styledParts && !showAlternate
            ? `<font color="${theme.colors.textSecondary}">` + part(dateFormat) + "</font>&nbsp;&nbsp;&nbsp;"
                + (PanelBus.barAccent === "off" ? "<b>" + part(timeFormat) + "</b>"
                    : `<b><font color="${PanelBus.accent}">` + part(timeFormat) + "</font></b>")
            : part(activeFormat)
        tick.interval = nextTick()
        tick.restart()
    }

    function toggleFormat() {
        showAlternate = !showAlternate
    }

    function nextTimeZone() {
        if (timeZones.length > 1)
            timeZoneIndex = (timeZoneIndex + 1) % timeZones.length
    }

    function toggleCalendar() {
        if (calendar.visible) {
            calendar.close()
            return
        }
        const [year, month, day] = zones.format(timeZone, "yyyy-M-d", "C").split("-").map(Number)
        calendar.today = new Date(year, month - 1, day)
        calendar.month = calendar.today.getMonth()
        calendar.year = calendar.today.getFullYear()
        placePopup()
        calendar.open()
    }

    function placePopup() {
        const start = mapToGlobal(0, 0)
        let px = edge === "left" ? start.x + width + popupGap
            : edge === "right" ? start.x - calendar.width - popupGap : start.x + (width - calendar.width) / 2
        let py = edge === "top" ? start.y + height + popupGap
            : edge === "bottom" ? start.y - calendar.height - popupGap : start.y + (height - calendar.height) / 2
        const screen = clock.Screen
        px = Math.max(screen.virtualX + 8, Math.min(px, screen.virtualX + screen.width - calendar.width - 8))
        py = Math.max(screen.virtualY + 8, Math.min(py, screen.virtualY + screen.desktopAvailableHeight - calendar.height - 8))
        calendar.x = Math.round(px)
        calendar.y = Math.round(py)
    }

    // The theme's text colour; the font comes from the bar, but on a side bar the time is stacked, a little larger
    // and bolder
    color: clock.popupTextColor
    font.pixelSize: vertical ? 14 : theme.bar.font.pixelSize
    font.weight: vertical ? Font.DemiBold : theme.bar.font.weight
    textFormat: styledParts && !showAlternate ? Text.StyledText : Text.PlainText
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    leftPadding: vertical ? 0 : 6
    rightPadding: vertical ? 0 : 6

    Component.onCompleted: refresh()
    onActiveFormatChanged: refresh()
    onStyledPartsChanged: refresh()
    onDateFormatChanged: refresh()
    onTimeFormatChanged: refresh()
    onTimeZoneChanged: refresh()
    onLocaleChanged: refresh()
    Component.onDestruction: calendar.hide()

    // Another program coming to the front closes the calendar; the bar's accent colours the time
    Connections {
        target: PanelBus

        function onBarAccentChanged() {
            clock.refresh()
        }

        function onAccentChanged() {
            clock.refresh()
        }

        function onOtherAppActivated() {
            calendar.close()
        }
    }

    TimeZones {
        id: zones
    }

    Timer {
        id: tick

        onTriggered: clock.refresh()
    }

    Connections {
        target: clock.Window.window
        function onVisibleChanged() {
            if (!clock.Window.window?.visible)
                calendar.hide()
        }
        function onXChanged() { if (calendar.visible) clock.placePopup() }
        function onYChanged() { if (calendar.visible) clock.placePopup() }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                clock.toggleCalendar()
            else if (mouse.button === Qt.MiddleButton)
                clock.nextTimeZone()
            else
                clock.toggleFormat()
        }
    }

    // The calendars whose events the popup shows: iCal links, kept with the control center's settings, so a new copy
    // of these files keeps them. Added and removed in the popup (the calendar button at the bottom)
    Settings {
        id: feedStore

        location: Qt.resolvedUrl("../../control-center.ini")
        category: "calendars"
        property string feeds: "[]"
    }

    // The events of those calendars, fetched straight from their links (no account, no script) and listed by day
    QtObject {
        id: agenda

        readonly property var feeds: {
            try {
                const list = JSON.parse(feedStore.feeds)
                return Array.isArray(list) ? list : []
            } catch (error) {
                return []
            }
        }
        // url: { events, error, time }
        property var loaded: ({})
        // "2026-11-20": [{ summary, location, start, end, allDay, color, calendar }]
        property var days: ({})
        property int busy: 0
        // The first calendar in the accent, the others in colours whose hue stays clear of it
        readonly property var colors: {
            const accent = PanelBus.accent
            const others = ["#5B8DEF", "#E5484D", "#30A46C", "#F2A65A", "#8E4EC6", "#12A594", "#D6409F"].filter(c => {
                const hue = Qt.color(c).hslHue
                const gap = Math.abs(hue - accent.hslHue)
                return accent.hslSaturation < 0.15 || Math.min(gap, 1 - gap) > 0.08
            })
            return [accent].concat(others)
        }

        function colorAt(index: int): color {
            return colors[index % colors.length]
        }

        function fetchAll(force: bool) {
            for (const feed of feeds) {
                const known = loaded[feed.url]
                if (force || !known || Date.now() - known.time > 15 * 60000)
                    fetch(feed.url)
            }
        }

        function fetch(url: string) {
            const request = new XMLHttpRequest()
            busy++
            request.onreadystatechange = () => {
                if (request.readyState !== XMLHttpRequest.DONE)
                    return
                busy--
                const next = Object.assign({}, loaded)
                const text = request.status === 200 ? request.responseText : ""
                next[url] = text.includes("BEGIN:VCALENDAR")
                    ? { events: Ics.parse(text), error: "", time: Date.now() }
                    : { events: loaded[url]?.events ?? [], time: Date.now(),
                        error: request.status === 200 ? "Not an iCal calendar"
                            : request.status ? `Error ${request.status}` : "Can't reach it" }
                loaded = next
                rebuild()
            }
            request.open("GET", url.replace(/^webcal:/i, "https:"))
            request.send()
        }

        // The shown month with the days around it in the grid
        function rebuild() {
            const from = new Date(calendar.year, calendar.month, -7)
            const to = new Date(calendar.year, calendar.month + 1, 15)
            days = Ics.byDay(feeds.map((feed, index) => ({
                events: loaded[feed.url]?.events ?? [], color: colorAt(index), name: feed.name
            })), from, to)
        }

        function eventsOn(date: date): var {
            return days[Ics.dayKey(date)] ?? []
        }

        function add(name: string, url: string): bool {
            url = url.trim()
            if (!/^(https?|webcal):\/\//i.test(url) || feeds.some(feed => feed.url === url))
                return false
            feedStore.feeds = JSON.stringify(feeds.concat([{ name: name.trim() || `Calendar ${feeds.length + 1}`, url: url }]))
            fetch(url)
            return true
        }

        function remove(index: int) {
            const list = feeds.slice()
            list.splice(index, 1)
            feedStore.feeds = JSON.stringify(list)
            rebuild()
        }

        onColorsChanged: rebuild()
        Component.onCompleted: fetchAll(false)
    }

    // A fresh copy every quarter hour
    Timer {
        interval: 15 * 60000
        running: agenda.feeds.length > 0
        repeat: true
        onTriggered: agenda.fetchAll(true)
    }

    BackdropPopup {
        id: calendar

        property real reveal: 0
        property date today: new Date()
        property int month: today.getMonth()
        property int year: today.getFullYear()
        // The day whose events show below the month
        property date selected: today
        // The list of calendars instead of the events
        property bool managing: false
        property date now: new Date()

        // Names in English unless the widget sets a `locale`
        readonly property var locale: Qt.locale(clock.locale || "en_GB")

        function showMonth(offset: int) {
            const shown = new Date(year, month + offset, 1)
            month = shown.getMonth()
            year = shown.getFullYear()
        }

        function sameDay(a: date, b: date): bool {
            return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
        }

        function isToday(date: date): bool {
            return sameDay(date, today)
        }

        // The ISO week number: weeks start on Monday, week 1 holds the year's first Thursday
        function weekOf(date: date): int {
            const thursday = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 3 - (date.getDay() + 6) % 7)
            const first = new Date(thursday.getFullYear(), 0, 4)
            return 1 + Math.round(((thursday - first) / 86400000 - 3 + (first.getDay() + 6) % 7) / 7)
        }

        function dayName(date: date): string {
            const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1)
            return isToday(date) ? "Today" : sameDay(date, tomorrow) ? "Tomorrow" : date.toLocaleDateString(locale, "dddd d MMMM")
        }

        function timeOf(event: var): string {
            if (event.allDay)
                return "All day"
            const start = event.start.toLocaleTimeString(locale, "HH:mm")
            return event.end > event.start ? start + " – " + event.end.toLocaleTimeString(locale, "HH:mm") : start
        }

        objectName: "calendar"
        title: "Calendar"
        width: 320
        height: popupContent.implicitHeight + 36
        anchor: clock
        font: clock.popupFont
        theme: clock.theme
        backdropItem: surface
        enter: NumberAnimation { target: calendar; property: "reveal"; to: 1; duration: clock.popupOpenDuration; easing.type: PanelBus.openEasing }
        exit: NumberAnimation { target: calendar; property: "reveal"; to: 0; duration: clock.popupCloseDuration; easing.type: PanelBus.closeEasing }
        onVisibleChanged: {
            if (visible) {
                selected = today
                managing = false
                now = new Date()
                agenda.fetchAll(false)
            } else {
                reveal = 0
            }
        }
        onMonthChanged: agenda.rebuild()
        onYearChanged: agenda.rebuild()

        Timer {
            interval: 1000
            running: calendar.visible
            repeat: true
            onTriggered: calendar.now = new Date()
        }

        PopupFace {
            id: surface

            anchors.fill: parent
            reveal: calendar.reveal
            radius: clock.popupRadius
            color: clock.popupColor
            border.color: clock.popupBorderColor
            transformOrigin: clock.edge === "bottom" ? Item.Bottom : Item.Top

            // The month's band, for a theme with a header fill (an accent block in neobrutalism)
            Rectangle {
                readonly property real inset: PanelBus.borderWidth

                visible: PanelBus.headerBackground.a > 0
                x: inset
                y: inset
                width: surface.width - 2 * inset
                height: popupContent.y + header.height + 14 - inset
                topLeftRadius: Math.max(0, surface.radius - inset)
                topRightRadius: Math.max(0, surface.radius - inset)
                color: PanelBus.headerBackground
            }

            ColumnLayout {
                id: popupContent

                x: 20
                y: 16
                width: surface.width - 40
                spacing: 0

                // The month and the selected day, with the arrows that change the month
                RowLayout {
                    id: header

                    readonly property color ink: PanelBus.headerBackground.a > 0 ? PanelBus.headerText : clock.popupTextColor

                    Layout.fillWidth: true
                    spacing: 4

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            objectName: "title"
                            Layout.fillWidth: true
                            text: `${calendar.locale.standaloneMonthName(calendar.month)} ${calendar.year}`
                            color: header.ink
                            font.family: PanelBus.font.family
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            font.capitalization: PanelBus.headingCapitalization
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: calendar.selected.toLocaleDateString(calendar.locale, "dddd d MMMM")
                                + "  ·  week " + calendar.weekOf(calendar.selected)
                            color: Qt.alpha(header.ink, 0.7)
                            font.family: PanelBus.font.family
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    IconButton { icon: "chevron-left"; ink: header.ink; onClicked: calendar.showMonth(-1) }
                    IconButton { icon: "chevron-right"; ink: header.ink; onClicked: calendar.showMonth(1) }
                }

                // The band's bottom line, across the whole popup
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: -20 + PanelBus.borderWidth
                    Layout.rightMargin: -20 + PanelBus.borderWidth
                    Layout.topMargin: 14
                    Layout.bottomMargin: 12
                    implicitHeight: PanelBus.dividerWidth
                    color: PanelBus.divider
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: calendar.locale

                    delegate: Text {
                        required property string shortName

                        text: shortName.slice(0, 2)
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        font.capitalization: Font.AllUppercase
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MonthGrid {
                    id: grid

                    Layout.fillWidth: true
                    Layout.preferredHeight: 6 * 38
                    Layout.topMargin: 4
                    month: calendar.month
                    year: calendar.year
                    locale: calendar.locale
                    spacing: 0

                    delegate: Item {
                        id: day

                        required property var model
                        readonly property bool today: calendar.isToday(model.date)
                        readonly property bool chosen: calendar.sameDay(model.date, calendar.selected)
                        readonly property bool inMonth: model.month === grid.month
                        // The colours of this day's calendars, once each
                        readonly property var dots: {
                            agenda.days
                            const seen = []
                            for (const event of agenda.eventsOn(model.date)) {
                                if (!seen.some(c => Qt.colorEqual(c, event.color)))
                                    seen.push(event.color)
                            }
                            return seen.slice(0, 3)
                        }

                        implicitHeight: 38

                        Rectangle {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            width: 32
                            height: 32
                            radius: Math.min(16, PanelBus.pill === 0 ? 0 : 8 * PanelBus.radiusScale + (PanelBus.pill > 100 ? 8 : 0))
                            color: day.today ? clock.accentColor : dayArea.containsMouse ? PanelBus.raised : "transparent"
                            border.width: day.chosen && !day.today ? Math.max(1.5, PanelBus.cardBorderWidth) : day.today ? PanelBus.cardBorderWidth : 0
                            border.color: day.today ? PanelBus.outline : clock.accentColor
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -3
                            text: day.model.day
                            color: day.today ? clock.todayTextColor : clock.popupTextColor
                            opacity: day.inMonth || day.today ? 1 : 0.35
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                            font.weight: day.today ? Font.DemiBold : Font.Normal
                        }

                        // A dot for each calendar with something on this day
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 + 7
                            spacing: 3
                            opacity: day.inMonth ? 1 : 0.4

                            Repeater {
                                model: day.dots

                                delegate: Rectangle {
                                    required property color modelData

                                    width: 4
                                    height: 4
                                    radius: PanelBus.pill === 0 ? 0 : 2
                                    color: day.today ? clock.todayTextColor : modelData
                                }
                            }
                        }

                        MouseArea {
                            id: dayArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calendar.selected = day.model.date
                                calendar.managing = false
                                if (!day.inMonth)
                                    calendar.showMonth(day.model.date < new Date(calendar.year, calendar.month, 1) ? -1 : 1)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 12
                    implicitHeight: PanelBus.dividerWidth
                    color: PanelBus.divider
                }

                // The selected day's events
                ColumnLayout {
                    id: events

                    readonly property var list: { agenda.days; return agenda.eventsOn(calendar.selected) }
                    readonly property int shown: 4

                    visible: !calendar.managing
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Section { text: calendar.dayName(calendar.selected); Layout.fillWidth: true }
                        Section {
                            visible: events.list.length > 0
                            text: events.list.length === 1 ? "1 event" : `${events.list.length} events`
                        }
                    }

                    Repeater {
                        model: events.list.slice(0, events.shown)

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 3
                                radius: PanelBus.pill === 0 ? 0 : 1.5
                                color: modelData.color
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    color: clock.popupTextColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: calendar.timeOf(modelData) + (modelData.location ? "  ·  " + modelData.location : "")
                                        + (agenda.feeds.length > 1 ? "  ·  " + modelData.calendar : "")
                                    color: PanelBus.textDim
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Text {
                        visible: events.list.length > events.shown
                        text: `+ ${events.list.length - events.shown} more`
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 11
                    }

                    Text {
                        visible: events.list.length === 0
                        Layout.fillWidth: true
                        text: agenda.feeds.length === 0 ? "Add a calendar to see your events here."
                            : agenda.busy > 0 ? "Loading…" : "Nothing planned."
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }

                // The calendars: added by their iCal link, removed with the cross
                ColumnLayout {
                    id: feedList

                    visible: calendar.managing
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        Section { text: "Calendars"; Layout.fillWidth: true }
                        IconButton {
                            visible: agenda.feeds.length > 0
                            icon: "refresh"
                            onClicked: agenda.fetchAll(true)
                        }
                    }

                    Repeater {
                        model: agenda.feeds

                        delegate: RowLayout {
                            required property var modelData
                            required property int index
                            readonly property var info: agenda.loaded[modelData.url] ?? null

                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: PanelBus.pill === 0 ? 0 : 5
                                color: agenda.colorAt(index)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: clock.popupTextColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: !info ? "Loading…" : info.error ? info.error
                                        : info.events.length === 1 ? "1 event" : `${info.events.length} events`
                                    color: info?.error ? PanelBus.theme?.colors.critical ?? PanelBus.textDim : PanelBus.textDim
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            IconButton { icon: "close"; onClicked: agenda.remove(index) }
                        }
                    }

                    Field { id: feedName; placeholderText: "Name (optional)" }
                    Field {
                        id: feedUrl

                        placeholderText: "iCal link (.ics)"
                        onAccepted: addButton.clicked()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            id: addProblem

                            Layout.fillWidth: true
                            color: PanelBus.textDim
                            font.family: PanelBus.font.family
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                        Rectangle {
                            id: addButton

                            signal clicked

                            implicitWidth: addLabel.implicitWidth + 28
                            implicitHeight: 30
                            radius: 6 * PanelBus.radiusScale
                            color: clock.accentColor
                            border.width: PanelBus.cardBorderWidth
                            border.color: PanelBus.outline
                            onClicked: {
                                if (agenda.add(feedName.text, feedUrl.text)) {
                                    feedName.text = ""
                                    feedUrl.text = ""
                                    addProblem.text = ""
                                } else {
                                    addProblem.text = "Paste a link that starts with https:// or webcal://"
                                }
                            }

                            Text {
                                id: addLabel

                                anchors.centerIn: parent
                                text: "Add"
                                color: clock.todayTextColor
                                font.family: PanelBus.font.family
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: addButton.clicked()
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Google Calendar: Settings › your calendar › Integrate calendar › Secret address in iCal format. "
                            + "Outlook: Settings › Calendar › Shared calendars › Publish a calendar, ICS link. "
                            + "Samsung Calendar: sync it with one of those accounts and add that one."
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        lineHeight: 1.15
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 10
                    implicitHeight: PanelBus.dividerWidth
                    color: PanelBus.divider
                }

                // The time to the second, and the calendars
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: { calendar.now; return zones.format(clock.timeZone, "HH:mm:ss", "C") }
                        color: clock.popupTextColor
                        font.family: PanelBus.font.family
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: clock.timeZone ? clock.timeZone.replace(/_/g, " ") : "Local time"
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    IconButton {
                        icon: "calendar"
                        active: calendar.managing
                        onClicked: calendar.managing = !calendar.managing
                    }
                }
            }
        }
    }

    // A small heading, as in the control center
    component Section: Text {
        color: PanelBus.textDim
        font.family: PanelBus.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    // A square button with one of this setup's icons
    component IconButton: Rectangle {
        id: button

        property string icon
        property color ink: clock.popupTextColor
        property bool active: false

        signal clicked

        implicitWidth: 28
        implicitHeight: 28
        radius: 6 * PanelBus.radiusScale
        color: active ? Qt.alpha(clock.accentColor, 0.18) : area.containsMouse ? Qt.alpha(ink, 0.12) : "transparent"
        border.width: active ? Math.max(1, PanelBus.cardBorderWidth) : 0
        border.color: clock.accentColor

        Icon {
            anchors.centerIn: parent
            name: button.icon
            color: button.active ? clock.accentColor : button.ink
        }
        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // A text field in the popup's colours
    component Field: TextField {
        Layout.fillWidth: true
        implicitHeight: 32
        leftPadding: 10
        rightPadding: 10
        color: clock.popupTextColor
        placeholderTextColor: Qt.alpha(clock.popupTextColor, 0.45)
        selectionColor: clock.accentColor
        selectedTextColor: clock.todayTextColor
        font.family: PanelBus.font.family
        font.pixelSize: 12
        selectByMouse: true
        background: Rectangle {
            radius: 6 * PanelBus.radiusScale
            color: PanelBus.raised
            border.width: Math.max(1, PanelBus.cardBorderWidth)
            border.color: parent.activeFocus ? clock.accentColor : PanelBus.outline
        }
    }
}
