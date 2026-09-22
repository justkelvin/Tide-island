import QtQuick

// Owned by the shell, so changing screens or unloading a view never resets it.
Item {
    id: root
    visible: false
    property int selectedSeconds: 120
    property bool minuteMode: false
    property bool active: false
    property bool paused: false
    property real remainingMs: 0
    property real durationMs: 0
    property real deadlineMs: 0
    readonly property int remainingSeconds: Math.ceil(remainingMs / 1000)
    readonly property real progress: durationMs > 0 ? remainingMs / durationMs : 0
    readonly property string displayTime: formatTime(remainingSeconds)
    signal finished()

    function formatTime(seconds) {
        const value = Math.max(0, Math.ceil(seconds));
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0");
    }

    function select(seconds) {
        if (isFinite(seconds))
            selectedSeconds = Math.max(1, Math.min(86400, Math.round(seconds)));
    }

    function start() {
        durationMs = selectedSeconds * 1000;
        remainingMs = durationMs;
        deadlineMs = Date.now() + remainingMs;
        paused = false;
        active = true;
    }

    function update() {
        if (!active || paused) return;
        remainingMs = Math.max(0, deadlineMs - Date.now());
        if (remainingMs === 0) {
            active = false;
            finished();
        }
    }

    function togglePause() {
        if (!active) return;
        if (paused) {
            deadlineMs = Date.now() + remainingMs;
            paused = false;
        } else {
            update();
            if (active) paused = true;
        }
    }

    function stop() {
        active = false;
        paused = false;
        remainingMs = 0;
        deadlineMs = 0;
    }

    Timer {
        interval: 50
        repeat: true
        running: root.active && !root.paused
        onTriggered: root.update()
    }
}
