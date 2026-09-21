import QtQuick
import IslandBackend

Item {
    id: root

    property var windowRoot: null
    property var islandController: null
    property var capsule: null
    property var hoverExpandTimer: null
    property var hoverCollapseTimer: null

    readonly property bool sideSwipeInteractive: capsuleMouseArea.sideSwipeInteractive
    readonly property bool containsMouse: capsuleMouseArea.containsMouse
    property alias suppressNextClick: capsuleMouseArea.suppressNextClick

    anchors.fill: parent

    function triggerHoverExpand() {
        if (hoverCollapseTimer)
            hoverCollapseTimer.stop();
        if (hoverExpandTimer)
            hoverExpandTimer.restart();
    }

    function triggerHoverCollapse() {
        if (hoverCollapseTimer)
            hoverCollapseTimer.restart();
    }

    function suppressClick() {
        capsuleMouseArea.suppressNextClick = true;
        swipeSuppressReset.restart();
    }

    Timer {
        id: swipeSuppressReset
        interval: 180
        repeat: false
        onTriggered: capsuleMouseArea.suppressNextClick = false
    }

    MouseArea {
        id: capsuleMouseArea
        anchors.fill: parent
        z: -1
        enabled: twoFingerTouchArea.touchPoints.length < 2
        acceptedButtons: windowRoot ? windowRoot.dynamicIslandAcceptedButtons : (Qt.LeftButton | Qt.RightButton)
        preventStealing: true
        hoverEnabled: windowRoot ? (windowRoot.hoverExpandEnabled || windowRoot.autoHideEnabled) : false

        property real swipeStartX: 0
        property real swipeStartY: 0
        property real swipeStartProgress: 0
        property real swipeLastX: 0
        readonly property real sideSwipeVerticalTolerance: 24
        property bool swipeArmed: false
        property bool swipeMoved: false
        property bool sideSwipeInteractive: false
        property bool suppressNextClick: false

        onEntered: {
            if (windowRoot && windowRoot.autoHideEnabled) {
                windowRoot.autoHidePointerInside = true;
                windowRoot.showAutoHiddenIsland();
            }
            if (windowRoot && windowRoot.hoverExpandEnabled) {
                root.triggerHoverExpand();
            }
        }

        onExited: {
            if (windowRoot && windowRoot.autoHideEnabled) {
                windowRoot.autoHidePointerInside = false;
                windowRoot.scheduleAutoHide();
            }
            if (windowRoot && windowRoot.hoverExpandEnabled) {
                root.triggerHoverCollapse();
            }
        }

        onPressed: (mouse) => {
            if (!islandController || !capsule) return;
            const mappedPoint = capsuleMouseArea.mapToItem(islandController, mouse.x, mouse.y);
            swipeStartX = mappedPoint.x;
            swipeStartY = mappedPoint.y;
            islandController.cancelSideSwipeSettle();
            swipeArmed = mouse.button === Qt.LeftButton
                && islandController.canShowSideSwipe;
            swipeStartProgress = islandController.swipeTransitionProgress;
            swipeLastX = mappedPoint.x;
            swipeMoved = false;
            sideSwipeInteractive = swipeArmed;
            islandController.swipeTransitionProgress = swipeStartProgress;
        }

        onPositionChanged: (mouse) => {
            if (!pressed || !swipeArmed || suppressNextClick || twoFingerTouchArea.touchPoints.length >= 2) return;
            if (!islandController || !capsule) return;

            const mappedPoint = capsuleMouseArea.mapToItem(islandController, mouse.x, mouse.y);
            const deltaX = mappedPoint.x - swipeLastX;
            const deltaY = Math.abs(mappedPoint.y - swipeStartY);
            const adjustedDeltaX = deltaY < sideSwipeVerticalTolerance ? deltaX : 0;
            const nextProgress = islandController.advanceSideSwipeProgress(
                islandController.swipeTransitionProgress,
                adjustedDeltaX
            );

            swipeMoved = swipeMoved || Math.abs(nextProgress - swipeStartProgress) > 0.03 || deltaY > 6;
            swipeLastX = mappedPoint.x;
            islandController.swipeTransitionProgress = nextProgress;
            capsule.displayedWidth = capsule.sideSwipePreviewWidth;
        }

        onReleased: {
            if (!islandController || !capsule) return;

            if (swipeMoved) {
                suppressNextClick = true;
                swipeSuppressReset.restart();
            }
            let settleResult = {
                action: "",
                progress: islandController.sideSwipeRestProgressForProgress(swipeStartProgress),
                width: islandController.sideSwipeRestWidthForProgress(swipeStartProgress)
            };

            if (swipeArmed)
                settleResult = islandController.resolveSideSwipeSettle(
                    swipeStartProgress,
                    islandController.swipeTransitionProgress
                );

            sideSwipeInteractive = false;

            if (swipeArmed)
                islandController.beginSideSwipeSettle(settleResult.width);
            else
                capsule.displayedWidth = capsule.baseTargetWidth;

            if (swipeArmed) {
                switch (settleResult.action) {
                case "time":
                    islandController.showTimeCapsule();
                    break;
                case "custom":
                    islandController.showCustomCapsule();
                    break;
                case "lyrics":
                    islandController.showLyricsCapsule();
                    break;
                default:
                    islandController.swipeTransitionProgress = settleResult.progress;
                }
            } else {
                islandController.swipeTransitionProgress = settleResult.progress;
            }
            swipeArmed = false;
            swipeMoved = false;
        }

        onCanceled: {
            if (!islandController || !capsule) return;
            swipeArmed = false;
            swipeMoved = false;
            sideSwipeInteractive = false;
            suppressNextClick = false;
            swipeSuppressReset.stop();
            capsule.displayedWidth = capsule.baseTargetWidth;
            islandController.swipeTransitionProgress = islandController.swipeRestProgressForState();
        }

        onClicked: (mouse) => {
            if (!islandController) return;

            islandController.hoverExpandedActive = false;
            if (hoverExpandTimer) hoverExpandTimer.stop();
            if (hoverCollapseTimer) hoverCollapseTimer.stop();

            if (suppressNextClick) {
                swipeSuppressReset.stop();
                suppressNextClick = false;
                return;
            }

            if (mouse.button === UserConfig.mouseButton(UserConfig.dynamicIslandPrimaryButton)) {
                if (islandController.toggleNotificationExpansionIfNeeded()) {
                    return;
                }

                islandController.handleConfiguredClickAction(UserConfig.dynamicIslandPrimaryAction);
                return;
            }

            if (mouse.button === UserConfig.mouseButton(UserConfig.dynamicIslandSecondaryButton)) {
                const secondaryAction = UserConfig.dynamicIslandSecondaryAction;
                if (secondaryAction === "" || secondaryAction === "none") {
                    if (mouse.button === Qt.RightButton)
                        islandController.toggleSecondaryPanel();
                    return;
                }
                islandController.handleConfiguredClickAction(secondaryAction);
                return;
            }

            if (mouse.button === Qt.RightButton) {
                islandController.toggleSecondaryPanel();
            }
        }
    }

    MultiPointTouchArea {
        id: twoFingerTouchArea
        anchors.fill: parent
        z: 0
        mouseEnabled: false
        minimumTouchPoints: 2
        maximumTouchPoints: 2

        property real swipeStartX: 0
        property real swipeStartProgress: 0
        property bool swipeMoved: false

        onPressed: (touchPoints) => {
            if (!islandController) return;
            const centerPoint = islandController.mapFromItem(twoFingerTouchArea, 
                (touchPoints[0].x + touchPoints[1].x) / 2,
                (touchPoints[0].y + touchPoints[1].y) / 2);
            swipeStartX = centerPoint.x;
            swipeStartProgress = islandController.swipeTransitionProgress;
            swipeMoved = false;
            islandController.cancelSideSwipeSettle();
        }

        onUpdated: (touchPoints) => {
            if (!islandController || !capsule) return;
            const centerPoint = islandController.mapFromItem(twoFingerTouchArea, 
                (touchPoints[0].x + touchPoints[1].x) / 2,
                (touchPoints[0].y + touchPoints[1].y) / 2);
            
            const deltaX = centerPoint.x - swipeStartX;
            const nextProgress = islandController.advanceSideSwipeProgress(
                swipeStartProgress,
                deltaX
            );

            if (Math.abs(nextProgress - swipeStartProgress) > 0.03) {
                swipeMoved = true;
            }

            islandController.swipeTransitionProgress = nextProgress;
            capsule.displayedWidth = capsule.sideSwipePreviewWidth;
        }

        onReleased: {
            if (!islandController) return;

            if (swipeMoved) {
                const settleResult = islandController.resolveSideSwipeSettle(
                    swipeStartProgress,
                    islandController.swipeTransitionProgress
                );

                islandController.beginSideSwipeSettle(settleResult.width);

                switch (settleResult.action) {
                case "time":
                    islandController.showTimeCapsule();
                    break;
                case "custom":
                    islandController.showCustomCapsule();
                    break;
                case "lyrics":
                    islandController.showLyricsCapsule();
                    break;
                default:
                    islandController.swipeTransitionProgress = settleResult.progress;
                }
            } else {
                islandController.swipeTransitionProgress = islandController.sideSwipeRestProgressForProgress(swipeStartProgress);
            }
            swipeMoved = false;
        }
    }
}
