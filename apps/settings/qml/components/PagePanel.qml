import QtQuick
import TideIsland 1.0

Item {
    id: pagePanel

    default property alias content: pagePanel.data

    visible: false
    opacity: 0

    function showPage() {
        hideAnim.stop()
        showAnim.start()
    }

    function hidePage() {
        showAnim.stop()
        hideAnim.start()
    }

    SequentialAnimation {
        id: hideAnim

        ParallelAnimation {
            NumberAnimation {
                target: pagePanel
                property: "opacity"
                to: 0
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pagePanel
                property: "y"
                to: 6
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: {
                pagePanel.visible = false
                pagePanel.y = 0
            }
        }
    }

    SequentialAnimation {
        id: showAnim

        ScriptAction {
            script: {
                pagePanel.y = 6
                pagePanel.visible = true
                pagePanel.opacity = 0
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: pagePanel
                property: "opacity"
                to: 1
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pagePanel
                property: "y"
                to: 0
                duration: Theme.motion
                easing.type: Easing.OutCubic
            }
        }
    }
}
