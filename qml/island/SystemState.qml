import QtQuick
import IslandBackend
import Quickshell.Io

Item {
    id: root

    visible: false
    width: 0
    height: 0

    signal transientRequested(string icon, real progress, string text)

    property var configuredLeftSwipeItems: []
    property string timeText: "00:00"
    property string dateText: "Mon, Jan 01"
    property int currentWorkspace: 1
    property bool customSwipeActive: false
    property bool lyricsCavaActive: false

    readonly property var configuredLeftSwipeIds: buildNormalizedSwipeItemIds(configuredLeftSwipeItems)
    readonly property bool usesSystemStatsModule: configuredLeftSwipeIds.indexOf("cpu") !== -1
        || configuredLeftSwipeIds.indexOf("ram") !== -1
    readonly property bool usesStorageModule: configuredLeftSwipeIds.indexOf("storage") !== -1
    readonly property bool usesCavaModule: configuredLeftSwipeIds.indexOf("cava") !== -1
    readonly property bool hasCustomLeftItems: customLeftItems.length > 0
    readonly property string systemServicesClientId: "island-system-state-" + Math.random().toString(36).slice(2)
    readonly property string defaultStatusIcon: Qt.resolvedUrl("../resources/icons/notification.svg")
    readonly property string volumeDownStatusIcon: Qt.resolvedUrl("../resources/icons/volume-down.svg")
    readonly property string volumeUpStatusIcon: Qt.resolvedUrl("../resources/icons/volume-up.svg")
    readonly property string volumeStatusIcon: Qt.resolvedUrl("../resources/icons/volume-up.svg")
    readonly property string muteStatusIcon: Qt.resolvedUrl("../resources/icons/volume-mute.svg")
    readonly property string brightnessLowStatusIcon: Qt.resolvedUrl("../resources/icons/brightness-low.svg")
    readonly property string brightnessMediumStatusIcon: Qt.resolvedUrl("../resources/icons/brightness.svg")
    readonly property string brightnessHighStatusIcon: Qt.resolvedUrl("../resources/icons/brightness.svg")
    readonly property string chargingStatusIcon: Qt.resolvedUrl("../resources/icons/battery-bolt.svg")
    readonly property string dischargingStatusIcon: Qt.resolvedUrl("../resources/icons/battery-discharging.svg")
    readonly property string cpuStatusIcon: Qt.resolvedUrl("../resources/icons/cpu.svg")
    readonly property string ramStatusIcon: Qt.resolvedUrl("../resources/icons/memory.svg")
    readonly property string bluetoothStatusIcon: Qt.resolvedUrl("../resources/icons/bluetooth-off.svg")
    readonly property string storageStatusIcon: Qt.resolvedUrl("../resources/icons/hard-drive.svg")

    property int batteryCapacity: SysBackend.batteryCapacity
    property bool isCharging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"
    property real currentVolume: -1
    property bool isMuted: false
    property real currentBrightness: -1
    property real currentCpuUsage: -1
    property real currentRamUsage: -1
    property var cavaLevels: [0, 0, 0, 0, 0, 0, 0, 0]
    property real currentStorageUsage: -1
    property var customLeftItems: []

    property string _lastChargeStatus: SysBackend.batteryStatus
    property string _pendingVolType: ""
    property real _pendingVolVal: 0.0
    property string _lastVolType: ""
    property real _lastVolVal: -1.0
    property bool _bluetoothVolumeSuppressed: false
    property real _pendingBrightnessValue: 0.0
    property string _customLeftItemsSignature: ""

    onConfiguredLeftSwipeIdsChanged: {
        syncCustomLeftItems();
        refreshMissingValues();
        updateCavaSubscription();
    }
    onUsesSystemStatsModuleChanged: refreshMissingValues()
    onUsesStorageModuleChanged: refreshMissingValues()
    onUsesCavaModuleChanged: updateCavaSubscription()
    onCustomSwipeActiveChanged: updateCavaSubscription()
    onLyricsCavaActiveChanged: updateCavaSubscription()
    onBatteryCapacityChanged: syncCustomLeftItems()
    onIsChargingChanged: syncCustomLeftItems()
    onCurrentVolumeChanged: syncCustomLeftItems()
    onIsMutedChanged: syncCustomLeftItems()
    onCurrentBrightnessChanged: syncCustomLeftItems()
    onCurrentCpuUsageChanged: syncCustomLeftItems()
    onCurrentRamUsageChanged: syncCustomLeftItems()
    onCurrentStorageUsageChanged: syncCustomLeftItems()
    onCurrentWorkspaceChanged: syncCustomLeftItems()
    onTimeTextChanged: syncCustomLeftItems()
    onDateTextChanged: syncCustomLeftItems()
    Component.onCompleted: {
        syncCustomLeftItems();
        refreshMissingValues();
        updateCavaSubscription();
    }

    Component.onDestruction: {
        SystemServices.setCavaClientActive(systemServicesClientId, false);
    }

    function statusIcon(name) {
        switch (name) {
        case "default":
            return defaultStatusIcon;
        case "volume":
            return currentVolume <= 0.4 ? volumeDownStatusIcon : volumeUpStatusIcon;
        case "volumeDown":
            return volumeDownStatusIcon;
        case "volumeUp":
            return volumeUpStatusIcon;
        case "mute":
            return muteStatusIcon;
        case "brightnessLow":
            return brightnessLowStatusIcon;
        case "brightnessMedium":
            return brightnessMediumStatusIcon;
        case "brightnessHigh":
            return brightnessHighStatusIcon;
        case "charging":
            return chargingStatusIcon;
        case "discharging":
            return dischargingStatusIcon;
        case "cpu":
            return cpuStatusIcon;
        case "ram":
            return ramStatusIcon;
        case "bluetooth":
            return bluetoothStatusIcon;
        case "storage":
            return storageStatusIcon;
        default:
            return "";
        }
    }

    function normalizeSwipeItemId(rawId) {
        return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
    }

    function listValues(rawItems) {
        if (!rawItems)
            return [];
        if (Array.isArray(rawItems))
            return rawItems;

        const length = Number(rawItems.length);
        if (!isFinite(length) || length < 0)
            return [];

        const resolved = [];
        for (let index = 0; index < Math.floor(length); index++)
            resolved.push(rawItems[index]);
        return resolved;
    }

    function formatPercentText(value) {
        return Math.round(Math.max(0, value) * 100) + "%";
    }

    function clamp01(value) {
        return Math.max(0, Math.min(1, value));
    }

    function brightnessStatusIcon(value) {
        if (value < 0.3) return statusIcon("brightnessLow");
        if (value < 0.7) return statusIcon("brightnessMedium");
        return statusIcon("brightnessHigh");
    }

    function refreshMissingValues() {
        if (currentBrightness < 0)
            SystemServices.requestBrightness();
        if (currentVolume < 0)
            SystemServices.requestVolume();
        if (usesSystemStatsModule || usesStorageModule)
            SystemServices.requestSystemStats();
    }

    function updateCavaSubscription() {
        const active = (usesCavaModule && customSwipeActive) || lyricsCavaActive;
        SystemServices.setCavaClientActive(systemServicesClientId, active);
        if (active)
            cavaLevels = SystemServices.cavaLevels;
    }

    function buildNormalizedSwipeItemIds(rawItems) {
        const source = listValues(rawItems);
        const resolved = [];
        const seen = {};

        for (let index = 0; index < source.length; index++) {
            const itemId = normalizeSwipeItemId(source[index]);
            if (itemId === "" || seen[itemId]) continue;
            seen[itemId] = true;
            resolved.push(itemId);
        }

        return resolved;
    }

    function buildCustomSwipeItem(itemId) {
        switch (itemId) {
        case "time":
            return { id: itemId, icon: "", text: timeText };
        case "date":
            return { id: itemId, icon: "", text: dateText };
        case "battery":
            if (batteryCapacity < 0) return null;
            return {
                id: itemId,
                kind: "battery",
                level: Math.max(0, Math.min(100, batteryCapacity)),
                isCharging: isCharging,
                icon: "",
                text: Math.max(0, batteryCapacity) + "%"
            };
        case "volume":
            if (currentVolume < 0) return null;
            return {
                id: itemId,
                icon: isMuted ? statusIcon("mute") : statusIcon("volume"),
                text: formatPercentText(currentVolume)
            };
        case "brightness":
            if (currentBrightness < 0) return null;
            return {
                id: itemId,
                icon: brightnessStatusIcon(currentBrightness),
                text: formatPercentText(currentBrightness)
            };
        case "workspace":
            return { id: itemId, icon: Qt.resolvedUrl("../resources/icons/workspace-change.svg"), text: "Workspace " + currentWorkspace };
        case "cpu":
            return {
                id: itemId,
                icon: statusIcon("cpu"),
                text: currentCpuUsage >= 0 ? formatPercentText(currentCpuUsage) : "--%"
            };
        case "ram":
            return {
                id: itemId,
                icon: statusIcon("ram"),
                text: currentRamUsage >= 0 ? formatPercentText(currentRamUsage) : "--%"
            };
        case "cava":
            return { id: itemId, kind: "cava" };
        case "storage":
            return {
                id: itemId,
                icon: storageStatusIcon,
                text: currentStorageUsage >= 0 ? Math.round(currentStorageUsage) + "%" : "--%"
            };
        default:
            return null;
        }
    }

    function buildCustomSwipeItems(itemIds) {
        const source = listValues(itemIds);
        const resolved = [];

        for (let index = 0; index < source.length; index++) {
            const itemId = String(source[index] || "");
            if (itemId === "") continue;

            const nextItem = buildCustomSwipeItem(itemId);
            if (nextItem) resolved.push(nextItem);
        }

        return resolved;
    }

    function customSwipeItemsSignature(items) {
        const source = listValues(items);
        let signature = "";

        for (let index = 0; index < source.length; index++) {
            const item = source[index] || {};
            signature += String(item.id || "")
                + "\u001f" + String(item.kind || "")
                + "\u001f" + String(item.icon || "")
                + "\u001f" + String(item.text || "")
                + "\u001f" + String(item.level === undefined ? "" : item.level)
                + "\u001f" + String(item.isCharging === undefined ? "" : item.isCharging)
                + "\u001e";
        }

        return signature;
    }

    function syncCustomLeftItems() {
        const nextItems = buildCustomSwipeItems(configuredLeftSwipeIds);
        const nextSignature = customSwipeItemsSignature(nextItems);
        if (nextSignature === _customLeftItemsSignature)
            return;

        _customLeftItemsSignature = nextSignature;
        customLeftItems = nextItems;
    }

    Timer {
        id: bluetoothVolumeSuppressionTimer

        interval: 2000

        onTriggered: root._bluetoothVolumeSuppressed = false
    }

    Timer {
        id: volumeDebounce

        interval: 16

        onTriggered: {
            if (root._bluetoothVolumeSuppressed) return;
            if (root._pendingVolType !== root._lastVolType
                    || Math.abs(root._pendingVolVal - root._lastVolVal) > 0.001) {
                root._lastVolType = root._pendingVolType;
                root._lastVolVal = root._pendingVolVal;
                root.transientRequested(
                    root._pendingVolType === "MUTE" ? root.statusIcon("mute") : (root._pendingVolVal <= 0.4 ? root.statusIcon("volumeDown") : root.statusIcon("volumeUp")),
                    root._pendingVolVal,
                    ""
                );
            }
        }
    }

    Timer {
        id: brightnessDebounce

        interval: 16

        onTriggered: root.transientRequested(
            root.brightnessStatusIcon(root._pendingBrightnessValue),
            root._pendingBrightnessValue,
            ""
        )
    }

    Timer {
        id: systemStatsPollTimer

        interval: 3000
        repeat: true
        running: root.usesSystemStatsModule || root.usesStorageModule
        triggeredOnStart: true

        onTriggered: SystemServices.requestSystemStats()
    }

    Connections {
        target: SystemServices

        function onBrightnessSnapshotReady(value, errorString) {
            if (errorString === "" && value >= 0)
                root.currentBrightness = root.clamp01(value);
        }

        function onVolumeSnapshotReady(value, muted, errorString) {
            if (errorString !== "" || value < 0)
                return;
            root.currentVolume = root.clamp01(value);
            root.isMuted = muted;
        }

        function onSystemStatsReady(cpuUsage, ramUsage, errorString) {
            if (errorString !== "")
                return;
            if (cpuUsage >= 0)
                root.currentCpuUsage = root.clamp01(cpuUsage);
            if (ramUsage >= 0)
                root.currentRamUsage = root.clamp01(ramUsage);
        }

        function onStorageSnapshotReady(value, errorString) {
            if (errorString === "" && value >= 0)
                root.currentStorageUsage = Math.round(root.clamp01(value) * 100);
        }

        function onCavaLevelsChanged() {
            root.cavaLevels = SystemServices.cavaLevels;
        }
    }

    Connections {
        target: SysBackend

        function onVolumeChanged(volPercentage, isMuted) {
            const nextVolType = isMuted ? "MUTE" : "VOL";
            const nextVolValue = root.clamp01(volPercentage / 100.0);
            const unchanged = root.isMuted === isMuted
                && Math.abs(root.currentVolume - nextVolValue) <= 0.001
                && root._pendingVolType === nextVolType
                && Math.abs(root._pendingVolVal - nextVolValue) <= 0.001;

            if (unchanged)
                return;

            root._pendingVolType = nextVolType;
            root._pendingVolVal = nextVolValue;
            root.currentVolume = nextVolValue;
            root.isMuted = isMuted;
            volumeDebounce.restart();
        }

        function onBatteryChanged(capacity, statusString) {
            root.batteryCapacity = capacity;
            const nowCharging = (statusString === "Charging" || statusString === "Full");
            const wasCharging = (root._lastChargeStatus === "Charging" || root._lastChargeStatus === "Full");
            root.isCharging = nowCharging;
            if (root._lastChargeStatus !== "" && wasCharging !== nowCharging) {
                if (nowCharging)
                    root.transientRequested(root.statusIcon("charging"), -1.0, "");
                else
                    root.transientRequested(root.statusIcon("discharging"), -1.0, "");
            }
            root._lastChargeStatus = statusString;
        }

        function onBrightnessChanged(value) {
            root._pendingBrightnessValue = value;
            root.currentBrightness = value;
            brightnessDebounce.restart();
        }

        function onBluetoothChanged(isConnected) {
            root._bluetoothVolumeSuppressed = true;
            bluetoothVolumeSuppressionTimer.restart();
            if (isConnected)
                return;

            root.transientRequested(root.statusIcon("bluetooth"), -1.0, "Disconnected");
        }
    }
}
