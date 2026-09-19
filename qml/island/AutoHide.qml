import QtQuick
import IslandBackend

Item {
    id: root

    required property var window
    required property var islandController

    readonly property var userConfig: UserConfig

    property bool visibleState: false
    property bool pointerInside: false
    property bool forcedHidden: false
    property string revealSource: "none"

    readonly property bool runtimeEnabled: !window.shellRootController
        || window.shellRootController.islandAutoHideRuntimeEnabled === undefined
        || !!window.shellRootController.islandAutoHideRuntimeEnabled

    readonly property bool enabled: userConfig.islandAutoHideEnabled && runtimeEnabled

    readonly property bool restingState: islandController.islandState === "normal"
        || islandController.islandState === "custom"
        || islandController.islandState === "lyrics"

    readonly property bool canHideNow: enabled && restingState
    readonly property bool mustShow: !restingState

    readonly property bool targetVisible: mustShow
        || (!forcedHidden && (!enabled || visibleState))

    readonly property bool suppressesTransientReveal: (enabled || forcedHidden)
        && !targetVisible

    property real progress: targetVisible ? 1 : 0

    readonly property bool exclusiveZoneTargetActive: (!enabled && targetVisible)
        || (revealSource === "edge" && targetVisible)
        || islandController.notificationLayerVisible

    property real exclusiveZoneProgress: exclusiveZoneTargetActive ? 1 : 0

    readonly property real revealWidth: Math.min(window.width, Math.max(userConfig.islandWidth + 120, 240))
    readonly property real revealHeight: enabled ? 10 : 0
    readonly property real revealX: Math.max(
        0,
        Math.min(window.width - revealWidth, window.width * userConfig.islandPositionX / 100 - revealWidth / 2)
    )

    readonly property real topGestureInputX: enabled ? revealX : 0
    readonly property real topGestureInputWidth: window.topGestureInputActive
        ? (enabled ? revealWidth : window.width)
        : 0
    readonly property real topGestureInputHeight: window.topGestureInputActive
        ? (enabled ? revealHeight : window.baseExclusiveZone)
        : 0

    Behavior on progress {
        NumberAnimation {
            duration: root.targetVisible ? 120 : 300
            easing.type: root.targetVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on exclusiveZoneProgress {
        NumberAnimation {
            duration: root.exclusiveZoneTargetActive ? 120 : 300
            easing.type: root.exclusiveZoneTargetActive ? Easing.OutCubic : Easing.InCubic
        }
    }

    function setRevealSource(source) {
        if (source === undefined || source === null)
            return;

        const nextSource = String(source);
        revealSource = nextSource === "edge" || nextSource === "state" || nextSource === "manual"
            ? nextSource
            : "manual";
    }

    function show(source) {
        setRevealSource(source);
        forcedHidden = false;
        hideTimer.stop();
        visibleState = true;
    }

    function scheduleHide() {
        if (!enabled) {
            hideTimer.stop();
            visibleState = true;
            return;
        }

        if (!canHideNow) {
            hideTimer.stop();
            show("state");
            return;
        }

        if (pointerInside) {
            hideTimer.stop();
            return;
        }

        hideTimer.interval = Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs));
        hideTimer.restart();
    }

    function hide(force) {
        if (force === undefined) force = false;
        if (!enabled) {
            hideTimer.stop();
            if (!force && mustShow)
                return;
            forcedHidden = true;
            revealSource = "none";
            visibleState = false;
            return;
        }

        if (!force && (!canHideNow || pointerInside))
            return;

        hideTimer.stop();
        forcedHidden = false;
        revealSource = "none";
        visibleState = false;
    }

    function toggle() {
        if (targetVisible)
            hide(false);
        else
            show("manual");
    }

    function refresh() {
        if (enabled)
            scheduleHide();
        else
            show("manual");
    }

    onEnabledChanged: refresh()
    onCanHideNowChanged: {
        if (canHideNow)
            scheduleHide();
        else
            show("state");
    }

    Timer {
        id: hideTimer
        interval: Math.max(100, Math.min(10000, userConfig.islandAutoHideDelayMs))
        repeat: false
        onTriggered: root.hide(false)
    }

    MouseArea {
        id: revealArea

        x: root.revealX
        y: 0
        z: 20
        width: root.revealWidth
        height: root.revealHeight
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.pointerInside = true;
            root.show("edge");
        }

        onExited: {
            root.pointerInside = false;
            root.scheduleHide();
        }
    }
}
