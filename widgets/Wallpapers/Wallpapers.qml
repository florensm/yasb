pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Yasb
import Yasb.Common
import "../../panel"

// Wallpapers: a button on the bar that opens a panel in the middle of the screen with a large view of the wallpaper
// under the pointer (or the current one) and the colours it would give, a search, shuffle, a grid of every wallpaper in
// your folders, the desktop transition to play, and whether the theme takes the wallpaper's colours. A click or Enter
// sets the wallpaper, and the panel stays open to try another; Escape closes it. Right click on the bar button sets a
// random one.
Item {
    id: wallpapers

    property Item bar: null
    // Folders searched for wallpapers, subfolders included; empty for your Pictures folder
    property list<string> folders: ["C:/Users/FMN/OneDrive - SPS/Afbeeldingen/Wallpapers/"]
    // Hotkey that opens the panel, such as "alt+w", and its screen: active, cursor or primary
    property string keys: "ctrl+alt+w"
    property string hotkeyScreen: "active"
    // Thumbnails in a row
    property int columns: 4
    // The desktop transition when a wallpaper is set on every screen: circle, slide_top, diamond, split or "" for
    // none. The panel's Transition buttons change it, and it is remembered
    readonly property string animation: store.animation

    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("wallpapers") ?? false

    // The wallpaper on this bar's screen
    property string currentPath: ""

    function toggleGallery() {
        panelHost?.toggle("wallpapers", wallpapers)
    }

    function updateCurrentPath() {
        const index = library.currentIndex(wallpapers.Screen.name)
        currentPath = index >= 0 ? (library.images[index]?.path ?? "") : ""
    }

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("wallpapers", panelContent, wallpapers)
        }
    }
    onCurrentPathChanged: WallpaperColors.wallpaperPath = currentPath
    Component.onCompleted: {
        PanelBus.register("wallpapers", wallpapers.keys)
        updateCurrentPath()
    }
    Component.onDestruction: panelHost?.withdraw("wallpapers", wallpapers)

    Settings {
        id: store

        location: Qt.resolvedUrl("../../control-center.ini")
        category: "wallpapers"
        property string animation: "circle"
    }

    WallpaperLibrary {
        id: library

        folders: wallpapers.folders
        animation: wallpapers.animation
    }

    Hotkey {
        keys: wallpapers.keys
        screen: wallpapers.hotkeyScreen
        onActivated: wallpapers.toggleGallery()
    }

    Connections {
        target: library

        function onCurrentChanged() {
            wallpapers.updateCurrentPath()
        }
        function onImagesChanged() {
            wallpapers.updateCurrentPath()
        }
    }

    // The wallpaper colours (the Wallpaper colour scheme): a small copy of the wallpaper on this screen is read by
    // WallpaperPalette, and WallpaperColors fades to the palette it makes, however the wallpaper changes
    WallpaperThumbnail {
        id: paletteSource

        path: wallpapers.currentPath
        size: Qt.size(128, 72)
        // A cached copy comes back at once, so the same wallpaper is read again only when it changes
        onPathChanged: if (source.toString() !== "") palette.source = source
        onSourceChanged: {
            if (source.toString() !== "")
                palette.source = source
        }
    }

    WallpaperPalette {
        id: palette

        onExtracted: WallpaperColors.setWallpaperPalette(palette)
    }

    BarButton {
        id: barButton

        anchors.centerIn: parent
        icon: "image"
        open: wallpapers.panelOpen
        tip: qsTr("Wallpapers (%1) · right click for a random one").arg(PanelBus.label(wallpapers.keys))
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse?.button === Qt.RightButton)
                library.setRandomWallpaper()
            else
                wallpapers.toggleGallery()
        }
    }

    property Component panelContent: Component {
        Item {
            id: gallery

            property string query: ""
            readonly property var shown: library.images.filter(image => query === ""
                || image.name.toLowerCase().includes(query.toLowerCase()))
            readonly property int currentShown: shown.findIndex(image => image.path === wallpapers.currentPath)
            // The wallpaper under the pointer or picked with the keys, else the one on the screen
            readonly property var preview: shown[grid.currentIndex] ?? library.images.find(image => image.path === wallpapers.currentPath) ?? null
            readonly property bool previewIsCurrent: (preview?.path ?? "") === wallpapers.currentPath

            function apply(path: string) {
                if (path !== "" && path !== wallpapers.currentPath)
                    library.setWallpaper(path)
            }

            // Called by PanelHost each time the panel opens
            function panelShown(fresh: bool) {
                library.refresh()
                search.text = ""
                grid.currentIndex = Math.max(0, currentShown)
                grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
                grid.forceActiveFocus()
            }

            Keys.onEscapePressed: wallpapers.panelHost?.hide()

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // The large view, with its name and the colours it gives
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(width * 0.36)

                    Rectangle {
                        visible: PanelBus.cardShadowOffset > 0
                        x: PanelBus.cardShadowOffset
                        y: PanelBus.cardShadowOffset
                        width: parent.width
                        height: parent.height
                        radius: hero.radius
                        color: PanelBus.outline
                    }

                    RoundedImage {
                        id: hero

                        anchors.fill: parent
                        path: gallery.preview?.path ?? ""
                        radius: 12 * PanelBus.radiusScale
                    }

                    // A shade along the bottom, under the caption
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 72
                        bottomLeftRadius: hero.radius
                        bottomRightRadius: hero.radius
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.alpha("#000000", 0.6) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: hero.radius
                        color: "transparent"
                        border.width: Math.max(PanelBus.cardBorderWidth, 1)
                        border.color: PanelBus.cardBorderWidth > 0 ? PanelBus.outline : Qt.alpha("#ffffff", 0.12)
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        width: parent.width - swatches.width - 42
                        spacing: 2

                        Text {
                            width: parent.width
                            text: gallery.preview?.name ?? qsTr("No wallpapers found")
                            elide: Text.ElideRight
                            color: "#ffffff"
                            font.family: PanelBus.font.family
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: gallery.previewIsCurrent ? qsTr("On your desktop") : qsTr("Click or press Enter to set it")
                            color: Qt.alpha("#ffffff", 0.75)
                            font.family: PanelBus.font.family
                            font.pixelSize: 11
                        }
                    }

                    // The colours this wallpaper gives with the Wallpaper colour scheme
                    Row {
                        id: swatches

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        spacing: 4
                        visible: previewPalette.ready

                        Repeater {
                            model: [previewPalette.bar, previewPalette.surface, previewPalette.accent, previewPalette.accent2, previewPalette.text]

                            delegate: Rectangle {
                                required property color modelData

                                width: 16
                                height: 16
                                radius: 4 * PanelBus.radiusScale
                                color: modelData
                                border.width: 1
                                border.color: Qt.alpha("#ffffff", 0.7)
                            }
                        }
                    }

                    WallpaperThumbnail {
                        id: previewSource

                        path: gallery.preview?.path ?? ""
                        size: Qt.size(128, 72)
                        onSourceChanged: {
                            if (source.toString() !== "")
                                previewPalette.source = source
                        }
                    }

                    WallpaperPalette {
                        id: previewPalette
                    }
                }

                // Search, how many, shuffle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: search

                        Layout.fillWidth: true
                        placeholderText: qsTr("Search wallpapers")
                        color: PanelBus.textColor
                        font.family: PanelBus.font.family
                        font.pixelSize: 13
                        leftPadding: 12
                        background: Rectangle {
                            radius: 8 * PanelBus.radiusScale
                            color: PanelBus.surface
                            border.width: search.activeFocus ? Math.max(1.5, PanelBus.cardBorderWidth) : Math.max(1, PanelBus.cardBorderWidth)
                            border.color: search.activeFocus ? PanelBus.accent : PanelBus.outline
                        }
                        onTextChanged: {
                            gallery.query = text
                            grid.currentIndex = gallery.shown.length > 0 ? 0 : -1
                        }
                        Keys.onDownPressed: grid.forceActiveFocus()
                        Keys.onReturnPressed: gallery.apply(gallery.preview?.path ?? "")
                    }
                    Text {
                        text: library.scanning ? qsTr("Looking…") : qsTr("%1 of %2").arg(gallery.shown.length).arg(library.images.length)
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                    Chip {
                        icon: "shuffle"
                        text: qsTr("Shuffle")
                        onClicked: library.setRandomWallpaper()
                    }
                }

                GridView {
                    id: grid

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    focus: true
                    keyNavigationEnabled: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / wallpapers.columns)
                    cellHeight: Math.round(cellWidth * 10 / 16)
                    model: gallery.shown
                    currentIndex: -1
                    ScrollBar.vertical: ScrollBar {}

                    Keys.onReturnPressed: gallery.apply(gallery.preview?.path ?? "")
                    Keys.onEnterPressed: gallery.apply(gallery.preview?.path ?? "")

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index
                        readonly property bool current: modelData.path === wallpapers.currentPath
                        readonly property bool picked: GridView.isCurrentItem

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Item {
                            id: tile

                            anchors.fill: parent
                            anchors.margins: 5
                            scale: cellArea.containsMouse ? 1.04 : 1
                            z: cellArea.containsMouse ? 1 : 0

                            Behavior on scale {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }

                            // The theme's hard shadow under the picked one
                            Rectangle {
                                visible: cell.picked && PanelBus.cardShadowOffset > 0
                                x: PanelBus.cardShadowOffset
                                y: PanelBus.cardShadowOffset
                                width: parent.width
                                height: parent.height
                                radius: thumb.radius
                                color: cell.current ? PanelBus.accent : PanelBus.outline
                            }

                            RoundedImage {
                                id: thumb

                                anchors.fill: parent
                                path: cell.modelData.path
                                radius: 8 * PanelBus.radiusScale
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: thumb.radius
                                color: "transparent"
                                border.width: cell.current || cell.picked ? Math.max(2, PanelBus.cardBorderWidth) : PanelBus.cardBorderWidth
                                border.color: cell.current ? PanelBus.accent : cell.picked ? PanelBus.textColor : PanelBus.outline
                            }

                            // The one on the desktop
                            Rectangle {
                                visible: cell.current
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: 18
                                height: 18
                                radius: Math.min(9, PanelBus.pill)
                                color: PanelBus.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2713"
                                    color: PanelBus.onAccent
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                visible: cellArea.containsMouse
                                text: cell.modelData.name
                                elide: Text.ElideRight
                                color: "#ffffff"
                                style: Text.Outline
                                styleColor: Qt.alpha("#000000", 0.5)
                                font.family: PanelBus.font.family
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: cellArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: grid.currentIndex = cell.index
                            onClicked: gallery.apply(cell.modelData.path)
                        }
                    }
                }

                // The desktop transition and the colours
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.rightMargin: 4
                        text: qsTr("Transition")
                        color: PanelBus.textDim
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: [["circle", qsTr("Circle")], ["slide_top", qsTr("Slide")], ["diamond", qsTr("Diamond")],
                                ["split", qsTr("Split")], ["", qsTr("None")]]

                        delegate: Chip {
                            required property var modelData

                            text: modelData[1]
                            on: wallpapers.animation === modelData[0]
                            onClicked: store.animation = modelData[0]
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    PanelSwitch {
                        text: qsTr("Theme takes its colours")
                        checked: PanelBus.followWallpaper
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                        onToggled: PanelBus.setFollowWallpaper(checked)
                    }
                }
            }
        }
    }

    // A picture of a wallpaper, filled to its size and cut to the corners
    component RoundedImage: Item {
        id: rounded

        property string path
        property real radius: 0

        WallpaperThumbnail {
            id: made

            readonly property real ratio: rounded.Screen.devicePixelRatio || 1

            path: rounded.path
            size: Qt.size(Math.max(1, Math.round(rounded.width * made.ratio)), Math.max(1, Math.round(rounded.height * made.ratio)))
        }

        Rectangle {
            anchors.fill: parent
            radius: rounded.radius
            color: Qt.alpha(PanelBus.textColor, 0.08)
            visible: picture.status !== Image.Ready
        }

        // Shown as it is with square corners; cut to the corners by the Shape below otherwise
        Image {
            id: picture

            anchors.fill: parent
            visible: rounded.radius <= 0 && opacity > 0
            opacity: picture.status === Image.Ready ? 1 : 0
            source: made.source
            asynchronous: true
            fillMode: Image.PreserveAspectCrop

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }
        }

        Shape {
            anchors.fill: parent
            enabled: rounded.radius > 0
            opacity: rounded.radius > 0 && picture.status === Image.Ready ? 1 : 0
            visible: opacity > 0
            preferredRendererType: Shape.CurveRenderer

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            ShapePath {
                strokeColor: "transparent"
                fillItem: picture
                // The fill takes the picture's pixels one to one; scaled to the item, the whole picture shows
                fillTransform: PlanarTransform.fromScale(rounded.width / Math.max(1, picture.implicitWidth),
                    rounded.height / Math.max(1, picture.implicitHeight))

                PathRectangle {
                    width: rounded.width
                    height: rounded.height
                    radius: rounded.radius
                }
            }
        }
    }

    // A small choice or action: an optional icon and a label, filled with the accent while on
    component Chip: Rectangle {
        id: chip

        property string text
        property string icon
        property bool on: false

        signal clicked

        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 28
        radius: Math.min(14, 6 * PanelBus.radiusScale + (PanelBus.pill > 0 ? 8 : 0))
        color: on ? PanelBus.accent : chipArea.containsMouse ? PanelBus.raised : "transparent"
        border.width: on ? PanelBus.cardBorderWidth : Math.max(1, PanelBus.cardBorderWidth)
        border.color: PanelBus.outline

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon !== ""
                name: chip.icon
                color: chip.on ? PanelBus.onAccent : PanelBus.textColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: chip.on ? PanelBus.onAccent : PanelBus.textColor
                font.family: PanelBus.font.family
                font.pixelSize: 12
                font.weight: chip.on ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
