// SDDM login theme that reproduces the hyprlock lock screen. The design
// (positions, sizes, colours, texts) lives in modules/lockscreen.nix and
// reaches this file through the generated Style.qml.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
    id: root
    color: "#" + style.s.background.color

    Style { id: style }
    readonly property var s: style.s

    // Starts on the last user (the first one if unknown); ←/→ or a click on
    // the name switches. There is a single session (Hyprland), never shown.
    property int userIndex: Math.max(0, s.users.findIndex(u => u.name === userModel.lastUser))
    readonly property string userName: s.users[userIndex].name
    function switchUser(step) {
        userIndex = (userIndex + step + s.users.length) % s.users.length
        password.text = ""
        authState = "idle"
    }
    readonly property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    // "idle" | "checking" | "failed", like hyprlock's input states.
    property string authState: "idle"

    // hyprlock sizes are points at 96 dpi; its positions are offsets from the
    // centre with y up. hyprlock colours are rrggbbaa, Qt wants #aarrggbb.
    function px(points) { return Math.round(points * 4 / 3) }
    function argb(rgba) { return "#" + rgba.slice(6, 8) + rgba.slice(0, 6) }
    function weight(name) { return { Regular: 400, SemiBold: 600, Bold: 700 }[name] }

    // Background: wallpaper, blurred, then darkened. A black layer at
    // (1 - brightness) multiplies the colours exactly like hyprlock does.
    Image {
        id: wallpaper
        // Bigger than the screen so the blur's dark fringe at the edges stays off-screen.
        anchors.fill: parent
        anchors.margins: -96
        // The wallpaper picked with SUPER+W; Stylix's if that link is broken.
        source: s.wallpaper
        onStatusChanged: if (status === Image.Error) source = s.fallbackWallpaper
        fillMode: Image.PreserveAspectCrop
        // Decoding small and letting it upscale smoothly gives an even blur
        // instead of MultiEffect's blocky pattern at full resolution.
        sourceSize.width: 480
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: s.background.vibrancy
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 1 - s.background.brightness
    }

    // Everything fades in together, as hyprlock does.
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: s.fadeMs; easing.type: Easing.OutCubic } }

        Text {
            id: date
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -s.date.y
            color: argb(s.date.color)
            font.family: s.font
            font.pixelSize: px(s.date.size)
            font.weight: weight(s.date.weight)
            text: new Date().toLocaleDateString(Qt.locale(s.date.locale), s.date.qtFormat)
        }

        Text {
            id: clock
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -s.clock.y
            color: argb(s.clock.color)
            font.family: s.font
            font.pixelSize: px(s.clock.size)
            font.weight: weight(s.clock.weight)
            text: Qt.formatTime(new Date(), "HH:mm")
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                const now = new Date()
                clock.text = Qt.formatTime(now, "HH:mm")
                date.text = now.toLocaleDateString(Qt.locale(s.date.locale), s.date.qtFormat)
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -s.name.y
            color: argb(s.name.color)
            font.family: s.font
            font.pixelSize: px(s.name.size)
            font.weight: weight(s.name.weight)
            text: s.users[root.userIndex].realName

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.BlankCursor
                onClicked: root.switchUser(1)
            }

            // Faint arrows either side when there is someone else to switch to.
            Repeater {
                model: s.users.length > 1 ? ["‹", "›"] : []
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: index === 0 ? -width - parent.font.pixelSize : parent.width + parent.font.pixelSize
                    text: modelData
                    color: parent.color
                    opacity: 0.4
                    font: parent.font
                }
            }
        }

        // Password field: a glass pill showing dots, like hyprlock's input-field.
        Rectangle {
            id: field
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -s.input.y
            width: s.input.width
            height: s.input.height
            radius: height / 2
            color: argb(s.input.fill)
            border.width: 1
            border.color: root.authState === "checking" ? "#" + s.input.checkColor
                        : root.authState === "failed" ? "#" + s.input.failColor
                        : argb(s.input.outline)
            Behavior on border.color { ColorAnimation { duration: 200 } }

            TextInput {
                id: password
                anchors.fill: parent
                focus: true
                echoMode: TextInput.Password
                color: "transparent"
                selectionColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item {}
                onTextChanged: if (text !== "" && root.authState === "failed") root.authState = "idle"
                // The dots have no cursor to move, so ←/→ pick the user instead.
                Keys.onLeftPressed: root.switchUser(-1)
                Keys.onRightPressed: root.switchUser(1)
                onAccepted: {
                    if (text === "" || root.authState === "checking") return
                    root.authState = "checking"
                    sddm.login(root.userName, text, root.sessionIndex)
                }
            }

            Row {
                anchors.centerIn: parent
                readonly property real dot: field.height * s.input.dotsSize
                spacing: dot * s.input.dotsSpacing
                visible: password.text !== ""
                Repeater {
                    model: password.text.length
                    Rectangle {
                        width: parent.dot
                        height: parent.dot
                        radius: width / 2
                        color: "#" + s.input.textColor
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: password.text === ""
                text: root.authState === "failed" ? s.input.failText : s.input.placeholder
                color: root.authState === "failed" ? "#" + s.input.textColor : argb(s.input.placeholderColor)
                font.family: s.font
                font.pixelSize: px(11)
            }
        }
    }

    Timer {
        id: failReset
        interval: s.input.failTimeoutMs
        onTriggered: if (root.authState === "failed") root.authState = "idle"
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            root.authState = "failed"
            failReset.restart()
        }
    }

    // hyprlock hides the cursor too.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.NoButton
    }

    Component.onCompleted: password.forceActiveFocus()
}
