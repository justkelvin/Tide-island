import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "../components"

PagePanel {
    id: root

    property int revision: 0

    function intValue(key, fallback) {
        revision
        const val = ConfigStore.value(key, fallback)
        const parsed = Number(val)
        return isNaN(parsed) ? fallback : Math.round(parsed)
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (value === undefined || value === null || String(value).trim().length === 0)
            return fallback

        const parsedValue = Number(value)
        if (isNaN(parsedValue))
            return fallback

        const boundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, boundedValue)
        ConfigStore.save()
        revision += 1
        return boundedValue
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
                    text: "General"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Configure the capsule dimensions, screen positioning, transparency, and modules."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            CardGroup {
                title: "Dimensions & Placement"
                description: "Physical dimensions and offset of the resting Dynamic Island capsule."

                SettingRow {
                    title: "Island Width"
                    description: "Base width of the island capsule in clock mode (px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: widthSlider
                            from: 80
                            to: 360
                            stepSize: 2
                            value: root.intValue("islandWidth", 140)
                            onMoved: root.saveInt("islandWidth", value, 140, 80, 500)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(widthSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 60; top: 600 }
                            onEditingFinished: widthSlider.value = root.saveInt("islandWidth", text, 140, 60, 600)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Island Height"
                    description: "Base height of the island capsule in clock mode (px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: heightSlider
                            from: 26
                            to: 64
                            stepSize: 1
                            value: root.intValue("islandHeight", 38)
                            onMoved: root.saveInt("islandHeight", value, 38, 20, 100)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(heightSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 20; top: 100 }
                            onEditingFinished: heightSlider.value = root.saveInt("islandHeight", text, 38, 20, 100)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Top Margin"
                    description: "Distance from the top edge of the screen to the capsule (px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: topMarginSlider
                            from: 0
                            to: 40
                            stepSize: 1
                            value: root.intValue("islandTopMargin", 4)
                            onMoved: root.saveInt("islandTopMargin", value, 4, 0, 100)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(topMarginSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 0; top: 100 }
                            onEditingFinished: topMarginSlider.value = root.saveInt("islandTopMargin", text, 4, 0, 100)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Reserved Top Space"
                    description: "Screen exclusive zone reserved for the capsule (px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: exclusiveZoneSlider
                            from: 0
                            to: 80
                            stepSize: 1
                            value: root.intValue("islandExclusiveZone", 45)
                            onMoved: root.saveInt("islandExclusiveZone", value, 45, 0, 200)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(exclusiveZoneSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 0; top: 200 }
                            onEditingFinished: exclusiveZoneSlider.value = root.saveInt("islandExclusiveZone", text, 45, 0, 200)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Horizontal Position"
                    description: "Horizontal alignment across the display (0% = Left, 50% = Center, 100% = Right)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: positionXSlider
                            from: 0
                            to: 100
                            stepSize: 1
                            value: root.intValue("islandPositionX", 50)
                            onMoved: root.saveInt("islandPositionX", value, 50, 0, 100)
                            width: 140
                        }

                        Text {
                            text: Math.round(positionXSlider.value) + "%"
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
            }

            CardGroup {
                title: "Appearance & Clock"
                description: "Visual surface characteristics and time formatting."

                SettingRow {
                    title: "Background Opacity"
                    description: "Opacity of the capsule background surface (0 = fully transparent, 100 = solid)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: opacitySlider
                            from: 0
                            to: 100
                            stepSize: 1
                            value: root.intValue("islandBackgroundOpacity", 60)
                            onMoved: root.saveInt("islandBackgroundOpacity", value, 60, 0, 100)
                            width: 140
                        }

                        Text {
                            text: Math.round(opacitySlider.value) + "%"
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

                SettingRow {
                    title: "OSD Progress Style"
                    description: "Progress indicator on the volume and brightness overlay (line fills the capsule, ring hugs the edge)"

                    SegmentedControl {
                        options: [
                            { label: "Line", value: "line" },
                            { label: "Ring", value: "ring" }
                        ]
                        currentValue: String(ConfigStore.value("osdProgressStyle", "line"))
                        onSelected: function(val) {
                            ConfigStore.setValue("osdProgressStyle", val)
                            ConfigStore.save()
                        }
                        implicitWidth: 160
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Clock Format"
                    description: "Time display standard on the resting capsule"

                    SegmentedControl {
                        options: [
                            { label: "12-Hour", value: "12" },
                            { label: "24-Hour", value: "24" }
                        ]
                        currentValue: String(ConfigStore.value("clockFormat", "12"))
                        onSelected: function(val) {
                            ConfigStore.setValue("clockFormat", val)
                            ConfigStore.save()
                        }
                        implicitWidth: 160
                    }
                }
            }

            CardGroup {
                title: "Custom Page Layout"
                description: "Customize the items displayed when swiping left onto the custom info view."

                CustomPage {
                    width: parent.width
                }
            }
        }
    }
}
