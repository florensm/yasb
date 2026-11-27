pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../panel"

// The rows of GlazeWalker.qml in Search: each workspace with its ring, as on the bar, and its windows under it.
// A click goes there, Shift+click brings the window here, middle click closes it.
ListView {
    id: list

    required property GlazeWalker glaze
    property int iconSize: 24
    readonly property color ink: PanelBus.textColor
    readonly property color dim: Qt.alpha(PanelBus.textColor, 0.55)

    clip: true
    spacing: 2
    model: list.glaze.rows
    currentIndex: list.glaze.current
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0
    ScrollBar.vertical: ScrollBar {}
    onCurrentIndexChanged: {
        if (currentIndex >= 0)
            positionViewAtIndex(currentIndex, ListView.Contain)
    }

    delegate: Item {
        id: row

        required property var modelData
        required property int index
        readonly property bool isWorkspace: modelData.kind === "workspace"
        readonly property bool isHeading: modelData.kind === "heading"
        readonly property bool isCurrent: index === list.glaze.current
        // Grouped under its workspace while nothing is typed
        readonly property bool indented: !isWorkspace && !isHeading && list.glaze.query.trim() === ""
                                         && modelData.managed

        width: ListView.view.width
        height: isHeading ? 28 : isWorkspace ? 32 : 38

        Rectangle {
            anchors.fill: parent
            visible: !row.isHeading
            radius: 9 * PanelBus.radiusScale
            color: row.isCurrent ? Qt.alpha(PanelBus.accent, 0.14)
                : mouse.containsMouse ? Qt.alpha(list.ink, 0.06) : "transparent"
            border.width: row.isCurrent ? PanelBus.selectedBorderWidth : 0
            border.color: PanelBus.accent
        }

        // "Other windows"
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            visible: row.isHeading
            text: row.modelData.title ?? ""
            color: list.dim
            font.family: PanelBus.font.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        // A workspace: its ring as on the bar, its name, and how many windows
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            visible: row.isWorkspace
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                radius: Math.min(6, PanelBus.pill)
                color: row.modelData.focused ? PanelBus.accent : "transparent"
                border.width: row.modelData.focused ? 0 : (row.modelData.count > 0 ? 2 : 1)
                border.color: Qt.alpha(list.ink, row.modelData.count > 0 ? 0.8 : 0.4)

                Rectangle {
                    anchors.centerIn: parent
                    width: 4
                    height: 4
                    radius: Math.min(2, PanelBus.pill)
                    visible: row.modelData.displayed === true && row.modelData.focused !== true
                    color: list.ink
                }
            }

            Label {
                text: row.modelData.name ?? ""
                textFormat: Text.PlainText
                color: row.modelData.focused ? PanelBus.accent : list.ink
                font.family: PanelBus.font.family
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Label {
                Layout.fillWidth: true
                text: row.modelData.label ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: list.dim
                font.family: PanelBus.font.family
                font.pixelSize: 13
            }

            Label {
                visible: list.glaze.monitorCount > 1
                text: qsTr("monitor %1").arg(row.modelData.monitor ?? 1)
                color: list.dim
                font.family: PanelBus.font.family
                font.pixelSize: 11
            }

            Label {
                text: row.modelData.focused ? qsTr("here")
                    : (row.modelData.count ?? 0) === 0 ? qsTr("empty")
                    : row.modelData.count === 1 ? qsTr("1 window") : qsTr("%1 windows").arg(row.modelData.count)
                color: row.modelData.focused ? PanelBus.accent : list.dim
                font.family: PanelBus.font.family
                font.pixelSize: 11
            }
        }

        // A window: its icon, title and app, and how it sits
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: row.indented ? 34 : 12
            anchors.rightMargin: 12
            visible: !row.isWorkspace && !row.isHeading
            spacing: 10

            Image {
                Layout.preferredWidth: list.iconSize
                Layout.preferredHeight: list.iconSize
                source: row.isWorkspace || row.isHeading ? "" : list.glaze.iconOf(row.modelData.hwnd)
                sourceSize: Qt.size(list.iconSize, list.iconSize)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Label {
                // As wide as it needs, the app name taking what's left; both shrink when the row is too narrow
                Layout.fillWidth: true
                Layout.preferredWidth: implicitWidth
                Layout.maximumWidth: implicitWidth
                text: row.modelData.title ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.modelData.focused ? PanelBus.accent : list.ink
                font.family: PanelBus.font.family
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Label {
                Layout.fillWidth: true
                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: 40
                text: row.modelData.process ?? ""
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: list.dim
                font.family: PanelBus.font.family
                font.pixelSize: 12
            }

            Chip {
                visible: ["floating", "minimized", "fullscreen"].includes(row.modelData.state)
                text: row.modelData.state ?? ""
            }

            // Where it is, while searching shows every workspace's windows together
            Chip {
                visible: !row.indented && (row.modelData.workspace ?? "") !== ""
                text: row.modelData.workspaceLabel ? `${row.modelData.workspace} · ${row.modelData.workspaceLabel}`
                                                   : row.modelData.workspace ?? ""
                accent: row.modelData.workspace === list.glaze.focusedWorkspace
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            enabled: !row.isHeading
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                list.glaze.current = row.index
                if (event.button === Qt.MiddleButton)
                    list.glaze.closeWindow(row.modelData)
                else if (event.modifiers & Qt.ShiftModifier)
                    list.glaze.bringHere(row.modelData)
                else
                    list.glaze.activate(row.modelData)
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: list.count === 0
        text: list.glaze.query.trim() !== "" ? qsTr("Nothing matches")
            : list.glaze.connected ? qsTr("No windows") : qsTr("GlazeWM isn't running")
        color: list.dim
        font.family: PanelBus.font.family
        font.pixelSize: 13
    }

    component Chip: Label {
        property bool accent: false

        leftPadding: 7
        rightPadding: 7
        topPadding: 2
        bottomPadding: 2
        textFormat: Text.PlainText
        color: accent ? PanelBus.accent : Qt.alpha(PanelBus.textColor, 0.7)
        font.family: PanelBus.font.family
        font.pixelSize: 11
        background: Rectangle {
            radius: 6 * PanelBus.radiusScale
            color: parent.accent ? Qt.alpha(PanelBus.accent, 0.15) : Qt.alpha(PanelBus.textColor, 0.08)
        }
    }
}
