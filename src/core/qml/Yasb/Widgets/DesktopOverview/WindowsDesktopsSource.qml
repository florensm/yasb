import QtQuick
import Yasb

// Windows' virtual desktops, each under its number.
OverviewSource {
    id: source

    property int lastCount: 0

    cards: desktops.desktops.map(desktop => ({
        key: desktop.number,
        label: String(desktop.number),
        name: desktop.name,
        title: desktop.name || qsTr("Desktop %1").arg(desktop.number),
        detail: desktop.app,
        populated: desktop.populated,
        icons: []
    }))
    currentKey: desktops.current
    canCreate: true
    // Windows' own slide between desktops
    switchCover: 350

    onSwitchRequested: card => desktops.switchTo(card.key)
    onCreateRequested: desktops.create()

    VirtualDesktops {
        id: desktops

        onDesktopsChanged: {
            const count = desktops.desktops.length
            // Deleting a desktop renumbers the ones after it, so their pictures would land on the wrong cards
            if (count !== source.lastCount && source.lastCount > 0)
                source.stale(Array.from({ length: source.lastCount }, (_, index) => index + 1))
            source.lastCount = count
        }
    }
}
