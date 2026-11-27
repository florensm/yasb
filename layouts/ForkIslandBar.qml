import QtQuick
import QtQuick.Shapes
import Yasb.Bar

ForkBar {
    id: root

    property real railHeight: 4
    property real edgeRadius: 0
    // Where the bars on the neighbouring edges end, measured in from this bar's start and end. Above 0 the rail
    // curves there into a rounded inner corner of `radius`, so bars on every edge frame the screen. The curve
    // takes the room the bar is thicker than its rail; a bar with none, like a thin strip, leaves the corner to
    // its neighbour. The border then follows only the frame's inner edge up to the neighbouring bars, so the
    // bars on every edge draw one line around the screen.
    property real cornerStart: 0
    property real cornerEnd: 0
    // true: every widget sits on the rail and nothing bulges into an island, so a side bar's rail holds its
    // widgets. false: a widget makes an island unless it declares `property bool island: false`.
    property bool railWidgets: false
    property ShapeGradient fillGradient: null

    readonly property real barLength: vertical ? height : width
    readonly property real barThickness: vertical ? width : height
    // [start, end, reach, bulges] for each island, reach being how far it bulges past the rail, from 0 to 1. A
    // widget sets its island's with `property real islandReach`, to pop it out of the bar or sink it back in,
    // and can raise parts of it further with `property var islandBulges: [[from, to, reach], ...]`, measured
    // along the bar from its own start. Each bulge rounds into the island like the island into the rail.
    readonly property var islandShapes: islandSpans()
    readonly property var islands: islandShapes.map(shape => [shape[0], shape[1]])

    property Shape islandShape: Shape {
        parent: root
        z: -1
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            fillGradient: root.fillGradient
            strokeWidth: -1
            PathSvg { path: root.silhouette }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.border.color
            strokeWidth: root.border.width > 0 ? root.border.width : -1
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.outline(root.border.width / 2, false, true) }
        }
    }

    // A widget that declares `property bool island: false` ends the island it is in, and the next widget
    // starts a new one
    function islandSpans(): var {
        const spans = []
        const outside = []
        const bulges = []
        for (const slot of slots) {
            if (!slot.visible)
                continue
            let origin = slot.contentStart
            for (let item = slot; item && item !== root; item = item.parent)
                origin += vertical ? item.y : item.x
            let run = null
            for (const widget of slot.content.children) {
                const size = vertical ? widget.height : widget.width
                if (!widget.visible || size <= 0)
                    continue
                const start = origin + (vertical ? widget.y : widget.x)
                if (!isIsland(widget.item)) {
                    outside.push(start, start + size)
                    if (run)
                        spans.push(run)
                    run = null
                } else if (run) {
                    run[1] = start + size
                    run[2] = Math.max(run[2], islandReach(widget.item))
                } else {
                    run = [start, start + size, islandReach(widget.item)]
                }
                if (isIsland(widget.item)) {
                    for (const [from, to, reach] of widget.item?.islandBulges ?? [])
                        bulges.push([start + from, start + to, Math.max(0, Math.min(1, reach))])
                }
            }
            if (run)
                spans.push(run)
        }
        for (const span of spans)
            span.splice(0, 2, Math.round(span[0] - padding), Math.round(span[1] + padding))
        spans.sort((a, b) => a[0] - b[0])

        const merged = []
        for (const [start, end, reach] of spans) {
            const from = Math.max(0, start)
            const to = Math.min(barLength, end)
            const last = merged[merged.length - 1]
            if (to <= from)
                continue
            if (last && from <= last[1]) {
                last[1] = Math.max(last[1], to)
                last[2] = Math.max(last[2], reach)
            } else {
                merged.push([from, to, reach, []])
            }
        }
        if (merged.length > 0) {
            const first = merged[0]
            const last = merged[merged.length - 1]
            if (first[0] <= radius && !outside.some(edge => edge < first[0]))
                first[0] = 0
            if (last[1] >= barLength - radius && !outside.some(edge => edge > last[1]))
                last[1] = barLength
            // The edge curves meet the full thickness
            if (edgeRadius > 0) {
                if (first[0] === 0)
                    first[2] = 1
                if (last[1] === barLength)
                    last[2] = 1
            }
        }
        for (const [from, to, reach] of bulges) {
            const island = merged.find(shape => from < shape[1] && to > shape[0])
            if (island)
                island[3].push([Math.max(from, island[0]), Math.min(to, island[1]), reach])
        }
        for (const island of merged)
            island[3].sort((a, b) => a[0] - b[0])
        return merged
    }

    function islandReach(widget: Item): real {
        return Math.max(0, Math.min(1, widget?.islandReach ?? 1))
    }

    function isIsland(widget: Item): bool {
        return !railWidgets && widget?.island !== false
    }

    function slotBand(): var {
        if (!railWidgets)
            return [0, barThickness]
        const rail = railSize()
        return [edge === "right" || edge === "bottom" ? barThickness - rail : 0, rail]
    }

    function railSize(): real {
        return Math.min(railHeight, barThickness)
    }

    function innerCorner(): real {
        return Math.max(0, Math.min(radius, barThickness - railSize()))
    }

    // How far the island reaches from the screen edge, and the largest its corners can round. `moving` counts
    // an island that is out at all at its full reach.
    function reachDepth(reach: real, moving: bool): real {
        return railSize() + (barThickness - railSize()) * (moving && reach > 0 ? 1 : reach)
    }

    function islandDepth(index: int, moving: bool): real {
        return reachDepth(islandShapes[index][2], moving)
    }

    function islandLimit(index: int, moving: bool): real {
        return Math.max(0, Math.min(radius, (islandDepth(index, moving) - railSize()) / 2))
    }

    function fillets(index: int, moving: bool): var {
        const [start, end] = islands[index]
        const previous = index > 0 ? islands[index - 1][1] : 0
        const next = index + 1 < islands.length ? islands[index + 1][0] : barLength
        return [
            start > 0 ? Math.min(islandLimit(index, moving), (start - previous) / 2) : 0,
            end < barLength ? Math.min(islandLimit(index, moving), (next - end) / 2) : 0,
        ]
    }

    // Item coordinates of a point `along` the bar's length and `across` it, away from the screen edge
    function point(along: real, across: real): string {
        switch (edge) {
        case "bottom":
            return `${along} ${barThickness - across}`
        case "left":
            return `${across} ${along}`
        case "right":
            return `${barThickness - across} ${along}`
        default:
            return `${along} ${across}`
        }
    }

    // Path pieces moved `inset` into the shape: an arc, and, walking toward the bar's start, a rise from depth
    // `low` to `high` at `at` through a concave fillet and a convex corner, and a fall back down the same way
    function pieces(inset: real): var {
        const mirrored = edge === "bottom" || edge === "left"
        const arc = (r, along, across, sweep) => r > 0
            ? `A ${r} ${r} 0 0 ${mirrored ? 1 - sweep : sweep} ${point(along, across)}`
            : `L ${point(along, across)}`
        return {
            arc,
            rise: (at, low, high, fillet, corner) => [
                `L ${point(at + fillet, low)}`,
                arc(fillet + inset, at - inset, low + inset + fillet, 0),
                `L ${point(at - inset, high - corner)}`,
                arc(corner, at - inset - corner, high, 1),
            ],
            fall: (at, high, low, corner, fillet) => [
                `L ${point(at + inset + corner, high)}`,
                arc(corner, at + inset, high - corner, 1),
                `L ${point(at + inset, low + inset + fillet)}`,
                arc(fillet + inset, at - fillet, low, 0),
            ],
        }
    }

    // Island `index` past the rail, walking toward the bar's start: up from the rail at its end, over its
    // bulges, and back down at its start, where those are inside the bar
    function islandOutline(index: int, inset: real, moving: bool): var {
        const {rise, fall} = pieces(inset)
        const [start, end] = islands[index]
        const [before, after] = fillets(index, moving)
        const rail = railSize() - inset
        const far = islandDepth(index, moving) - inset
        const corner = Math.max(0, Math.min(islandLimit(index, moving), (end - start) / 2) - inset)
        const path = []
        if (end < barLength)
            path.push(...rise(end, rail, far, after, corner))
        // Bulges rise further out of the island, like islands of their own on top of it
        const bulges = islandShapes[index][3]
        for (let bulge = bulges.length - 1; bulge >= 0; --bulge) {
            const [from, to, reach] = bulges[bulge]
            const high = reachDepth(reach, moving) - inset
            if (high <= far)
                continue
            const limit = Math.max(0, Math.min(radius, (high - far) / 2))
            const top = Math.max(0, Math.min(limit, (to - from) / 2) - inset)
            path.push(...rise(to, far, high, Math.min(limit, (end - to) / 2), top))
            path.push(...fall(from, high, far, top, Math.min(limit, (from - start) / 2)))
        }
        if (start > 0)
            path.push(...fall(start, far, rail, corner, before))
        return path
    }

    // SVG path along the side of the shape away from the screen edge, from the far end of the bar back to
    // its start, moved `inset` into the shape. The edge curves hang outside the item, in the space the
    // window adds for them. `moving` draws each island that is out at all at its full reach. `trim` leaves out
    // what lies along the neighbouring bars past cornerStart and cornerEnd, for the border.
    function outline(inset: real, moving: bool, trim: bool): string {
        const {arc} = pieces(inset)
        const length = barLength
        const rail = railSize() - inset
        const bottom = barThickness - inset
        const last = islands.length - 1
        const inner = innerCorner()
        const path = []
        if (last < 0 || islands[last][1] < length) {
            const at = length - cornerEnd
            if (!trim || cornerEnd <= 0)
                path.push(`M ${point(length, rail)}`)
            else if (inner <= 0)
                // The neighbouring bar draws the corner, which ends `radius` past it
                path.push(`M ${point(at - radius, rail)}`)
            if (cornerEnd > 0 && inner > 0) {
                if (trim) {
                    path.push(`M ${point(at + inset, rail + inset + inner)}`)
                } else {
                    path.push(`L ${point(at + inset, rail)}`)
                    path.push(`L ${point(at + inset, rail + inset + inner)}`)
                }
                path.push(arc(inner + inset, at - inner, rail, 0))
            }
        } else if (edgeRadius > 0) {
            path.push(`M ${point(length + inset, barThickness + edgeRadius)}`)
            path.push(arc(edgeRadius + inset, length - edgeRadius, bottom, 0))
        } else {
            path.push(`M ${point(length, islandDepth(last, moving) - inset)}`)
        }

        for (let index = last; index >= 0; --index) {
            // Comes back down to the rail by itself where the island starts inside the bar
            path.push(...islandOutline(index, inset, moving))
            if (islands[index][0] > 0)
                continue
            if (edgeRadius > 0) {
                path.push(`L ${point(edgeRadius, bottom)}`)
                path.push(arc(edgeRadius + inset, -inset, barThickness + edgeRadius, 0))
            } else {
                path.push(`L ${point(0, islandDepth(index, moving) - inset)}`)
            }
        }
        if (last < 0 || islands[0][0] > 0) {
            if (cornerStart > 0 && inner > 0) {
                path.push(`L ${point(cornerStart + inner, rail)}`)
                path.push(arc(inner + inset, cornerStart - inset, rail + inset + inner, 0))
                if (!trim)
                    path.push(`L ${point(cornerStart - inset, rail)}`)
            } else if (trim && cornerStart > 0) {
                path.push(`L ${point(cornerStart + radius, rail)}`)
            }
            if (!trim || cornerStart <= 0)
                path.push(`L ${point(0, rail)}`)
        }
        return path.join(" ")
    }

    function fillPath(moving: bool): string {
        return `${outline(0, moving, false)} L ${point(0, 0)} L ${point(barLength, 0)} Z`
    }

    // The shape drawn, which the native blur follows too
    readonly property string silhouette: fillPath(false)
    // Where a bar reaching over windows takes clicks: the silhouette with every island that pops in or out at
    // its full reach, so the window changes shape only as one starts or finishes moving, not on every frame
    readonly property string clickPath: fillPath(true)

    backdropShapes: []
    backdropPath: silhouette
    radius: 12
    background.visible: false

    Component.onCompleted: {
        if (gradient)
            console.warn("IslandBar does not use gradient, which only fills a Rectangle. Set fillGradient to a LinearGradient from QtQuick.Shapes instead.")
    }
}
