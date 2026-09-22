pragma ComponentBehavior: Bound
import QtQuick
import IslandBackend
import "../../components"

Item {
    id: root
    required property var countdown
    required property var controller
    property bool editing: true
    property bool finished: false
    property string fontFamily: ""
    readonly property color accent: StyleTokens.timerAccent

    // Swallow background clicks so they cannot trigger configured media actions.
    MouseArea { anchors.fill: parent; onClicked: {} }

    Item {
        id: editor
        anchors.fill: parent
        visible: root.editing

        Text {
            x: 26; y: 22
            text: root.countdown.minuteMode ? "Minutes" : "Seconds"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 12
            opacity: 0.75
        }

        Item {
            id: ruler
            x: 24; y: 48
            width: parent.width - 48
            height: 68
            clip: true
            readonly property real step: root.countdown.minuteMode ? 60 : 1
            property real position: root.countdown.selectedSeconds / step
            property real spacing: root.countdown.minuteMode ? 15 : 11

            Behavior on position {
                enabled: !rulerMouse.dragging
                NumberAnimation { duration: StyleTokens.durationStandard; easing.type: Easing.OutQuint }
            }
            Behavior on spacing {
                NumberAnimation { duration: StyleTokens.durationStandard; easing.type: Easing.OutQuint }
            }

            Repeater {
                model: 45
                Item {
                    id: tick
                    required property int index
                    readonly property int value: Math.floor(ruler.position) + index - 22
                    x: ruler.width / 2 + (value - ruler.position) * ruler.spacing
                    width: 2
                    height: 55
                    visible: value >= 0 && value * ruler.step <= 86400
                    opacity: Math.max(0, 1 - Math.pow(Math.abs(x - ruler.width / 2) / (ruler.width / 2), 2))
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: tick.value
                        visible: tick.value % 5 === 0
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 12
                    }
                    Rectangle {
                        y: 23
                        width: 2
                        height: tick.value % 5 === 0 ? 30 : 24
                        radius: 1
                        color: root.accent
                        opacity: tick.value <= ruler.position ? 1 : 0.35
                    }
                }
            }

            SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 49
                iconSize: 26
                source: Qt.resolvedUrl("../../resources/icons/caret.svg")
                color: root.accent
            }

            MouseArea {
                id: rulerMouse
                anchors.fill: parent
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real pressX: 0
                property real startSeconds: 0
                property bool dragging: false
                property real wheelRemainder: 0
                onPressed: mouse => {
                    pressX = mouse.x;
                    startSeconds = root.countdown.selectedSeconds;
                    dragging = false;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    if (Math.abs(mouse.x - pressX) > 4) dragging = true;
                    if (dragging)
                        root.countdown.select(startSeconds + Math.round((pressX - mouse.x) / ruler.spacing) * ruler.step);
                }
                onClicked: {
                    if (!dragging) root.countdown.minuteMode = !root.countdown.minuteMode;
                }
                onReleased: Qt.callLater(() => { dragging = false; })
                onCanceled: dragging = false
                onWheel: wheel => {
                    const pixels = wheel.pixelDelta.y || wheel.pixelDelta.x;
                    const angle = wheel.angleDelta.y || wheel.angleDelta.x;
                    wheelRemainder += pixels !== 0 ? pixels / 12 : angle / 120;
                    const steps = Math.trunc(wheelRemainder);
                    if (steps !== 0) {
                        root.countdown.select(root.countdown.selectedSeconds + steps * ruler.step);
                        wheelRemainder -= steps;
                    }
                    wheel.accepted = true;
                }
            }
        }

        Rectangle {
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            width: 122; height: 36; radius: 18
            color: StyleTokens.timerFill
            scale: startMouse.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: StyleTokens.durationFast } }
            Text {
                anchors.centerIn: parent
                text: "Start Timer"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: startMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.controller.startCountdown()
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 26
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 17
            text: root.countdown.formatTime(root.countdown.selectedSeconds)
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 38
            font.weight: Font.Light
            font.features: { "tnum": 1 }
        }
    }

    Row {
        visible: !root.editing
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: 2
            Rectangle {
                id: control
                required property int index
                visible: !root.finished || index === 1
                width: 38; height: 38; radius: 19
                color: index === 0 ? StyleTokens.timerFill : StyleTokens.secondaryButton
                scale: controlMouse.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: StyleTokens.durationFast } }
                SvgIcon {
                    anchors.centerIn: parent
                    iconSize: 20
                    color: control.index === 0 ? root.accent : StyleTokens.textPrimary
                    source: Qt.resolvedUrl("../../resources/icons/" + (control.index === 1 ? "cancel" : root.countdown.paused ? "play" : "pause") + ".svg")
                }
                MouseArea {
                    id: controlMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (control.index === 0) root.controller.toggleCountdownPause();
                        else if (root.finished) root.controller.smartRestoreState();
                        else root.countdown.stop();
                    }
                }
            }
        }
    }
    Row {
        visible: !root.editing
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        Text {
            anchors.baseline: countdownText.baseline
            text: root.finished ? "Timer done" : root.countdown.paused ? "Paused" : "Timer"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 12
        }
        Text {
            id: countdownText
            text: root.countdown.displayTime
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: 28
            font.features: { "tnum": 1 }
        }
    }
}
