import QtQuick
import "../panel"

// The bar along the top, and optionally a small frame on the left, right and bottom: one bar per edge, all from this
// layout. With the frame, the inner corners where the bars meet are rounded. Colours and fonts come from the theme
// file config.yaml names. Without the frame, the top bar looks as the control center's Bar setting says: Full across
// the screen, Floating as one card clear of its edges, or Islands with a card around each group of widgets.
ForkIslandBar {
    id: frame

    // Set to true, and turn on the frame bars in config.yaml, for the frame around the screen.
    readonly property bool framed: false
    readonly property int barHeight: 32 // The top bar; with the frame its thickness in config.yaml is this plus the corner.
    readonly property int rail: 4       // The frame on the left, right and bottom.

    // full, floating or islands; only the top bar without the frame changes
    readonly property string barStyle: edge === "top" && !framed ? PanelBus.barStyle : "full"
    // The cards of Floating and Islands: clear of the screen's edges by `gap`, rounded with the theme
    readonly property real gap: 3
    readonly property real cardRadius: Math.min((height - 2 * gap) / 2, 8 * PanelBus.radiusScale)
    // Each group's card, as [x, width], from where its widgets sit
    readonly property var islandCards: [leftSlot, centerSlot, rightSlot]
        .filter(slot => slot && slot.contentLength > 0)
        .map(slot => [slot.x + slot.contentOffset - 6, slot.contentLength + 12])

    color: barStyle === "full" ? theme.bar.background : "transparent"
    // Scales with the theme's corners: 10 with the usual ones, 0 in a square theme
    radius: 10 * PanelBus.radiusScale
    border.width: 0
    railHeight: edge === "top" ? barHeight : rail
    // The top bar holds its widgets on its solid part; with the frame, the space under it carries the rounded corners.
    railWidgets: edge === "top"
    // The side rails start where the top bar's solid part ends; the top and bottom bars start and end at the side
    // rails. Without the frame there is nothing to round into.
    cornerStart: !framed ? 0 : edge === "left" || edge === "right" ? barHeight : rail
    cornerEnd: framed ? rail : 0
    // The top bar's widgets keep clear of the side rails and their corners, and of a floating card's edges.
    leadingSpace: edge === "top" ? (framed ? rail : 0) + (barStyle === "floating" ? 12 : 6) : 0
    trailingSpace: edge === "top" ? (framed ? rail : 0) + (barStyle === "floating" ? 12 : 6) : 0
    padding: 6
    spacing: 4
    // The blur behind the bar follows its cards
    backdropPath: barStyle === "full" ? silhouette : ""
    backdropShapes: barStyle === "floating" ? [{ x: gap * 2, y: gap, width: width - gap * 4, height: height - gap * 2, radius: cardRadius }]
        : barStyle === "islands" ? islandCards.map(card => ({ x: card[0], y: gap, width: card[1], height: height - gap * 2, radius: cardRadius }))
        : []

    // Full: a line along the bottom in a theme with ink outlines
    Rectangle {
        z: -1
        visible: frame.barStyle === "full" && PanelBus.borderWidth > 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: PanelBus.borderWidth
        color: frame.theme.bar.border
    }

    // Floating: one card
    BarCard {
        visible: frame.barStyle === "floating"
        x: frame.gap * 2
        width: frame.width - frame.gap * 4
    }

    // Islands: a card around each group of widgets
    Repeater {
        model: frame.barStyle === "islands" ? frame.islandCards : []

        delegate: BarCard {
            required property var modelData

            x: modelData[0]
            width: modelData[1]
        }
    }

    component BarCard: Rectangle {
        z: -1
        y: frame.gap
        height: frame.height - frame.gap * 2
        radius: frame.cardRadius
        color: frame.theme.bar.background
        border.width: PanelBus.borderWidth
        border.color: frame.theme.bar.border

        // The theme's hard shadow, as far as the bar has room for it
        Rectangle {
            z: -1
            visible: PanelBus.shadowOffset > 0
            x: Math.min(PanelBus.shadowOffset, frame.gap - 1)
            y: Math.min(PanelBus.shadowOffset, frame.gap - 1)
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: PanelBus.shadowColor
        }
    }
}
