import QtQuick

Item {
    id: root

    property bool enabled: false
    property bool active: false
    property string provider: "none"
    property string location: ""
    property string units: "metric"
    property int refreshIntervalMs: 1800000
    property string state: !enabled ? "disabled" : "unavailable"
    property string temperature: ""
    property string condition: ""
    property string icon: ""
    property string errorString: ""
    property date updatedAt

    visible: false
    width: 0
    height: 0

    function refresh() {
        if (!enabled) {
            state = "disabled";
            return;
        }

        if (provider !== "mock") {
            state = "unavailable";
            return;
        }

        state = "loading";
        mockRefreshTimer.restart();
    }

    function markStale() {
        state = temperature !== "" || condition !== "" ? "stale" : "unavailable";
    }

    function fail(message) {
        errorString = String(message || "Weather provider error");
        state = temperature !== "" || condition !== "" ? "stale" : "error";
    }

    onEnabledChanged: refresh()
    onProviderChanged: refresh()
    onActiveChanged: if (active) refresh()

    Timer {
        id: mockRefreshTimer
        interval: 1
        onTriggered: {
            root.temperature = root.units === "imperial" ? "72°F" : "22°C";
            root.condition = "Mock weather";
            root.icon = "󰖕";
            root.updatedAt = new Date();
            root.state = "fresh";
        }
    }

    Timer {
        interval: Math.max(900000, root.refreshIntervalMs)
        repeat: true
        running: root.enabled && root.active && root.provider === "mock"
        onTriggered: root.refresh()
    }
}
