import QtQuick
import Qt5Compat.GraphicalEffects
import IslandBackend
import "../../components"
import "TimeAgo.js" as TimeAgo

Item {
    id: root

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string iconSource: Qt.resolvedUrl("../../resources/icons/notification.svg")
    property string iconImage: ""
    readonly property string effectiveIconImage: root.iconImage !== "" ? root.iconImage : root.imageDataUrl
    readonly property bool hasFullColorIcon: root.effectiveIconImage !== ""
    property string iconText: ""
    property bool expanded: false
    property int notificationId: 0
    property var actions: []
    property int urgency: 1
    property int progress: -1
    property string imageDataUrl: ""
    property double createdMs: 0
    property int toggleButton: Qt.LeftButton
    property var configSource: null
    readonly property var activeConfig: configSource || userConfig
    property string iconFontFamily: activeConfig.iconFontFamily
    property string textFontFamily: activeConfig.textFontFamily
    property string heroFontFamily: activeConfig.heroFontFamily

    signal expansionToggleRequested()
    signal backgroundClicked()
    signal closeRequested()
    signal controlPressed()
    signal actionClicked(string actionKey)

    // Flat D-Bus pairs [key, label, ...] minus the "default" action, which
    // belongs to the card background instead of a pill.
    readonly property var actionPairs: {
        const src = root.actions || [];
        const out = [];
        for (let i = 0; i + 1 < src.length; i += 2) {
            if (String(src[i]) === "default")
                continue;
            out.push({ key: String(src[i]), label: String(src[i + 1]) });
        }
        return out;
    }
    readonly property bool hasDefaultAction: {
        const src = root.actions || [];
        for (let i = 0; i + 1 < src.length; i += 2) {
            if (String(src[i]) === "default")
                return true;
        }
        return false;
    }

    function actionIconSource(key, label) {
        const s = (String(key || "") + " " + String(label || "")).toLowerCase();
        if (s.indexOf("reply") >= 0 || s.indexOf("respond") >= 0
                || s.indexOf("message") >= 0 || s.indexOf("chat") >= 0)
            return Qt.resolvedUrl("../../resources/icons/reply.svg");
        if (s.indexOf("read") >= 0 || s.indexOf("done") >= 0
                || s.indexOf("accept") >= 0 || s.indexOf("yes") >= 0
                || s.indexOf(" ok") >= 0 || s === "ok")
            return Qt.resolvedUrl("../../resources/icons/read.svg");
        if (s.indexOf("dismiss") >= 0 || s.indexOf("cancel") >= 0
                || s.indexOf("decline") >= 0 || s.indexOf("delete") >= 0
                || s.indexOf("close") >= 0 || s.indexOf("remove") >= 0)
            return Qt.resolvedUrl("../../resources/icons/cancel.svg");
        if (s.indexOf("open") >= 0 || s.indexOf("view") >= 0
                || s.indexOf("browser") >= 0 || s.indexOf("link") >= 0
                || s.indexOf("show") >= 0)
            return Qt.resolvedUrl("../../resources/icons/up-open.svg");
        if (s.indexOf("copy") >= 0 || s.indexOf("clipboard") >= 0)
            return Qt.resolvedUrl("../../resources/icons/copy.svg");
        return "";
    }

    readonly property string contentText: {
        if (summary !== "" && body !== "" && body !== summary) return summary + "  " + body;
        if (summary !== "") return summary;
        if (body !== "") return body;
        return "New notification";
    }
    readonly property real minimumWidth: 272
    readonly property real compactMaximumWidth: 400
    readonly property real maximumWidth: expanded ? actionCardWidth : compactMaximumWidth
    readonly property real iconSlotWidth: 32
    readonly property real contentSpacing: 13
    readonly property real horizontalPadding: 16
    readonly property real compactVerticalPadding: 7
    readonly property real compactMaximumContentHeight: 68 - compactVerticalPadding * 2
    readonly property real textBlockWidthAtMaximum: compactMaximumWidth - horizontalPadding * 2
        - iconSlotWidth - contentSpacing
    readonly property real availableWidth: Math.max(0, width - horizontalPadding * 2
        - iconSlotWidth - contentSpacing)
    readonly property bool prefersWrappedContent: contentMetrics.advanceWidth > textBlockWidthAtMaximum
    readonly property bool hasOverflowContent: compactContentProbe.lineCount > 2
        || contentMetrics.advanceWidth > textBlockWidthAtMaximum * 2
        || (contentMetrics.advanceWidth > textBlockWidthAtMaximum && compactContentProbe.lineCount <= 1)
    readonly property real compactPreferredWidth: prefersWrappedContent
        ? maximumWidth
        : Math.max(minimumWidth, Math.min(maximumWidth, contentMetrics.advanceWidth + iconSlotWidth
            + contentSpacing + horizontalPadding * 2))
    readonly property real compactPreferredHeight: prefersWrappedContent ? compactMaximumContentHeight + compactVerticalPadding * 2 : 56

    // Expanded action card geometry (matches StateMachine/Capsule math).
    readonly property real actionCardWidth: 440
    readonly property real actionHeaderHeight: 24
    readonly property real actionIconSize: 20
    readonly property real actionPillHeight: 30
    readonly property real actionTextWidth: actionCardWidth - horizontalPadding * 2
        - actionIconSize - contentSpacing
    readonly property real actionMaxBodyHeight: actionPairs.length > 0 ? 44 : 86
    readonly property real actionTextHeight: 20 + (body !== "" ? 4 + Math.min(actionBodyProbe.implicitHeight, actionMaxBodyHeight) : 0)
    readonly property real actionCardHeight: Math.max(96, Math.min(170,
        13 + actionHeaderHeight + 10 + actionTextHeight + (actionPairs.length > 0 ? 12 + actionPillHeight : 0) + 13))

    readonly property real preferredWidth: expanded ? actionCardWidth : compactPreferredWidth
    readonly property real preferredHeight: expanded ? actionCardHeight : compactPreferredHeight

    anchors.fill: parent
    anchors.margins: 0
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 280 : 140
            easing.type: Easing.InOutQuad
        }
    }

    TextMetrics {
        id: contentMetrics
        font.family: textFontFamily
        font.pixelSize: userConfig.bodyFontSize
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        text: contentText
    }

    Text {
        id: compactContentProbe
        x: -10000
        y: -10000
        height: 0
        opacity: 0
        width: textBlockWidthAtMaximum
        text: contentText
        font.pixelSize: userConfig.bodyFontSize
        font.family: textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        wrapMode: Text.WordWrap
        lineHeight: 0.95
    }

    Text {
        id: actionBodyProbe
        x: -10000
        y: -10000
        height: 0
        opacity: 0
        width: actionTextWidth
        text: body
        font.pixelSize: userConfig.bodyFontSize - 3
        font.family: textFontFamily
        wrapMode: Text.WordWrap
    }

    // ---------- Compact banner ----------
    Row {
        id: compactRow
        visible: !root.expanded
        anchors.fill: parent
        anchors.leftMargin: horizontalPadding
        anchors.rightMargin: horizontalPadding
        anchors.topMargin: compactVerticalPadding
        anchors.bottomMargin: compactVerticalPadding
        spacing: contentSpacing
        anchors.verticalCenter: parent.verticalCenter

        // Tier 1-2: full-color app icon (file/data image or theme name),
        // masked to a rounded squircle so photo corners never poke out.
        Item {
            id: fullColorIconSlot
            visible: root.hasFullColorIcon
            width: iconSlotWidth
            height: iconSlotWidth
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: fullColorIconSlot.width
                    height: fullColorIconSlot.height
                    radius: 8
                }
            }

            Image {
                anchors.fill: parent
                source: root.effectiveIconImage
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
        }

        SvgIcon {
            id: notificationSvgIcon
            visible: root.iconSource !== "" && !fullColorIconSlot.visible
            width: iconSlotWidth
            height: iconSlotWidth
            iconSize: iconSlotWidth
            source: root.iconSource
            color: "#f4f5f7"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: !notificationSvgIcon.visible && !fullColorIconSlot.visible
            width: iconSlotWidth
            anchors.verticalCenter: parent.verticalCenter
            text: iconText
            color: "#f4f5f7"
            font.pixelSize: userConfig.iconFontSize
            font.family: iconFontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            width: parent.width - iconSlotWidth - contentSpacing
            height: parent.height

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: contentText
                color: "white"
                font.pixelSize: userConfig.bodyFontSize
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                width: parent.width
                wrapMode: prefersWrappedContent ? Text.WordWrap : Text.NoWrap
                maximumLineCount: prefersWrappedContent ? 2 : 1
                elide: Text.ElideRight
                lineHeight: 0.95
            }
        }

    }

    // ---------- Expanded action card ----------
    Item {
        id: expandedRoot
        visible: root.expanded
        anchors.fill: parent

        Row {
            id: expandedHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 13
            anchors.leftMargin: horizontalPadding
            anchors.rightMargin: horizontalPadding
            height: actionHeaderHeight
            spacing: 10

            Item {
                id: expandedIconSlot
                width: actionIconSize
                height: actionIconSize
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasFullColorIcon || root.iconSource !== ""
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: expandedIconSlot.width
                        height: expandedIconSlot.height
                        radius: 5
                    }
                }

                Image {
                    anchors.fill: parent
                    visible: root.hasFullColorIcon
                    source: root.effectiveIconImage
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }

                SvgIcon {
                    anchors.fill: parent
                    visible: !root.hasFullColorIcon && root.iconSource !== ""
                    iconSize: actionIconSize
                    source: root.iconSource
                    color: "#f4f5f7"
                }
            }

            Text {
                text: root.appName !== "" ? root.appName : "Notification"
                color: "white"
                font.pixelSize: userConfig.bodyFontSize - 2
                font.family: textFontFamily
                font.weight: Font.DemiBold
                font.letterSpacing: -0.15
                elide: Text.ElideRight
                width: Math.max(0, parent.width - expandedIconSlot.width - parent.spacing
                    - closeBadge.width - parent.spacing
                    - (agoLabel.visible ? agoLabel.contentWidth + parent.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: agoLabel
                text: TimeAgo.timeAgo(root.createdMs)
                visible: text !== ""
                color: "#8e8e93"
                font.pixelSize: userConfig.bodyFontSize - 5
                font.family: textFontFamily
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: closeBadge
                width: 18
                height: 18
                radius: 9
                color: closeArea.pressed ? "#555558" : "#3a3a3c"
                border.width: 1
                border.color: Qt.rgba(255, 255, 255, 0.10)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeArea.pressed ? "white" : "#c7c7cc"
                    font.pixelSize: 9
                    font.family: textFontFamily
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
                    onClicked: root.closeRequested()
                }
            }
        }

        Flickable {
            id: expandedTextFlick
            anchors.top: expandedHeader.bottom
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: horizontalPadding
            anchors.rightMargin: horizontalPadding
            anchors.bottom: actionPairs.length > 0 ? actionFlick.top : parent.bottom
            anchors.bottomMargin: actionPairs.length > 0 ? 12 : 13
            clip: true
            contentWidth: width
            contentHeight: expandedTextColumn.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: expandedTextColumn
                width: parent.width
                spacing: 4

                Text {
                    text: root.summary !== "" ? root.summary : contentText
                    color: "white"
                    font.pixelSize: userConfig.bodyFontSize - 2
                    font.family: textFontFamily
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.15
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    visible: root.body !== ""
                    text: root.body
                    color: "#c7c7cc"
                    font.pixelSize: userConfig.bodyFontSize - 3
                    font.family: textFontFamily
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }
        }

        Flickable {
            id: actionFlick
            readonly property int visibleActionSlots: Math.min(3, root.actionPairs.length)
            readonly property real equalPillWidth: visibleActionSlots > 0
                ? (width - actionRow.spacing * (visibleActionSlots - 1)) / visibleActionSlots
                : 0
            visible: root.actionPairs.length > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: horizontalPadding
            anchors.rightMargin: horizontalPadding
            anchors.bottomMargin: 13
            height: actionPillHeight
            clip: true
            contentWidth: actionRow.implicitWidth
            contentHeight: actionPillHeight
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Row {
                id: actionRow
                height: parent.height
                spacing: 10

                Repeater {
                    model: root.actionPairs

                    delegate: Rectangle {
                        readonly property bool isPrimary: index === 0
                        readonly property url actionIcon: root.actionIconSource(modelData.key, modelData.label)
                        width: actionFlick.equalPillWidth
                        height: actionPillHeight
                        radius: actionPillHeight / 2
                        color: pillMouse.pressed ? (isPrimary ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.16))
                            : pillMouse.containsMouse ? (isPrimary ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.15))
                            : (isPrimary ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09))
                        border.width: 1
                        border.color: isPrimary ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                        scale: pillMouse.pressed ? 0.96 : (pillMouse.containsMouse ? 1.03 : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: pillMouse.pressed ? 60 : 100; easing.type: Easing.InOutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        Row {
                            id: pillContent
                            anchors.centerIn: parent
                            spacing: 6

                            SvgIcon {
                                visible: actionIcon.toString() !== ""
                                width: visible ? 12 : 0
                                height: 12
                                iconSize: 12
                                source: actionIcon
                                color: "#f4f5f7"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.label
                                color: "#f4f5f7"
                                font.pixelSize: 12
                                font.family: textFontFamily
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: Math.max(0, actionFlick.equalPillWidth - 28
                                    - (actionIcon.toString() !== "" ? 18 : 0))
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: pillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: (mouse) => {
                                root.controlPressed();
                                mouse.accepted = true;
                            }
                            onClicked: root.actionClicked(modelData.key)
                        }
                    }
                }
            }
        }
    }

    TapHandler {
        acceptedButtons: root.toggleButton
        onTapped: {
            if (root.expanded)
                root.backgroundClicked();
            else
                root.expansionToggleRequested();
        }
    }
}
