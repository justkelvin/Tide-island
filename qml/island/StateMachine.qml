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
    property string notificationAppIcon: ""
    property string notificationIconSource: Qt.resolvedUrl("../resources/icons/notification.svg")
    property bool notificationExpanded: false
    property int notificationId: 0
    property var notificationActions: []
    property int notificationUrgency: 1
    property int notificationProgress: -1
    property string notificationImageDataUrl: ""
    property string notificationResolvedIcon: ""
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
    readonly property int swipeAnimationDuration: 220
    readonly property bool blocksTransientSplit: islandState === "expanded"
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
        notificationAppIcon = "";
        notificationIconSource = Qt.resolvedUrl("../resources/icons/notification.svg");
        notificationExpanded = false;
        notificationId = 0;
        notificationActions = [];
        notificationUrgency = 1;
        notificationProgress = -1;
        notificationImageDataUrl = "";
        notificationResolvedIcon = "";
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

    function resolveNotificationIcon(appName, summary, body, appIcon) {
        const app = String(appName || "").toLowerCase();
        const sum = String(summary || "").toLowerCase();
        const bdy = String(body || "").toLowerCase();
        const ico = String(appIcon || "").toLowerCase();
        const combined = (app + " " + sum + " " + bdy + " " + ico).trim();

        // 1. Microphone
        const isMic = ico.indexOf("microphone") !== -1 || ico.indexOf("audio-input-microphone") !== -1
            || ico.indexOf("mic") !== -1 || app.indexOf("microphone") !== -1 || app.indexOf("mic") !== -1
            || combined.indexOf("microphone") !== -1 || /\bmic\b/.test(combined);
        if (isMic) {
            const isExplicitlyUnmuted = ico.indexOf("unmuted") !== -1 || combined.indexOf("unmuted") !== -1 || combined.indexOf("unmute") !== -1;
            const isMuted = !isExplicitlyUnmuted && (ico.indexOf("muted") !== -1 || ico.indexOf("slash") !== -1 || ico.indexOf("disabled") !== -1 || ico.indexOf("off") !== -1
                || combined.indexOf("muted") !== -1 || /\bmute\b/.test(combined) || combined.indexOf("disabled") !== -1 || /\boff\b/.test(combined));
            return isMuted ? Qt.resolvedUrl("../resources/icons/microphone-slash.svg")
                           : Qt.resolvedUrl("../resources/icons/microphone.svg");
        }

        // 2. Wi-Fi / Wireless Network
        const isWifi = ico.indexOf("wireless") !== -1 || ico.indexOf("wifi") !== -1 || ico.indexOf("network-wireless") !== -1
            || app.indexOf("networkmanager") !== -1 || app.indexOf("nm-applet") !== -1 || app.indexOf("iwd") !== -1
            || combined.indexOf("wi-fi") !== -1 || combined.indexOf("wifi") !== -1 || combined.indexOf("wireless") !== -1;
        if (isWifi) {
            const isOff = ico.indexOf("disconnected") !== -1 || ico.indexOf("offline") !== -1 || ico.indexOf("disabled") !== -1 || ico.indexOf("none") !== -1 || ico.indexOf("no-route") !== -1
                || combined.indexOf("disconnected") !== -1 || combined.indexOf("disabled") !== -1 || combined.indexOf("offline") !== -1 || combined.indexOf("turned off") !== -1 || combined.indexOf("lost") !== -1;
            return isOff ? Qt.resolvedUrl("../resources/icons/wifi-slash.svg")
                         : Qt.resolvedUrl("../resources/icons/wifi.svg");
        }

        // 3. Bluetooth
        const isBt = ico.indexOf("bluetooth") !== -1 || app.indexOf("bluetooth") !== -1 || app.indexOf("blueman") !== -1 || combined.indexOf("bluetooth") !== -1;
        if (isBt) {
            const isOff = ico.indexOf("disabled") !== -1 || ico.indexOf("off") !== -1 || ico.indexOf("disconnected") !== -1
                || combined.indexOf("disconnected") !== -1 || combined.indexOf("disabled") !== -1 || combined.indexOf("turned off") !== -1 || combined.indexOf("off") !== -1;
            return isOff ? Qt.resolvedUrl("../resources/icons/bluetooth-off.svg")
                         : Qt.resolvedUrl("../resources/icons/bluetooth-connected.svg");
        }

        // 4. Battery / Power
        const isBat = ico.indexOf("battery") !== -1 || app.indexOf("power") !== -1 || app.indexOf("upower") !== -1 || app.indexOf("battery") !== -1 || combined.indexOf("battery") !== -1;
        if (isBat) {
            const isDischarging = ico.indexOf("discharging") !== -1 || combined.indexOf("discharging") !== -1 || combined.indexOf("unplugged") !== -1 || combined.indexOf("on battery") !== -1;
            const isCharging = !isDischarging && (ico.indexOf("charging") !== -1 || ico.indexOf("ac-adapter") !== -1 || ico.indexOf("bolt") !== -1
                || combined.indexOf("charging") !== -1 || combined.indexOf("plugged in") !== -1 || combined.indexOf("connected to power") !== -1);
            if (isCharging) return Qt.resolvedUrl("../resources/icons/battery-bolt.svg");
            if (isDischarging) return Qt.resolvedUrl("../resources/icons/battery-discharging.svg");

            const isFull = ico.indexOf("full") !== -1 || ico.indexOf("charged") !== -1
                || combined.indexOf("battery full") !== -1 || combined.indexOf("fully charged") !== -1 || combined.indexOf("charged") !== -1;
            if (isFull) return Qt.resolvedUrl("../resources/icons/battery-full.svg");

            return Qt.resolvedUrl("../resources/icons/battery-discharging.svg");
        }

        // 5. Brightness
        const isBrightness = ico.indexOf("brightness") !== -1 || ico.indexOf("backlight") !== -1
            || app.indexOf("brightness") !== -1 || combined.indexOf("brightness") !== -1 || combined.indexOf("backlight") !== -1
            || /_bl\b|_bl\d+/.test(combined)
            || (ico.indexOf("knob") !== -1 && !/audio|stereo|sink|speaker|sound|headphone/i.test(combined));
        if (isBrightness) {
            const match = combined.match(/(\d+)/);
            const percent = match ? parseInt(match[1], 10) : -1;
            const isLow = (percent >= 0 && percent <= 35) || combined.indexOf("low") !== -1;
            return isLow ? Qt.resolvedUrl("../resources/icons/brightness-low.svg")
                         : Qt.resolvedUrl("../resources/icons/brightness.svg");
        }

        // 6. Workspace
        const isWs = ico.indexOf("workspace") !== -1 || app.indexOf("workspace") !== -1 || combined.indexOf("workspace") !== -1;
        if (isWs) {
            return Qt.resolvedUrl("../resources/icons/workspace-change.svg");
        }

        // 7. Volume / Audio Output
        const isVol = ico.indexOf("volume") !== -1 || ico.indexOf("audio-volume") !== -1
            || app.indexOf("volume") !== -1 || app.indexOf("wireplumber") !== -1 || app.indexOf("pipewire") !== -1
            || combined.indexOf("volume") !== -1 || combined.indexOf("sound") !== -1 || combined.indexOf("audio") !== -1;
        if (isVol) {
            const isExplicitlyUnmuted = ico.indexOf("unmuted") !== -1 || combined.indexOf("unmuted") !== -1 || combined.indexOf("unmute") !== -1;
            const isMuted = !isExplicitlyUnmuted && (ico.indexOf("muted") !== -1 || /\bmute\b/.test(combined) || combined.indexOf("silent") !== -1);
            if (isMuted) return Qt.resolvedUrl("../resources/icons/volume-mute.svg");

            const match = combined.match(/(\d+)/);
            const percent = match ? parseInt(match[1], 10) : -1;
            const isLow = (percent >= 0 && percent <= 40) || combined.indexOf("low") !== -1 || ico.indexOf("low") !== -1;
            return isLow ? Qt.resolvedUrl("../resources/icons/volume-down.svg")
                         : Qt.resolvedUrl("../resources/icons/volume-up.svg");
        }

        // 8. Do Not Disturb / Notification Silenced
        const isDnd = ico.indexOf("bell-slash") !== -1 || ico.indexOf("dnd") !== -1
            || combined.indexOf("do not disturb") !== -1 || combined.indexOf("dnd") !== -1 || combined.indexOf("notifications paused") !== -1;
        if (isDnd) {
            return Qt.resolvedUrl("../resources/icons/bell-slash.svg");
        }

        // 9. Airplane Mode / Flight Mode
        const isAirplane = ico.indexOf("airplane") !== -1 || ico.indexOf("flight") !== -1
            || combined.indexOf("airplane") !== -1 || combined.indexOf("flight mode") !== -1;
        if (isAirplane) {
            return Qt.resolvedUrl("../resources/icons/plane-alt.svg");
        }

        // 10. Caps Lock / Keyboard
        const isCaps = ico.indexOf("caps-lock") !== -1 || ico.indexOf("letter-case") !== -1
            || combined.indexOf("caps lock") !== -1 || combined.indexOf("capslock") !== -1;
        if (isCaps) {
            return Qt.resolvedUrl("../resources/icons/letter-case.svg");
        }

        // 11. Music / Media Player
        const isMusic = ico.indexOf("music") !== -1 || ico.indexOf("spotify") !== -1
            || app.indexOf("spotify") !== -1 || app.indexOf("music") !== -1 || app.indexOf("rhythmbox") !== -1
            || combined.indexOf("now playing") !== -1;
        if (isMusic) {
            return Qt.resolvedUrl("../resources/icons/music-alt.svg");
        }

        // 12. CPU / RAM / Storage Stats
        if (ico.indexOf("cpu") !== -1 || combined.indexOf("cpu ") !== -1) {
            return Qt.resolvedUrl("../resources/icons/cpu.svg");
        }
        if (ico.indexOf("memory") !== -1 || ico.indexOf("ram") !== -1 || combined.indexOf("memory") !== -1 || combined.indexOf("ram") !== -1) {
            return Qt.resolvedUrl("../resources/icons/memory.svg");
        }
        if (ico.indexOf("disk") !== -1 || ico.indexOf("storage") !== -1 || ico.indexOf("drive") !== -1 || combined.indexOf("disk") !== -1 || combined.indexOf("storage") !== -1) {
            return Qt.resolvedUrl("../resources/icons/hard-drive.svg");
        }

        // 13. Generic notification icon
        return Qt.resolvedUrl("../resources/icons/notification.svg");
    }

    function showNotificationCapsule(item) {
        if (islandState === "expanded") return;
        if (!item) return;

        // Text arrives pre-sanitized from NotificationServer (C++).
        const appName = String(item.appName || "");
        const summary = String(item.summary || "");
        const body = String(item.body || "");
        const resolvedSummary = summary !== ""
            ? summary
            : (body !== "" ? body : "New notification");

        abortSideTransientMode();
        clearTransientCapsule();
        notificationId = Number(item.id) || 0;
        notificationActions = item.actions || [];
        notificationUrgency = item.urgency === undefined ? 1 : Number(item.urgency);
        notificationProgress = item.progress === undefined ? -1 : Number(item.progress);
        notificationImageDataUrl = String(item.imageDataUrl || "");
        notificationAppName = appName !== "" ? appName : "Notification";
        notificationSummary = resolvedSummary;
        notificationBody = summary !== "" ? body : "";
        notificationAppIcon = String(item.appIcon || "");
        notificationResolvedIcon = String(item.resolvedIcon || item.imagePath || item.imageDataUrl || item.appIcon || "");
        notificationIconSource = resolveNotificationIcon(appName, summary, body, notificationResolvedIcon || notificationAppIcon);
        notificationExpanded = false;
        islandState = "notification";
        // Visual presentation timer: critical alerts get an extended display window,
        // but never freeze the UI permanently.
        const presentationInterval = notificationUrgency === 2
            ? Math.max(notificationAutoHideInterval, 8000)
            : notificationAutoHideInterval;
        restartAutoHideTimer(presentationInterval);
    }

    function toggleNotificationExpansionIfNeeded() {
        if (islandState !== "notification")
            return false;

        if (mainCapsule.notificationItem && mainCapsule.notificationItem.hasOverflowContent && !notificationExpanded) {
            notificationExpanded = true;
            stopAutoHideTimer();
            return true;
        }

        dismissNotificationCapsule();
        return true;
    }

    function dismissNotificationCapsule() {
        if (islandState !== "notification")
            return false;
        const dismissedId = notificationId;
        smartRestoreState();
        if (dismissedId > 0)
            NotificationServer.dismissNotification(dismissedId);
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

    Connections {
        target: NotificationServer

        function onNotificationRemoved(id) {
            if (id === root.notificationId && root.islandState === "notification")
                root.smartRestoreState();
        }
    }

    onCurrentTrackChanged: {
        if (userConfig.disableAutoExpandOnTrackChange) return;
        if (currentTrack !== ""
                && islandState !== "notification") {
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
