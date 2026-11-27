import QtQuick
import Yasb
import "../../panel"

// The keyboard layout as a short code ("EN"). A click switches the focused window to the next layout; the code
// takes the accent while Caps Lock is on.
Item {
    id: keyboardWidget

    property Item bar: null
    // Hidden while only one layout is installed
    property bool hideSingle: false

    readonly property var layouts: keyboard.layouts ?? []
    readonly property string code: (keyboard.language?.language_code ?? "").toUpperCase()

    function next() {
        if (layouts.length < 2)
            return
        const at = Math.max(0, layouts.findIndex(layout => layout.current))
        // The bar never takes focus, so the window focused now is the one to switch
        keyboard.rememberWindow()
        keyboard.activate(layouts[(at + 1) % layouts.length].id)
    }

    visible: code !== "" && !(hideSingle && layouts.length < 2)
    implicitWidth: visible ? button.implicitWidth : 0
    implicitHeight: visible ? button.implicitHeight : 0

    KeyboardLanguage {
        id: keyboard
    }

    BarButton {
        id: button

        anchors.centerIn: parent
        text: keyboardWidget.code
        foreground: keyboard.capsLock ? PanelBus.accent : PanelBus.textColor
        tip: (keyboard.language?.full_layout_name ?? keyboard.language?.layout_name ?? "")
            + (keyboard.capsLock ? "\nCaps Lock is on" : "")
            + (keyboardWidget.layouts.length > 1 ? "\nClick for the next layout" : "")
        onClicked: keyboardWidget.next()
    }
}
