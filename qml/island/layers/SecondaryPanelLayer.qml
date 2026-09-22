import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend
import "TimeAgo.js" as TimeAgo

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal closeRequested()
    signal clearAllRequested()
    signal timerRequested()
    signal removeHistoryItemRequested(var notificationId)

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property bool timerActive: false
    property var history: []
    property string textFontFamily: userConfig.textFontFamily

    readonly property int historyCount: history ? history.length : 0
    readonly property string headerText: historyCount > 0 ? "Notifications (" + historyCount + ")" : "Notifications"

    // Local mirror of NotificationServer.history as a real ListModel.
    // QVariantList reassigns wholesale on every change (instant rebuild = blip),
    // while ListModel emits per-row signals so ListView can play remove/add/
    // displaced transitions for an Apple-style dismiss animation.
    ListModel {
        id: historyModel
    }

    function toElement(item) {
        const summary = item && item.summary ? String(item.summary) : "";
        const app = item && item.appName ? String(item.appName) : "";
        const rawBody = item && item.body ? String(item.body) : "";
        const title = summary !== "" ? summary : (app !== "" ? app : "Notification");
        const body = (rawBody !== "" && rawBody !== title) ? rawBody : "";
        const imageDataUrl = item && item.imageDataUrl ? String(item.imageDataUrl) : "";
        const imagePath = item && item.imagePath ? String(item.imagePath) : "";
        const appIcon = item && item.appIcon ? String(item.appIcon) : "";
        const resolved = item && item.resolvedIcon ? String(item.resolvedIcon) : "";
        // Bare names (e.g. notify-send puts the theme name in image-path)
        // are theme icons, not files — only path-like values become images.
        function asImageRef(value) {
            if (value === "") return "";
            if (value.indexOf("data:") === 0 || value.indexOf("://") >= 0) return value;
            if (value.indexOf("/") < 0) return "";
            return value.charAt(0) === "/" ? "file://" + value : value;
        }
        function asThemeName(value) {
            if (value === "") return "";
            if (value.indexOf("/") >= 0 || value.indexOf("://") >= 0 || value.indexOf("data:") === 0) return "";
            return value;
        }
        let iconImage = asImageRef(imageDataUrl);
        if (iconImage === "") iconImage = asImageRef(imagePath);
        if (iconImage === "") iconImage = asImageRef(appIcon);
        let iconName = asThemeName(resolved);
        if (iconName === "") iconName = asThemeName(appIcon);
        if (iconName === "") iconName = asThemeName(imagePath);
        // Resolve theme names to real files (IconImage does no theme lookup
        // in this Quickshell version); unresolvable names collapse the slot.
        if (iconImage === "" && iconName !== "")
            iconImage = NotificationServer.themeIconPath(iconName);
        return {
            nid: (item && item.id !== undefined) ? Number(item.id) : 0,
            title: title,
            body: body,
            createdMs: (item && item.createdMs !== undefined) ? Number(item.createdMs) : 0,
            iconImage: iconImage
        };
    }

    function syncHistory() {
        const source = root.history || [];
        let i = historyModel.count - 1;
        while (i >= 0) {
            const id = historyModel.get(i).nid;
            let found = false;
            for (let j = 0; j < source.length; ++j) {
                if (Number(source[j].id) === id) {
                    found = true;
                    break;
                }
            }
            if (!found)
                historyModel.remove(i);
            i -= 1;
        }
        for (let j = 0; j < source.length; ++j) {
            const hid = Number(source[j].id);
            if (j < historyModel.count && historyModel.get(j).nid === hid)
                continue;
            let at = -1;
            for (let k = j + 1; k < historyModel.count; ++k) {
                if (historyModel.get(k).nid === hid) {
                    at = k;
                    break;
                }
            }
            if (at >= 0)
                historyModel.move(at, j, 1);
            else
                historyModel.insert(j, toElement(source[j]));
        }
        while (historyModel.count > source.length)
            historyModel.remove(historyModel.count - 1);
    }

    onHistoryChanged: syncHistory()
    Component.onCompleted: syncHistory()

    anchors.fill: parent
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.showCondition && root.historyCount > 0
        onTriggered: historyList.refreshTimestamps()
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

        Column {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            spacing: 10

            Rectangle {
                width: parent.width
                height: 38
                radius: StyleTokens.radiusButton
                color: timerArea.pressed ? StyleTokens.moduleHover : StyleTokens.timerFill
                Accessible.role: Accessible.Button
                Accessible.name: timerLabel.text
                Accessible.onPressAction: root.timerRequested()

                Text {
                    id: timerLabel
                    anchors.centerIn: parent
                    text: root.timerActive ? "Show Timer" : "Set Timer"
                    color: StyleTokens.timerAccent
                    font.family: root.textFontFamily
                    font.pixelSize: userConfig.bodyFontSize - 2
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: timerArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: root.controlPressed()
                    onClicked: root.timerRequested()
                }
            }

            Item {
                width: parent.width
                height: 28

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.headerText
                    color: "white"
                    font.pixelSize: userConfig.bodyFontSize
                    font.family: root.textFontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.15
                    elide: Text.ElideRight
                    width: parent.width - pillButton.width - 12
                }

                Rectangle {
                    id: pillButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 92
                    height: 26
                    radius: 13
                    color: pillArea.pressed ? "#555558" : "#3a3a3c"
                    opacity: root.historyCount > 0 ? 1 : 0.4

                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Easing.InOutQuad }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All"
                        color: "#f4f5f7"
                        font.pixelSize: userConfig.bodyFontSize - 4
                        font.family: root.textFontFamily
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: pillArea
                        anchors.fill: parent
                        anchors.margins: -8
                        preventStealing: true
                        enabled: root.historyCount > 0
                        onPressed: (mouse) => {
                            root.controlPressed();
                            mouse.accepted = true;
                        }
                        onClicked: root.clearAllRequested()
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 86

                Text {
                    anchors.centerIn: parent
                    visible: historyModel.count === 0
                    text: "No Recent Notifications"
                    color: "#8e8e93"
                    font.pixelSize: userConfig.bodyFontSize - 2
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                }

                ListView {
                    id: historyList
                    anchors.fill: parent
                    visible: historyModel.count > 0
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: historyModel

                    // Apple-style dismiss: exiting card slides right + fades
                    // while siblings glide up to fill the gap.
                    remove: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; to: historyList.width; duration: 300; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
                        }
                    }
                    displaced: Transition {
                        NumberAnimation { properties: "x,y"; duration: 340; easing.type: Easing.OutQuint }
                    }
                    add: Transition {
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.InOutQuad }
                            NumberAnimation { property: "y"; from: -16; duration: 260; easing.type: Easing.OutCubic }
                        }
                    }
                    move: Transition {
                        NumberAnimation { properties: "x,y"; duration: 340; easing.type: Easing.OutQuint }
                    }

                    property int timestampRevision: 0
                    function refreshTimestamps() {
                        timestampRevision += 1;
                    }

                    delegate: Item {
                        width: historyList.width
                        height: model.body !== "" ? 60 : 56

                        readonly property int entryId: model.nid
                        readonly property string agoText: {
                            historyList.timestampRevision;
                            return TimeAgo.timeAgo(model.createdMs);
                        }

                        Rectangle {
                            id: card
                            x: 8
                            y: 8
                            width: parent.width - 8
                            height: parent.height - 8
                            radius: 12
                            color: Qt.rgba(255, 255, 255, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                anchors.leftMargin: 14
                                anchors.rightMargin: 10
                                spacing: 10

                                // Leading app-icon tile, vertically centered.
                                Item {
                                    id: iconSlot
                                    width: hasIcon ? 32 : 0
                                    height: 32
                                    visible: hasIcon
                                    anchors.verticalCenter: parent.verticalCenter

                                    readonly property bool hasIcon: model.iconImage !== ""

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: Qt.rgba(255, 255, 255, 0.08)
                                    }

                                    // Mask the content itself so image pixels
                                    // follow the rounded tile instead of sitting
                                    // sharp-cornered on top of it.
                                    Item {
                                        id: iconContent
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: iconContent.width
                                                height: iconContent.height
                                                radius: 6
                                            }
                                        }

                                        Image {
                                            anchors.fill: parent
                                            source: model.iconImage
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - (iconSlot.visible ? iconSlot.width + parent.spacing : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Row {
                                        width: parent.width
                                        spacing: 8

                                        Text {
                                            text: model.title
                                            color: "white"
                                            font.pixelSize: userConfig.bodyFontSize - 2
                                            font.family: root.textFontFamily
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: -0.15
                                            elide: Text.ElideRight
                                            width: Math.max(0, parent.width - (agoLabel.visible ? agoLabel.contentWidth + parent.spacing : 0))
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            id: agoLabel
                                            text: agoText
                                            visible: agoText !== ""
                                            color: "#8e8e93"
                                            font.pixelSize: userConfig.bodyFontSize - 5
                                            font.family: root.textFontFamily
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        visible: model.body !== ""
                                        text: model.body
                                        color: "#c7c7cc"
                                        font.pixelSize: userConfig.bodyFontSize - 3
                                        font.family: root.textFontFamily
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: parent.width
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: closeBadge
                            x: 0
                            y: 0
                            width: 18
                            height: 18
                            radius: 9
                            color: closeArea.pressed ? "#555558" : "#3a3a3c"
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.10)

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeArea.pressed ? "white" : "#c7c7cc"
                                font.pixelSize: 9
                                font.family: root.textFontFamily
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                anchors.margins: -6
                                preventStealing: true
                                onPressed: (mouse) => {
                                    root.controlPressed();
                                    mouse.accepted = true;
                                }
                                onClicked: root.removeHistoryItemRequested(entryId)
                            }
                        }
                    }
                }
            }
        }
    }
}
