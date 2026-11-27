import QtQuick

// The panel's card: a box in the theme's popup colours and shape, floating under the bar like the calendar and the
// power menu, with the theme's hard shadow behind it. `reveal` fades and grows it in from its top edge: 0 hidden,
// 1 shown. `card` is what the blur follows.
Item {
    id: surface

    property real reveal: 1
    readonly property real panelWidth: width
    readonly property alias card: card
    default property alias content: card.data

    // Behind the card, moved right and down; drawn only when the theme has one
    Rectangle {
        visible: PanelBus.shadowOffset > 0
        x: PanelBus.shadowOffset
        y: PanelBus.shadowOffset
        width: card.width
        height: card.height
        radius: card.radius
        color: PanelBus.shadowColor
        opacity: card.opacity
        scale: card.scale
        transformOrigin: Item.Top
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: PanelBus.popupRadius
        color: PanelBus.theme?.popup.background ?? PanelBus.color
        border.width: PanelBus.borderWidth
        border.color: PanelBus.theme?.popup.border ?? PanelBus.outline
        opacity: surface.reveal
        scale: PanelBus.openScale + surface.reveal * (1 - PanelBus.openScale)
        transformOrigin: Item.Top
        clip: true
    }
}
