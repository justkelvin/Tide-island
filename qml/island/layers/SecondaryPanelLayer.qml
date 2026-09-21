import QtQuick
import IslandBackend

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal closeRequested()

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string titleText: "Title"
    property string textFontFamily: userConfig.textFontFamily

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        MouseArea {
            id: backgroundMouseArea
            anchors.fill: parent
            onClicked: root.backgroundClicked()
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.titleText
                    color: "white"
                    font.pixelSize: userConfig.bodyFontSize
                    font.family: root.textFontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.15
                    elide: Text.ElideRight
                    width: parent.width - pillButton.width - 12
                }

                Rectangle {
                    id: pillButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    height: 26
                    radius: 13
                    color: pillArea.pressed ? "#555558" : "#3a3a3c"

                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Easing.InOutQuad }
                    }

                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        anchors.margins: -8
                        preventStealing: true
                        onPressed: (mouse) => {
                            root.controlPressed();
                            mouse.accepted = true;
                        }
                        onClicked: root.closeRequested()
                    }
                }
            }
        }
    }
}
