pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Yasb
import "../../panel"

// The weather on the bar (the sky and the temperature) and the Weather page in the panel: now, the next
// hours and the coming days, from Open-Meteo through yasb's WeatherForecast. "Change place" searches for another.
Item {
    id: weather

    property Item bar: null
    // Widgets with the same id share the saved place, so this one keeps the place set in yasb's own Weather widget
    property string locationId: "weather"
    // metric or imperial
    property string units: "metric"
    property int forecastDays: 7
    property int updateInterval: 3600000
    property string timeFormat: "24h"
    property string keys: ""
    // Hours on the page
    property int hourCount: 12

    property var pictures: ({
        sunnyDay: Qt.resolvedUrl("icons/sunny-day.svg"),
        clearNight: Qt.resolvedUrl("icons/clear-night.svg"),
        cloudyDay: Qt.resolvedUrl("icons/cloudy-day.svg"),
        cloudyNight: Qt.resolvedUrl("icons/cloudy-night.svg"),
        foggyDay: Qt.resolvedUrl("icons/foggy.svg"),
        foggyNight: Qt.resolvedUrl("icons/foggy.svg"),
        drizzleDay: Qt.resolvedUrl("icons/drizzle.svg"),
        drizzleNight: Qt.resolvedUrl("icons/drizzle.svg"),
        rainyDay: Qt.resolvedUrl("icons/rainy-day.svg"),
        rainyNight: Qt.resolvedUrl("icons/rainy-night.svg"),
        snowyDay: Qt.resolvedUrl("icons/snowy.svg"),
        snowyNight: Qt.resolvedUrl("icons/snowy.svg"),
        thunderstormDay: Qt.resolvedUrl("icons/thunderstorm.svg"),
        thunderstormNight: Qt.resolvedUrl("icons/thunderstorm.svg"),
        default: Qt.resolvedUrl("icons/sunny-day.svg")
    })

    readonly property var values: forecast.values
    property bool choosing: false

    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("weather") ?? false

    // The bar's line icon for a condition such as "rainyDay": panel/Icon.qml's name for it
    function lineIcon(condition: string): string {
        const sky = condition.replace(/(Day|Night)$/, "")
        return ({ sunny: "sun", clear: "moon", cloudy: "cloud", foggy: "fog", drizzle: "drizzle", rainy: "rain",
                  snowy: "snow", thunderstorm: "storm" })[sky] ?? "sun"
    }

    function picture(condition: string): url {
        return pictures[condition] ?? pictures["default"] ?? ""
    }

    function whole(value: var): string {
        return Number.isFinite(value) ? `${Math.round(value)}°` : "--"
    }

    function dayName(index: int, weekday: int): string {
        return index === 0 ? "Today" : Qt.locale("en_US").dayName(weekday, Locale.ShortFormat)
    }

    function toggle() {
        panelHost?.toggle("weather", weather)
    }

    function pick(place: var) {
        forecast.setLocation(place)
        choosing = false
    }

    // Like "12°" from "12.4 °C"
    readonly property string shortTemp: {
        const current = forecast.current?.temperature
        return forecast.hasLocation && Number.isFinite(current) ? `${Math.round(current)}°` : "--"
    }

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("weather", pageView, weather)
        }
    }
    Component.onCompleted: PanelBus.register("weather", keys)
    Component.onDestruction: panelHost?.withdraw("weather", weather)

    WeatherForecast {
        id: forecast

        locationId: weather.locationId
        units: weather.units
        forecastDays: weather.forecastDays
        updateInterval: weather.updateInterval
        hideDecimal: true
        timeFormat: weather.timeFormat
    }

    Hotkey {
        keys: weather.keys
        onActivated: weather.toggle()
    }

    BarButton {
        id: barButton

        anchors.centerIn: parent
        open: weather.panelOpen
        text: weather.shortTemp
        tip: forecast.hasLocation ? `${weather.values.location}: ${weather.values.condition_text}, ${weather.values.temp}` : "Weather: set a place"
        onClicked: weather.toggle()
        icon: weather.lineIcon(forecast.condition)
        glyphSize: 16
    }

    component SectionLabel: Text {
        color: PanelBus.textDim
        font.family: PanelBus.font.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }

    component Detail: Column {
        property string label
        property string value

        width: parent ? (parent.width - 2 * 12) / 3 : 100
        spacing: 2

        Text {
            width: parent.width
            text: parent.label
            elide: Text.ElideRight
            color: PanelBus.textDim
            font.family: PanelBus.font.family
            font.pixelSize: 11
        }
        Text {
            width: parent.width
            text: parent.value
            elide: Text.ElideRight
            color: PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    component LinkButton: Rectangle {
        id: link

        property string text

        signal clicked

        implicitWidth: linkLabel.implicitWidth + 20
        implicitHeight: 28
        radius: 8 * PanelBus.radiusScale
        color: linkArea.containsMouse ? PanelBus.raised : Qt.alpha(PanelBus.raised, 0.6)

        Text {
            id: linkLabel

            anchors.centerIn: parent
            text: link.text
            color: PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 12
        }
        MouseArea {
            id: linkArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // ---------- The page ----------

    property Item page: Item {
        id: pageView

        function panelShown(fresh) {
            if (!forecast.hasLocation)
                weather.choosing = true
            if (weather.choosing)
                Qt.callLater(() => field.forceActiveFocus())
        }

        // Where: search for a place
        ColumnLayout {
            anchors.fill: parent
            visible: weather.choosing
            spacing: 10

            Text {
                text: "Choose a place"
                color: PanelBus.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            TextField {
                id: field

                Layout.fillWidth: true
                Layout.preferredHeight: 40
                placeholderText: "City or town"
                color: PanelBus.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 14
                leftPadding: 12
                background: Rectangle {
                    radius: 10 * PanelBus.radiusScale
                    color: PanelBus.surface
                    border.width: 1
                    border.color: field.activeFocus ? Qt.alpha(PanelBus.accent, 0.6) : PanelBus.outline
                }
                onTextChanged: searchDelay.restart()
                Keys.onReturnPressed: {
                    if (forecast.searchResults.length > 0)
                        weather.pick(forecast.searchResults[0])
                }
                Keys.onEscapePressed: event => {
                    if (forecast.hasLocation) {
                        weather.choosing = false
                        event.accepted = true
                    } else {
                        event.accepted = false
                    }
                }

                Timer {
                    id: searchDelay

                    interval: 300
                    onTriggered: forecast.search(field.text)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: field.text.length < 2 ? "" : forecast.searching ? "Searching..."
                    : forecast.searchError !== "" ? forecast.searchError
                    : forecast.searchResults.length === 0 ? "No places found" : ""
                color: PanelBus.textDim
                font.family: PanelBus.font.family
                font.pixelSize: 12
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: forecast.searchResults

                delegate: Rectangle {
                    id: place

                    required property var modelData

                    width: ListView.view.width
                    height: 46
                    radius: 10 * PanelBus.radiusScale
                    color: placeArea.containsMouse ? PanelBus.raised : "transparent"

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        width: parent.width - 24
                        spacing: 2

                        Text {
                            width: parent.width
                            text: place.modelData.name
                            elide: Text.ElideRight
                            color: PanelBus.textColor
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: place.modelData.region ?? ""
                            elide: Text.ElideRight
                            color: PanelBus.textDim
                            font.family: PanelBus.font.family
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: placeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: weather.pick(place.modelData)
                    }
                }
            }

            LinkButton {
                visible: forecast.hasLocation
                text: "Cancel"
                onClicked: weather.choosing = false
            }
        }

        // The weather
        Flickable {
            anchors.fill: parent
            visible: !weather.choosing
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content

                width: parent.width
                spacing: 12

                // Now
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: now.implicitHeight + 32
                    radius: 14 * PanelBus.radiusScale
                    color: PanelBus.surface
                    border.width: PanelBus.cardBorderWidth
                    border.color: PanelBus.outline

                    ColumnLayout {
                        id: now

                        x: 16
                        y: 16
                        width: parent.width - 32
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Image {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                source: weather.picture(forecast.condition)
                                sourceSize: Qt.size(128, 128)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: weather.shortTemp
                                    color: PanelBus.textColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 40
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: forecast.ready ? `${weather.values.condition_text} · feels like ${weather.whole(forecast.current?.feelsLike)}` : forecast.loading ? "Loading..." : ""
                                    elide: Text.ElideRight
                                    color: PanelBus.textDim
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: weather.values.location ?? ""
                                    color: PanelBus.textColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.alignment: Qt.AlignRight
                                    text: forecast.ready ? `${weather.whole(forecast.days[0]?.high)} / ${weather.whole(forecast.days[0]?.low)}` : ""
                                    color: PanelBus.textDim
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 12
                                }
                            }
                        }

                        Grid {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 10
                            columnSpacing: 12

                            Detail { label: "Wind"; value: weather.values.wind ?? "--" }
                            Detail { label: "Humidity"; value: weather.values.humidity ?? "--" }
                            Detail { label: "Rain"; value: weather.values.precipitation_probability ?? "--" }
                            Detail { label: "UV index"; value: weather.values.uv ?? "--" }
                            Detail { label: "Sunrise"; value: weather.values.sunrise ?? "--" }
                            Detail { label: "Sunset"; value: weather.values.sunset ?? "--" }
                        }
                    }
                }

                SectionLabel {
                    Layout.topMargin: 4
                    text: "Next hours"
                }

                // The next hours, side by side
                ListView {
                    id: hours

                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: (forecast.upcoming ?? []).slice(0, weather.hourCount)

                    delegate: Rectangle {
                        id: hour

                        required property var modelData
                        required property int index

                        width: 56
                        height: 92
                        radius: 12 * PanelBus.radiusScale
                        color: index === 0 ? Qt.alpha(PanelBus.accent, 0.14) : PanelBus.surface

                        border.width: PanelBus.cardBorderWidth
                        border.color: PanelBus.outline
                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hour.index === 0 ? "Now" : hour.modelData.timeText
                                color: hour.index === 0 ? PanelBus.accent : PanelBus.textDim
                                font.family: PanelBus.font.family
                                font.pixelSize: 11
                            }
                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 24
                                height: 24
                                source: weather.picture(hour.modelData.condition)
                                sourceSize: Qt.size(48, 48)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: weather.whole(hour.modelData.temperature)
                                color: PanelBus.textColor
                                font.family: PanelBus.font.family
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                SectionLabel {
                    Layout.topMargin: 4
                    text: "Coming days"
                }

                // The days, each with a bar from its low to its high across the week's range
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: dayList.implicitHeight + 8
                    radius: 14 * PanelBus.radiusScale
                    color: PanelBus.surface
                    border.width: PanelBus.cardBorderWidth
                    border.color: PanelBus.outline

                    Column {
                        id: dayList

                        readonly property var days: forecast.days ?? []
                        readonly property real coldest: Math.min(...days.map(day => day.low).filter(Number.isFinite))
                        readonly property real warmest: Math.max(...days.map(day => day.high).filter(Number.isFinite))

                        x: 14
                        y: 4
                        width: parent.width - 28

                        Repeater {
                            model: dayList.days

                            delegate: RowLayout {
                                id: day

                                required property var modelData
                                required property int index
                                readonly property real span: Math.max(1, dayList.warmest - dayList.coldest)

                                width: dayList.width
                                height: 40
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 48
                                    text: weather.dayName(day.index, day.modelData.weekday)
                                    color: PanelBus.textColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                }
                                Image {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    source: weather.picture(day.modelData.condition)
                                    sourceSize: Qt.size(44, 44)
                                }
                                Text {
                                    Layout.preferredWidth: 36
                                    horizontalAlignment: Text.AlignRight
                                    text: Number.isFinite(day.modelData.precipitationChance) && day.modelData.precipitationChance >= 20
                                        ? `${Math.round(day.modelData.precipitationChance)}%` : ""
                                    color: PanelBus.accent2
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 11
                                }
                                Text {
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                    text: weather.whole(day.modelData.low)
                                    color: PanelBus.textDim
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 6

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 3 * PanelBus.radiusScale
                                        color: PanelBus.raised
                                    }
                                    Rectangle {
                                        x: parent.width * (day.modelData.low - dayList.coldest) / day.span
                                        width: Math.max(6, parent.width * (day.modelData.high - day.modelData.low) / day.span)
                                        height: parent.height
                                        radius: 3 * PanelBus.radiusScale
                                        color: PanelBus.accent
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 32
                                    text: weather.whole(day.modelData.high)
                                    color: PanelBus.textColor
                                    font.family: PanelBus.font.family
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: forecast.error !== "" ? forecast.error
                            : forecast.updated instanceof Date && !isNaN(forecast.updated) ? `Updated ${Qt.formatTime(forecast.updated, "HH:mm")}` : ""
                        elide: Text.ElideRight
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 11
                    }
                    LinkButton {
                        text: "Refresh"
                        onClicked: forecast.refresh()
                    }
                    LinkButton {
                        text: "Change place"
                        onClicked: {
                            weather.choosing = true
                            field.text = ""
                            Qt.callLater(() => field.forceActiveFocus())
                        }
                    }
                }
            }
        }
    }
}
