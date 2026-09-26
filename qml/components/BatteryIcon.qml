import QtQuick

// Live iOS-style battery glyph drawn natively in QML: translucent track,
// solid fill at the exact level, level number + bolt while charging, Apple
// red at or below 20%. Shared by the custom-info widget and the OSD overlay
// so both always agree.
Item {
    id: root

    property real level: 0
    property bool charging: false
    property string textFontFamily: "Inter Display"
    property string iconFontFamily: "JetBrainsMono Nerd Font"
    property int batteryFontSize: 13
    property int batteryFontSizeCharging: 12
    property int batteryBoltSize: 10
    property string chargingGlyph: "\uf0e7"
    property real tipWidth: 2
    property real tipHeight: 5
    property real outerRadius: 6

    readonly property real clampedLevel: Math.max(0, Math.min(100, Number(level) || 0))
    readonly property bool roundedEnd: clampedLevel >= 85
    readonly property color bodyColor: {
        if (charging)
            return "#34c759";
        if (clampedLevel <= 20)
            return "#ff3b30";
        return "white";
    }
    readonly property color emptyColor: Qt.rgba(1, 1, 1, 0.56)

    implicitWidth: 37
    implicitHeight: 17

    Rectangle {
        id: batteryBody
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - root.tipWidth - 1
        height: parent.height
        radius: root.outerRadius
        color: root.emptyColor
        border.width: 0
        clip: true

        Rectangle {
            id: batteryFill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 0
            topLeftRadius: root.outerRadius
            bottomLeftRadius: root.outerRadius
            topRightRadius: root.roundedEnd ? root.outerRadius : 0
            bottomRightRadius: root.roundedEnd ? root.outerRadius : 0
            width: Math.max(root.outerRadius * 2, parent.width * (root.clampedLevel / 100.0))
            color: root.bodyColor

            Behavior on width {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        Row {
            visible: root.charging
            anchors.centerIn: parent
            spacing: 2
            z: 2

            Text {
                text: Math.round(root.clampedLevel) + ""
                color: "black"
                font.pixelSize: root.batteryFontSizeCharging
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.chargingGlyph
                color: "#242424"
                font.pixelSize: root.batteryBoltSize
                font.family: root.iconFontFamily
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            visible: !root.charging
            anchors.centerIn: parent
            text: Math.round(root.clampedLevel) + ""
            color: root.clampedLevel <= 20 ? "white" : "black"
            font.pixelSize: root.batteryFontSize
            font.family: root.textFontFamily
            font.weight: root.clampedLevel <= 20 ? Font.Bold : Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            z: 2
        }
    }

    Rectangle {
        width: root.tipWidth
        height: root.tipHeight
        radius: Math.round(root.tipWidth / 2)
        color: root.clampedLevel >= 100 ? root.bodyColor : root.emptyColor
        anchors.left: batteryBody.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color {
            ColorAnimation { duration: 300 }
        }
    }
}
