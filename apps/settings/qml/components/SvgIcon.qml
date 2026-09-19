import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string source: ""
    property color color: "white"
    property real iconSize: 18

    implicitWidth: iconSize
    implicitHeight: iconSize

    Image {
        id: rawIcon
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.max(32, Math.round(root.width * 2)), Math.max(32, Math.round(root.height * 2)))
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        visible: false
    }

    ColorOverlay {
        anchors.fill: rawIcon
        source: rawIcon
        color: root.color

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }
}
