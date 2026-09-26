import QtQuick
import IslandBackend
import "../../components"

Item {
    id: root

    readonly property var userConfig: UserConfig

    property int workspaceId: 1
    property string displayText: "Workspace " + workspaceId
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string textFontFamily: activeConfig.textFontFamily
    property bool showCondition: false
    property int textPixelSize: userConfig.bodyFontSize
    property string slideDirection: "none"
    property bool animateVisibility: true
    property real transitionProgress: 0
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 16
    property real hiddenRightPadding: 16

    readonly property real clampedProgress: slideDirection === "right"
        ? Math.max(0, Math.min(1, transitionProgress))
        : (slideDirection === "left"
            ? Math.max(0, Math.min(1, -transitionProgress))
            : 0)
    readonly property real revealProgress: slideDirection === "none" ? 1 : (1 - clampedProgress)
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredX: horizontalPadding
    readonly property real hiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real hiddenRightX: width + hiddenRightPadding
    readonly property real labelX: slideDirection === "right"
        ? centeredX + (hiddenRightX - centeredX) * clampedProgress
        : (slideDirection === "left"
            ? centeredX + (hiddenLeftX - centeredX) * clampedProgress
            : centeredX)

    anchors.fill: parent
    clip: true
    opacity: showCondition ? (animateVisibility ? revealProgress : 1) : 0

    Behavior on opacity {
        enabled: animateVisibility

        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        x: labelX
        width: textWidth
        height: parent.height
        opacity: revealProgress

        Row {
            anchors.centerIn: parent
            spacing: 8

            SvgIcon {
                source: Qt.resolvedUrl("../../resources/icons/workspace-change.svg")
                iconSize: textPixelSize + 2
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: displayText
                color: "white"
                font.pixelSize: textPixelSize
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }
}
