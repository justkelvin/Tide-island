import QtQuick
import QtQuick.Controls
import Quickshell
import IslandBackend
import "../notifications/NotificationLogic.js" as NotificationLogic

Item {
    id: root

    readonly property var userConfig: UserConfig

    property var notificationEntry: null
    property var notificationService: null
    property bool showCondition: false
    property bool expanded: false
    property int toggleButton: Qt.LeftButton
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconText: ""
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string heroFontFamily: activeConfig.heroFontFamily
    property bool replyEditorVisible: false

    signal expansionToggleRequested()
    signal dismissRequested()

    readonly property real notificationId: notificationEntry
        ? Number(notificationEntry.notificationId)
        : 0
    readonly property string appName: notificationEntry && notificationEntry.appName
        ? String(notificationEntry.appName)
        : "Notification"
    readonly property string summary: notificationEntry && notificationEntry.summary
        ? String(notificationEntry.summary)
        : ""
    readonly property string body: notificationEntry && notificationEntry.body
        ? String(notificationEntry.body)
        : ""
    readonly property string sourceName: notificationEntry && notificationEntry.sourceName
        ? String(notificationEntry.sourceName)
        : ""
    readonly property var presentation: NotificationLogic.presentationText(
        summary,
        body,
        "New notification"
    )
    readonly property string titleText: presentation.title
    readonly property string bodyText: presentation.body
    readonly property var actionIdentifiers: notificationEntry
        && notificationEntry.actionIdentifiers
        ? notificationEntry.actionIdentifiers
        : []
    readonly property var actionTexts: notificationEntry && notificationEntry.actionTexts
        ? notificationEntry.actionTexts
        : []
    readonly property bool hasSecondaryActions: {
        for (let index = 0; index < actionIdentifiers.length; ++index) {
            if (String(actionIdentifiers[index]) !== "default")
                return true;
        }
        return false;
    }
    readonly property bool hasInlineReply: notificationEntry
        ? !!notificationEntry.hasInlineReply
        : false
    readonly property bool hasOverflowContent: bodyProbe.truncated
        || body.indexOf("\n") >= 0
        || hasSecondaryActions
        || hasInlineReply
    readonly property bool interactionActive: replyEditorVisible && replyField.activeFocus
    readonly property real minimumWidth: 340
    readonly property real compactMaximumWidth: 460
    readonly property real expandedMaximumWidth: 540
    readonly property real maximumWidth: expanded ? expandedMaximumWidth : compactMaximumWidth
    readonly property real preferredWidth: expanded ? expandedMaximumWidth : compactMaximumWidth
    readonly property real preferredHeight: {
        let height = 78;
        if (hasSecondaryActions)
            height += 34;
        if (hasInlineReply)
            height += replyEditorVisible ? 42 : 28;
        if (expanded && hasOverflowContent)
            height += Math.min(116, Math.max(30, expandedBody.implicitHeight - 30));
        return Math.min(280, height);
    }

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    onNotificationIdChanged: replyEditorVisible = false

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 240 : 120
            easing.type: Easing.InOutQuad
        }
    }

    Text {
        id: bodyProbe
        visible: false
        width: 330
        text: root.bodyText
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: 2
        font.pixelSize: Math.max(11, root.activeConfig.bodyFontSize - 3)
        font.family: root.textFontFamily
    }

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.right: dismissButton.left
        anchors.top: parent.top
        anchors.bottom: actionsColumn.top
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        anchors.topMargin: 8
        spacing: 10

        Rectangle {
            width: 42
            height: 42
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: root.notificationEntry && root.notificationEntry.urgencyName === "critical"
                ? "#36ff5b57"
                : "#16ffffff"
            clip: true

            Image {
                id: notificationImage
                anchors.fill: parent
                anchors.margins: 3
                source: root.notificationEntry ? String(root.notificationEntry.visualSource || "") : ""
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 96
                sourceSize.height: 96
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: notificationImage.status !== Image.Ready
                text: ""
                color: "#f4f5f7"
                font.pixelSize: root.activeConfig.iconFontSize
                font.family: root.iconFontFamily
            }
        }

        Item {
            width: Math.max(0, contentRow.width - 52)
            height: contentRow.height

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: root.titleText
                    textFormat: Text.PlainText
                    color: "white"
                    font.pixelSize: Math.max(12, root.activeConfig.bodyFontSize - 1)
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Item {
                    width: parent.width
                    height: root.bodyText === "" ? 0
                        : (root.expanded
                            ? Math.min(110, expandedBody.implicitHeight)
                            : Math.min(32, compactBody.implicitHeight))
                    visible: height > 0

                    Text {
                        id: compactBody
                        anchors.fill: parent
                        visible: !root.expanded
                        text: root.bodyText
                        textFormat: Text.PlainText
                        color: "#d7d8dc"
                        font.pixelSize: Math.max(10, root.activeConfig.bodyFontSize - 3)
                        font.family: root.textFontFamily
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        lineHeight: 1.05
                    }

                    Flickable {
                        id: bodyFlickable
                        anchors.fill: parent
                        visible: root.expanded
                        clip: true
                        contentWidth: width
                        contentHeight: expandedBody.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

                        Text {
                            id: expandedBody
                            width: bodyFlickable.width
                            text: root.bodyText
                            textFormat: Text.PlainText
                            color: "#d7d8dc"
                            font.pixelSize: Math.max(10, root.activeConfig.bodyFontSize - 3)
                            font.family: root.textFontFamily
                            wrapMode: Text.Wrap
                            lineHeight: 1.05
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: {
                        const parts = [];
                        if (root.appName !== "" && root.appName !== "Notification")
                            parts.push(root.appName);
                        if (root.sourceName !== "")
                            parts.push(root.sourceName);
                        return parts.join(" · ");
                    }
                    textFormat: Text.PlainText
                    visible: text !== ""
                    color: "#9699a2"
                    font.pixelSize: 9
                    font.family: root.textFontFamily
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.notificationEntry && root.notificationEntry.hasDefaultAction
                            && root.notificationService) {
                        root.notificationService.invokeDefault(root.notificationId);
                    } else if (root.hasOverflowContent) {
                        root.expansionToggleRequested();
                    }
                }
            }
        }
    }

    Rectangle {
        id: dismissButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 7
        anchors.rightMargin: 8
        width: 24
        height: 24
        radius: 12
        color: dismissMouse.containsMouse ? "#22ffffff" : "transparent"

        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#c8c9cd"
            font.pixelSize: 17
            font.family: root.textFontFamily
        }

        MouseArea {
            id: dismissMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissRequested()
        }
    }

    Column {
        id: actionsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 7
        spacing: 5

        Row {
            width: parent.width
            height: root.hasSecondaryActions ? 28 : 0
            visible: root.hasSecondaryActions
            spacing: 6

            Repeater {
                model: root.actionTexts

                Rectangle {
                    required property int index
                    required property var modelData

                    readonly property string identifier: index < root.actionIdentifiers.length
                        ? String(root.actionIdentifiers[index])
                        : ""
                    visible: identifier !== "default"
                    width: visible ? Math.min(150, Math.max(62, actionLabel.implicitWidth + 22)) : 0
                    height: 28
                    radius: 9
                    color: actionMouse.pressed ? "#35ffffff"
                        : (actionMouse.containsMouse ? "#28ffffff" : "#18ffffff")

                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: String(parent.modelData || parent.identifier)
                        textFormat: Text.PlainText
                        color: "#f2f2f4"
                        font.pixelSize: 10
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        visible: root.notificationEntry
                            && root.notificationEntry.hasActionIcons
                            && parent.identifier !== ""
                        source: visible ? Quickshell.iconPath(parent.identifier) : ""
                        asynchronous: true
                        sourceSize.width: 24
                        sourceSize.height: 24
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.notificationService)
                                root.notificationService.invokeAction(root.notificationId, parent.identifier);
                        }
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: root.hasInlineReply ? (root.replyEditorVisible ? 36 : 24) : 0
            visible: root.hasInlineReply
            spacing: 6

            Rectangle {
                visible: !root.replyEditorVisible
                width: 72
                height: 24
                radius: 8
                color: replyOpenMouse.containsMouse ? "#28ffffff" : "#18ffffff"

                Text {
                    anchors.centerIn: parent
                    text: "Reply"
                    color: "white"
                    font.pixelSize: 10
                    font.family: root.textFontFamily
                }

                MouseArea {
                    id: replyOpenMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.replyEditorVisible = true;
                        replyField.forceActiveFocus();
                    }
                }
            }

            TextField {
                id: replyField
                visible: root.replyEditorVisible
                width: visible ? parent.width - sendButton.width - parent.spacing : 0
                height: 36
                placeholderText: root.notificationEntry
                    ? String(root.notificationEntry.inlineReplyPlaceholder || "Reply…")
                    : "Reply…"
                color: "white"
                font.pixelSize: 11
                font.family: root.textFontFamily
                selectByMouse: true
                background: Rectangle {
                    radius: 9
                    color: "#20ffffff"
                    border.color: replyField.activeFocus ? "#55ffffff" : "#20ffffff"
                }
                Keys.onEscapePressed: event => {
                    root.replyEditorVisible = false;
                    event.accepted = true;
                }
                onAccepted: sendButton.send()
            }

            Rectangle {
                id: sendButton
                visible: root.replyEditorVisible
                width: visible ? 54 : 0
                height: 36
                radius: 9
                color: sendMouse.containsMouse ? "#3d7cff" : "#3267d6"

                function send() {
                    if (root.notificationService
                            && root.notificationService.sendInlineReply(root.notificationId, replyField.text))
                        root.replyEditorVisible = false;
                }

                Text {
                    anchors.centerIn: parent
                    text: "Send"
                    color: "white"
                    font.pixelSize: 10
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: sendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sendButton.send()
                }
            }
        }
    }
}
