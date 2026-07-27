import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url source
    property real cornerRadius: Math.min(width, height) / 2
    property bool active: true
    property color fallbackColor: "#2c2c2e"
    property string fallbackGlyph: "♪"
    property string fallbackFontFamily: ""
    property int fallbackPixelSize: Math.max(12, Math.round(Math.min(width, height) * 0.45))

    readonly property bool hasArtwork: source.toString() !== ""
        && artworkImage.status !== Image.Error

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.fallbackColor
    }

    Image {
        id: artworkImage

        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(Math.max(1, root.width * 2), Math.max(1, root.height * 2))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: false
    }

    Rectangle {
        id: artworkMask

        anchors.fill: parent
        radius: root.cornerRadius
        color: "white"
        visible: false
        layer.enabled: true
        antialiasing: true
    }

    MultiEffect {
        anchors.fill: parent
        source: artworkImage
        maskEnabled: true
        maskSource: artworkMask
        saturation: root.active ? 0 : -0.78
        opacity: root.hasArtwork ? (root.active ? 1 : 0.58) : 0

        Behavior on saturation {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutQuad
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: !root.hasArtwork
        text: root.fallbackGlyph
        color: "white"
        opacity: root.active ? 1 : 0.5
        font.family: root.fallbackFontFamily
        font.pixelSize: root.fallbackPixelSize
        font.weight: Font.DemiBold

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.InOutQuad
            }
        }
    }
}
