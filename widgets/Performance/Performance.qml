pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Yasb
import "../../panel"

// CPU, memory and GPU together. On the bar: "CPU 15%  RAM 50%". In the panel: each with its numbers and the last
// two minutes as a graph.
Item {
    id: perf

    property Item bar: null
    property string keys: "ctrl+alt+p"
    property int updateInterval: 2000
    // Which GPU to show, as Windows counts them
    property int gpuIndex: 0
    property bool showGpu: true

    property list<real> cpuHistory: []
    property list<real> memoryHistory: []
    property list<real> gpuHistory: []

    readonly property real cpuLoad: Math.max(0, cpu.data?.percent?.total ?? 0)
    readonly property real memoryLoad: memory.data?.virtual?.percent ?? 0
    readonly property real gpuLoad: gpu.data?.utilization ?? 0

    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("performance") ?? false

    function toggle() {
        panelHost?.toggle("performance", perf)
    }

    function gigabytes(bytes: real): string {
        return Number.isFinite(bytes) ? (bytes / 1073741824).toFixed(1) : "--"
    }

    function size(bytes: real): string {
        if (!Number.isFinite(bytes) || bytes <= 0)
            return "--"
        return bytes >= 1073741824 ? `${(bytes / 1073741824).toFixed(1)} GB` : `${Math.round(bytes / 1048576)} MB`
    }

    implicitWidth: readout.implicitWidth
    implicitHeight: readout.implicitHeight

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("performance", pageView, perf)
        }
    }
    Component.onCompleted: PanelBus.register("performance", keys)
    Component.onDestruction: panelHost?.withdraw("performance", perf)

    CpuMonitor {
        id: cpu

        updateInterval: perf.updateInterval
        onDataChanged: perf.cpuHistory = [...perf.cpuHistory, cpu.data.percent.total].slice(-60)
    }

    MemoryMonitor {
        id: memory

        updateInterval: perf.updateInterval
        onDataChanged: perf.memoryHistory = [...perf.memoryHistory, memory.data.virtual.percent].slice(-60)
    }

    GpuMonitor {
        id: gpu

        gpuIndex: perf.gpuIndex
        updateInterval: perf.showGpu ? perf.updateInterval : 60000
        onDataChanged: perf.gpuHistory = [...perf.gpuHistory, gpu.data.utilization].slice(-60)
    }

    Hotkey {
        keys: perf.keys
        onActivated: perf.toggle()
    }

    // "CPU 15%  RAM 50%" on the bar
    Row {
        id: readout

        anchors.centerIn: parent
        spacing: 0

        BarButton {
            open: perf.panelOpen
            text: `CPU ${Math.round(perf.cpuLoad)}%`
            tip: `CPU ${Math.round(perf.cpuLoad)}% · Memory ${Math.round(perf.memoryLoad)}%`
                + (perf.showGpu ? ` · GPU ${Math.round(perf.gpuLoad)}%` : "") + ` (${PanelBus.label(perf.keys)})`
            onClicked: perf.toggle()
        }
        BarButton {
            open: perf.panelOpen
            text: `RAM ${Math.round(perf.memoryLoad)}%`
            tip: `Memory ${perf.gigabytes(memory.data?.virtual?.used)} of ${perf.gigabytes(memory.data?.virtual?.total)} GB`
            onClicked: perf.toggle()
        }
    }

    // A line through the last values, 0 to 100, filling down to the bottom
    component Graph: Item {
        id: graph

        property list<real> values: []
        property color color: PanelBus.accent
        readonly property var points: values.map((value, index) => Qt.point(
            values.length > 1 ? index * width / (59) + (60 - values.length) * width / 59 : width,
            height - 2 - Math.max(0, Math.min(100, value)) / 100 * (height - 4)))

        Shape {
            anchors.fill: parent
            visible: graph.points.length > 1
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    y1: 0
                    y2: graph.height
                    GradientStop { position: 0; color: Qt.alpha(graph.color, 0.22) }
                    GradientStop { position: 1; color: Qt.alpha(graph.color, 0) }
                }
                startX: graph.points[0]?.x ?? 0
                startY: graph.height
                PathPolyline { path: graph.points }
                PathLine { x: graph.width; y: graph.height }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: graph.color
                strokeWidth: 1.6
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap
                PathPolyline { path: graph.points }
            }
        }
    }

    component Meter: Item {
        id: meter

        property real value: 0
        property color color: PanelBus.accent

        implicitHeight: 6

        Rectangle {
            anchors.fill: parent
            radius: 3 * PanelBus.radiusScale
            color: PanelBus.raised
        }
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
            height: parent.height
            radius: 3 * PanelBus.radiusScale
            color: meter.color

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }
    }

    component Card: Rectangle {
        default property alias content: inner.data

        implicitHeight: inner.implicitHeight + 28
        radius: 12 * PanelBus.radiusScale
        color: PanelBus.surface
        border.width: PanelBus.cardBorderWidth
        border.color: PanelBus.outline

        ColumnLayout {
            id: inner

            x: 14
            y: 14
            width: parent.width - 28
            spacing: 10
        }
    }

    component Heading: RowLayout {
        property string title
        property string detail

        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: parent.title
            color: PanelBus.textDim
            font.family: PanelBus.font.family
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            font.capitalization: Font.AllUppercase
        }
        Text {
            text: parent.detail
            color: PanelBus.textDim
            font.family: PanelBus.font.family
            font.pixelSize: 12
        }
    }

    // A load in large figures with a small percent sign
    component Big: Row {
        property real value: 0

        spacing: 2

        Text {
            text: Math.round(Math.max(0, Math.min(100, parent.value)))
            color: PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }
        Text {
            anchors.baseline: parent.children[0].baseline
            text: "%"
            color: PanelBus.textDim
            font.family: PanelBus.font.family
            font.pixelSize: 15
        }
    }

    // ---------- The page ----------

    property Item page: Item {
        id: pageView

        Flickable {
            anchors.fill: parent
            contentHeight: cards.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: cards

                width: parent.width
                spacing: 12

                Card {
                    Layout.fillWidth: true

                    Heading {
                        title: "CPU"
                        detail: cpu.data?.freq ? `${(cpu.data.freq.current / 1000).toFixed(2)} GHz · ${cpu.data.cores.physical} cores, ${cpu.data.cores.total} threads` : ""
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Big {
                            Layout.preferredWidth: 80
                            value: perf.cpuLoad
                        }
                        Graph {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            values: perf.cpuHistory
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true

                    Heading {
                        title: "Memory"
                        detail: memory.data?.virtual ? `${perf.gigabytes(memory.data.virtual.used)} of ${perf.gigabytes(memory.data.virtual.total)} GB` : ""
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Big {
                            Layout.preferredWidth: 80
                            value: perf.memoryLoad
                        }
                        Graph {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            values: perf.memoryHistory
                            color: PanelBus.accent2
                        }
                    }
                    Meter {
                        Layout.fillWidth: true
                        value: perf.memoryLoad
                        color: PanelBus.accent2
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: (memory.data?.swap?.total ?? 0) > 0
                        text: `Page file ${perf.size(memory.data?.swap?.used)} of ${perf.size(memory.data?.swap?.total)}`
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                }

                Card {
                    Layout.fillWidth: true
                    visible: perf.showGpu

                    Heading {
                        title: "GPU"
                        detail: Number.isFinite(gpu.data?.temp) && gpu.data.temp > 0 ? `${Math.round(gpu.data.temp)} °C` : ""
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: gpu.data?.name ?? ""
                        elide: Text.ElideRight
                        color: PanelBus.textColor
                        font.family: PanelBus.font.family
                        font.pixelSize: 13
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Big {
                            Layout.preferredWidth: 80
                            value: perf.gpuLoad
                        }
                        Graph {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            values: perf.gpuHistory
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: (gpu.data?.mem_total ?? 0) > 0
                        spacing: 10

                        Text {
                            text: "VRAM"
                            color: PanelBus.textDim
                            font.family: PanelBus.font.family
                            font.pixelSize: 12
                        }
                        Meter {
                            Layout.fillWidth: true
                            value: (gpu.data?.mem_total ?? 0) > 0 ? 100 * gpu.data.mem_used / gpu.data.mem_total : 0
                        }
                        Text {
                            text: `${perf.size(gpu.data?.mem_used)} / ${perf.size(gpu.data?.mem_total)}`
                            color: PanelBus.textDim
                            font.family: PanelBus.font.family
                            font.pixelSize: 12
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 10 * PanelBus.radiusScale
                    color: taskArea.containsMouse ? PanelBus.raised : PanelBus.surface

                    border.width: PanelBus.cardBorderWidth
                    border.color: PanelBus.outline
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open Task Manager"
                        color: taskArea.containsMouse ? PanelBus.textColor : PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\ue76c"
                        color: PanelBus.textDim
                        font.family: PanelBus.iconFont.family
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: taskArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            perf.panelHost?.hide()
                            Qt.openUrlExternally("file:///C:/Windows/System32/Taskmgr.exe")
                        }
                    }
                }
            }
        }
    }
}
