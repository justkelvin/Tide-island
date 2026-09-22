import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import IslandBackend
import "layers"
import "../components"

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
    readonly property int secondaryHistoryCount: NotificationServer.history.length

    function secondaryPanelGeometry() {
        const count = secondaryHistoryCount;
        let panelHeight = 360;
        if (count <= 0)
            panelHeight = 130;
        else if (count === 1)
            panelHeight = 155;
        else if (count === 2)
            panelHeight = 220;
        else if (count === 3)
            panelHeight = 285;
        return { width: 430, height: panelHeight + 48, radius: 40 };
    }

    function capsuleTargetGeometry(state, expandedContent, historyCount) {
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
            if (expandedContent === "timerEditor")
                return { width: 410, height: 180, radius: 40 };
            if (expandedContent === "timerControls" || expandedContent === "timerFinished")
                return { width: 300, height: 62, radius: 31 };
            if (expandedContent === "secondary")
                return secondaryPanelGeometry();
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
            return { width: islandController.normalRestingWidth, height: userConfig.islandHeight, radius: userConfig.islandHeight / 2 };
        }
    }

    readonly property var targetGeometry: capsuleTargetGeometry(
        islandController.islandState,
        islandController.expandedContent,
        secondaryHistoryCount
    )
    readonly property real baseTargetWidth: targetGeometry.width
    readonly property real targetHeight: targetGeometry.height
    readonly property real targetRadius: targetGeometry.radius

    function sideSwipeWidthForProgress(progressValue) {
        const baseWidth = islandController.normalRestingWidth;
        if (progressValue < 0)
            return baseWidth + (islandController.customCapsuleWidth - baseWidth)
                * islandController.clamp01(-progressValue);
        if (progressValue > 0)
            return baseWidth + (islandController.lyricsCapsuleWidth - baseWidth)
                * islandController.clamp01(progressValue);
        return baseWidth;
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
    scale: (0.96 + windowRoot.autoHideProgress * 0.04) * (capsuleGestureArea.timerHoldPressed ? 0.98 : 1)
    Behavior on scale { NumberAnimation { duration: StyleTokens.durationFast; easing.type: Easing.OutCubic } }
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
            CustomInfoLayer {
                items: islandController.customLeftItems
                cavaLevels: islandController.cavaLevels
                currentArtUrl: islandController.currentArtUrl
                hasMediaPlaying: islandController.hasMediaPlaying
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
            && !(islandController.timerActive && islandController.islandState === "normal")
        asynchronous: false
        visible: active

        onLoaded: islandController.syncLyricsCapsuleWidth()

        sourceComponent: Component {
            LyricsLayer {
                lyricText: islandController.lyricsDisplayText
                currentArtUrl: islandController.currentArtUrl
                cavaLevels: islandController.cavaLevels
                hasMediaPlaying: islandController.hasMediaPlaying
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
                batteryLevel: islandController.osdBatteryLevel
                batteryCharging: islandController.osdBatteryCharging
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
        anchors.fill: parent
        active: islandController.timerActive && islandController.islandState === "normal"
        sourceComponent: TimerIdleLayer {
            countdown: islandController.countdown
            timeText: timeObj.currentTime
            fontFamily: windowRoot.timeFontFamily
            recordingActive: islandController.screenRecordingActive
        }
    }

    Loader {
        anchors.fill: parent
        active: islandController.timerLayerVisible
        sourceComponent: TimerLayer {
            countdown: islandController.countdown
            controller: islandController
            editing: islandController.expandedContent === "timerEditor"
            finished: islandController.expandedContent === "timerFinished"
            fontFamily: windowRoot.textFontFamily
        }
    }

    Loader {
        id: expandedPlayerLoader
        anchors.fill: parent
        active: islandController.expandedLayerVisible && islandController.expandedContent === "player"
        asynchronous: false
        visible: active

        sourceComponent: Component {
            PlayerLayer {
                currentArtUrl: islandController.currentArtUrl
                currentTrack: islandController.currentTrack
                currentArtist: islandController.currentArtist
                timePlayed: islandController.timePlayed
                timeTotal: islandController.timeTotal
                trackProgress: islandController.trackProgress
                cavaLevels: islandController.cavaLevels
                activePlayer: islandController.activePlayer
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                showCondition: islandController.playerLayerVisible
                onControlPressed: islandController.suppressCapsuleClick()
                onBackgroundClicked: islandController.smartRestoreState()
                onKeyboardFocusRequested: islandController.requestExpandedPlayerKeyboardFocus()
                onKeyboardFocusReleased: islandController.releaseExpandedPlayerKeyboardFocus()
                onPreviousRequested: islandController.mediaController.previous()
            }
        }
    }

    Loader {
        id: secondaryPanelLoader
        anchors.fill: parent
        active: islandController.secondaryPanelVisible
        asynchronous: false
        visible: active

        sourceComponent: Component {
            SecondaryPanelLayer {
                history: NotificationServer.history
                timerActive: islandController.timerActive
                onTimerRequested: islandController.openTimer()
                textFontFamily: windowRoot.textFontFamily
                showCondition: islandController.secondaryPanelVisible
                onControlPressed: islandController.suppressCapsuleClick()
                onBackgroundClicked: islandController.smartRestoreState()
                onCloseRequested: islandController.smartRestoreState()
                onClearAllRequested: {
                    islandController.suppressCapsuleClick();
                    NotificationServer.clearHistory();
                    NotificationServer.clearAllNotifications();
                }
                onRemoveHistoryItemRequested: (notificationId) => {
                    islandController.suppressCapsuleClick();
                    NotificationServer.removeHistoryItem(notificationId);
                }
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
                iconSource: islandController.notificationIconSource
                iconImage: islandController.notificationIconImage
                iconText: windowRoot.notificationStatusIcon
                notificationId: islandController.notificationId
                actions: islandController.notificationActions
                urgency: islandController.notificationUrgency
                progress: islandController.notificationProgress
                imageDataUrl: islandController.notificationImageDataUrl
                createdMs: islandController.notificationCreatedMs
                replyPlaceholder: islandController.notificationReplyPlaceholder
                iconFontFamily: windowRoot.iconFontFamily
                textFontFamily: windowRoot.textFontFamily
                heroFontFamily: windowRoot.heroFontFamily
                showCondition: true
                onControlPressed: {
                    islandController.suppressCapsuleClick(true);
                    islandController.noteNotificationActivity();
                }
                onBackgroundClicked: {
                    islandController.suppressCapsuleClick(true);
                    islandController.activateNotificationBackground();
                }
                onCloseRequested: {
                    islandController.suppressCapsuleClick(true);
                    islandController.dismissNotificationCapsule();
                }
                onActionClicked: (actionKey) => {
                    islandController.suppressCapsuleClick(true);
                    islandController.invokeNotificationAction(actionKey);
                }
                onReplySubmitted: (text) => {
                    islandController.suppressCapsuleClick(true);
                    islandController.submitNotificationReply(text);
                }
                onReplyCancelled: islandController.cancelNotificationReply()
                onKeyboardFocusRequested: islandController.requestNotificationReplyKeyboardFocus()
                onKeyboardFocusReleased: islandController.releaseNotificationReplyKeyboardFocus()
                onUserActivity: islandController.noteNotificationActivity()
                onExpansionToggleRequested: {
                    islandController.suppressCapsuleClick(true);
                    islandController.toggleNotificationExpansionIfNeeded();
                }
            }
        }
    }
}
