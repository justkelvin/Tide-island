import QtQuick
import QtQuick.Controls
import Quickshell
import IslandBackend
import "../controlcenter"

Item {
    id: root

    readonly property var userConfig: UserConfig

    property var notificationService: null
    property var notificationModel: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property string heroFontFamily: userConfig.heroFontFamily

    readonly property real headerHeight: 28
    readonly property real listTopGap: 9
    readonly property real cardHeight: 92
    readonly property real cardRadius: 16
    readonly property real cardGap: 7
    readonly property int maxVisibleItems: 3
    readonly property int itemCount: notificationService
        ? notificationService.historyCount
        : (notificationModel ? notificationModel.count : 0)
    readonly property bool hasNotifications: itemCount > 0

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.headerHeight

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "↶"
                color: "#c5c5c8"
                font.pixelSize: 18
                font.family: root.textFontFamily
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notification History"
                textFormat: Text.PlainText
                color: "#f7f7f7"
                font.pixelSize: 15
                font.family: root.textFontFamily
                font.weight: Font.Bold
            }
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: root.listTopGap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        Text {
            visible: !root.hasNotifications
            anchors.centerIn: parent
            text: "No notifications"
            textFormat: Text.PlainText
            color: "#6f6f74"
            font.pixelSize: 11
            font.family: root.textFontFamily
        }

        ListView {
            id: listView
            anchors.fill: parent
            visible: root.hasNotifications
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.notificationModel
            currentIndex: -1
            spacing: root.cardGap

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { property: "scale"; to: 0.95; duration: 170 }
                }
            }

            removeDisplaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle { radius: 1.5; color: "#5b5b60" }
                background: Rectangle { color: "transparent" }
            }

            delegate: Item {
                id: delegateItem

                readonly property real entryId: Number(model.notificationId)
                readonly property bool isHistoryEntry: !!model.inHistory
                readonly property var actionIds: model.actionIdentifiers || []
                readonly property var actionLabels: model.actionTexts || []
                readonly property bool hasDefaultAction: !!model.hasDefaultAction
                readonly property bool hasActionIcons: !!model.hasActionIcons
                readonly property bool canAct: !!model.liveActionable
                readonly property string displayTitle: String(model.summary || "") !== ""
                    ? String(model.summary)
                    : (String(model.body || "") !== "" ? String(model.body).split("\n")[0] : "Notification")

                width: listView.width
                height: isHistoryEntry ? root.cardHeight : 0
                visible: isHistoryEntry
                clip: true

                MatteSurface {
                    anchors.fill: parent
                    radius: root.cardRadius
                    hovered: cardMouse.containsMouse
                    pressed: cardMouse.pressed
                }

                Image {
                    id: historyImage
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    source: String(model.visualSource || "")
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 80
                    sourceSize.height: 80
                }

                Text {
                    anchors.centerIn: historyImage
                    visible: historyImage.status !== Image.Ready
                    text: ""
                    color: "#d8d9dd"
                    font.pixelSize: 15
                    font.family: root.iconFontFamily
                }

                Column {
                    anchors.left: historyImage.right
                    anchors.leftMargin: 10
                    anchors.right: dismissButton.left
                    anchors.rightMargin: 7
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 1

                    Text {
                        width: parent.width
                        text: delegateItem.displayTitle
                        textFormat: Text.PlainText
                        color: "#f7f7f7"
                        font.pixelSize: 13
                        font.family: root.textFontFamily
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: String(model.summary || "") !== "" ? String(model.body || "") : ""
                        textFormat: Text.PlainText
                        visible: text !== ""
                        color: "#c8c8cc"
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: {
                            const parts = [];
                            if (String(model.appName || "") !== "")
                                parts.push(String(model.appName));
                            if (String(model.sourceName || "") !== "")
                                parts.push(String(model.sourceName));
                            return parts.join(" · ");
                        }
                        textFormat: Text.PlainText
                        visible: text !== ""
                        color: "#85878e"
                        font.pixelSize: 8
                        font.family: root.textFontFamily
                        elide: Text.ElideRight
                    }
                }

                Row {
                    z: 2
                    anchors.left: historyImage.right
                    anchors.leftMargin: 10
                    anchors.right: dismissButton.left
                    anchors.rightMargin: 7
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    height: 22
                    spacing: 5

                    Repeater {
                        model: delegateItem.actionLabels

                        Rectangle {
                            required property int index
                            required property var modelData

                            readonly property string actionId: index < delegateItem.actionIds.length
                                ? String(delegateItem.actionIds[index])
                                : ""
                            visible: delegateItem.canAct && actionId !== "default"
                            width: visible ? Math.min(110, Math.max(50, label.implicitWidth + 16)) : 0
                            height: 22
                            radius: 7
                            color: actionMouse.containsMouse ? "#30ffffff" : "#18ffffff"

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: String(parent.modelData || parent.actionId)
                                color: "#ececef"
                                font.pixelSize: 9
                                font.family: root.textFontFamily
                                elide: Text.ElideRight
                            }

                            Image {
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 11
                                height: 11
                                visible: delegateItem.hasActionIcons && parent.actionId !== ""
                                source: visible ? Quickshell.iconPath(parent.actionId) : ""
                                asynchronous: true
                                sourceSize.width: 22
                                sourceSize.height: 22
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.notificationService)
                                        root.notificationService.invokeAction(delegateItem.entryId, parent.actionId);
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: dismissButton
                    z: 2
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 6
                    anchors.rightMargin: 7
                    width: 24
                    height: 24
                    radius: 12
                    color: dismissMouse.containsMouse ? "#24ffffff" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "#c8c8cc"
                        font.pixelSize: 16
                        font.family: root.textFontFamily
                    }

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.notificationService)
                                root.notificationService.dismissNotification(delegateItem.entryId);
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    z: 1
                    anchors.left: parent.left
                    anchors.right: dismissButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    hoverEnabled: true
                    cursorShape: delegateItem.hasDefaultAction && delegateItem.canAct
                        ? Qt.PointingHandCursor
                        : Qt.ArrowCursor
                    propagateComposedEvents: true
                    onClicked: mouse => {
                        if (delegateItem.hasDefaultAction && delegateItem.canAct
                                && root.notificationService)
                            root.notificationService.invokeDefault(delegateItem.entryId);
                        else
                            mouse.accepted = false;
                    }
                }
            }
        }
    }
}
