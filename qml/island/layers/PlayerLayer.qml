import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend
import Quickshell.Services.Mpris
import "../../components"

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal keyboardFocusRequested()
    signal keyboardFocusReleased()
    signal previousRequested()

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    property var cavaLevels: []
    readonly property var pausedLevels: [0.34, 0.58, 0.82, 0.58, 0.34]

    function togglePlayback() {
        if (!activePlayer || !activePlayer.canControl) return;

        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }

        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) activePlayer.pause();
            return;
        }

        if (activePlayer.canPlay) activePlayer.play();
    }

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

        Item {
            id: musicPage
            anchors.fill: parent

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Item {
                        width: parent.width
                        height: 60

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 16

                            Rectangle {
                                width: 60
                                height: 60
                                radius: 14
                                color: "#2c2c2e"

                                SvgIcon {
                                    anchors.centerIn: parent
                                    source: Qt.resolvedUrl("../../resources/icons/music-alt.svg")
                                    iconSize: 28
                                    color: "#5f6368"
                                    visible: !albumArt.visible
                                }

                                Rectangle {
                                    id: albumArtMask
                                    anchors.fill: parent
                                    radius: 14
                                    antialiasing: true
                                    visible: false
                                    layer.enabled: true
                                }

                                Image {
                                    id: albumArt
                                    anchors.fill: parent
                                    source: currentArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source.toString() !== ""
                                    sourceSize: Qt.size(120, 120)
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: albumArtMask
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: currentTrack !== "" ? currentTrack : "No media playing"
                                    color: "white"
                                    font.pixelSize: userConfig.bodyFontSize
                                    font.family: textFontFamily
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: -0.15
                                    width: 180
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: currentArtist
                                    visible: currentArtist !== ""
                                    color: "#8e8e93"
                                    font.pixelSize: userConfig.bodyFontSize - 2
                                    font.family: textFontFamily
                                    font.weight: Font.Medium
                                    width: 200
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 22
                            visible: currentTrack !== ""

                            CavaBars {
                                anchors.centerIn: parent
                                levels: isPlaying ? root.cavaLevels : root.pausedLevels
                                barCount: 5
                                barWidth: 4
                                barSpacing: 4
                                minimumBarHeight: 6
                                height: 22
                                barColor: isPlaying ? "white" : "#8e8e93"
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            id: timeL
                            anchors.left: parent.left
                            text: timePlayed
                            color: "#8e8e93"
                            font.pixelSize: userConfig.bodyFontSize - 4
                            font.family: textFontFamily
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: timeL.right
                            anchors.right: timeR.left
                            anchors.margins: 12
                            height: 6
                            radius: 3
                            color: "#333333"

                            Rectangle {
                                height: parent.height
                                radius: 3
                                color: "white"
                                width: parent.width * trackProgress

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 500
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Text {
                            id: timeR
                            anchors.right: parent.right
                            text: timeTotal
                            color: "#8e8e93"
                            font.pixelSize: userConfig.bodyFontSize - 4
                            font.family: textFontFamily
                            font.weight: Font.Medium
                        }
                    }

                    Item {
                        width: parent.width
                        height: 36

                        Row {
                            anchors.centerIn: parent
                            spacing: 50

                            Item {
                                width: 28
                                height: 28
                                scale: prevArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    iconSize: 22
                                    source: Qt.resolvedUrl("../../resources/icons/step-backward.svg")
                                    color: prevArea.pressed ? "#888888" : "white"
                                }

                                MouseArea {
                                    id: prevArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: root.previousRequested()
                                }
                            }

                            Item {
                                width: 28
                                height: 28
                                scale: playArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    iconSize: 22
                                    source: isPlaying
                                        ? Qt.resolvedUrl("../../resources/icons/pause.svg")
                                        : Qt.resolvedUrl("../../resources/icons/play.svg")
                                    color: playArea.pressed ? "#888888" : "white"
                                }

                                MouseArea {
                                    id: playArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: togglePlayback()
                                }
                            }

                            Item {
                                width: 28
                                height: 28
                                scale: nextArea.pressed ? 0.8 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    iconSize: 22
                                    source: Qt.resolvedUrl("../../resources/icons/step-forward.svg")
                                    color: nextArea.pressed ? "#888888" : "white"
                                }

                                MouseArea {
                                    id: nextArea
                                    anchors.fill: parent
                                    anchors.margins: -15
                                    preventStealing: true
                                    onPressed: (mouse) => {
                                        controlPressed();
                                        mouse.accepted = true;
                                    }
                                    onClicked: if (activePlayer) activePlayer.next()
                                }
                            }
                        }
                }
            }
        }
    }
}
