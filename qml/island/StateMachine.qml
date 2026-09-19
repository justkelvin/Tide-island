import QtQuick
import Quickshell
import IslandBackend
import "../components"
import "../hyprland"

FocusScope {
    id: root
    anchors.fill: parent
    focus: expandedPlayerKeyboardFocusRequested

    required property var windowRoot

    readonly property var userConfig: UserConfig
    readonly property alias capsule: mainCapsule
    readonly property alias mediaController: mediaController
    readonly property bool sideTransientRestoreTimerRunning: sideTransientRestoreTimer.running

    property string islandState: "normal"
    property string splitIcon: windowRoot.defaultSplitIcon
    property real osdProgress: -1.0
    property bool osdProgressAnimationEnabled: true
    property string osdCustomText: ""
    property int currentWs: windowRoot.currentMonitorWorkspaceId > 0 ? windowRoot.currentMonitorWorkspaceId : 1
    readonly property int batteryCapacity: systemState.batteryCapacity
    readonly property bool isCharging: systemState.isCharging
    readonly property real currentVolume: systemState.currentVolume
    readonly property bool isMuted: systemState.isMuted
    readonly property real currentBrightness: systemState.currentBrightness
    readonly property real currentCpuUsage: systemState.currentCpuUsage
    readonly property real currentRamUsage: systemState.currentRamUsage
    property string notificationAppName: ""
    property string notificationSummary: ""
    property string notificationBody: ""
    property bool notificationExpanded: false
    property var bluetoothExpandedDevice: null
    readonly property var cavaLevels: systemState.cavaLevels
    property real swipeTransitionProgress: 0
    property string workspaceOriginSide: "none"
    property string splitOriginSide: "none"
    property string restingState: "normal"
    property bool expandedByPlayerAutoOpen: false
    property real customCapsuleWidth: 220
    property real lyricsCapsuleWidth: 220
    property bool sideSwipeSettling: false
    property bool hoverExpandedActive: false
    property bool expandedPlayerKeyboardFocusRequested: false
    readonly property int defaultAutoHideInterval: 1250
    readonly property int notificationAutoHideInterval: 4200
    readonly property int bluetoothExpandedAutoHideInterval: 2500
    readonly property int swipeAnimationDuration: 220
    readonly property bool blocksTransientSplit: islandState === "expanded"
        || islandState === "bluetooth_expanded"
        || islandState === "notification"
    readonly property bool splitShowsProgress: islandState === "split" && osdProgress >= 0
    readonly property bool splitShowsText: islandState === "split" && osdProgress < 0 && osdCustomText !== ""
    readonly property bool splitShowsIconOnly: islandState === "split" && osdProgress < 0 && osdCustomText === ""
    readonly property bool splitUsesExtendedLayout: splitShowsProgress || splitShowsText
    readonly property real splitCapsuleWidth: splitShowsProgress ? 248 : (splitShowsText ? 220 : userConfig.islandWidth)
    readonly property bool canShowSideSwipe: islandState === "normal"
        || islandState === "custom"
        || islandState === "lyrics"
        || (islandState === "long_capsule" && workspaceOriginSide === "none")
    readonly property real rightSwipeProgress: Math.max(0, swipeTransitionProgress)
    readonly property var customLeftItems: systemState.customLeftItems
    readonly property bool hasCustomLeftItems: systemState.hasCustomLeftItems
    readonly property bool customSwipeVisible: hasCustomLeftItems
        && (
            mainCapsule.gestureArea.sideSwipeInteractive
            ? swipeTransitionProgress < 0
            : (
                islandState === "custom"
                || (islandState === "normal" && swipeTransitionProgress < 0)
                || (islandState === "split" && splitOriginSide === "left")
                || (islandState === "long_capsule"
                    && (workspaceOriginSide === "left" || swipeTransitionProgress < 0))
            )
        )
    readonly property bool lyricsSwipeVisible: (
        mainCapsule.gestureArea.sideSwipeInteractive
        ? swipeTransitionProgress >= 0
        : (
            islandState === "lyrics"
            || (islandState === "normal" && swipeTransitionProgress >= 0)
            || (islandState === "split" && splitOriginSide === "right")
            || (islandState === "long_capsule"
                && (workspaceOriginSide === "right" || swipeTransitionProgress > 0))
        )
    )
    readonly property bool expandedLayerVisible: islandState === "expanded"
    readonly property bool bluetoothExpandedLayerVisible: islandState === "bluetooth_expanded"
    readonly property bool notificationLayerVisible: islandState === "notification"
    readonly property var activePlayer: mediaController.activePlayer
    readonly property string lyricsDisplayText: mediaController.displayText
    readonly property string currentTrack: mediaController.currentTrack
    readonly property string currentArtist: mediaController.currentArtist
    readonly property string currentArtUrl: mediaController.currentArtUrl
    readonly property real trackProgress: mediaController.trackProgress
    readonly property string timePlayed: mediaController.timePlayed
    readonly property string timeTotal: mediaController.timeTotal
    readonly property bool screenRecordingActive: windowRoot.screenRecordingActive
    readonly property var bluetoothDevices: bluetoothConnectionTracker.devices

    onExpandedLayerVisibleChanged: {
        if (!expandedLayerVisible)
            expandedPlayerKeyboardFocusRequested = false;
    }

    onCustomLeftItemsChanged: {
        if (restingState === "custom" && !hasCustomLeftItems) {
            restingState = "normal";

            if (islandState === "custom"
                    || (islandState === "split" && splitOriginSide === "left")
                    || (islandState === "long_capsule" && workspaceOriginSide === "left")) {
                restoreRestingCapsule(true);
            } else {
                applyRestingVisuals();
            }
        } else if (restingState === "custom") {
            syncCustomCapsuleWidth();
        }
    }

    Clock {
        id: timeObj
        clockFormat: userConfig.clockFormat
    }

    MprisController {
        id: mediaController

        expanded: root.islandState === "expanded"
        clientId: "island-mpris-" + windowRoot.screenOutputName
    }

    BluetoothConnectionTracker {
        id: bluetoothConnectionTracker

        onAdapterChanged: root.bluetoothExpandedDevice = null

        onNewConnection: function(device) {
            root.showBluetoothExpanded(device);
        }
    }

    SystemState {
        id: systemState

        configuredLeftSwipeItems: userConfig.dynamicIslandLeftSwipeItems
        timeText: timeObj.currentTime
        dateText: timeObj.currentDateLabel
        currentWorkspace: root.currentWs
        customSwipeActive: mainCapsule.customSwipeActive
        lyricsCavaActive: root.lyricsSwipeVisible
            && root.rightSwipeProgress > 0.001

        onTransientRequested: function(icon, progress, text) {
            root.showTransientCapsule(icon, progress, text);
        }
    }

    HyprlandWorkspaceTracker {
        id: workspaceTracker

        hyprMonitor: windowRoot.hyprMonitor
        monitorName: windowRoot.hyprMonitorName
        monitorFocused: windowRoot.monitorFocused

        onWorkspaceSynced: function(workspaceId) {
            root.currentWs = workspaceId;
        }

        onWorkspaceActivated: function(workspaceId) {
            if (userConfig.islandShowWorkspaceOnAutoHide) {
                windowRoot.showAutoHiddenIsland();
            }

            root.showWorkspaceCapsule(workspaceId);
        }
    }

    Behavior on osdProgress {
        enabled: root.osdProgressAnimationEnabled

        SmoothedAnimation { velocity: 1.2; duration: 180; easing.type: Easing.InOutQuad }
    }
    Behavior on swipeTransitionProgress {
        NumberAnimation {
            duration: mainCapsule.gestureArea.sideSwipeInteractive ? 0 : root.swipeAnimationDuration
            easing.type: Easing.OutCubic
        }
    }

    function handleConfiguredClickAction(actionName) {
        switch (actionName) {
        case "":
        case "none":
            return;
        case "toggleExpandedPlayer":
            if (islandState === "expanded") {
                autoHideTimer.stop();
                smartRestoreState();
            } else {
                showExpandedPlayer(false);
            }
            return;
        case "openExpandedPlayer":
            showExpandedPlayer(false);
            return;
        case "closeExpandedPlayer":
            if (islandState === "expanded")
                smartRestoreState();
            return;
        case "toggleLyrics":
            if (restingState === "lyrics")
                showTimeCapsule();
            else
                showLyricsCapsule();
            return;
        case "showLyrics":
            showLyricsCapsule();
            return;
        case "showTime":
            showTimeCapsule();
            return;
        case "restoreRestingCapsule":
            smartRestoreState();
            return;
        default:
        }
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function normalizeRestingState(nextState) {
        if (nextState === "lyrics") return "lyrics";
        if (nextState === "custom" && hasCustomLeftItems) return "custom";
        return "normal";
    }

    function restingStateProgress(nextState) {
        switch (normalizeRestingState(nextState)) {
        case "custom":
            return -1;
        case "lyrics":
            return 1;
        default:
            return 0;
        }
    }

    function restingStateSide(nextState) {
        switch (normalizeRestingState(nextState)) {
        case "custom":
            return "left";
        case "lyrics":
            return "right";
        default:
            return "none";
        }
    }

    function swipeRestProgressForState() {
        switch (islandState) {
        case "custom":
            return -1;
        case "lyrics":
            return 1;
        default:
            return 0;
        }
    }

    function currentTransientOriginSide() {
        switch (islandState) {
        case "custom":
            return "left";
        case "lyrics":
            return "right";
        case "long_capsule":
            return workspaceOriginSide;
        case "split":
            return splitOriginSide;
        default:
            return "none";
        }
    }

    function setOsdProgress(nextProgress, animate) {
        osdProgressAnimationReset.stop();
        osdProgressAnimationEnabled = animate;
        osdProgress = nextProgress;
        if (!animate) osdProgressAnimationReset.restart();
    }

    function abortSideTransientMode() {
        sideTransientRestoreTimer.stop();
        workspaceOriginSide = "none";
        splitOriginSide = "none";
    }

    function clearTransientCapsule() {
        setOsdProgress(-1.0, false);
        osdCustomText = "";
        notificationAppName = "";
        notificationSummary = "";
        notificationBody = "";
        notificationExpanded = false;
        bluetoothExpandedDevice = null;
    }

    function cleanNotificationText(text) {
        return String(text === undefined || text === null ? "" : text)
            .replace(/<[^>]*>/g, " ")
            .replace(/&nbsp;/g, " ")
            .replace(/&amp;/g, "&")
            .replace(/&quot;/g, "\"")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/\s+/g, " ")
            .trim();
    }

    function prepareRestingCapsuleGeometry() {
        if (restingState === "custom")
            syncCustomCapsuleWidth();
        if (restingState === "lyrics")
            syncLyricsCapsuleWidth();
    }

    function applyRestingVisuals() {
        prepareRestingCapsuleGeometry();
        swipeTransitionProgress = restingStateProgress(restingState);
    }

    function sideSwipeRestProgressForProgress(progressValue) {
        if (progressValue <= -0.5) return -1;
        if (progressValue >= 0.5) return 1;
        return 0;
    }

    function sideSwipeRestWidthForProgress(progressValue) {
        if (progressValue <= -0.5) return customCapsuleWidth;
        if (progressValue >= 0.5) return lyricsCapsuleWidth;
        return userConfig.islandWidth;
    }

    function customSideSwipeDragDistance() {
        const view = mainCapsule.customSwipeItem;
        if (view && view.dragDistance > 0) return view.dragDistance;
        return Math.max(userConfig.islandWidth, customCapsuleWidth + 4);
    }

    function lyricsSideSwipeDragDistance() {
        const view = mainCapsule.lyricsSwipeItem;
        if (view && view.dragDistance > 0) return view.dragDistance;
        return Math.max(userConfig.islandWidth, lyricsCapsuleWidth + 2);
    }

    function sideSwipeDragDistanceForDirection(direction) {
        if (direction === "left") return customSideSwipeDragDistance();
        if (direction === "right") return lyricsSideSwipeDragDistance();
        return userConfig.islandWidth;
    }

    function advanceSideSwipeProgress(currentProgress, deltaX) {
        const minProgress = hasCustomLeftItems ? -1 : 0;
        let nextProgress = Math.max(minProgress, Math.min(1, currentProgress));
        let remainingDelta = deltaX;

        if (remainingDelta > 0) {
            if (nextProgress < 0) {
                const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                const progressToCenter = Math.min(-nextProgress, remainingDelta / leftDistance);
                nextProgress += progressToCenter;
                remainingDelta -= progressToCenter * leftDistance;
            }

            if (remainingDelta > 0 && nextProgress < 1) {
                const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                nextProgress = Math.min(1, nextProgress + remainingDelta / rightDistance);
            }
        } else if (remainingDelta < 0) {
            if (nextProgress > 0) {
                const rightDistance = Math.max(1, sideSwipeDragDistanceForDirection("right"));
                const progressToCenter = Math.min(nextProgress, -remainingDelta / rightDistance);
                nextProgress -= progressToCenter;
                remainingDelta += progressToCenter * rightDistance;
            }

            if (remainingDelta < 0 && nextProgress > minProgress) {
                const leftDistance = Math.max(1, sideSwipeDragDistanceForDirection("left"));
                nextProgress = Math.max(minProgress, nextProgress + remainingDelta / leftDistance);
            }
        }

        return Math.max(minProgress, Math.min(1, nextProgress));
    }

    function resolveSideSwipeSettle(startProgress, finalProgress) {
        let settleAction = "";
        let settleProgress = sideSwipeRestProgressForProgress(startProgress);
        let settleWidth = sideSwipeRestWidthForProgress(startProgress);

        if (finalProgress >= 0.56) {
            settleAction = "lyrics";
            settleProgress = 1;
            settleWidth = lyricsCapsuleWidth;
        } else if (hasCustomLeftItems && finalProgress <= -0.56) {
            settleAction = "custom";
            settleProgress = -1;
            settleWidth = customCapsuleWidth;
        } else if (startProgress <= -0.5) {
            if (finalProgress >= -0.44) {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = userConfig.islandWidth;
            }
        } else if (startProgress >= 0.5) {
            if (finalProgress <= 0.44) {
                settleAction = "time";
                settleProgress = 0;
                settleWidth = userConfig.islandWidth;
            }
        } else {
            settleAction = "time";
            settleProgress = 0;
            settleWidth = userConfig.islandWidth;
        }

        return {
            action: settleAction,
            progress: settleProgress,
            width: settleWidth
        };
    }

    function beginSideSwipeSettle(targetWidth) {
        sideSwipeSettling = true;
        mainCapsule.displayedWidth = targetWidth;
        sideSwipeSettleReset.restart();
    }

    function cancelSideSwipeSettle() {
        sideSwipeSettleReset.stop();
        sideSwipeSettling = false;
    }

    function finishSideSwipeSettle() {
        sideSwipeSettling = false;
        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
    }

    function restartAutoHideTimer(duration) {
        autoHideTimer.interval = duration === undefined ? defaultAutoHideInterval : duration;
        autoHideTimer.restart();
    }

    function stopAutoHideTimer() {
        autoHideTimer.stop();
        autoHideTimer.interval = defaultAutoHideInterval;
    }

    function requestExpandedPlayerKeyboardFocus() {
        const shouldGrabFocus = !expandedPlayerKeyboardFocusRequested;
        expandedPlayerKeyboardFocusRequested = true;
        if (shouldGrabFocus)
            expandedPlayerFocusTimer.restart();
    }

    function releaseExpandedPlayerKeyboardFocus() {
        expandedPlayerKeyboardFocusRequested = false;
    }

    function showTransientCapsule(icon, progress, customText) {
        if (progress === undefined)    progress = -1.0;
        if (customText === undefined)  customText = "";

        if (windowRoot.autoHideSuppressesTransientReveal) return;
        if (blocksTransientSplit) return;

        const nextProgress = progress >= 0 ? progress : -1.0;
        const animateProgress = islandState === "split" && osdProgress >= 0 && nextProgress >= 0;
        const animateFromSide = currentTransientOriginSide();

        abortSideTransientMode();
        splitIcon = icon;
        osdCustomText = customText;
        setOsdProgress(nextProgress, animateProgress);
        splitOriginSide = animateFromSide;
        islandState = "split";
        swipeTransitionProgress = 0;
        restartAutoHideTimer();
    }

    function showNotificationCapsule(appName, summary, body) {
        if (islandState === "expanded") return;

        const cleanedAppName = cleanNotificationText(appName);
        const cleanedSummary = cleanNotificationText(summary);
        const cleanedBody = cleanNotificationText(body);
        const resolvedSummary = cleanedSummary !== ""
            ? cleanedSummary
            : (cleanedBody !== "" ? cleanedBody : "New notification");

        abortSideTransientMode();
        clearTransientCapsule();
        notificationAppName = cleanedAppName !== "" ? cleanedAppName : "Notification";
        notificationSummary = resolvedSummary;
        notificationBody = cleanedSummary !== "" ? cleanedBody : "";
        notificationExpanded = false;
        islandState = "notification";
        restartAutoHideTimer(notificationAutoHideInterval);
    }

    function toggleNotificationExpansionIfNeeded() {
        if (islandState !== "notification" || !mainCapsule.notificationItem || !mainCapsule.notificationItem.hasOverflowContent)
            return false;

        if (notificationExpanded) {
            smartRestoreState();
            return true;
        }

        notificationExpanded = true;
        stopAutoHideTimer();
        return true;
    }

    function suppressCapsuleClick(suppress) {
        mainCapsule.gestureArea.suppressClick(suppress);
    }

    function restoreRestingCapsule(forceImmediate) {
        if (forceImmediate === undefined) forceImmediate = false;
        const normalizedRestingState = normalizeRestingState(restingState);
        const targetSide = restingStateSide(normalizedRestingState);
        const shouldAnimateToSide = targetSide !== "none"
            && ((islandState === "long_capsule" && workspaceOriginSide === targetSide)
                || (islandState === "split" && splitOriginSide === targetSide));

        if (!forceImmediate && shouldAnimateToSide) {
            expandedByPlayerAutoOpen = false;
            prepareRestingCapsuleGeometry();
            swipeTransitionProgress = restingStateProgress(normalizedRestingState);
            stopAutoHideTimer();
            sideTransientRestoreTimer.restart();
            return;
        }

        abortSideTransientMode();
        prepareRestingCapsuleGeometry();
        islandState = normalizedRestingState;
        clearTransientCapsule();
        applyRestingVisuals();
        expandedByPlayerAutoOpen = false;
        stopAutoHideTimer();
    }

    function setRestingState(nextState) {
        restingState = normalizeRestingState(nextState);
    }

    function smartRestoreState() {
        restoreRestingCapsule();
    }

    function showRestingCapsule(nextState) {
        setRestingState(nextState);
        restoreRestingCapsule();
        stopAutoHideTimer();
    }

    function showExpandedPlayer(autoOpened) {
        cancelSideSwipeSettle();
        abortSideTransientMode();
        clearTransientCapsule();
        islandState = "expanded";
        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        expandedByPlayerAutoOpen = autoOpened;
        if (autoOpened) restartAutoHideTimer();
        else stopAutoHideTimer();
    }

    function showBluetoothExpanded(device) {
        if (!device || islandState === "notification")
            return;

        cancelSideSwipeSettle();
        abortSideTransientMode();
        clearTransientCapsule();
        bluetoothExpandedDevice = device;
        islandState = "bluetooth_expanded";
        mainCapsule.displayedWidth = mainCapsule.baseTargetWidth;
        expandedByPlayerAutoOpen = false;
        restartAutoHideTimer(bluetoothExpandedAutoHideInterval);
    }

    function showCustomCapsule() {
        if (!hasCustomLeftItems) {
            showTimeCapsule();
            return;
        }

        systemState.refreshMissingValues();
        showRestingCapsule("custom");
    }

    function showLyricsCapsule() {
        showRestingCapsule("lyrics");
    }

    function showTimeCapsule() {
        showRestingCapsule("normal");
    }

    function showWorkspaceCapsule(wsId) {
        currentWs = wsId;
        if (windowRoot.autoHideSuppressesTransientReveal) return;
        if (islandState === "notification") return;
        const animateFromSide = currentTransientOriginSide();
        clearTransientCapsule();
        sideTransientRestoreTimer.stop();
        workspaceOriginSide = animateFromSide;
        splitOriginSide = "none";
        islandState = "long_capsule";
        swipeTransitionProgress = 0;
        restartAutoHideTimer();
    }

    function swipeRightWindow() {
        if (restingState === "lyrics")
            showTimeCapsule();
        else if (restingState === "normal") {
            if (hasCustomLeftItems)
                showCustomCapsule();
            else
                showLyricsCapsule();
        }
        else
            showLyricsCapsule();

        windowRoot.showAutoHiddenIsland("manual");
        windowRoot.scheduleAutoHide();
    }

    function swipeLeftWindow() {
        if (restingState === "custom")
            showTimeCapsule();
        else if (restingState === "normal")
            showLyricsCapsule();
        else if (hasCustomLeftItems)
            showCustomCapsule();
        else
            showTimeCapsule();

        windowRoot.showAutoHiddenIsland("manual");
        windowRoot.scheduleAutoHide();
    }

    function togglePlayerWindow() {
        if (islandState === "expanded")
            smartRestoreState();
        else
            showExpandedPlayer(false);
    }

    Timer { id: autoHideTimer; interval: root.defaultAutoHideInterval; onTriggered: root.smartRestoreState() }
    Timer {
        id: osdProgressAnimationReset
        interval: 0
        onTriggered: root.osdProgressAnimationEnabled = true
    }
    Timer {
        id: sideTransientRestoreTimer
        interval: root.swipeAnimationDuration
        onTriggered: {
            root.workspaceOriginSide = "none";
            root.splitOriginSide = "none";
            root.prepareRestingCapsuleGeometry();
            root.islandState = root.normalizeRestingState(root.restingState);
            root.clearTransientCapsule();
            root.applyRestingVisuals();
            root.expandedByPlayerAutoOpen = false;
        }
    }
    Timer {
        id: sideSwipeSettleReset
        interval: mainCapsule.morphDuration
        onTriggered: root.finishSideSwipeSettle()
    }
    Timer {
        id: hoverExpandDelayTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!mainCapsule.gestureArea.containsMouse) return;
            if (!windowRoot.hoverExpandEnabled) return;

            const current = root.islandState;
            const target = "expanded";
            if (current === target) return;
            if (current !== "normal" && current !== "custom" && current !== "lyrics")
                return;

            root.hoverExpandedActive = true;
            root.showExpandedPlayer(false);
        }
    }
    Timer {
        id: hoverCollapseDelayTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (mainCapsule.gestureArea.containsMouse) return;
            if (!root.hoverExpandedActive) return;
            root.hoverExpandedActive = false;
            root.smartRestoreState();
        }
    }
    Timer {
        id: expandedPlayerFocusTimer
        interval: 0
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    function syncCustomCapsuleWidth() {
        const view = mainCapsule.customSwipeItem;
        if (!view) return;
        customCapsuleWidth = Math.max(220, Math.min(windowRoot.width - 48, view.preferredWidth));
    }

    function syncLyricsCapsuleWidth() {
        const view = mainCapsule.lyricsSwipeItem;
        if (!view) return;
        lyricsCapsuleWidth = Math.max(220, Math.min(windowRoot.width - 48, view.preferredWidth));
    }

    onCurrentTrackChanged: {
        if (userConfig.disableAutoExpandOnTrackChange) return;
        if (currentTrack !== ""
                && islandState !== "notification"
                && islandState !== "bluetooth_expanded") {
            if (windowRoot.autoHideSuppressesTransientReveal) return;
            if (islandState === "expanded" && !expandedByPlayerAutoOpen) return;
            showExpandedPlayer(true);
        }
    }

    Capsule {
        id: mainCapsule
        windowRoot: root.windowRoot
        islandController: root
        timeObj: timeObj
        hoverExpandTimer: hoverExpandDelayTimer
        hoverCollapseTimer: hoverCollapseDelayTimer
    }
}
