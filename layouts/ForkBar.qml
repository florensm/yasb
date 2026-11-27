import QtQuick
import Yasb.Bar

// Yasb.Bar's Bar, with two additions: the slots can keep to a band across the bar (`slotBand`), and the first slot
// can start further in than the last one ends (`leadingSpace`).
BarBase {
    id: root

    // Extra space before the first slot, such as where another bar overlaps this one's start.
    property int leadingSpace: 0
    // Extra space after the last slot, such as between a side bar's last widget and the screen's edge.
    property int trailingSpace: 0

    property alias leftSlot: startItem
    property alias topSlot: startItem
    property alias centerSlot: centerItem
    property alias rightSlot: endItem
    property alias bottomSlot: endItem

    readonly property var lengths: sectionLengths((vertical ? height : width) - 2 * padding - leadingSpace - trailingSpace)

    // Stretching sections share the free space equally, but none gets shorter than its widgets
    function sectionLengths(available: real): var {
        const slots = [startItem, centerItem, endItem]
        const lengths = slots.map(slot => slot.contentLength)
        const flexible = slots.map((slot, index) => index)
            .filter(index => slots[index].stretch)
            .sort((a, b) => lengths[a] - lengths[b])
        let rest = available - slots.reduce((sum, slot, index) => sum + (slot.stretch ? 0 : lengths[index]), 0)
        while (flexible.length > 0) {
            const share = rest / flexible.length
            const longest = flexible[flexible.length - 1]
            if (lengths[longest] <= share) {
                // Whole pixels, so every section and its widgets start on one
                const whole = Math.floor(share)
                let remainder = Math.round(rest - whole * flexible.length)
                flexible.forEach(index => lengths[index] = whole + (remainder-- > 0 ? 1 : 0))
                break
            }
            rest -= lengths[longest]
            flexible.pop()
        }
        return lengths
    }

    // Where the slots, and so their widgets, sit across the bar, as [offset, size]: the whole thickness, unless a
    // bar keeps its widgets to a part of it.
    function slotBand(): var {
        return [0, vertical ? width : height]
    }

    readonly property var band: slotBand()

    contentImplicitLength: leadingSpace + startItem.contentLength + centerItem.contentLength + endItem.contentLength + trailingSpace

    WidgetSlot {
        id: startItem

        objectName: `slot-${name}`
        name: root.vertical ? "top" : "left"
        bar: root
        alignment: root.vertical ? "top" : "left"
        x: root.vertical ? root.band[0] : root.leadingSpace
        y: root.vertical ? root.leadingSpace : root.band[0]
        width: root.vertical ? root.band[1] : root.lengths[0]
        height: root.vertical ? root.lengths[0] : root.band[1]
    }

    WidgetSlot {
        id: centerItem

        objectName: `slot-${name}`
        name: "center"
        bar: root
        alignment: "center"
        x: root.vertical ? root.band[0] : startItem.x + startItem.width
        y: root.vertical ? startItem.y + startItem.height : root.band[0]
        width: root.vertical ? root.band[1] : root.lengths[1]
        height: root.vertical ? root.lengths[1] : root.band[1]
    }

    WidgetSlot {
        id: endItem

        objectName: `slot-${name}`
        name: root.vertical ? "bottom" : "right"
        bar: root
        alignment: root.vertical ? "bottom" : "right"
        x: root.vertical ? root.band[0] : centerItem.x + centerItem.width
        y: root.vertical ? centerItem.y + centerItem.height : root.band[0]
        width: root.vertical ? root.band[1] : root.lengths[2]
        height: root.vertical ? root.lengths[2] : root.band[1]
    }
}
