pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Yasb
import Yasb.Bar
import "../../panel"

Item {
    id: root

    property string serverUri: "ws://localhost:6123"
    property bool monitorExclusive: true
    property string offlineLabel: "GlazeWM Offline"
    property bool hideIfOffline: false
    property string populatedLabel: ""
    property string emptyLabel: ""
    property string activePopulatedLabel: ""
    property string activeEmptyLabel: ""
    property string focusedPopulatedLabel: ""
    property string focusedEmptyLabel: ""
    property bool enableScrollSwitching: true
    property bool reverseScrollDirection: false
    property color focusedColor: root.dark ? Qt.alpha("#ffffff", 0.1) : Qt.alpha("#000000", 0.1)
    property color activeColor: root.dark ? Qt.alpha("#ffffff", 0.1) : Qt.alpha("#000000", 0.1)
    property color hoveredColor: root.dark ? Qt.alpha("#ffffff", 0.1) : Qt.alpha("#000000", 0.1)
    property int spacing: vertical ? 4 : 0
    // "rings": a ring per workspace, filled in the accent while focused, with a dot while another monitor shows it.
    // With `ringNames`, a workspace with a display name of its own shows that instead. "numbers" puts the focused
    // workspace's number in a rounded square; "dots" draws dots that stretch into a pill.
    property string style: "rings"
    property int ringSize: 12
    property bool ringNames: false
    property int numberSize: 22
    property color numberAccentColor: PanelBus.accent
    property color numberAccentTextColor: PanelBus.onAccent
    property int dotSize: 8
    property color dotColor: textColor
    property color dotAccentColor: PanelBus.accent
    // Milliseconds for the dot animations; 0 turns them off.
    property int animationDuration: 220
    property BarBase bar: null

    component AppIcons: QtObject {
        property bool enabledPopulated: false
        property bool enabledActive: false
        property var enabledFocused: null
        property int size: 16
        property int maxIcons: 3
        property bool hideLabel: false
        property bool hideDuplicates: false
        property bool hideFloating: false
    }

    property AppIcons appIcons: AppIcons {}

    readonly property QtObject model: workspaceModel
    readonly property bool dark: Application.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property color textColor: bar ? bar.theme.colors.text : dark ? "white" : "black"
    readonly property bool vertical: bar?.vertical ?? false
    readonly property bool shown: workspaceModel.connected || (!hideIfOffline && offlineLabel !== "")

    implicitWidth: !shown ? 0 : workspaceModel.connected ? buttons.implicitWidth : offline.implicitWidth
    implicitHeight: !shown ? 0 : workspaceModel.connected ? buttons.implicitHeight : offline.implicitHeight
    visible: shown

    function label(workspace: var): string {
        const fallback = workspace.displayName || workspace.name
        const labels = {
            populated: populatedLabel,
            empty: emptyLabel,
            active_populated: activePopulatedLabel,
            active_empty: activeEmptyLabel,
            focused_populated: focusedPopulatedLabel || activePopulatedLabel,
            focused_empty: focusedEmptyLabel || activeEmptyLabel
        }
        return (labels[workspace.status] || fallback)
            .replace(/\{(name|display_name)\}/g, (_, key) => key === "name" ? workspace.name : workspace.displayName)
    }

    function scroll(delta: int): void {
        if (enableScrollSwitching)
            workspaceModel.switchWorkspace(reverseScrollDirection ? -delta : delta)
    }

    GlazewmWorkspaceList {
        id: workspaceModel

        serverUri: root.serverUri
        screenName: root.bar?.screenName ?? ""
        monitorExclusive: root.monitorExclusive
        appIcons: ({
            enabledPopulated: root.appIcons.enabledPopulated,
            enabledActive: root.appIcons.enabledActive,
            enabledFocused: root.appIcons.enabledFocused,
            maxIcons: root.appIcons.maxIcons,
            hideDuplicates: root.appIcons.hideDuplicates,
            hideFloating: root.appIcons.hideFloating
        })
    }

    Text {
        id: offline

        objectName: "offline"
        anchors.verticalCenter: parent.verticalCenter
        visible: !workspaceModel.connected && root.shown
        text: root.offlineLabel
        textFormat: Text.PlainText
        color: root.textColor
        font.family: root.bar ? root.bar.theme.bar.font.family : Application.font.family
        font.pixelSize: root.bar ? root.bar.theme.bar.font.pixelSize : 13
    }

    Flow {
        id: buttons

        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: root.spacing
        visible: workspaceModel.connected

        Repeater {
            // A count keeps each dot alive while the workspaces change, so the changes animate. Dots are rebuilt
            // only when the number of workspaces changes.
            model: workspaceModel.workspaces.length

            delegate: Item {
                id: dot

                required property int index
                readonly property var workspace: workspaceModel.workspaces[index] ?? ({})
                readonly property bool populated: (workspace.windowCount ?? 0) > 0
                readonly property bool focused: workspace.focused ?? false
                readonly property bool active: root.monitorExclusive && (workspace.displayed ?? false)
                readonly property bool numbers: root.style === "numbers"
                readonly property bool rings: root.style === "rings"
                // A ring workspace with a display name of its own shows the name
                readonly property bool named: rings && root.ringNames && !!workspace.displayName && workspace.displayName !== workspace.name
                // Size along the bar. A focused dot stretches into a pill, the one this monitor shows into a shorter one.
                readonly property real length: rings
                    ? (named ? Math.ceil(nameLabel.implicitWidth) + 4 : root.ringSize + 6)
                    : numbers ? (focused ? root.numberSize : Math.round(root.numberSize * 0.8))
                    : root.dotSize * (focused ? 3 : active ? 2 : 1)
                readonly property real across: numbers ? root.numberSize + 4 : rings ? root.ringSize + 10 : root.dotSize + 16
                readonly property Item shape: numbers ? box : rings ? (named ? nameLabel : ring) : pill

                objectName: "workspace-" + (workspace.name ?? "")
                implicitWidth: root.vertical ? across : length + 4
                implicitHeight: root.vertical ? length + 4 : across
                Accessible.role: Accessible.Button
                Accessible.name: root.label(workspace)
                onFocusedChanged: if (focused && root.animationDuration > 0) ripple.restart()

                Behavior on implicitWidth {
                    enabled: !root.vertical && root.animationDuration > 0
                    NumberAnimation { duration: root.animationDuration * 1.5; easing.type: Easing.OutBack }
                }
                Behavior on implicitHeight {
                    enabled: root.vertical && root.animationDuration > 0
                    NumberAnimation { duration: root.animationDuration * 1.5; easing.type: Easing.OutBack }
                }

                Rectangle {
                    id: box

                    visible: dot.numbers
                    anchors.centerIn: parent
                    width: dot.focused ? root.numberSize : Math.round(root.numberSize * 0.8)
                    height: width
                    radius: (dot.focused ? 7 : 5) * PanelBus.radiusScale
                    // Fading only the alpha brings the square in without passing through black.
                    color: dot.focused ? root.numberAccentColor
                        : mouseArea.containsMouse ? Qt.alpha(root.dotColor, 0.12) : Qt.alpha(root.numberAccentColor, 0)
                    scale: mouseArea.pressed ? 0.85 : 1

                    Behavior on width {
                        NumberAnimation { duration: root.animationDuration * 1.5; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: root.animationDuration }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: root.animationDuration / 2; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dot.workspace.displayName || dot.workspace.name || ""
                        textFormat: Text.PlainText
                        color: dot.focused ? root.numberAccentTextColor : root.dotColor
                        opacity: dot.focused || dot.active ? 1 : dot.populated ? 0.75 : 0.4
                        font.family: root.bar ? root.bar.theme.bar.font.family : Application.font.family
                        font.pixelSize: dot.focused ? 14 : 11
                        font.bold: dot.focused

                        Behavior on color {
                            ColorAnimation { duration: root.animationDuration }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: root.animationDuration }
                        }
                    }
                }

                Rectangle {
                    id: ring

                    visible: dot.rings && !dot.named
                    anchors.centerIn: parent
                    width: root.ringSize
                    height: root.ringSize
                    radius: Math.min(width / 2, PanelBus.pill)
                    // Fading only the alpha fills it in without passing through black.
                    color: dot.focused ? root.dotAccentColor : Qt.alpha(root.dotAccentColor, 0)
                    border.width: dot.focused ? 0 : dot.populated || dot.active ? 2 : 1.5
                    border.color: root.dotColor
                    opacity: dot.focused || dot.active ? 1 : dot.populated ? 0.85 : 0.4
                    scale: mouseArea.pressed ? 0.75 : mouseArea.containsMouse && !dot.focused ? 1.2 : 1

                    Behavior on color {
                        ColorAnimation { duration: root.animationDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: root.animationDuration }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutBack }
                    }

                    // Shown on another monitor
                    Rectangle {
                        anchors.centerIn: parent
                        visible: dot.active && !dot.focused
                        width: 4
                        height: 4
                        radius: 2 * PanelBus.radiusScale
                        color: root.dotColor
                    }
                }

                Text {
                    id: nameLabel

                    visible: dot.named
                    anchors.centerIn: parent
                    text: dot.workspace.displayName ?? ""
                    textFormat: Text.PlainText
                    color: dot.focused ? root.dotAccentColor : root.dotColor
                    opacity: dot.focused || dot.active ? 1 : dot.populated ? 0.85 : 0.4
                    font.family: root.bar ? root.bar.theme.bar.font.family : Application.font.family
                    font.pixelSize: (root.bar ? root.bar.theme.bar.font.pixelSize : 13) + 1
                    font.weight: dot.focused ? Font.Bold : Font.Medium
                    scale: mouseArea.pressed ? 0.85 : 1

                    Behavior on color {
                        ColorAnimation { duration: root.animationDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: root.animationDuration }
                    }
                }

                Rectangle {
                    id: pill

                    readonly property color tint: dot.focused ? root.dotAccentColor : root.dotColor

                    visible: !dot.numbers && !dot.rings
                    anchors.centerIn: parent
                    width: root.vertical ? root.dotSize : dot.width - 4
                    height: root.vertical ? dot.height - 4 : root.dotSize
                    radius: Math.min(root.dotSize / 2, PanelBus.pill)
                    // A ring while empty. Fading only the alpha fills it in without passing through black.
                    color: dot.populated || dot.focused || dot.active ? tint : Qt.alpha(tint, 0)
                    border.width: 1.5
                    border.color: tint
                    opacity: dot.focused || dot.active ? 1 : dot.populated ? 0.85 : 0.5
                    scale: mouseArea.pressed ? 0.75 : mouseArea.containsMouse && !dot.focused ? 1.3 : 1

                    Behavior on color {
                        ColorAnimation { duration: root.animationDuration }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: root.animationDuration }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: root.animationDuration }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutBack }
                    }
                }

                // A ring that spreads out from the workspace that just took focus.
                Rectangle {
                    id: wave

                    anchors.centerIn: dot.shape
                    width: dot.named ? root.ringSize + 6 : dot.shape.width
                    height: dot.named ? root.ringSize + 6 : dot.shape.height
                    radius: dot.named ? width / 2 : dot.shape.radius
                    color: "transparent"
                    border.width: 1.5
                    border.color: dot.numbers ? root.numberAccentColor : root.dotAccentColor
                    opacity: 0
                }

                ParallelAnimation {
                    id: ripple

                    NumberAnimation { target: wave; property: "scale"; from: 1; to: 1.6; duration: root.animationDuration * 3; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wave; property: "opacity"; from: 0.7; to: 0; duration: root.animationDuration * 3; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspaceModel.activateWorkspace(dot.workspace.name)
                }
            }
        }
    }

    WheelHandler {
        enabled: root.enableScrollSwitching && workspaceModel.connected
        onWheel: event => {
            const delta = event.angleDelta.y || event.angleDelta.x
            if (delta !== 0) {
                root.scroll(delta)
                event.accepted = true
            }
        }
    }
}
