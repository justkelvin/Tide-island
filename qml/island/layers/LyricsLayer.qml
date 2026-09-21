import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend
import "../../components"

Item {
    id: root

    readonly property var userConfig: UserConfig

    property string lyricText: ""
    property string currentArtUrl: ""
    property var cavaLevels: []
    property bool hasMediaPlaying: false
    property string timeText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string textFontFamily: activeConfig.textFontFamily
    property string timeFontFamily: activeConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property bool recordingActive: false
    property real transitionProgress: 0
    property int textPixelSize: userConfig.bodyFontSize
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 12
    property real coverSize: 20
    property real coverRadius: 6
    property real visualSpacing: 10
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 16
    property string activeLyricText: lyricText
    property string previousLyricText: ""
    property real lyricChangeProgress: 1
    property int recordingDotSpacing: 12

    readonly property real clampedProgress: Math.max(0, Math.min(1, transitionProgress))
    readonly property bool lyricMostlyVisible: clampedProgress > 0.92
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real lyricTextWidth: Math.max(
        0,
        textWidth - coverSize - cavaBars.implicitWidth - visualSpacing * 2
    )
    readonly property real centeredX: horizontalPadding
    readonly property real lyricHiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real timeHiddenRightX: width + hiddenRightPadding
    readonly property real lyricEntryDistance: Math.max(0, centeredX - lyricHiddenLeftX)
    readonly property real timeExitDistance: Math.max(0, timeHiddenRightX - centeredX)
    readonly property real dragDistance: Math.max(lyricEntryDistance, timeExitDistance)
    readonly property real lyricX: centeredX - (1 - clampedProgress) * dragDistance
    readonly property real timeX: centeredX + clampedProgress * dragDistance
    readonly property real lyricBaselineY: lyricBaselineGuide.y + lyricBaselineGuide.baselineOffset
    readonly property real timeBaselineY: timeBaselineGuide.y + timeBaselineGuide.baselineOffset
    readonly property real visibleLyricWidth: Math.min(lyricTextWidth, Math.max(0, lyricMetrics.advanceWidth))
    readonly property real visibleTimeWidth: Math.min(textWidth, Math.max(0, timeMetrics.advanceWidth))
    readonly property real timeRecordingDotX: Math.max(
        4,
        timeX + (textWidth - visibleTimeWidth) / 2 - recordingDotSpacing - timeRecordingIndicator.width
    )
    readonly property real preferredWidth: Math.max(
        minimumWidth,
        Math.min(
            Math.max(minimumWidth, maximumWidth),
            lyricMetrics.advanceWidth
                + horizontalPadding * 2
                + coverSize
                + cavaBars.implicitWidth
                + visualSpacing * 2
        )
    )

    onLyricTextChanged: {
        if (lyricText === activeLyricText) return;

        if (activeLyricText === "" || !lyricMostlyVisible) {
            lyricChangeAnimation.stop();
            previousLyricText = "";
            activeLyricText = lyricText;
            lyricChangeProgress = 1;
            return;
        }

        previousLyricText = activeLyricText;
        activeLyricText = lyricText;
        lyricChangeProgress = 0;
        lyricChangeAnimation.restart();
    }

    onShowConditionChanged: {
        if (showCondition) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    onTransitionProgressChanged: {
        if (lyricMostlyVisible) return;
        lyricChangeAnimation.stop();
        previousLyricText = "";
        activeLyricText = lyricText;
        lyricChangeProgress = 1;
    }

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 220 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: lyricMetrics
        font.family: textFontFamily
        font.pixelSize: textPixelSize
        font.weight: Font.DemiBold
        text: activeLyricText !== "" ? activeLyricText : lyricText
    }

    TextMetrics {
        id: timeMetrics
        font.family: timeFontFamily
        font.pixelSize: textPixelSize + 1
        font.weight: Font.Bold
        text: timeText
    }

    Text {
        id: lyricBaselineGuide
        anchors.verticalCenter: parent.verticalCenter
        text: "Ag国"
        opacity: 0
        font.pixelSize: textPixelSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        wrapMode: Text.NoWrap
    }

    Text {
        id: timeBaselineGuide
        anchors.verticalCenter: parent.verticalCenter
        text: "00:00"
        opacity: 0
        font.pixelSize: textPixelSize + 1
        font.family: timeFontFamily
        font.weight: Font.Bold
        font.letterSpacing: -0.25
        wrapMode: Text.NoWrap
    }

    SequentialAnimation {
        id: lyricChangeAnimation

        NumberAnimation {
            target: root
            property: "lyricChangeProgress"
            from: 0
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.previousLyricText = ""
        }
    }

    // Left: Album Art / Cover Image Squircle (visible when media is playing or lyrics swiped)
    Rectangle {
        id: coverFrame
        anchors.left: parent.left
        anchors.leftMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.coverSize
        height: root.coverSize
        radius: root.coverRadius
        color: "#2c2c2e"
        antialiasing: true
        clip: true

        visible: opacity > 0.001
        opacity: (root.hasMediaPlaying || root.clampedProgress > 0.001) ? 1.0 : 0.0
        scale: (root.hasMediaPlaying || root.clampedProgress > 0.001) ? 1.0 : 0.6

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack }
        }

        SvgIcon {
            anchors.centerIn: parent
            source: Qt.resolvedUrl("../../resources/icons/music-alt.svg")
            iconSize: 11
            color: "#9e9ea0"
            visible: !coverArtImage.visible
        }

        Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: root.coverRadius
            antialiasing: true
            visible: false
            layer.enabled: true
        }

        Image {
            id: coverArtImage
            anchors.fill: parent
            source: root.currentArtUrl
            fillMode: Image.PreserveAspectCrop
            visible: source.toString() !== ""
            sourceSize: Qt.size(root.coverSize * 2, root.coverSize * 2)
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: coverMask
            }
        }
    }

    // Right: Cava Audio Visualizer (visible when media is playing or lyrics swiped)
    CavaBars {
        id: cavaBars
        anchors.right: parent.right
        anchors.rightMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        levels: root.cavaLevels
        barCount: 4
        barWidth: 3
        barSpacing: 2
        minimumBarHeight: 3
        barColor: "white"

        visible: opacity > 0.001
        opacity: (root.hasMediaPlaying || root.clampedProgress > 0.001) ? 1.0 : 0.0
        scale: (root.hasMediaPlaying || root.clampedProgress > 0.001) ? 1.0 : 0.6

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack }
        }
    }

    // Center: Clock in Idle / Resting state (fades out as lyrics swipe in)
    Row {
        id: timeCenterContainer
        anchors.centerIn: parent
        spacing: root.recordingDotSpacing
        opacity: 1 - root.clampedProgress
        visible: opacity > 0.001 && root.showSecondaryText && root.timeText !== ""

        RecordingIndicator {
            id: timeRecordingIndicator
            active: root.recordingActive && root.clampedProgress < 0.001
            contentOpacity: 1 - root.clampedProgress
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: timeDisplay
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            color: "white"
            font.pixelSize: root.textPixelSize + 1
            font.family: root.timeFontFamily
            font.weight: Font.Bold
            font.letterSpacing: -0.25
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
        }
    }

    // Center: Lyric Viewport (fades in as lyrics swipe in, anchored between art and visualizer)
    Item {
        id: lyricViewport
        anchors.left: coverFrame.right
        anchors.leftMargin: root.visualSpacing
        anchors.right: cavaBars.left
        anchors.rightMargin: root.visualSpacing
        height: parent.height
        clip: true
        opacity: root.clampedProgress
        visible: opacity > 0.001

        Text {
            visible: root.previousLyricText !== ""
            y: root.lyricBaselineY - baselineOffset - 14 * root.lyricChangeProgress
            width: parent.width
            text: root.previousLyricText
            color: "white"
            opacity: 1 - root.lyricChangeProgress
            font.pixelSize: root.textPixelSize
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: -0.15
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        Text {
            visible: root.activeLyricText !== ""
            y: root.lyricBaselineY - baselineOffset
                + (root.previousLyricText !== "" ? 12 * (1 - root.lyricChangeProgress) : 0)
            width: parent.width
            text: root.activeLyricText
            color: "white"
            opacity: root.previousLyricText !== "" ? root.lyricChangeProgress : 1
            font.pixelSize: root.textPixelSize
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
            font.letterSpacing: -0.15
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }
}
