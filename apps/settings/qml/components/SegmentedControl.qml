import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Rectangle {
    id: root

    property var options: [] // Array of { label: "...", value: ... }
    property var currentValue: null

    signal selected(var value)

    implicitWidth: Math.max(120, row.implicitWidth + 8)
    implicitHeight: 34
    radius: Theme.radiusControl
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.outline

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 3

        Repeater {
            model: root.options

            delegate: Item {
                id: optionItem
                width: (row.width - (root.options.length - 1) * row.spacing) / Math.max(1, root.options.length)
                height: row.height

                readonly property bool isCurrent: root.currentValue === modelData.value

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusControl - 2
                    color: isCurrent ? Theme.accent : (itemMouse.containsMouse ? Theme.hover : "transparent")

                    Behavior on color { ColorAnimation { duration: Theme.motion } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: isCurrent ? Theme.onAccent : (itemMouse.containsMouse ? Theme.text : Theme.muted)
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: isCurrent ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight

                        Behavior on color { ColorAnimation { duration: Theme.motion } }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.currentValue = modelData.value
                        root.selected(modelData.value)
                    }
                }
            }
        }
    }
}
