import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Rectangle {
    id: control

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias inputMethodHints: field.inputMethodHints
    property alias validator: field.validator
    property alias field: field
    property int textPixelSize: 13

    signal accepted()
    signal editingFinished()

    readonly property bool hovered: hoverHandler.hovered

    radius: Theme.radiusControl
    color: field.activeFocus ? Theme.card : hovered ? Theme.cardHover : Theme.surfaceElevated
    border.width: 1
    border.color: field.activeFocus ? Theme.accent : hovered ? Theme.muted : Theme.outline
    implicitWidth: 100
    implicitHeight: 34

    Behavior on color { ColorAnimation { duration: Theme.motion } }
    Behavior on border.color { ColorAnimation { duration: Theme.motion } }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.IBeamCursor
    }

    TextField {
        id: field
        background: null
        anchors.fill: parent
        color: Theme.text
        placeholderTextColor: Theme.subtle
        selectionColor: Theme.accentSoftHover
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: control.textPixelSize
        leftPadding: 12
        rightPadding: 12
        verticalAlignment: TextInput.AlignVCenter

        onAccepted: control.accepted()
        onEditingFinished: control.editingFinished()
    }
}
