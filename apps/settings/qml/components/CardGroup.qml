import QtQuick
import TideIsland 1.0

Column {
    id: root

    property string title: ""
    property string description: ""
    default property alias content: cardContent.data

    width: parent ? parent.width : 400
    spacing: 8

    Column {
        visible: root.title.length > 0
        width: parent.width
        spacing: 2

        Text {
            text: root.title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            visible: root.description.length > 0
            text: root.description
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.Wrap
            width: parent.width
        }
    }

    Rectangle {
        id: cardBox
        width: parent.width
        height: cardContent.implicitHeight + 24
        radius: Theme.radiusCard
        color: Theme.card
        border.width: 1
        border.color: Theme.outline

        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion } }

        Column {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
        }
    }
}
