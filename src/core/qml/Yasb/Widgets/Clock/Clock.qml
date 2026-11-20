pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import Yasb.Bar
import Yasb.Common
import Yasb.Themes

Label {
    id: clock

    property string format: "HH:mm"
    property string alternateFormat: "ddd d MMM yyyy  HH:mm"
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
    property real popupRadius: theme.popup.radius
    property real popupGap: theme.popup.gap
    // Text in the popup: the theme's body, caption and heading, each part unless set here
    property font popupFont
    popupFont.family: theme.type.body.family
    popupFont.pixelSize: theme.type.body.pixelSize
    popupFont.weight: theme.type.body.weight
    property font popupSmallFont
    popupSmallFont.family: theme.type.caption.family
    popupSmallFont.pixelSize: theme.type.caption.pixelSize
    popupSmallFont.weight: theme.type.caption.weight
    property int popupOpenDuration: theme.popup.openDuration
    property int popupCloseDuration: theme.popup.closeDuration
    property font popupTitleFont
    popupTitleFont.family: theme.type.heading.family
    popupTitleFont.pixelSize: theme.type.heading.pixelSize
    popupTitleFont.weight: theme.type.heading.weight
    popupTitleFont.capitalization: theme.type.heading.capitalization
    // The arrows that change the month, the weekday names and the week numbers
    property font arrowFont
    arrowFont.family: theme.type.body.family
    arrowFont.pixelSize: 18
    property font weekdayFont
    weekdayFont.family: theme.type.caption.family
    weekdayFont.pixelSize: 11
    weekdayFont.weight: theme.type.caption.weight
    property font weekNumberFont
    weekNumberFont.family: theme.type.caption.family
    weekNumberFont.pixelSize: 11
    property color popupDividerColor: theme.colors.divider
    readonly property string edge: bar.edge

    function nextTick(): int {
        const time = new Date()
        if (activeFormat.includes("s"))
            return 1000 - time.getMilliseconds()
        return 60000 - time.getSeconds() * 1000 - time.getMilliseconds()
    }

    function refresh() {
        text = zones.format(timeZone, activeFormat, locale)
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

    // The theme's text colour; the font comes from the bar, each part unless the widget file sets it
    color: clock.popupTextColor
    verticalAlignment: Text.AlignVCenter

    Component.onCompleted: refresh()
    onActiveFormatChanged: refresh()
    onTimeZoneChanged: refresh()
    onLocaleChanged: refresh()
    Component.onDestruction: calendar.hide()

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

    BackdropPopup {
        id: calendar
        property real reveal: 0
        property date today: new Date()
        property int month: today.getMonth()
        property int year: today.getFullYear()

        readonly property var locale: clock.locale ? Qt.locale(clock.locale) : Qt.locale()

        function showMonth(offset: int) {
            const shown = new Date(year, month + offset, 1)
            month = shown.getMonth()
            year = shown.getFullYear()
        }

        function isToday(date: date): bool {
            return date.getFullYear() === today.getFullYear()
                && date.getMonth() === today.getMonth()
                && date.getDate() === today.getDate()
        }

        objectName: "calendar"
        title: "Calendar"
        width: popupContent.implicitWidth + 2 * surface.border.width
        height: popupContent.implicitHeight + 2 * surface.border.width
        anchor: clock
        font: clock.popupFont
        theme: clock.theme
        backdropItem: surface
        enter: NumberAnimation { target: calendar; property: "reveal"; to: 1; duration: clock.popupOpenDuration; easing.type: clock.theme.popup.openEasing }
        exit: NumberAnimation { target: calendar; property: "reveal"; to: 0; duration: clock.popupCloseDuration; easing.type: clock.theme.popup.closeEasing }
        onVisibleChanged: { if (!visible) reveal = 0 }

        PopupSurface {
            id: surface
            anchors.fill: parent
            theme: clock.theme
            reveal: calendar.reveal
            radius: clock.popupRadius
            color: clock.popupColor
            border.color: clock.popupBorderColor
            transformOrigin: clock.edge === "bottom" ? Item.Bottom : Item.Top

            // Inside the outline, so the header's fill does not cover it
            ColumnLayout {
                id: popupContent
                x: surface.border.width
                y: surface.border.width
                width: parent.width - 2 * surface.border.width
                spacing: 8

                PopupHeader {
                    id: header
                    Layout.fillWidth: true
                    theme: clock.theme
                    title: `${calendar.locale.standaloneMonthName(calendar.month)} ${calendar.year}`
                    font: clock.popupTitleFont
                    popupRadius: clock.popupRadius
                    rightPadding: 8

                    Repeater {
                        model: [{ glyph: "", tip: "Previous month", offset: -1 }, { glyph: "", tip: "Next month", offset: 1 }]

                        delegate: PopupIconButton {
                            required property var modelData

                            theme: clock.theme
                            glyph: modelData.glyph
                            iconSize: 12
                            color: header.textColor
                            tip: modelData.tip
                            onClicked: calendar.showMonth(modelData.offset)
                            Accessible.name: modelData.tip
                        }
                    }
                }

                GridLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: 12
                    columns: clock.showWeekNumbers ? 2 : 1
                    columnSpacing: 4
                    rowSpacing: 4

                    Item {
                        visible: clock.showWeekNumbers
                    }

                    DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: calendar.locale

                        delegate: Text {
                            required property string shortName

                            text: shortName
                            color: clock.popupTextColor
                            opacity: 0.6
                            font: clock.weekdayFont
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    WeekNumberColumn {
                        visible: clock.showWeekNumbers
                        Layout.fillHeight: true
                        month: calendar.month
                        year: calendar.year
                        locale: calendar.locale

                        delegate: Text {
                            required property int weekNumber

                            text: weekNumber
                            color: clock.popupTextColor
                            opacity: 0.5
                            font: clock.weekNumberFont
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MonthGrid {
                        id: grid

                        Layout.preferredWidth: 7 * 34
                        Layout.preferredHeight: 6 * 30
                        month: calendar.month
                        year: calendar.year
                        locale: calendar.locale

                        delegate: Text {
                            id: day

                            required property var model
                            readonly property bool today: calendar.isToday(model.date)

                            text: model.day
                            color: today ? clock.todayTextColor : clock.popupTextColor
                            opacity: model.month === grid.month ? 1 : 0.35
                            font: clock.popupSmallFont
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: Math.min(13, clock.theme.radius.pill)
                                color: clock.accentColor
                                visible: day.today
                                z: -1
                            }
                        }
                    }
                }
            }
        }
    }
}
