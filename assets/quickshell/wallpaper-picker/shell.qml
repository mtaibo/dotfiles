// The wallpaper picker (`wallpaper pick`, SUPER+Shift+W): a full-screen
// carousel of tall previews that grow towards the middle, adapted from
// hyprquickpaper. The script passes the collection, the thumbnails and the
// current wallpaper's file name through the environment; choosing one runs
// `wallpaper set`, so swww, matugen and the current link work as with SUPER+W.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel

PanelWindow {
    id: main
    readonly property real ui: Screen.height / 1080
    readonly property real refWidth: 1920
    readonly property real refHeight: 500
    readonly property int numberOfPictures: 10
    property int speed: 5000
    property int animDuration: 1000
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real edgeSpacing: 80
    property real shadowOpacity: 0.4
    property real shadowBlur: 0.45
    property real shadowX: 6
    property real shadowY: 6
    readonly property string wallpaperDir: Quickshell.env("WALLPAPER_DIR")
    readonly property string thumbsDir: Quickshell.env("WALLPAPER_THUMBS")
    readonly property string currentName: Quickshell.env("WALLPAPER_CURRENT") ?? ""

    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    FolderListModel {
        id: folderModel
        folder: "file://" + main.wallpaperDir
        showDirs: false
        sortField: FolderListModel.Name
    }

    // A click anywhere outside the previews closes it; the wheel and dragging
    // with the left button work anywhere.
    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) { list.dragStart(mouse.x) }
        onPositionChanged: function(mouse) { list.dragMove(mouse.x, mouse.y) }
        onReleased: list.dragEnd()
        onClicked: if (!list.dragged) Qt.quit()
        onWheel: function(wheel) { list.scroll(wheel) }
    }

    ListView {
        id: list
        width: parent.width
        height: tileHeight
        anchors.centerIn: parent
        focus: true
        model: folderModel
        orientation: ListView.Horizontal
        clip: true
        cacheBuffer: 400 * main.ui
        boundsBehavior: Flickable.StopAtBounds
        interactive: false

        property int selectedIndex: 0

        readonly property real tileHeight: main.refHeight * main.ui
        readonly property real tileWidth: (main.refWidth / main.numberOfPictures - 10) * main.ui
        readonly property real viewportCenterX: width / 2
        readonly property real falloffRadius: (main.refWidth / 2) * main.ui
        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        property bool ready: false
        property bool userMoved: false
        property real lastMouseX: -1
        property real lastMouseY: -1
        property real wheelDelta: 0
        property real dragX: NaN
        property bool dragged: false

        leftMargin: sideMargin
        rightMargin: sideMargin

        function clampIndex(i) { return Math.max(0, Math.min(i, count - 1)) }
        // contentX that puts tile i exactly in the middle of the viewport.
        function centerX(i) {
            const it = itemAtIndex(i)
            if (it) return it.x + tileWidth / 2 - width / 2
            return i * tileWidth - sideMargin
        }

        // Opens on the wallpaper in use.
        function centerOnStart() {
            if (userMoved || count <= 0) return
            selectedIndex = Math.max(0, folderModel.indexOf("file://" + main.wallpaperDir + "/" + main.currentName))
            contentX = centerX(selectedIndex)
            ready = true
        }

        function activateCurrent() {
            Quickshell.execDetached(["wallpaper", "set", folderModel.get(selectedIndex, "filePath")])
            Qt.quit()
        }

        function moveSelection(delta, speedMultiplier) {
            userMoved = true
            anim.velocity = main.speed * speedMultiplier
            selectedIndex = clampIndex(selectedIndex + delta)
            contentX = centerX(selectedIndex)
        }

        // Each notch of the wheel (120 units; a touchpad sends many small ones)
        // moves one wallpaper, like the arrows. Either scroll axis works.
        function scroll(wheel) {
            wheelDelta += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : -wheel.angleDelta.x
            const steps = Math.trunc(wheelDelta / 120)
            if (steps === 0) return
            wheelDelta -= steps * 120
            moveSelection(-steps, 1)
        }

        // Dragging with the left button pulls the carousel along with the
        // pointer, one wallpaper for every tile it travels; a short wobble
        // still counts as a click.
        function dragStart(x) {
            dragX = x
            dragged = false
        }

        function dragMove(x, y) {
            lastMouseX = x
            lastMouseY = y
            if (isNaN(dragX)) return
            const delta = dragX - x
            if (!dragged && Math.abs(delta) < 10 * main.ui) return
            dragged = true
            const step = tileWidth * main.zoomScale
            const steps = Math.trunc(delta / step)
            if (steps === 0) return
            dragX -= steps * step
            moveSelection(steps, 1)
        }

        function dragEnd() { dragX = NaN }

        onCountChanged: centerOnStart()
        onWidthChanged: centerOnStart()

        Behavior on contentX {
            enabled: list.ready
            SmoothedAnimation { id: anim; velocity: main.speed; duration: main.animDuration }
        }

        delegate: Item {
            id: delegateItem
            width: list.tileWidth
            height: list.tileHeight

            readonly property real baseCenterX: x - list.contentX + width / 2
            readonly property real fraction: Math.min(1, Math.abs(baseCenterX - list.viewportCenterX) / list.falloffRadius)
            // Tiles near the edges bunch up towards the middle...
            readonly property real edgeOffset: {
                const amount = main.edgeSpacing * main.ui * Math.pow(fraction, 4)
                return baseCenterX < list.viewportCenterX ? amount : -amount
            }
            // ...and shrink smoothly the further they are from it.
            readonly property real scaleFactor: {
                const t = 1 - fraction * fraction * (3 - 2 * fraction)
                return main.edgeScale + (main.zoomScale - main.edgeScale) * t
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: delegateItem.width * delegateItem.scaleFactor
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
                x: (delegateItem.width - width) / 2 + delegateItem.edgeOffset

                Image {
                    x: main.shadowX * main.ui
                    y: main.shadowY * main.ui
                    width: parent.width
                    height: parent.height
                    source: img.source
                    sourceSize: img.sourceSize
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    opacity: main.shadowOpacity
                    layer.enabled: true
                    layer.effect: MultiEffect { brightness: -1; blurEnabled: true; blur: main.shadowBlur }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: 0.95
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    source: "file://" + main.thumbsDir + "/" + fileBaseName + ".jpg"
                    sourceSize.width: delegateItem.width * main.zoomScale
                    sourceSize.height: delegateItem.height
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: list.ready
                onPressed: function(mouse) { list.dragStart(mapToItem(null, mouse.x, mouse.y).x) }
                onReleased: list.dragEnd()
                onPositionChanged: function(mouse) {
                    const p = mapToItem(null, mouse.x, mouse.y)
                    if (pressed) {
                        list.dragMove(p.x, p.y)
                        return
                    }
                    if (p.x === list.lastMouseX && p.y === list.lastMouseY) return
                    list.lastMouseX = p.x
                    list.lastMouseY = p.y
                    list.userMoved = true
                    list.selectedIndex = index
                }
                onClicked: if (!list.dragged) list.activateCurrent()
                onWheel: function(wheel) { list.scroll(wheel); wheel.accepted = true }
            }
        }

        Keys.onPressed: function(event) {
            const fast = event.isAutoRepeat ? 2 : 1
            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_A:
                moveSelection(-1, fast)
                break
            case Qt.Key_Right:
            case Qt.Key_D:
                moveSelection(1, fast)
                break
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (count > 0) activateCurrent()
                break
            case Qt.Key_W:
            case Qt.Key_Escape:
                Qt.quit()
                break
            default:
                return
            }
            event.accepted = true
        }
    }
}
