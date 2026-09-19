import QtQuick
import TideIsland 1.0

Item {
    id: root

    property string title: ""
    property string description: ""
    default property alias control: controlSlot.data

    width: parent ? parent.width : 400
    implicitHeight: Math.max(36, textColumn.implicitHeight + 4)

    Row {
        anchors.fill: parent
        spacing: 16

        Column {
            id: textColumn
            width: parent.width - controlSlot.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                visible: root.description.length > 0
                text: root.description
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
                width: parent.width
            }
        }

        Item {
            id: controlSlot
            width: childrenRect.width
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
