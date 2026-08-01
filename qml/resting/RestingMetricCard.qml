import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property string iconFontFamily: ""
    property string textFontFamily: ""

    radius: 11
    color: "#17171a"
    border.width: 1
    border.color: "#242429"

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: "#d7d7dc"
            font.family: root.iconFontFamily
            font.pixelSize: 16
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                color: "#8e8e93"
                elide: Text.ElideRight
                font.family: root.textFontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Text {
                width: parent.width
                text: root.value
                color: "#f5f5f7"
                elide: Text.ElideRight
                font.family: root.textFontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
        }
    }
}
