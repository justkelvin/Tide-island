import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "../components"

PagePanel {
    id: root

    property int revision: 0
    property int previewMode: 0
    property var liveCavaLevels: [0.35, 0.75, 0.5, 0.9, 0.6, 0.85, 0.4]

    Timer {
        interval: 220
        running: true
        repeat: true
        onTriggered: {
            root.liveCavaLevels = [
                0.25 + Math.random() * 0.55,
                0.4 + Math.random() * 0.55,
                0.3 + Math.random() * 0.65,
                0.5 + Math.random() * 0.45,
                0.35 + Math.random() * 0.55,
                0.45 + Math.random() * 0.5,
                0.2 + Math.random() * 0.6
            ]
        }
    }

    function textValue(key, fallback) {
        revision
        return String(ConfigStore.value(key, fallback))
    }

    function intValue(key, fallback) {
        revision
        const val = ConfigStore.value(key, fallback)
        const parsed = Number(val)
        return isNaN(parsed) ? fallback : Math.round(parsed)
    }

    function saveText(key, value) {
        ConfigStore.setValue(key, value)
        ConfigStore.save()
        revision += 1
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (value === undefined || value === null || String(value).trim().length === 0)
            return fallback

        const parsedValue = Number(value)
        if (isNaN(parsedValue))
            return fallback

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        revision += 1
        return roundedValue
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
                    text: "Typography"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Configure font families, scale sizes, and glyph rendering for the island."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            CardGroup {
                title: "Font Families"
                description: "Typography typefaces for icons, titles, bodies, and clocks."

                SettingRow {
                    title: "Icon Font Family"
                    description: "Font containing status glyphs and symbols (e.g. Nerd Font)"

                    ConfigTextField {
                        text: root.textValue("iconFontFamily", "JetBrainsMono Nerd Font")
                        implicitWidth: 200
                        onEditingFinished: root.saveText("iconFontFamily", text)
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Text Font Family"
                    description: "Primary typeface for song titles, lyrics, and system metrics"

                    ConfigTextField {
                        text: root.textValue("textFontFamily", "Inter Display")
                        implicitWidth: 200
                        onEditingFinished: root.saveText("textFontFamily", text)
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Hero Font Family"
                    description: "Display typeface for headers, popups, and OSD percentages"

                    ConfigTextField {
                        text: root.textValue("heroFontFamily", "Inter Display")
                        implicitWidth: 200
                        onEditingFinished: root.saveText("heroFontFamily", text)
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Time Font Family"
                    description: "Typeface used on the resting digital clock"

                    ConfigTextField {
                        text: root.textValue("timeFontFamily", "Inter Display")
                        implicitWidth: 200
                        onEditingFinished: root.saveText("timeFontFamily", text)
                    }
                }
            }

            CardGroup {
                title: "Font Sizes"
                description: "Scalable font sizes in pixels across various island views."

                SettingRow {
                    title: "Body Font Size"
                    description: "Standard body text pixel size (default: 16px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: bodySizeSlider
                            from: 10
                            to: 28
                            stepSize: 1
                            value: root.intValue("bodyFontSize", 16)
                            onMoved: root.saveInt("bodyFontSize", value, 16, 10, 30)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(bodySizeSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 10; top: 30 }
                            onEditingFinished: bodySizeSlider.value = root.saveInt("bodyFontSize", text, 16, 10, 30)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Title Font Size"
                    description: "Heading and prominent OSD pixel size (default: 20px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: titleSizeSlider
                            from: 14
                            to: 36
                            stepSize: 1
                            value: root.intValue("titleFontSize", 20)
                            onMoved: root.saveInt("titleFontSize", value, 20, 12, 40)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(titleSizeSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 12; top: 40 }
                            onEditingFinished: titleSizeSlider.value = root.saveInt("titleFontSize", text, 20, 12, 40)
                        }
                    }
                }

                CardDivider {}

                SettingRow {
                    title: "Icon Font Size"
                    description: "Glyph and status icon pixel size (default: 18px)"

                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter

                        TideSlider {
                            id: iconSizeSlider
                            from: 12
                            to: 32
                            stepSize: 1
                            value: root.intValue("iconFontSize", 18)
                            onMoved: root.saveInt("iconFontSize", value, 18, 10, 36)
                            width: 140
                        }

                        ConfigTextField {
                            text: String(Math.round(iconSizeSlider.value))
                            implicitWidth: 64
                            validator: IntValidator { bottom: 10; top: 36 }
                            onEditingFinished: iconSizeSlider.value = root.saveInt("iconFontSize", text, 18, 10, 36)
                        }
                    }
                }
            }

            CardGroup {
                title: "Live Preview"
                description: "Real-time Dynamic Island capsule rendering with your configured typography. Click capsule to cycle states."

                Column {
                    width: parent.width
                    spacing: 12

                    SegmentedControl {
                        options: [
                            { label: "Status & Clock", value: 0 },
                            { label: "Now Playing", value: 1 },
                            { label: "Volume OSD", value: 2 }
                        ]
                        currentValue: root.previewMode
                        onSelected: function(val) { root.previewMode = Number(val) }
                        implicitWidth: 340
                    }

                    Rectangle {
                        id: islandViewport
                        width: parent.width
                        height: 110
                        radius: Theme.radiusControl
                        color: Theme.darkMode ? "#0c0d12" : "#181922"
                        border.width: 1
                        border.color: Theme.outline
                        clip: true

                        Rectangle {
                            id: islandCapsule
                            anchors.centerIn: parent
                            height: 44
                            radius: height / 2
                            color: "#000000"
                            width: Math.max(180, contentRow.implicitWidth + 36)

                            Behavior on width {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutQuint
                                }
                            }

                            Row {
                                id: contentRow
                                anchors.centerIn: parent
                                spacing: 14

                                // Mode 0: Status & Clock
                                Row {
                                    visible: root.previewMode === 0
                                    spacing: 14
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "12:45"
                                        color: "white"
                                        font.family: root.textValue("timeFontFamily", "Inter Display")
                                        font.pixelSize: root.intValue("bodyFontSize", 16) + 1
                                        font.weight: Font.Bold
                                        font.letterSpacing: -0.25
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        spacing: 3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Repeater {
                                            model: root.liveCavaLevels

                                            Rectangle {
                                                width: 3.5
                                                height: Math.max(4, Math.round(16 * modelData))
                                                radius: 1.75
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Behavior on height {
                                                    NumberAnimation { duration: 180 }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        width: 37
                                        height: 17
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            id: prevBatBody
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 3
                                            height: parent.height
                                            radius: 6
                                            color: Qt.rgba(1, 1, 1, 0.56)
                                            clip: true

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: Math.max(12, parent.width * 0.76)
                                                radius: 6
                                                color: "white"
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "76"
                                                color: "black"
                                                font.family: root.textValue("textFontFamily", "Inter Display")
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 5
                                            radius: 1
                                            color: "white"
                                            anchors.left: prevBatBody.right
                                            anchors.leftMargin: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                // Mode 1: Now Playing
                                Row {
                                    visible: root.previewMode === 1
                                    spacing: 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: ""
                                        color: "white"
                                        font.family: root.textValue("iconFontFamily", "JetBrainsMono Nerd Font")
                                        font.pixelSize: root.intValue("iconFontSize", 18)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Starboy — The Weeknd"
                                        color: "white"
                                        font.family: root.textValue("textFontFamily", "Inter Display")
                                        font.pixelSize: root.intValue("bodyFontSize", 16)
                                        font.weight: Font.Bold
                                        font.letterSpacing: -0.15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        spacing: 3
                                        anchors.verticalCenter: parent.verticalCenter

                                        Repeater {
                                            model: root.liveCavaLevels

                                            Rectangle {
                                                width: 3.5
                                                height: Math.max(4, Math.round(16 * modelData))
                                                radius: 1.75
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Behavior on height {
                                                    NumberAnimation { duration: 180 }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Mode 2: Volume OSD
                                Row {
                                    visible: root.previewMode === 2
                                    spacing: 12
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: ""
                                        color: "white"
                                        font.family: root.textValue("iconFontFamily", "JetBrainsMono Nerd Font")
                                        font.pixelSize: root.intValue("iconFontSize", 18)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "68%"
                                        color: "white"
                                        font.family: root.textValue("heroFontFamily", "Inter Display")
                                        font.pixelSize: root.intValue("titleFontSize", 20)
                                        font.weight: Font.Bold
                                        font.letterSpacing: -0.35
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Rectangle {
                                        width: 80
                                        height: 5
                                        radius: 2.5
                                        color: Qt.rgba(1, 1, 1, 0.28)
                                        anchors.verticalCenter: parent.verticalCenter
                                        clip: true

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: parent.width * 0.68
                                            radius: 2.5
                                            color: "white"
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.previewMode = (root.previewMode + 1) % 3
                            }
                        }
                    }
                }
            }
        }
    }
}
