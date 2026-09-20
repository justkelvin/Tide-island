import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string source: ""
    property color color: "white"
    property real iconSize: 22

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: implicitWidth
    height: implicitHeight

    Image {
        id: rawIcon
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.max(48, Math.round(root.width * 2)), Math.max(48, Math.round(root.height * 2)))
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
            ColorAnimation { duration: 100 }
        }
    }
}
