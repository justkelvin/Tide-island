import QtQuick

Item {
    id: root

    property bool active: false
    property var itemOrder: []
    property string fullDate: ""
    property real cpuUsage: -1
    property real ramUsage: -1
    property int batteryCapacity: -1
    property bool charging: false
    property int workspace: 1
    property int notificationCount: 0
    property bool dndEnabled: false
    property string networkName: ""
    property bool networkConnected: false
    property bool vpnActive: false
    property string powerProfile: ""
    property var weatherProvider: null
    property string iconFontFamily: ""
    property string textFontFamily: ""

    readonly property var cards: buildCards()

    function percent(value) { return Math.round(Math.max(0, value) * 100) + "%"; }

    function buildCards() {
        const available = {
            date: fullDate !== "" ? { icon: "󰃭", label: "Date", value: fullDate } : null,
            weather: weatherProvider && (weatherProvider.state === "fresh" || weatherProvider.state === "stale")
                ? { icon: weatherProvider.icon, label: weatherProvider.state === "stale" ? "Weather · stale" : "Weather", value: weatherProvider.temperature + "  " + weatherProvider.condition }
                : null,
            cpu: cpuUsage >= 0 ? { icon: "󰻠", label: "CPU", value: percent(cpuUsage) } : null,
            ram: ramUsage >= 0 ? { icon: "󰍛", label: "Memory", value: percent(ramUsage) } : null,
            battery: batteryCapacity >= 0 ? { icon: charging ? "󰂄" : "󰁹", label: powerProfile !== "" ? "Battery · " + powerProfile : "Battery", value: batteryCapacity + "%" + (charging ? " · charging" : "") } : null,
            network: networkConnected ? { icon: vpnActive ? "󰌾" : "󰖩", label: vpnActive ? "Network · VPN" : "Network", value: networkName } : null,
            workspace: { icon: "󰍹", label: "Workspace", value: String(workspace) },
            notifications: { icon: dndEnabled ? "󰂛" : "󰂚", label: dndEnabled ? "Notifications · DND" : "Notifications", value: notificationCount === 0 ? "No unread items" : notificationCount + " in history" }
        };
        const result = [];
        const source = itemOrder || [];
        for (let index = 0; index < source.length && result.length < 6; ++index) {
            const card = available[String(source[index])];
            if (card)
                result.push(card);
        }
        return result;
    }

    anchors.fill: parent
    visible: active
    opacity: active ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: root.active ? 180 : 100 } }

    Grid {
        anchors.fill: parent
        anchors.margins: 12
        columns: 3
        rows: 2
        spacing: 8

        Repeater {
            model: root.cards

            RestingMetricCard {
                required property var modelData
                width: (root.width - 40) / 3
                height: (root.height - 32) / 2
                icon: modelData.icon || ""
                label: modelData.label || ""
                value: modelData.value || ""
                iconFontFamily: root.iconFontFamily
                textFontFamily: root.textFontFamily
            }
        }
    }
}
