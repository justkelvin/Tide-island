import QtQuick
import TideIsland 1.0

Rectangle {
    width: parent ? parent.width : 100
    height: 1
    color: Theme.divider

    Behavior on color { ColorAnimation { duration: Theme.motion } }
}
