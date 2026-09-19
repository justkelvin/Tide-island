import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Button {
    id: btn

    property bool selected: false
    property string variant: "secondary" // "primary", "secondary", "ghost", "danger"
    property string iconText: ""
    property int customRadius: Theme.radiusControl

    implicitHeight: 34
    implicitWidth: Math.max(34, contentRow.implicitWidth + 24)
    padding: 0
    leftPadding: 14
    rightPadding: 14

    background: Rectangle {
        id: bg
        radius: btn.customRadius
        color: {
            if (btn.selected || btn.variant === "primary") {
                return btn.down ? Theme.accentPressed : btn.hovered ? Theme.accentHover : Theme.accent;
            }
            if (btn.variant === "danger") {
                return btn.down ? Qt.darker(Theme.error, 1.2) : btn.hovered ? Theme.error : Theme.errorBg;
            }
            if (btn.variant === "ghost") {
                return btn.down ? Theme.pressed : btn.hovered ? Theme.hover : "transparent";
            }
            // default "secondary"
            return btn.down ? Theme.pressed : btn.hovered ? Theme.cardHover : Theme.card;
        }

        border.width: {
            if (btn.selected || btn.variant === "primary") return 0;
            if (btn.variant === "ghost") return 0;
            if (btn.variant === "danger") return 1;
            return 1;
        }
        border.color: {
            if (btn.activeFocus) return Theme.accent;
            if (btn.variant === "danger") return Theme.errorBorder;
            return btn.hovered ? Theme.muted : Theme.outline;
        }

        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion } }
    }

    contentItem: Row {
        id: contentRow
        spacing: 8
        anchors.centerIn: parent

        Text {
            visible: btn.iconText.length > 0
            text: btn.iconText
            color: {
                if (btn.selected || btn.variant === "primary") return Theme.onAccent;
                if (btn.variant === "danger") return btn.hovered ? Theme.onAccent : Theme.error;
                return Theme.text;
            }
            font.family: Theme.fontFamily
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: btn.text
            color: {
                if (btn.selected || btn.variant === "primary") return Theme.onAccent;
                if (btn.variant === "danger") return btn.hovered ? Theme.onAccent : Theme.error;
                return Theme.text;
            }
            opacity: btn.enabled ? 1.0 : 0.4
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: (btn.selected || btn.variant === "primary") ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
