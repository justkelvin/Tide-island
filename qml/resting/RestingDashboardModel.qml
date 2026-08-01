import QtQuick
import Quickshell.Io
import IslandBackend

Item {
    id: root

    property bool active: false
    property string networkName: ""
    property bool networkConnected: false
    property bool vpnActive: false
    property string powerProfile: ""

    visible: false
    width: 0
    height: 0

    function refresh() {
        if (!active)
            return;
        refreshNetwork();
        SystemServices.requestTlpState();
    }

    function refreshNetwork() {
        if (!active)
            return;
        networkTimeout.restart();
        networkProbe.running = true;
    }

    function parseNetworkLine(line) {
        const fields = String(line || "").split(":");
        if (fields.length < 3 || fields[1] !== "connected")
            return;

        const type = fields[0];
        const connection = fields.slice(2).join(":").trim();
        if (type === "tun" || type === "wireguard" || type === "vpn") {
            vpnActive = true;
            return;
        }
        if (!networkConnected && connection !== "" && connection !== "--") {
            networkConnected = true;
            networkName = connection;
        }
    }

    onActiveChanged: {
        if (active) {
            refresh();
            networkPollTimer.restart();
        } else {
            networkPollTimer.stop();
            networkTimeout.stop();
            networkProbe.running = false;
        }
    }

    Timer {
        id: networkPollTimer
        interval: 15000
        repeat: true
        onTriggered: root.refreshNetwork()
    }

    Timer {
        id: networkTimeout
        interval: 2000
        onTriggered: networkProbe.running = false
    }

    Process {
        id: networkProbe
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"]
        running: false

        onRunningChanged: {
            if (running) {
                root.networkName = "";
                root.networkConnected = false;
                root.vpnActive = false;
            } else {
                networkTimeout.stop();
            }
        }

        stdout: SplitParser {
            onRead: function(line) { root.parseNetworkLine(line); }
        }
    }

    Connections {
        target: SystemServices

        function onTlpStateReady(available, profile, output, errorString) {
            root.powerProfile = available ? String(profile || "").trim() : "";
        }
    }
}
