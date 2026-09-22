import QtQuick
import QtTest
import "../../qml/island"
import "../../qml/island/layers"

Item {
    width: 500
    height: 220

    Countdown { id: countdown }
    QtObject {
        id: controller
        property int starts: 0
        function startCountdown() { starts++; countdown.start(); }
        function toggleCountdownPause() { countdown.togglePause(); }
        function smartRestoreState() {}
    }
    QtObject {
        id: mockWindow
        property bool autoHideEnabled: false
        property int dynamicIslandAcceptedButtons: Qt.LeftButton | Qt.RightButton
    }
    Timer { id: hoverExpand; interval: 350 }
    Timer { id: hoverCollapse; interval: 250 }
    CapsuleGestureArea {
        id: gestures
        width: view.width
        height: view.height
        anchors.fill: undefined
        windowRoot: mockWindow
        hoverExpandTimer: hoverExpand
        hoverCollapseTimer: hoverCollapse
    }
    TimerLayer {
        id: view
        width: 410
        height: editing ? 180 : 62
        countdown: countdown
        controller: controller
    }
    SignalSpy { id: finishedSpy; target: countdown; signalName: "finished" }

    TestCase {
        name: "Countdown"
        when: windowShown

        function init() {
            countdown.stop();
            countdown.select(120);
            countdown.minuteMode = false;
            controller.starts = 0;
            view.editing = true;
            view.finished = false;
            finishedSpy.clear();
            wait(300);
        }

        function test_durationBoundsAndFormatting() {
            countdown.select(0);
            compare(countdown.selectedSeconds, 1);
            countdown.select(100000);
            compare(countdown.selectedSeconds, 86400);
            countdown.select(NaN);
            compare(countdown.selectedSeconds, 86400);
            compare(countdown.formatTime(9), "0:09");
            compare(countdown.formatTime(120), "2:00");
            compare(countdown.formatTime(3600), "60:00");
        }

        function test_pauseResumeAndCancel() {
            countdown.select(3);
            countdown.start();
            wait(170);
            countdown.togglePause();
            verify(countdown.paused);
            const frozen = countdown.remainingMs;
            wait(200);
            compare(countdown.remainingMs, frozen);
            countdown.togglePause();
            verify(!countdown.paused);
            wait(100);
            verify(countdown.remainingMs < frozen);
            countdown.stop();
            verify(!countdown.active);
            compare(countdown.remainingSeconds, 0);
            compare(finishedSpy.count, 0);
        }

        function test_elapsedDeadlineAndSingleCompletion() {
            countdown.start();
            // Simulate a delayed event loop (or waking from suspend).
            countdown.deadlineMs = Date.now() - 5000;
            countdown.update();
            verify(!countdown.active);
            compare(countdown.displayTime, "0:00");
            compare(finishedSpy.count, 1);
            countdown.update();
            compare(finishedSpy.count, 1);
        }

        function test_realCountdown() {
            countdown.select(1);
            countdown.start();
            tryCompare(countdown, "active", false, 1600);
            compare(finishedSpy.count, 1);
        }

        function test_rulerClickDragAndScroll() {
            mouseClick(view, 200, 80);
            verify(countdown.minuteMode);
            compare(countdown.selectedSeconds, 120);
            wait(300);
            mouseWheel(view, 200, 80, 0, 120);
            compare(countdown.selectedSeconds, 180);
            mouseClick(view, 200, 80);
            verify(!countdown.minuteMode);
            wait(300);
            mouseWheel(view, 200, 80, 0, -120);
            compare(countdown.selectedSeconds, 179);
            mousePress(view, 200, 80);
            mouseMove(view, 145, 80, 30);
            mouseRelease(view, 145, 80);
            compare(countdown.selectedSeconds, 184);
            verify(!countdown.minuteMode, "Dragging must not toggle ruler units");
        }

        function test_startPauseResumeCancelButtons() {
            mouseClick(view, 80, 140);
            compare(controller.starts, 1);
            verify(countdown.active);
            view.editing = false;
            mouseClick(view, 31, 31);
            verify(countdown.paused);
            mouseClick(view, 31, 31);
            verify(!countdown.paused);
            mouseClick(view, 77, 31);
            verify(!countdown.active);
            compare(finishedSpy.count, 0);
        }

        function test_hoverIncludesChildControls() {
            mouseMove(view, 200, 80);
            tryCompare(gestures, "containsMouse", true);
            mouseMove(view, 80, 140);
            wait(400);
            verify(gestures.containsMouse, "Hover must include the start button");
            mouseMove(view, 450, 210);
            tryCompare(gestures, "containsMouse", false);
        }
    }
}
