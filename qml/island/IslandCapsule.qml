import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import IslandBackend
import "../common"

Rectangle {
    id: root
    z: 5

    required property var windowRoot
    required property var islandController
    required property var timeObj
    required property var hoverExpandTimer
    required property var hoverCollapseTimer

    readonly property var userConfig: UserConfig
    property int morphDuration: 400
    property real outlineWidth: 0
    property color outlineColor: StyleTokens.clearBlack
    property real displayedWidth: baseTargetWidth

    readonly property alias gestureArea: capsuleGestureArea
    readonly property alias customSwipeItem: customSwipeLoader.item
    readonly property alias lyricsSwipeItem: lyricsSwipeLoader.item
    readonly property alias notificationItem: notificationLoader.item
    readonly property alias customSwipeActive: customSwipeLoader.active

    function capsuleTargetGeometry(state) {
        if (islandController.sideTransientRestoreTimerRunning) {
            if (islandController.restingState === "lyrics"
                    && ((state === "split" && islandController.splitOriginSide === "right")
                        || (state === "long_capsule" && islandController.workspaceOriginSide === "right"))) {
                return { width: islandController.lyricsCapsuleWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
            }

            if (islandController.restingState === "custom"
                    && ((state === "split" && islandController.splitOriginSide === "left")
                        || (state === "long_capsule" && islandController.workspaceOriginSide === "left"))) {
                return { width: islandController.customCapsuleWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
            }
        }

        switch (state) {
        case "expanded":
        case "bluetooth_expanded":
            return { width: 410, height: 165, radius: 40 };
        case "notification":
            const notifWidth = notificationLoader.item
                ? Math.max(notificationLoader.item.minimumWidth,
                           Math.min(windowRoot.width - 48, notificationLoader.item.maximumWidth, notificationLoader.item.preferredWidth))
                : 272;
            const notifHeight = notificationLoader.item
                ? Math.max(56, notificationLoader.item.preferredHeight)
                : 56;
            const notifRadius = islandController.notificationExpanded ? 28 : notifHeight / 2;
            return { width: notifWidth, height: notifHeight, radius: notifRadius };
        case "split":
            return { width: islandController.splitCapsuleWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        case "long_capsule":
            return { width: 220, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        case "custom":
            return { width: islandController.customCapsuleWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        case "lyrics":
            return { width: islandController.lyricsCapsuleWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        default:
            return { width: userConfig.islandWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        }
    }

    readonly property var targetGeometry: capsuleTargetGeometry(islandController.islandState)
    readonly property real baseTargetWidth: targetGeometry.width
    readonly property real targetHeight: targetGeometry.height
    readonly property real targetRadius: targetGeometry.radius

    function sideSwipeWidthForProgress(progressValue) {
        if (progressValue < 0)
            return userConfig.islandWidth + (islandController.customCapsuleWidth - userConfig.islandWidth)
                * islandController.clamp01(-progressValue);
        if (progressValue > 0)
            return userConfig.islandWidth + (islandController.lyricsCapsuleWidth - userConfig.islandWidth)
                * islandController.clamp01(progressValue);
        return userConfig.islandWidth;
    }

    readonly property real sideSwipePreviewWidth: root.sideSwipeWidthForProgress(
        islandController.swipeTransitionProgress
    )

    color: Qt.rgba(
        windowRoot.waybarMainBackground.r,
        windowRoot.waybarMainBackground.g,
        windowRoot.waybarMainBackground.b,
        userConfig.islandBackgroundOpacity / 100.0
    )
    y: userConfig.islandTopMargin
        - (1 - windowRoot.autoHideProgress) * (targetHeight + userConfig.islandTopMargin + 8)
    x: parent ? parent.width * userConfig.islandPositionX / 100 - width / 2 : 0
    clip: true
    width: displayedWidth
    height: targetHeight
    radius: targetRadius
    opacity: windowRoot.autoHideProgress
    scale: 0.96 + windowRoot.autoHideProgress * 0.04
    transformOrigin: Item.Top

    onBaseTargetWidthChanged: {
        if (!capsuleGestureArea.sideSwipeInteractive && !islandController.sideSwipeSettling)
            displayedWidth = baseTargetWidth;
    }

    Behavior on displayedWidth  {
        NumberAnimation {
            duration: capsuleGestureArea.sideSwipeInteractive ? 0 : root.morphDuration
            easing.type: Easing.OutQuint
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: root.morphDuration
            easing.type: Easing.OutQuint
        }
    }
    Behavior on radius { NumberAnimation { duration: root.morphDuration; easing.type: Easing.OutQuint } }
    Behavior on color { ColorAnimation { duration: 280; easing.type: Easing.InOutQuad } }
    Behavior on outlineWidth { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
    Behavior on outlineColor { ColorAnimation { duration: 260; easing.type: Easing.InOutQuad } }
    border.width: outlineWidth
    border.color: outlineColor

    CapsuleGestureArea {
        id: capsuleGestureArea
        windowRoot: root.windowRoot
        islandController: root.islandController
        capsule: root
        hoverExpandTimer: root.hoverExpandTimer
        hoverCollapseTimer: root.hoverCollapseTimer
    }

    Loader {
        id: customSwipeLoader
        anchors.fill: parent
        active: islandController.customSwipeVisible
        asynchronous: false
        visible: active

        onLoaded: islandController.syncCustomCapsuleWidth()

        sourceComponent: Component {
            SwipeCustomInfoLayer {
                items: islandController.customLeftItems
                cavaLevels: islandController.cavaLevels
                timeText: timeObj.currentTime
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.heroFontFamily
                timeFontFamily: windowRoot.heroFontFamily
                textPixelSize: windowRoot.bodyFontSize
                iconPixelSize: windowRoot.iconFontSize
                minimumWidth: 220
                maximumWidth: Math.max(220, windowRoot.width - 48)
                transitionProgress: islandController.swipeTransitionProgress
                recordingActive: islandController.screenRecordingActive
                showSecondaryText: islandController.workspaceOriginSide !== "left"
                    && islandController.splitOriginSide !== "left"
                showCondition: true
                onPreferredWidthChanged: islandController.syncCustomCapsuleWidth()
            }
        }
    }

    Loader {
        id: lyricsSwipeLoader
        anchors.fill: parent
        active: islandController.lyricsSwipeVisible
        asynchronous: false
        visible: active

        onLoaded: islandController.syncLyricsCapsuleWidth()

        sourceComponent: Component {
            SwipeLyricsLayer {
                lyricText: islandController.lyricsDisplayText
                currentArtUrl: islandController.currentArtUrl
                cavaLevels: islandController.cavaLevels
                timeText: timeObj.currentTime
                textFontFamily: windowRoot.textFontFamily
                timeFontFamily: windowRoot.timeFontFamily
                textPixelSize: windowRoot.bodyFontSize
                minimumWidth: 220
                maximumWidth: Math.max(220, windowRoot.width - 48)
                transitionProgress: islandController.rightSwipeProgress
                recordingActive: islandController.screenRecordingActive
                showSecondaryText: islandController.workspaceOriginSide !== "right"
                    && islandController.splitOriginSide !== "right"
                showCondition: true
                onPreferredWidthChanged: islandController.syncLyricsCapsuleWidth()
            }
        }
    }

    Loader {
        id: splitIconLoader
        anchors.fill: parent
        active: islandController.splitShowsIconOnly
        asynchronous: false
        visible: active

        sourceComponent: Component {
            SplitIconLayer {
                iconText: islandController.splitIcon
                iconFontFamily: windowRoot.iconFontFamily
                transitionProgress: islandController.swipeTransitionProgress
                slideDirection: islandController.splitOriginSide
                showCondition: true
            }
        }
    }

    Loader {
        id: osdLayerLoader
        anchors.fill: parent
        active: islandController.splitUsesExtendedLayout
        asynchronous: false
        visible: active

        sourceComponent: Component {
            OsdLayer {
                iconText: islandController.splitIcon
                progress: islandController.osdProgress
                customText: islandController.osdCustomText
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                heroFontFamily: windowRoot.heroFontFamily
                transitionProgress: islandController.swipeTransitionProgress
                slideDirection: islandController.splitOriginSide
                showCondition: true
            }
        }
    }

    Loader {
        id: workspaceLayerLoader
        anchors.fill: parent
        active: islandController.islandState === "long_capsule"
            && (islandController.workspaceOriginSide !== "none"
                || Math.abs(islandController.swipeTransitionProgress) < 0.001)
        asynchronous: false
        visible: active

        sourceComponent: Component {
            WorkspaceLayer {
                workspaceId: islandController.currentWs
                displayText: "Workspace " + islandController.currentWs
                textFontFamily: windowRoot.textFontFamily
                textPixelSize: windowRoot.bodyFontSize
                animateVisibility: islandController.restingState === "normal"
                transitionProgress: islandController.swipeTransitionProgress
                showCondition: true
                slideDirection: islandController.workspaceOriginSide
            }
        }
    }

    Loader {
        id: expandedPlayerLoader
        anchors.fill: parent
        active: islandController.expandedLayerVisible
        asynchronous: false
        visible: active

        sourceComponent: Component {
            ExpandedPlayerLayer {
                currentArtUrl: islandController.currentArtUrl
                currentTrack: islandController.currentTrack
                currentArtist: islandController.currentArtist
                timePlayed: islandController.timePlayed
                timeTotal: islandController.timeTotal
                trackProgress: islandController.trackProgress
                activePlayer: islandController.activePlayer
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                showCondition: islandController.expandedLayerVisible
                onControlPressed: islandController.suppressCapsuleClick()
                onBackgroundClicked: islandController.smartRestoreState()
                onKeyboardFocusRequested: islandController.requestExpandedPlayerKeyboardFocus()
                onKeyboardFocusReleased: islandController.releaseExpandedPlayerKeyboardFocus()
                onPreviousRequested: islandController.mediaController.previous()
            }
        }
    }

    Loader {
        id: bluetoothExpandedLoader
        anchors.fill: parent
        active: islandController.bluetoothExpandedLayerVisible
        asynchronous: false
        visible: active

        sourceComponent: Component {
            BluetoothExpandedLayer {
                device: islandController.bluetoothExpandedDevice
                volumeLevel: islandController.currentVolume
                iconText: ""
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                showCondition: islandController.bluetoothExpandedLayerVisible
            }
        }
    }

    Loader {
        id: notificationLoader
        anchors.fill: parent
        active: islandController.notificationLayerVisible
        asynchronous: false
        visible: active

        sourceComponent: Component {
            NotificationLayer {
                appName: islandController.notificationAppName
                summary: islandController.notificationSummary
                body: islandController.notificationBody
                expanded: islandController.notificationExpanded
                toggleButton: userConfig.mouseButton(userConfig.dynamicIslandPrimaryButton)
                iconText: windowRoot.notificationStatusIcon
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                heroFontFamily: windowRoot.heroFontFamily
                showCondition: true
                onExpansionToggleRequested: {
                    islandController.suppressCapsuleClick(true);
                    islandController.toggleNotificationExpansionIfNeeded();
                }
            }
        }
    }
}
