import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend
import "../../components"

Item {
    id: root

    readonly property var userConfig: UserConfig

    property var items: []
    property var cavaLevels: []
    property string currentArtUrl: ""
    property bool hasMediaPlaying: false
    property string timeText: ""
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string timeFontFamily: activeConfig.timeFontFamily
    property bool showCondition: false
    property bool showSecondaryText: true
    property bool recordingActive: false
    property real transitionProgress: 0
    property real minimumWidth: 220
    property real maximumWidth: minimumWidth
    property real horizontalPadding: 14
    property real hiddenLeftPadding: 18
    property real hiddenRightPadding: 18
    property real groupSpacing: 16
    property real iconSpacing: 8
    property int textPixelSize: userConfig.bodyFontSize
    property int iconPixelSize: userConfig.iconFontSize
    property int iconBoxSize: 18
    property int batteryIconWidth: 37
    property int batteryIconHeight: 17
    property int batteryFontSize: 13
    property int batteryFontSizeCharging: 12
    property int batteryBoltSize: 10
    property int batteryTipWidth: 2
    property int batteryTipHeight: 5
    property int batteryOuterRadius: 6
    property int batteryInnerRadius: 3
    property real iconVerticalOffset: 1
    property int recordingDotSpacing: 12
    property real batteryChargingXOffset: 0
    property real batteryChargingYOffset: 0
    readonly property string chargingIconGlyph: "\uf0e7"

    readonly property real clampedProgress: Math.max(0, Math.min(1, -transitionProgress))
    readonly property real textWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real centeredTimeX: horizontalPadding
    readonly property real centeredItemsX: (width - contentRow.implicitWidth) / 2
    readonly property real timeHiddenLeftX: -textWidth - hiddenLeftPadding
    readonly property real itemsHiddenRightX: width + hiddenRightPadding
    readonly property real timeExitDistance: Math.max(0, centeredTimeX - timeHiddenLeftX)
    readonly property real itemsEntryDistance: Math.max(0, itemsHiddenRightX - centeredItemsX)
    readonly property real dragDistance: Math.max(timeExitDistance, itemsEntryDistance)
    readonly property real itemsX: centeredItemsX + (1 - clampedProgress) * dragDistance
    readonly property real timeX: centeredTimeX - clampedProgress * dragDistance
    readonly property real visibleTimeWidth: Math.min(textWidth, Math.max(0, timeMetrics.advanceWidth))
    readonly property real timeRecordingDotX: Math.max(
        4,
        timeX + (textWidth - visibleTimeWidth) / 2 - recordingDotSpacing - timeRecordingIndicator.width
    )
    readonly property real preferredWidth: Math.max(
        minimumWidth,
        Math.min(Math.max(minimumWidth, maximumWidth), contentRow.implicitWidth + horizontalPadding * 2 + 28)
    )

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
        id: timeMetrics
        font.family: timeFontFamily
        font.pixelSize: root.textPixelSize + 1
        font.weight: Font.Bold
        text: timeText
    }

    Row {
        id: contentRow
        x: itemsX
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        opacity: clampedProgress
        spacing: groupSpacing

        Repeater {
            model: root.items

            delegate: Item {
                readonly property bool hasIcon: modelData.icon !== ""
                readonly property bool isCava: modelData.kind === "cava"
                readonly property bool isBattery: modelData.kind === "battery"
                readonly property bool hasLeadingVisual: hasIcon || isBattery
                implicitWidth: isCava
                    ? cavaBars.implicitWidth
                    : isBattery
                      ? root.batteryIconWidth
                      : leadingVisual.width + (hasLeadingVisual ? root.iconSpacing : 0) + valueText.implicitWidth
                implicitHeight: root.height
                width: implicitWidth
                height: implicitHeight

                CavaBars {
                    id: cavaBars
                    visible: parent.isCava
                    anchors.centerIn: parent
                    levels: root.cavaLevels
                }

                Item {
                    id: leadingVisual
                    visible: !parent.isCava && parent.hasLeadingVisual
                    width: parent.isBattery ? root.batteryIconWidth : (parent.hasIcon ? root.iconBoxSize : 0)
                    height: parent.isBattery ? Math.max(root.batteryIconHeight, valueText.implicitHeight) : root.iconBoxSize
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    SvgIcon {
                        anchors.centerIn: parent
                        visible: parent.parent.hasIcon && !parent.parent.isBattery && String(modelData.icon || "").indexOf(".svg") !== -1
                        source: visible ? modelData.icon : ""
                        iconSize: root.iconPixelSize
                        color: "white"
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: root.iconVerticalOffset
                        visible: parent.parent.hasIcon && !parent.parent.isBattery && String(modelData.icon || "").indexOf(".svg") === -1
                        text: modelData.icon || ""
                        color: "white"
                        font.pixelSize: root.iconPixelSize
                        font.family: root.iconFontFamily
                    }

                    BatteryIcon {
                        visible: parent.parent.isBattery
                        width: root.batteryIconWidth
                        height: root.batteryIconHeight
                        anchors.verticalCenter: parent.verticalCenter
                        level: Number(modelData.level || 0)
                        charging: modelData.isCharging || false
                        textFontFamily: root.textFontFamily
                        iconFontFamily: root.iconFontFamily
                        batteryFontSize: root.batteryFontSize
                        batteryFontSizeCharging: root.batteryFontSizeCharging
                        batteryBoltSize: root.batteryBoltSize
                        chargingGlyph: root.chargingIconGlyph
                        tipWidth: root.batteryTipWidth
                        tipHeight: root.batteryTipHeight
                        outerRadius: root.batteryOuterRadius
                    }
                }

                Text {
                    id: valueText
                    visible: !parent.isCava && !parent.isBattery
                    anchors.left: leadingVisual.right
                    anchors.leftMargin: parent.hasLeadingVisual && !parent.isBattery ? root.iconSpacing : 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text || ""
                    color: "white"
                    font.pixelSize: root.textPixelSize
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                    font.letterSpacing: -0.15
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    Item {
        id: restingTimeContainer
        x: root.timeX
        width: root.textWidth
        height: parent.height
        opacity: 1 - root.clampedProgress
        visible: opacity > 0.001 && root.showSecondaryText && root.timeText !== ""

        Rectangle {
            id: customCoverFrame
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            radius: 6
            color: "#2c2c2e"
            visible: root.hasMediaPlaying

            SvgIcon {
                anchors.centerIn: parent
                source: Qt.resolvedUrl("../../resources/icons/music-alt.svg")
                iconSize: 11
                color: "#9e9ea0"
                visible: !customCoverArt.visible
            }

            Rectangle {
                id: customCoverMask
                anchors.fill: parent
                radius: 6
                antialiasing: true
                visible: false
                layer.enabled: true
            }

            Image {
                id: customCoverArt
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: source.toString() !== ""
                sourceSize: Qt.size(40, 40)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: customCoverMask
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: root.recordingDotSpacing

            RecordingIndicator {
                id: timeRecordingIndicator
                active: root.recordingActive && root.clampedProgress < 0.001
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.timeText
                color: "white"
                font.pixelSize: root.textPixelSize + 1
                font.family: root.timeFontFamily
                font.weight: Font.Bold
                font.letterSpacing: -0.25
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.NoWrap
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        CavaBars {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            levels: root.cavaLevels
            barCount: 4
            barWidth: 3
            barSpacing: 2
            minimumBarHeight: 3
            barColor: "white"
            visible: root.hasMediaPlaying
        }
    }
}
