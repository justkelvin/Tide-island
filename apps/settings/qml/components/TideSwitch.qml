import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Item {
    id: control

    property alias text: titleText.text
    property string description: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 300
    implicitHeight: Math.max(38, textColumn.implicitHeight + 12)

    Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 12

        Column {
            id: textColumn
            width: parent.width - switchIndicator.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: titleText
                width: parent.width
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                visible: control.description.length > 0
                width: parent.width
                text: control.description
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }

        Item {
            id: switchContainer
            width: switchIndicator.width
            height: parent.height

            Rectangle {
                id: switchIndicator
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 22
                radius: 11
                color: control.checked ? Theme.accent : (mouseArea.containsMouse ? Theme.outline : Theme.cardBorder)
                border.width: mouseArea.activeFocus ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: Theme.motion } }

                Rectangle {
                    id: switchThumb
                    x: control.checked ? 19 : 3
                    y: 3
                    width: 16
                    height: 16
                    radius: 8
                    color: control.checked ? Theme.onAccent : Theme.muted

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.motion
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.motion } }
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            control.checked = !control.checked
            control.toggled(control.checked)
        }
    }
}
