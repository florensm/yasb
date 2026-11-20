import QtQuick
import Yasb.Themes

// The face of a popup: its fill, outline and corners, with the theme's hard shadow behind it. `reveal` runs from 0
// to 1 while the popup opens, fading it in and growing it from `transformOrigin` the theme's way.
Rectangle {
    id: surface

    required property Theme theme
    property real reveal: 1

    radius: theme.popup.radius
    color: theme.popup.background
    border.width: theme.popup.borderWidth
    border.color: theme.popup.border
    opacity: reveal
    scale: theme.popup.openScale + reveal * (1 - theme.popup.openScale)

    // Drawn before the surface, so it shows only where it sticks out
    Rectangle {
        z: -1
        visible: surface.theme.popup.shadowOffset > 0
        x: surface.theme.popup.shadowOffset
        y: surface.theme.popup.shadowOffset
        width: surface.width
        height: surface.height
        radius: surface.radius
        color: surface.theme.popup.shadowColor
    }
}
