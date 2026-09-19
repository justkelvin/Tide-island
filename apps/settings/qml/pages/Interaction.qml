import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "../components"

PagePanel {
    id: root

    readonly property string playerAction: "toggleExpandedPlayer"
    property int revision: 0

    function normalizedButton(value, fallback) {
        const parsed = Number(value)
        return (parsed === 1 || parsed === 2 || parsed === 3) ? parsed : fallback
    }

    function normalizedHoverAction(value) {
        const parsed = Number(value)
        return (parsed === 0 || parsed === 1) ? parsed : 1
    }

    function normalizedAutoHideDelay(value) {
        const parsed = Number(value)
        return isNaN(parsed) ? 1000 : Math.min(10000, Math.max(100, Math.round(parsed)))
    }

    function boolValue(key, fallback) {
        revision
        const value = ConfigStore.value(key, fallback)
        return value === true || value === "true"
    }

    function buttonForAction(fallback) {
        revision
        return normalizedButton(ConfigStore.value("dynamicIslandPrimaryButton", fallback), fallback)
    }

    function saveClickButton(button) {
        ConfigStore.setValue("dynamicIslandPrimaryAction", root.playerAction)
        ConfigStore.setValue("dynamicIslandPrimaryButton", button)
        ConfigStore.setValue("dynamicIslandSecondaryAction", "")
        ConfigStore.save()
        revision += 1
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
                    text: "Interaction"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Configure mouse clicks, hover expansion, auto-hide timings, and media triggers."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            CardGroup {
                title: "Click Actions"
                description: "Mouse button assignments to expand or collapse the island."

                SettingRow {
                    title: "Expand Music Player"
                    description: "Select which mouse button toggles the expanded media player"

                    SegmentedControl {
                        options: [
                            { label: "Left Click", value: 1 },
                            { label: "Middle Click", value: 2 },
                            { label: "Right Click", value: 3 }
                        ]
                        currentValue: root.buttonForAction(1)
                        onSelected: function(val) {
                            root.saveClickButton(val)
                        }
                        implicitWidth: 260
                    }
                }
            }

            CardGroup {
                title: "Hover Behavior"
                description: "Expand the capsule automatically when hovering over it."

                SettingRow {
                    title: "Hover Action"
                    description: "Triggers after hovering on the capsule for 350ms"

                    SegmentedControl {
                        options: [
                            { label: "Disabled", value: 0 },
                            { label: "Music Player", value: 1 }
                        ]
                        currentValue: root.normalizedHoverAction(ConfigStore.value("hoverExpandAction", 1))
                        onSelected: function(val) {
                            ConfigStore.setValue("hoverExpandAction", val)
                            ConfigStore.save()
                            root.revision += 1
                        }
                        implicitWidth: 200
                    }
                }
            }

            CardGroup {
                title: "Auto-Hide"
                description: "Hide the island when idle and reveal it on edge hover or events."

                TideSwitch {
                    width: parent.width
                    text: "Enable Auto-Hide"
                    description: "Hide the island after an idle delay and reveal it when hovering over the top screen edge"
                    checked: root.boolValue("islandAutoHideEnabled", true)
                    onToggled: function(val) {
                        ConfigStore.setValue("islandAutoHideEnabled", val)
                        ConfigStore.save()
                        root.revision += 1
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Auto-Hide Delay"
                    description: "Duration before the capsule retracts into the top edge (seconds)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: delaySlider
                            from: 0.1
                            to: 6.0
                            stepSize: 0.1
                            value: root.normalizedAutoHideDelay(ConfigStore.value("islandAutoHideDelayMs", 1000)) / 1000.0
                            onMoved: {
                                const ms = Math.round(value * 1000)
                                ConfigStore.setValue("islandAutoHideDelayMs", ms)
                                ConfigStore.save()
                                root.revision += 1
                            }
                            width: 140
                        }

                        Text {
                            text: delaySlider.value.toFixed(1) + " s"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            width: 44
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                CardDivider {}

                TideSwitch {
                    width: parent.width
                    text: "Show Workspace on Auto-Hide"
                    description: "Temporarily reveal the island with the active workspace indicator when switching Hyprland workspaces"
                    checked: root.boolValue("islandShowWorkspaceOnAutoHide", true)
                    onToggled: function(val) {
                        ConfigStore.setValue("islandShowWorkspaceOnAutoHide", val)
                        ConfigStore.save()
                        root.revision += 1
                    }
                }
            }

            CardGroup {
                title: "Media Playback"
                description: "Media player event reactions and notifications."

                TideSwitch {
                    width: parent.width
                    text: "Auto-Expand on Track Change"
                    description: "Automatically expand the music player capsule for a moment whenever a new song begins playing"
                    checked: !root.boolValue("disableAutoExpandOnTrackChange", false)
                    onToggled: function(val) {
                        ConfigStore.setValue("disableAutoExpandOnTrackChange", !val)
                        ConfigStore.save()
                        root.revision += 1
                    }
                }
            }
        }
    }
}
