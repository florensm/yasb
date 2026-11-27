import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Yasb
import Yasb.Common
import "../../panel"

Item {
    id: wallpapers

    property Item bar: null
    // Folders searched for wallpapers, subfolders included; empty for your Pictures folder
    property list<string> folders: []
    // Transition before a wallpaper is set on every screen: circle, slide_top, diamond, split or "" for none
    property string animation: "circle"
    property string icon: "\ue7aa"
    property int iconSize: 14
    // Hotkey that opens the gallery, such as "alt+w", and its screen: active, cursor or primary
    property string keys: "ctrl+alt+w"
    property string hotkeyScreen: "active"

    property int thumbnailWidth: 184
    // landscape or portrait
    property string orientation: "landscape"
    readonly property int thumbnailHeight: Math.round(orientation === "portrait" ? thumbnailWidth * 16 / 9 : thumbnailWidth * 9 / 16)
    property real selectedScale: 1.3
    property int spacing: 6
    property real cornerRadius: 10 * PanelBus.radiusScale
    property color accentColor: PanelBus.accent
    property int animationDuration: 120
    // How long the thumbnails take to fan out from behind the current wallpaper when the gallery opens
    property int openDuration: 450
    property real slideSpeed: 8
    // One thumbnail: gets modelData ({path, name}) and index; PathView.itemScale is 1 at the sides, selectedScale in the centre
    property Component thumbnail: Component {
        Item {
            id: card

            required property var modelData
            required property int index
            readonly property real growth: Number.isFinite(PathView.itemScale) ? PathView.itemScale : 1
            readonly property real nearness: Math.max(0, Math.min(1, (growth - 1) / Math.max(0.01, wallpapers.selectedScale - 1)))

            width: wallpapers.thumbnailWidth
            height: wallpapers.thumbnailHeight
            scale: growth
            z: growth

            Rectangle {
                anchors.fill: parent
                radius: wallpapers.cornerRadius
                color: Qt.alpha("#808080", 0.3)
                visible: picture.status !== Image.Ready
            }

            WallpaperThumbnail {
                id: made

                readonly property real ratio: (card.Screen.devicePixelRatio || 1) * wallpapers.selectedScale

                path: card.modelData.path
                size: Qt.size(Math.round(card.width * made.ratio), Math.round(card.height * made.ratio))
            }

            Image {
                id: picture

                anchors.fill: parent
                visible: false
                source: made.source
                asynchronous: true
            }

            Shape {
                anchors.fill: parent
                opacity: picture.status === Image.Ready ? 1 : 0
                visible: opacity > 0
                preferredRendererType: Shape.CurveRenderer

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                ShapePath {
                    strokeColor: "transparent"
                    fillItem: picture
                    // The fill takes the picture's pixels one to one; scaled to the card, the whole thumbnail shows
                    fillTransform: PlanarTransform.fromScale(card.width / Math.max(1, picture.implicitWidth),
                        card.height / Math.max(1, picture.implicitHeight))

                    PathRectangle {
                        width: card.width
                        height: card.height
                        radius: wallpapers.cornerRadius
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: wallpapers.cornerRadius
                color: Qt.alpha("#000000", 0.45 * (1 - card.nearness))
            }

            Rectangle {
                anchors.fill: parent
                radius: wallpapers.cornerRadius
                color: "transparent"
                border.width: 2
                border.color: wallpapers.accentColor
                opacity: card.nearness
            }
        }
    }

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    property color textColor: bar?.theme.colors.text ?? (dark ? "#ffffff" : "#000000")
    property font iconFont
    iconFont.family: bar?.iconFont?.family ?? "Segoe Fluent Icons"
    iconFont.weight: bar?.iconFont?.weight ?? Font.Normal

    // The bar's one bottom panel, which Wallpapers shares with Search and Sound
    property QtObject panelHost: null
    readonly property bool panelOpen: panelHost?.isOpen("wallpapers") ?? false

    onBarChanged: {
        if (bar) {
            panelHost = PanelBus.hostFor(bar)
            panelHost.provide("wallpapers", panelContent, wallpapers)
        }
    }

    implicitWidth: barButton.implicitWidth
    implicitHeight: barButton.implicitHeight
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Wallpapers")
    Accessible.onPressAction: toggleGallery()

    function toggleGallery() {
        panelHost?.toggle("wallpapers", wallpapers)
    }

    Component.onDestruction: panelHost?.withdraw("wallpapers", wallpapers)

    component PanelButton: Rectangle {
        id: button

        property string text
        property bool primary: false

        signal clicked

        implicitWidth: buttonLabel.implicitWidth + 28
        implicitHeight: 32
        radius: 9 * PanelBus.radiusScale
        color: primary ? (buttonArea.containsMouse ? Qt.lighter(wallpapers.accentColor, 1.06) : wallpapers.accentColor)
            : Qt.alpha(PanelBus.textColor, buttonArea.containsMouse ? 0.1 : 0.06)

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.text
            color: button.primary ? PanelBus.onAccent : PanelBus.textColor
            font.family: PanelBus.font.family
            font.pixelSize: 13
            font.weight: button.primary ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
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

    // The bar's colours follow the wallpaper on this screen: a small copy of it is read by WallpaperPalette, and
    // WallpaperColors fades every colour to the palette it makes. However the wallpaper changes, from here or from
    // anywhere else yasb hears about.
    property string currentPath: ""
    onCurrentPathChanged: WallpaperColors.wallpaperPath = currentPath

    function updateCurrentPath() {
        const index = library.currentIndex(wallpapers.Screen.name)
        currentPath = index >= 0 ? (library.images[index]?.path ?? "") : ""
    }

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

    Connections {
        target: library

        function onCurrentChanged() {
            wallpapers.updateCurrentPath()
        }
        function onImagesChanged() {
            wallpapers.updateCurrentPath()
        }
    }

    Component.onCompleted: {
        PanelBus.register("wallpapers", wallpapers.keys)
        updateCurrentPath()
    }

    BarButton {
        id: barButton

        anchors.centerIn: parent
        glyph: wallpapers.icon
        glyphSize: wallpapers.iconSize
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

    // What Wallpapers shows in the panel: the thumbnails rolling along the top, and the selected one
    // large under them with what to do with it
    property Component panelContent: Component {
        Item {
            id: galleryView

            // 0 with every thumbnail behind the current wallpaper, 1 with them in their places
            property real spread: 0
            property bool sliding: false
            property bool moved: false
            readonly property int screens: library.screenCount()

            function apply(path: string, screen: int) {
                if (screen < 0)
                    library.setWallpaper(path)
                else
                    library.setWallpaperOn(path, screen)
                wallpapers.panelHost?.hide()
            }

            function showCurrent() {
                sliding = false
                carousel.target = Math.max(0, library.currentIndex(wallpapers.Screen.name))
                carousel.place()
                Qt.callLater(() => sliding = true)
            }

            // fresh: the panel has just slid up, rather than been switched to from another tab. Then the
            // thumbnails fan out from behind the current wallpaper.
            function panelShown(fresh) {
                library.refresh()
                moved = false
                if (fresh || spread === 0) {
                    spread = 0
                    if (library.images.length > 0)
                        showCurrent()
                    fanOut.restart()
                }
                carousel.forceActiveFocus()
            }

            function panelHidden() {
                fanOut.stop()
            }

            Connections {
                target: library

                // Again once the carousel has taken the new list, which resets its offset
                function onImagesChanged() {
                    galleryView.showCurrent()
                    Qt.callLater(galleryView.showCurrent)
                }
                function onCurrentChanged() {
                    if (!galleryView.moved)
                        galleryView.showCurrent()
                }
            }

            NumberAnimation {
                id: fanOut

                target: galleryView
                property: "spread"
                to: 1
                duration: wallpapers.openDuration
                easing.type: Easing.OutCubic
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // The folder, the carousel and its keys
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: Math.round(wallpapers.thumbnailHeight * wallpapers.selectedScale) + 90
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        spacing: 10

                        Text {
                            Layout.maximumWidth: 480
                            text: wallpapers.folders.length > 0 ? wallpapers.folders.join(", ") : qsTr("Pictures")
                            elide: Text.ElideMiddle
                            color: PanelBus.textColor
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            text: library.scanning ? qsTr("Looking for wallpapers...") : qsTr("%1 images").arg(carousel.count)
                            color: Qt.alpha(PanelBus.textColor, 0.5)
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                        }
                    }

                    // The carousel stays inside its column: with thousands of wallpapers its path runs on past the
                    // edges, and without the clip the thumbnails slide past the panel's edges
                    Item {
                        id: carouselArea

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        PathView {
                            id: carousel

                            readonly property real step: wallpapers.thumbnailWidth + wallpapers.spacing
                            readonly property real near: wallpapers.thumbnailWidth * (wallpapers.selectedScale + 1) / 2 + wallpapers.spacing
                            readonly property int fits: 2 * Math.ceil(Math.max(0, width / 2 - near) / step) + 5
                            readonly property real side: Math.max(0, 0.5 - 1 / Math.max(1, pathItemCount))
                            readonly property real reach: Math.max(0, pathItemCount / 2 - 1) * step
                            readonly property int page: Math.max(1, Math.floor((width / 2 - near) / step) + 1)
                            // Never quite 0, since a path without length gives the thumbnails no scale
                            readonly property real open: Math.max(0.001, galleryView.spread)
                            // Counted on past the last wallpaper, so the carousel slides the short way round
                            property real target: 0
                            property real position: target
                            readonly property int selected: count > 0 ? (Math.round(target) % count + count) % count : -1

                            Behavior on position {
                                enabled: galleryView.sliding

                                SmoothedAnimation {
                                    velocity: wallpapers.slideSpeed
                                }
                            }

                            function selectedPath(): string {
                                return selected >= 0 ? library.images[selected].path : ""
                            }

                            // A held key stays at most one step ahead, so the carousel slides evenly and stops on key release
                            function move(steps: int, held: bool) {
                                galleryView.moved = true
                                if (count > 0 && !(held && Math.abs(target - position) >= 1))
                                    target += steps
                            }

                            function select(index: int) {
                                galleryView.moved = true
                                if (count === 0)
                                    return
                                const ahead = ((index - selected) % count + count) % count
                                target += ahead > count / 2 ? ahead - count : ahead
                            }

                            // PathView puts wallpaper i at (i + offset) / pathItemCount along the path
                            function place() {
                                if (count > 0)
                                    offset = ((pathItemCount / 2 - position) % count + count) % count
                            }

                            onPositionChanged: place()
                            onPathItemCountChanged: place()

                            objectName: "wallpapers"
                            anchors.fill: parent
                            focus: true
                            interactive: false
                            model: library.images
                            delegate: wallpapers.thumbnail
                            pathItemCount: Math.min(count, fits)
                            highlightRangeMode: PathView.NoHighlightRange

                            path: Path {
                                startX: carousel.width / 2 - (carousel.near + carousel.reach) * carousel.open
                                startY: carousel.height / 2

                                PathAttribute { name: "itemScale"; value: 1 }
                                PathLine { x: carousel.width / 2 - carousel.near * carousel.open; y: carousel.height / 2 }
                                PathPercent { value: carousel.side }
                                PathAttribute { name: "itemScale"; value: 1 }
                                PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                                PathPercent { value: 0.5 }
                                PathAttribute { name: "itemScale"; value: wallpapers.selectedScale }
                                PathLine { x: carousel.width / 2 + carousel.near * carousel.open; y: carousel.height / 2 }
                                PathPercent { value: 1 - carousel.side }
                                PathAttribute { name: "itemScale"; value: 1 }
                                PathLine { x: carousel.width / 2 + (carousel.near + carousel.reach) * carousel.open; y: carousel.height / 2 }
                                PathAttribute { name: "itemScale"; value: 1 }
                            }

                            Keys.onReturnPressed: if (selectedPath()) galleryView.apply(selectedPath(), -1)
                            Keys.onEnterPressed: if (selectedPath()) galleryView.apply(selectedPath(), -1)
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Left)
                                    move(-1, event.isAutoRepeat)
                                else if (event.key === Qt.Key_Right)
                                    move(1, event.isAutoRepeat)
                                else if (event.key === Qt.Key_PageUp)
                                    move(-page, event.isAutoRepeat)
                                else if (event.key === Qt.Key_PageDown)
                                    move(page, event.isAutoRepeat)
                                else if (event.key === Qt.Key_Home)
                                    select(0)
                                else if (event.key === Qt.Key_End)
                                    select(count - 1)
                                else
                                    return
                                event.accepted = true
                            }
                        }

                        // A click selects, a double click applies, the right button offers more
                        MouseArea {
                            anchors.fill: carousel
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onDoubleClicked: mouse => {
                                const index = carousel.indexAt(mouse.x, mouse.y)
                                if (mouse.button === Qt.LeftButton && index >= 0)
                                    galleryView.apply(library.images[index].path, -1)
                            }
                            onClicked: mouse => {
                                const index = carousel.indexAt(mouse.x, mouse.y)
                                if (index < 0)
                                    return
                                carousel.select(index)
                                if (mouse.button !== Qt.RightButton)
                                    return
                                menu.path = library.images[index].path
                                menu.screens = galleryView.screens
                                menu.popup()
                            }
                            onWheel: wheel => {
                                const delta = wheel.angleDelta.y || wheel.angleDelta.x
                                if (delta !== 0)
                                    carousel.move(delta > 0 ? -1 : 1, true)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: carousel.count === 0
                            text: library.scanning ? qsTr("Looking for wallpapers...") : qsTr("No wallpapers found")
                            color: PanelBus.textColor
                            font.family: PanelBus.font.family
                            font.pixelSize: 13
                        }

                        // Thumbnails fade out at the column's edges instead of being cut off
                        Rectangle {
                            anchors.left: parent.left
                            width: 40
                            height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: PanelBus.color }
                                GradientStop { position: 1; color: Qt.alpha(PanelBus.color, 0) }
                            }
                        }
                        Rectangle {
                            anchors.right: parent.right
                            width: 40
                            height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.alpha(PanelBus.color, 0) }
                                GradientStop { position: 1; color: PanelBus.color }
                            }
                        }
                    }

                    Text {
                        // Cut short rather than widen the column on a narrow screen
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: qsTr("← →  browse   ·   Enter  all screens   ·   Double click  apply   ·   Right click  more")
                        color: Qt.alpha(PanelBus.textColor, 0.42)
                        font.family: PanelBus.font.family
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 6
                    Layout.bottomMargin: 18
                    color: Qt.alpha(PanelBus.textColor, 0.06)
                }

                // The selected wallpaper, large, what to do with it, and the colours it gives the bar
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    Item {
                        id: previewBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * 9 / 16)

                        WallpaperThumbnail {
                            id: large

                            readonly property real ratio: previewBox.Screen.devicePixelRatio || 1

                            path: carousel.selectedPath()
                            size: Qt.size(Math.round(previewBox.width * large.ratio), Math.round(previewBox.height * large.ratio))
                        }

                        Image {
                            id: largePicture

                            anchors.fill: parent
                            visible: false
                            source: large.source
                            asynchronous: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12 * PanelBus.radiusScale
                            color: Qt.alpha("#808080", 0.2)
                            visible: largePicture.status !== Image.Ready
                        }

                        Shape {
                            anchors.fill: parent
                            visible: largePicture.status === Image.Ready
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeColor: "transparent"
                                fillItem: largePicture
                                fillTransform: PlanarTransform.fromScale(previewBox.width / Math.max(1, largePicture.implicitWidth),
                                    previewBox.height / Math.max(1, largePicture.implicitHeight))

                                PathRectangle {
                                    width: previewBox.width
                                    height: previewBox.height
                                    radius: 12 * PanelBus.radiusScale
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: carousel.selected >= 0 ? (library.images[carousel.selected]?.name ?? "") : ""
                        elide: Text.ElideMiddle
                        color: PanelBus.textColor
                        font.family: PanelBus.font.family
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        PanelButton {
                            text: qsTr("Apply to all screens")
                            primary: true
                            onClicked: {
                                if (carousel.selectedPath())
                                    galleryView.apply(carousel.selectedPath(), -1)
                            }
                        }
                        PanelButton {
                            text: qsTr("One screen...")
                            visible: galleryView.screens > 1
                            onClicked: {
                                menu.path = carousel.selectedPath()
                                menu.screens = galleryView.screens
                                menu.popup()
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // The theme takes its accent from the wallpaper on the screen (see panel/WallpaperColors.qml and PanelBus)
                        PanelSwitch {
                            text: qsTr("Theme follows wallpaper colours")
                            checked: PanelBus.followWallpaper
                            onToggled: PanelBus.setFollowWallpaper(checked)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            // Drawn inside the panel, so opening it doesn't take the panel's focus and close it
            Menu {
                id: menu

                property string path
                property int screens: 0

                popupType: Popup.Item

                MenuItem {
                    text: qsTr("Set on all screens")
                    onTriggered: galleryView.apply(menu.path, -1)
                }

                MenuSeparator {
                    visible: menu.screens > 1
                }

                Instantiator {
                    model: menu.screens > 1 ? menu.screens : 0
                    onObjectAdded: (index, item) => menu.insertItem(index + 2, item)
                    onObjectRemoved: (index, item) => menu.removeItem(item)

                    MenuItem {
                        required property int index

                        text: qsTr("Set on screen %1").arg(index + 1)
                        onTriggered: galleryView.apply(menu.path, index)
                    }
                }
            }
        }
    }
}
