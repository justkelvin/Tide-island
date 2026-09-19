import TideIsland 1.0
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root

    signal selectionChanged(var itemIds)

    readonly property string configKey: "dynamicIslandLeftSwipeItems"
    readonly property var defaultItems: ["cava", "battery"]
    readonly property string iconFontFamily: String(ConfigStore.value("iconFontFamily", "JetBrainsMono Nerd Font"))
    readonly property int selectedSpacing: 12
    readonly property var componentDefinitions: [
        { itemId: "time", displayName: "Time", previewText: "12:34", previewIcon: "", previewKind: "text" },
        { itemId: "date", displayName: "Date", previewText: "Fri, Jul 03", previewIcon: "", previewKind: "text" },
        { itemId: "battery", displayName: "Battery", previewText: "76%", previewIcon: "", previewKind: "battery" },
        { itemId: "volume", displayName: "Volume", previewText: "42%", previewIcon: "\u{F057E}", previewKind: "iconText" },
        { itemId: "brightness", displayName: "Brightness", previewText: "68%", previewIcon: "\u{F00E0}", previewKind: "iconText" },
        { itemId: "workspace", displayName: "Workspace", previewText: "Workspace 2", previewIcon: "", previewKind: "text" },
        { itemId: "cpu", displayName: "CPU", previewText: "38%", previewIcon: "\u{F035B}", previewKind: "iconText" },
        { itemId: "ram", displayName: "RAM", previewText: "61%", previewIcon: "\u{F061A}", previewKind: "iconText" },
        { itemId: "cava", displayName: "Cava", previewText: "", previewIcon: "", previewKind: "cava" }
    ]

    property bool dragActive: false
    property string dragItemId: ""
    property bool dragFromSelection: false
    property int dragSelectedIndex: -1
    property real dragX: 0
    property real dragY: 0
    property real dragPointerOffsetX: 0
    property real dragPointerOffsetY: 0
    property string dragZone: ""
    readonly property bool dragPreviewUsesIslandStyle: dragZone === "island" || dragFromSelection

    color: "transparent"
    radius: 0
    border.width: 0
    implicitHeight: selectorColumn.implicitHeight + 16

    ListModel {
        id: selectedModel
    }

    Component.onCompleted: loadFromConfig()

    function listValues(rawItems) {
        if (!rawItems) return [];
        if (Array.isArray(rawItems)) return rawItems;
        if (typeof rawItems === "string") return [rawItems];

        const length = Number(rawItems.length);
        if (!isFinite(length) || length < 0) return [];

        const resolved = [];
        for (let index = 0; index < Math.floor(length); index++)
            resolved.push(rawItems[index]);
        return resolved;
    }

    function normalizeItemId(rawId) {
        return String(rawId === undefined || rawId === null ? "" : rawId).trim().toLowerCase();
    }

    function definitionForId(itemId) {
        const normalizedId = normalizeItemId(itemId);
        for (let index = 0; index < componentDefinitions.length; index++) {
            if (componentDefinitions[index].itemId === normalizedId)
                return componentDefinitions[index];
        }
        return null;
    }

    function isSupported(itemId) {
        return definitionForId(itemId) !== null;
    }

    function previewText(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewText : "";
    }

    function previewIcon(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewIcon : "";
    }

    function previewKind(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.previewKind : "text";
    }

    function previewWidth(itemId, inIsland) {
        const isIsland = inIsland === true;
        switch (normalizeItemId(itemId)) {
        case "time": return isIsland ? 48 : 74;
        case "date": return isIsland ? 80 : 96;
        case "battery": return isIsland ? 42 : 102;
        case "volume": return isIsland ? 52 : 82;
        case "brightness": return isIsland ? 52 : 84;
        case "workspace": return isIsland ? 88 : 108;
        case "cpu": return isIsland ? 52 : 82;
        case "ram": return isIsland ? 52 : 82;
        case "cava": return isIsland ? 50 : 96;
        default: return isIsland ? 60 : 80;
        }
    }

    function displayName(itemId) {
        const definition = definitionForId(itemId);
        return definition ? definition.displayName : "";
    }

    function selectedIds() {
        const ids = [];
        for (let index = 0; index < selectedModel.count; index++)
            ids.push(selectedModel.get(index).itemId);
        return ids;
    }

    function containsSelected(itemId) {
        const normalizedId = normalizeItemId(itemId);
        for (let index = 0; index < selectedModel.count; index++) {
            if (selectedModel.get(index).itemId === normalizedId)
                return true;
        }
        return false;
    }

    function loadFromConfig() {
        const source = listValues(ConfigStore.value(configKey, defaultItems));
        const seen = {};
        selectedModel.clear();

        for (let index = 0; index < source.length; index++) {
            const itemId = normalizeItemId(source[index]);
            if (!isSupported(itemId) || seen[itemId]) continue;

            selectedModel.append({ itemId: itemId });
            seen[itemId] = true;
        }
    }

    function notifySelectionChanged() {
        const ids = selectedIds();
        ConfigStore.setValue(configKey, ids);
        ConfigStore.save();
        selectionChanged(ids);
    }

    function addItem(itemId, targetIndex) {
        const normalizedId = normalizeItemId(itemId);
        if (!isSupported(normalizedId) || containsSelected(normalizedId)) return;

        const insertIndex = Math.max(0, Math.min(selectedModel.count, targetIndex));
        selectedModel.insert(insertIndex, { itemId: normalizedId });
        notifySelectionChanged();
    }

    function moveItem(fromIndex, targetIndex) {
        if (fromIndex < 0 || fromIndex >= selectedModel.count) return;

        const boundedTarget = Math.max(0, Math.min(selectedModel.count, targetIndex));
        const nextIndex = fromIndex < boundedTarget ? boundedTarget - 1 : boundedTarget;
        if (fromIndex === nextIndex) return;

        selectedModel.move(fromIndex, nextIndex, 1);
        notifySelectionChanged();
    }

    function removeItem(index) {
        if (index < 0 || index >= selectedModel.count) return;

        selectedModel.remove(index, 1);
        notifySelectionChanged();
    }

    function containsRootPoint(item, rootX, rootY) {
        const point = root.mapToItem(item, rootX, rootY);
        return point.x >= 0 && point.x <= item.width && point.y >= 0 && point.y <= item.height;
    }

    function refreshDragZone(rootX, rootY) {
        if (containsRootPoint(paletteDropZone, rootX, rootY)) {
            dragZone = "palette";
        } else if (containsRootPoint(islandStage, rootX, rootY)) {
            dragZone = "island";
        } else {
            dragZone = "";
        }
    }

    function beginDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        dragItemId = sourceChip.itemId;
        dragFromSelection = sourceChip.fromSelection;
        dragSelectedIndex = sourceChip.selectedIndex;
        dragPointerOffsetX = mouseX;
        dragPointerOffsetY = mouseY;
        dragActive = true;
        updateDrag(sourceChip, mouseX, mouseY);
    }

    function updateDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        dragX = point.x - dragPointerOffsetX;
        dragY = point.y - dragPointerOffsetY;
        refreshDragZone(point.x, point.y);
    }

    function finishDrag(sourceChip, mouseX, mouseY) {
        const point = sourceChip.mapToItem(root, mouseX, mouseY);
        const wasFromSelection = dragFromSelection;
        const sourceIndex = dragSelectedIndex;
        const sourceId = dragItemId;

        if (containsRootPoint(paletteDropZone, point.x, point.y)) {
            if (wasFromSelection) removeItem(sourceIndex);
            clearDrag();
            return;
        }

        if (containsRootPoint(islandStage, point.x, point.y)) {
            const islandPoint = root.mapToItem(islandPreview, point.x, point.y);
            const targetIndex = targetIndexForIslandX(islandPoint.x, wasFromSelection ? sourceIndex : -1);
            if (wasFromSelection) moveItem(sourceIndex, targetIndex);
            else addItem(sourceId, targetIndex);
        }

        clearDrag();
    }

    function clearDrag() {
        dragActive = false;
        dragItemId = "";
        dragFromSelection = false;
        dragSelectedIndex = -1;
        dragZone = "";
    }

    function isDraggingSelection(index) {
        return dragActive && dragFromSelection && dragSelectedIndex === index;
    }

    function selectedContentWidth(excludedIndex) {
        let total = 0;
        let visibleCount = 0;
        for (let index = 0; index < selectedModel.count; index++) {
            if (index === excludedIndex) continue;
            total += previewWidth(selectedModel.get(index).itemId, true);
            visibleCount++;
        }
        if (visibleCount > 1) total += selectedSpacing * (visibleCount - 1);
        return total;
    }

    function targetIndexForIslandX(localX, excludedIndex) {
        const contentWidth = selectedContentWidth(excludedIndex);
        let cursorX = (islandPreview.width - contentWidth) / 2;

        for (let index = 0; index < selectedModel.count; index++) {
            if (index === excludedIndex) continue;
            const itemWidth = previewWidth(selectedModel.get(index).itemId, true);
            if (localX < cursorX + itemWidth / 2) return index;
            cursorX += itemWidth + selectedSpacing;
        }

        return selectedModel.count;
    }

    Column {
        id: selectorColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 16

        Column {
            width: parent.width
            spacing: 4

            Text {
                text: "Available Modules"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                text: "Drag modules into the Dynamic Island below to display them on swipe, or drag them back here to remove."
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.Wrap
                width: parent.width
            }
        }

        Item {
            id: paletteDropZone
            width: parent.width
            height: paletteFlow.implicitHeight + (root.dragActive && root.dragFromSelection ? 24 : 0)

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: Theme.radiusControl
                color: root.dragZone === "palette" ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : "transparent"
                border.width: 1
                border.color: root.dragZone === "palette" ? Theme.error : (root.dragActive && root.dragFromSelection ? Theme.outline : "transparent")
                visible: root.dragActive && root.dragFromSelection
                z: 0

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drop here to remove from Dynamic Island"
                    color: root.dragZone === "palette" ? Theme.error : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            Flow {
                id: paletteFlow
                width: parent.width
                spacing: 8
                z: 1

                Repeater {
                    model: root.componentDefinitions

                    PreviewChip {
                        itemId: modelData.itemId
                        fromSelection: false
                        selectedIndex: -1
                        paletteDisabled: root.containsSelected(modelData.itemId)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }

        Rectangle {
            id: islandStage
            width: parent.width
            height: 110
            radius: Theme.radiusControl
            color: Theme.darkMode ? "#0c0d12" : "#181922"
            border.width: 1
            border.color: Theme.outline
            clip: true

            Rectangle {
                id: islandPreview

                readonly property real wantedWidth: selectedModel.count > 0
                    ? selectedContentWidth(root.dragFromSelection ? root.dragSelectedIndex : -1) + 48
                    : 240

                anchors.centerIn: parent
                width: Math.min(parent.width - 32, Math.max(240, wantedWidth))
                height: 44
                radius: height / 2
                color: "#000000"
                border.width: 0
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: selectedModel.count === 0
                    text: "+ Drag modules here"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Row {
                    id: selectedRow
                    visible: selectedModel.count > 0
                    anchors.centerIn: parent
                    height: 36
                    spacing: root.selectedSpacing

                    Repeater {
                        model: selectedModel

                        Item {
                            id: selectedSlot
                            width: root.isDraggingSelection(index) ? 0 : selectedChip.width
                            height: selectedChip.height

                            Behavior on width {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            PreviewChip {
                                id: selectedChip
                                itemId: model.itemId
                                fromSelection: true
                                selectedIndex: index
                            }
                        }
                    }
                }
            }
        }
    }

    PreviewChip {
        id: dragPreview
        visible: root.dragActive
        itemId: root.dragItemId
        fromSelection: root.dragPreviewUsesIslandStyle
        floating: true
        interactive: false
        x: root.dragX
        y: root.dragY
        z: 10000
        opacity: 0.96
    }

    component PreviewChip: Rectangle {
        id: chip

        property string itemId: ""
        property bool fromSelection: false
        property bool paletteDisabled: false
        property bool floating: false
        property bool interactive: true
        property int selectedIndex: -1
        readonly property string chipKind: root.previewKind(itemId)
        readonly property string chipText: root.previewText(itemId)
        readonly property string chipIcon: root.previewIcon(itemId)
        readonly property string chipName: root.displayName(itemId)
        readonly property bool draggable: interactive && (fromSelection || !paletteDisabled)
        readonly property bool hiddenByDrag: root.dragActive
            && root.dragItemId === itemId
            && root.dragFromSelection === fromSelection
            && (!fromSelection || root.dragSelectedIndex === selectedIndex)

        readonly property bool inIsland: fromSelection || (floating && root.dragPreviewUsesIslandStyle)

        width: root.previewWidth(itemId, chip.inIsland)
        height: 34
        radius: chip.inIsland ? 17 : Theme.radiusControl
        color: {
            if (chip.inIsland) {
                return chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent";
            }
            if (paletteDisabled) {
                return Theme.surfaceElevated;
            }
            return chipMouse.containsMouse ? Theme.cardHover : Theme.surfaceElevated;
        }
        border.width: chip.inIsland ? 0 : 1
        border.color: {
            if (chip.inIsland) return "transparent";
            if (paletteDisabled) return "transparent";
            return chipMouse.containsMouse ? Theme.accent : Theme.outline;
        }
        opacity: hiddenByDrag ? 0 : (paletteDisabled ? 0.35 : 1.0)
        z: root.dragActive && hiddenByDrag ? 0 : 1

        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion } }

        Row {
            id: chipContent
            anchors.centerIn: parent
            spacing: 6

            BatteryPreview {
                visible: chip.chipKind === "battery"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: chip.chipKind === "battery" && !chip.inIsland
                anchors.verticalCenter: parent.verticalCenter
                text: "Battery"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            CavaPreview {
                visible: chip.chipKind === "cava"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: chip.chipKind === "cava" && !chip.inIsland
                anchors.verticalCenter: parent.verticalCenter
                text: "Cava"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Text {
                visible: chip.chipIcon !== "" && chip.chipKind !== "battery" && chip.chipKind !== "cava"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.chipIcon
                color: chip.inIsland ? "white" : Theme.accent
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            Text {
                visible: chip.chipKind !== "battery" && chip.chipKind !== "cava"
                anchors.verticalCenter: parent.verticalCenter
                text: chip.inIsland ? chip.chipText : chip.chipText
                color: chip.inIsland ? "white" : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: chip.inIsland ? Font.Bold : Font.Medium
                font.letterSpacing: chip.inIsland ? -0.15 : 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            enabled: chip.draggable
            hoverEnabled: true
            preventStealing: true
            cursorShape: chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor

            property real pressX: 0
            property real pressY: 0
            property bool dragStarted: false

            onPressed: function(mouse) {
                pressX = mouse.x;
                pressY = mouse.y;
                dragStarted = false;
                cursorShape = Qt.ClosedHandCursor;
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return;
                const dx = mouse.x - pressX;
                const dy = mouse.y - pressY;
                if (!dragStarted && Math.sqrt(dx * dx + dy * dy) >= 4) {
                    dragStarted = true;
                    root.beginDrag(chip, mouse.x, mouse.y);
                } else if (dragStarted) {
                    root.updateDrag(chip, mouse.x, mouse.y);
                }
            }

            onReleased: function(mouse) {
                cursorShape = chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor;
                if (dragStarted)
                    root.finishDrag(chip, mouse.x, mouse.y);
                dragStarted = false;
            }

            onCanceled: {
                cursorShape = chip.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor;
                dragStarted = false;
                root.clearDrag();
            }
        }
    }

    component BatteryPreview: Item {
        id: bat
        property int level: 76
        property color emptyColor: Qt.rgba(1, 1, 1, 0.56)
        property color fillColor: "white"

        width: 37
        height: 17

        Rectangle {
            id: batBody
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 3
            height: parent.height
            radius: 6
            color: bat.emptyColor
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(12, parent.width * (bat.level / 100.0))
                radius: 6
                color: bat.fillColor
            }

            Text {
                anchors.centerIn: parent
                text: String(bat.level)
                color: "black"
                font.pixelSize: 12
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            width: 2
            height: 5
            radius: 1
            color: bat.fillColor
            anchors.left: batBody.right
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component CavaPreview: Item {
        id: cavaPreview
        property color barColor: "white"
        readonly property var levels: [0.35, 0.8, 0.55, 0.95, 0.48, 0.7, 0.4]

        width: 44
        height: 16

        Row {
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: cavaPreview.levels

                Rectangle {
                    width: 3.5
                    height: Math.max(4, Math.round(cavaPreview.height * modelData))
                    radius: 1.75
                    anchors.verticalCenter: parent.verticalCenter
                    color: cavaPreview.barColor
                }
            }
        }
    }
}
