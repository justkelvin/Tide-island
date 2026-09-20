import QtCore
import QtQuick
import Quickshell
import Quickshell.Wayland
import IslandBackend
import "../components"
import "../hyprland"
import "../waybar"
import "../island"

PanelWindow {
    id: root

    property var shellRootController: null
    readonly property var hyprlandIntegration: hyprlandIntegrationLoader.item
    readonly property var hyprMonitor: hyprlandIntegration ? hyprlandIntegration.monitor : null
    readonly property string hyprMonitorName: hyprlandIntegration ? hyprlandIntegration.monitorName : ""
    readonly property string screenOutputName: screen && screen.name !== undefined ? String(screen.name) : ""
    readonly property string compositorOutputName: hyprMonitorName
    readonly property bool monitorFocused: hyprlandIntegration ? hyprlandIntegration.monitorFocused : false
    readonly property int currentMonitorWorkspaceId: hyprlandIntegration ? hyprlandIntegration.workspaceId : 1
    readonly property bool screenRecordingActive: shellRootController
        && shellRootController.screenRecordingActive !== undefined
        ? !!shellRootController.screenRecordingActive
        : false

    readonly property var userConfig: UserConfig
    readonly property alias waybarMainBackground: waybarTheme.mainBackground

    WaybarTheme {
        id: waybarTheme
    }

    Loader {
        id: hyprlandIntegrationLoader

        active: true
        asynchronous: false
        source: "../hyprland/HyprlandWindowIntegration.qml"
    }

    Binding {
        target: hyprlandIntegrationLoader.item
        property: "screenObject"
        value: root.screen
        when: hyprlandIntegrationLoader.item !== null
    }

    color: StyleTokens.transparent
    anchors { top: true; left: true; right: true }

    mask: Region {
        Region {
            x: Math.floor(root.topGestureInputX)
            y: 0
            width: Math.ceil(root.topGestureInputWidth)
            height: Math.ceil(root.topGestureInputHeight)
        }

        Region {
            intersection: Intersection.Combine
            x: Math.floor(islandContainer.capsule.x)
            y: Math.floor(islandContainer.capsule.y)
            width: Math.ceil(islandContainer.capsule.width)
            height: Math.ceil(islandContainer.capsule.height)
        }
    }

    implicitHeight: Math.max(280, Math.ceil(userConfig.islandTopMargin + 260))
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "tide-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: {
        if (islandContainer.expandedPlayerKeyboardFocusRequested)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.None;
    }

    readonly property string iconFontFamily: userConfig.iconFontFamily
    readonly property string textFontFamily: userConfig.textFontFamily
    readonly property string heroFontFamily: userConfig.heroFontFamily
    readonly property string timeFontFamily: userConfig.timeFontFamily
    readonly property int bodyFontSize: userConfig.bodyFontSize
    readonly property int titleFontSize: userConfig.titleFontSize
    readonly property int iconFontSize: userConfig.iconFontSize
    readonly property string defaultSplitIcon: "\ud83c\udfa7"
    readonly property string notificationStatusIcon: "\uf0f3"
    readonly property int dynamicIslandAcceptedButtons: userConfig.mouseButtonsMask([
        1,
        userConfig.dynamicIslandPrimaryButton,
        userConfig.dynamicIslandSecondaryButton
    ])
    readonly property int configuredHoverExpandAction: {
        const action = Number(userConfig.hoverExpandAction);
        return isNaN(action) ? 0 : Math.max(0, Math.min(2, Math.round(action)));
    }
    readonly property real baseExclusiveZone: userConfig.islandExclusiveZone
    readonly property bool hoverExpandEnabled: configuredHoverExpandAction > 0
    readonly property bool topGestureInputActive: islandContainer.canShowSideSwipe

    AutoHide {
        id: autoHide
        window: root
        islandController: islandContainer
    }

    readonly property alias autoHideTargetVisible: autoHide.targetVisible
    readonly property alias autoHideProgress: autoHide.progress
    readonly property alias autoHideSuppressesTransientReveal: autoHide.suppressesTransientReveal
    readonly property alias topGestureInputX: autoHide.topGestureInputX
    readonly property alias topGestureInputWidth: autoHide.topGestureInputWidth
    readonly property alias topGestureInputHeight: autoHide.topGestureInputHeight

    function showIslandWindow() { autoHide.show("manual"); }
    function hideIslandWindow() { autoHide.hide(false); }
    function toggleIslandWindow() { autoHide.toggle(); }
    function refreshAutoHideWindow() { autoHide.refresh(); }
    function showAutoHiddenIsland(source) { autoHide.show(source); }
    function scheduleAutoHide() { autoHide.scheduleHide(); }

    function showNotification(appName, summary, body, appIcon) {
        islandContainer.showNotificationCapsule(appName, summary, body, appIcon);
    }

    function showClockWindow() {
        islandContainer.showTimeCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function showCustomInfoWindow() {
        islandContainer.showCustomCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function showLyricsWindow() {
        islandContainer.showLyricsCapsule();
        showAutoHiddenIsland("manual");
        scheduleAutoHide();
    }

    function swipeRightWindow() {
        islandContainer.swipeRightWindow();
    }

    function swipeLeftWindow() {
        islandContainer.swipeLeftWindow();
    }

    function togglePlayerWindow() {
        islandContainer.togglePlayerWindow();
    }

    StateMachine {
        id: islandContainer
        windowRoot: root
    }

    RootGestureArea {
        anchors.fill: parent
        enabled: root.topGestureInputActive
        islandController: islandContainer
        capsule: islandContainer.capsule
    }
}
