import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "../components"

PagePanel {
    id: root

    function statusColor(ok) {
        return ok ? Theme.success : Theme.error
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: diagnostics.refresh()
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        anchors.rightMargin: 4
        clip: true
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        ScrollBar.vertical: ScrollBar {
            id: vbar
            active: vbar.hovered || vbar.pressed
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.muted
                opacity: vbar.active ? 0.6 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion } }
            }
        }

        Column {
            id: contentColumn
            width: parent.width - 24
            x: 12
            y: 12
            spacing: 24

            Column {
                width: parent.width - 40
                spacing: 4

                Text {
                    text: "Diagnostics"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Notification server ownership, background service state, and recent shell logs."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            CardGroup {
                title: "Notification Server"
                description: "Ownership of org.freedesktop.Notifications on the session bus."

                SettingRow {
                    title: "Status"
                    description: diagnostics.serverOwned
                        ? (diagnostics.serverIsTideIsland
                            ? "Tide Island owns the notification bus"
                            : "Owned by " + diagnostics.serverName + " " + diagnostics.serverVersion)
                        : "No owner registered"

                    Text {
                        text: diagnostics.serverOwned
                            ? (diagnostics.serverIsTideIsland ? "● Live" : "● Rival")
                            : "○ Down"
                        color: root.statusColor(diagnostics.serverOwned && diagnostics.serverIsTideIsland)
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Server"
                    description: diagnostics.serverOwned
                        ? diagnostics.serverName + " " + diagnostics.serverVersion
                          + " (" + diagnostics.serverVendor + ", spec " + diagnostics.serverSpecVersion + ")"
                        : "—"

                    Text {
                        text: diagnostics.serverOwner.length > 0 ? diagnostics.serverOwner : "—"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Refresh"
                    description: diagnostics.lastUpdated.length > 0
                        ? "Last checked at " + diagnostics.lastUpdated
                        : "Not checked yet"

                    ActionButton {
                        text: diagnostics.busy ? "Checking…" : "Refresh"
                        enabled: !diagnostics.busy
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: diagnostics.refresh()
                    }
                }
            }

            Rectangle {
                visible: diagnostics.serverOwned && !diagnostics.serverIsTideIsland
                width: parent.width
                implicitHeight: rivalRow.implicitHeight + 16
                radius: Theme.radiusSmall
                color: Theme.darkMode ? Qt.rgba(0.98, 0.74, 0.02, 0.08) : Qt.rgba(0.85, 0.51, 0.17, 0.08)
                border.width: 1
                border.color: Theme.darkMode ? Qt.rgba(0.98, 0.74, 0.02, 0.22) : Qt.rgba(0.85, 0.51, 0.17, 0.20)

                Row {
                    id: rivalRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "⚠️"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - 26
                        wrapMode: Text.WordWrap
                        text: "Another daemon (" + diagnostics.serverName + ") owns the notification bus, so Tide Island will not receive alerts. Stop the rival daemon and restart the tide-island service to take over."
                        color: Theme.warning
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        lineHeight: 1.15
                    }
                }
            }

            CardGroup {
                title: "Background Service"
                description: "tide-island user service state."

                SettingRow {
                    title: "Service"
                    description: "systemctl --user is-active / is-enabled tide-island"

                    Text {
                        text: diagnostics.serviceActive + " / " + diagnostics.serviceEnabled
                        color: root.statusColor(diagnostics.serviceActive === "active")
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            CardGroup {
                title: "Recent Logs"
                description: "Last 80 lines from journalctl --user -u tide-island."

                SettingRow {
                    title: "Logs"
                    description: diagnostics.errorString.length > 0 ? diagnostics.errorString : "Showing cached output"

                    Row {
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        ActionButton {
                            text: "Copy"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: backend.copyToClipboard(diagnostics.logText)
                        }

                        ActionButton {
                            text: "Refresh"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: diagnostics.refresh()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 220
                    radius: Theme.radiusSmall
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.outline

                    Flickable {
                        id: logScroller
                        anchors.fill: parent
                        anchors.margins: 10
                        clip: true
                        contentWidth: width
                        contentHeight: logText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: logText
                            width: logScroller.width
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: diagnostics.logText.length > 0 ? diagnostics.logText : "(no log output yet)"
                            color: Theme.text
                            font.family: "monospace"
                            font.pixelSize: 11
                            lineHeight: 1.25
                        }
                    }
                }
            }
        }
    }
}
