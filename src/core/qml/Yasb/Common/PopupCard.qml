import QtQuick
import Yasb.Themes

// A box that holds a group of things in a popup, with the theme's card fill, outline and hard shadow.
Rectangle {
    id: card

    required property Theme theme

    radius: theme.radius.md
    color: theme.colors.card
    border.width: theme.popup.cardBorderWidth
    border.color: theme.colors.cardBorder

    // Drawn before the card, so it shows only where it sticks out
    Rectangle {
        z: -1
        visible: card.theme.popup.cardShadowOffset > 0
        x: card.theme.popup.cardShadowOffset
        y: card.theme.popup.cardShadowOffset
        width: card.width
        height: card.height
        radius: card.radius
        color: card.theme.colors.cardBorder
    }
}
