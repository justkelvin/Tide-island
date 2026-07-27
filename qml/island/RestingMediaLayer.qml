import QtQuick

Item {
    id: root

    property string artworkSource: ""
    property string timeText: ""
    property var cavaLevels: []
    property string timeFontFamily: ""
    property string iconFontFamily: ""
    property int timePixelSize: 15
    property bool mediaPlaying: false
    property bool showCondition: false
    readonly property var pausedCavaLevels: [0.12, 0.28, 0.48, 0.34, 0.2, 0.1]

    anchors.fill: parent
    clip: true
    visible: opacity > 0.001
    opacity: showCondition ? 1 : 0
    scale: showCondition ? 1 : 0.92

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? 220 : 150
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.showCondition ? 240 : 160
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors.centerIn: parent
        height: parent.height
        spacing: 9

        RoundedArtwork {
            width: 24
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            source: root.artworkSource
            cornerRadius: 12
            active: root.mediaPlaying
            fallbackColor: Qt.rgba(1, 1, 1, 0.12)
            fallbackFontFamily: root.iconFontFamily
            fallbackPixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: "white"
            font.family: root.timeFontFamily
            font.pixelSize: root.timePixelSize
            font.weight: Font.Bold
            font.letterSpacing: -0.25
            wrapMode: Text.NoWrap
        }

        SwipeCavaBars {
            anchors.verticalCenter: parent.verticalCenter
            levels: root.mediaPlaying ? root.cavaLevels : root.pausedCavaLevels
            barCount: 6
            barWidth: 3
            barSpacing: 2
            minimumBarHeight: 3
            width: implicitWidth
            height: 16
            opacity: root.mediaPlaying ? 1 : 0.38

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
