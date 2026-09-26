import QtQuick
import IslandBackend
import "../../components"

Item {
    id: root
    required property var countdown
    property string timeText: ""
    property string fontFamily: ""
    property bool recordingActive: false
    property real countdownWidth: 0

    Row {
        anchors.centerIn: parent
        spacing: 14

        Canvas {
            id: progressClock
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.countdown.paused ? 0.55 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.durationStandard
                }
            }
            Connections {
                target: root.countdown
                function onRemainingMsChanged() {
                    progressClock.requestPaint();
                }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 2.6;
                ctx.lineCap = "round";
                ctx.strokeStyle = StyleTokens.timerFill;
                ctx.beginPath();
                ctx.arc(11, 11, 9, 0, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = StyleTokens.timerAccent;
                const handAngle = -Math.PI / 2 + Math.PI * 2 * root.countdown.progress;
                ctx.beginPath();
                ctx.arc(11, 11, 9, -Math.PI / 2, handAngle);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(11, 11);
                ctx.lineTo(11 + Math.cos(handAngle) * 6, 11 + Math.sin(handAngle) * 6);
                ctx.stroke();
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            RecordingIndicator {
                active: root.recordingActive
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.timeText
                color: StyleTokens.textPrimary
                font.family: root.fontFamily
                font.pixelSize: UserConfig.bodyFontSize + 1
                font.weight: Font.Bold
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, root.countdownWidth)
            horizontalAlignment: Text.AlignRight
            text: root.countdown.displayTime
            color: StyleTokens.timerAccent
            opacity: root.countdown.paused ? 0.55 : 1
            font.family: root.fontFamily
            font.pixelSize: UserConfig.bodyFontSize + 1
            font.weight: Font.DemiBold
            font.features: {
                "tnum": 1
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: StyleTokens.durationStandard
                }
            }
        }
    }
}
