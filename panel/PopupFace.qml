import QtQuick

// The face of a popup in this setup's shape: the theme's popup colours, the outline, radius and hard shadow from the
// theme file's tokens (PanelBus), and the opening scale. `reveal` runs from 0 to 1 while the popup opens.
Rectangle {
    id: face

    property real reveal: 1

    radius: PanelBus.popupRadius
    color: PanelBus.theme?.popup.background ?? PanelBus.color
    border.width: PanelBus.borderWidth
    border.color: PanelBus.theme?.popup.border ?? PanelBus.outline
    opacity: reveal
    scale: PanelBus.openScale + reveal * (1 - PanelBus.openScale)

    // Drawn before the face, so it shows only where it sticks out
    Rectangle {
        z: -1
        visible: PanelBus.shadowOffset > 0
        x: PanelBus.shadowOffset
        y: PanelBus.shadowOffset
        width: face.width
        height: face.height
        radius: face.radius
        color: PanelBus.shadowColor
    }
}
