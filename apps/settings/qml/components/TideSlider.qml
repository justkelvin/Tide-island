import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Slider {
    id: control

    property string unit: ""
    property int decimals: 0

    implicitHeight: 34
    implicitWidth: 200

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - 2
        width: control.availableWidth
        height: 4
        radius: 2
        color: Theme.cardBorder

        Rectangle {
            width: control.visualPosition * parent.width
            height: 4
            radius: 2
            color: Theme.accent
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 16
        height: 16
        radius: 8
        color: control.pressed ? Theme.text : Theme.accent
        border.width: (control.activeFocus || control.hovered) ? 2 : 0
        border.color: Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
        }
    }
}
