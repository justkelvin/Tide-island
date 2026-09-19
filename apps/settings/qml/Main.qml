import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "pages"
import "components"

ApplicationWindow {
    id: window

    visible: true
    width: 960
    height: 620
    minimumWidth: 800
    minimumHeight: 520
    title: "Tide Island Preferences"
    color: Theme.surface

    property int currentPage: 1

    Behavior on color {
        ColorAnimation { duration: Theme.motion }
    }

    function pageForIndex(index) {
        switch (index) {
        case 1: return generalPage
        case 2: return interactionPage
        case 3: return fontPage
        case 4: return shortcutPage
        default: return null
        }
    }

    function selectPage(index) {
        if (index === currentPage) return

        const previousPage = pageForIndex(currentPage)
        const nextPage = pageForIndex(index)
        currentPage = index

        if (previousPage) previousPage.hidePage()
        if (nextPage) nextPage.showPage()
    }

    Row {
        anchors.fill: parent

        // Left Sidebar
        Rectangle {
            id: sidebar
            width: 220
            height: parent.height
            color: Theme.surfaceElevated
            border.width: 0

            Behavior on color { ColorAnimation { duration: Theme.motion } }

            // Right border
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.divider
            }

            // Top Section (Header & Navigation)
            Column {
                id: topSection
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                spacing: 20

                // Header / Branding
                Row {
                    spacing: 12
                    width: parent.width

                    // Minimalist Island Capsule Logo
                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: Theme.card
                        border.width: 1
                        border.color: Theme.outline
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 8
                            radius: 4
                            color: Theme.accent
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "Tide Island"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Preferences"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                }

                // Navigation Items
                Column {
                    width: parent.width
                    spacing: 4

                    NavItem {
                        iconSource: "qrc:/resources/icons/nav-general.svg"
                        label: "General"
                        pageIndex: 1
                        isSelected: window.currentPage === 1
                        onClicked: window.selectPage(1)
                    }

                    NavItem {
                        iconSource: "qrc:/resources/icons/nav-interaction.svg"
                        label: "Interaction"
                        pageIndex: 2
                        isSelected: window.currentPage === 2
                        onClicked: window.selectPage(2)
                    }

                    NavItem {
                        iconSource: "qrc:/resources/icons/nav-typography.svg"
                        label: "Typography"
                        pageIndex: 3
                        isSelected: window.currentPage === 3
                        onClicked: window.selectPage(3)
                    }

                    NavItem {
                        iconSource: "qrc:/resources/icons/nav-shortcuts.svg"
                        label: "Shortcuts"
                        pageIndex: 4
                        isSelected: window.currentPage === 4
                        onClicked: window.selectPage(4)
                    }
                }
            }

            // Bottom Section (Dark / Light Mode & Footer Link)
            Column {
                id: bottomSection
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                spacing: 12

                // Dark / Light Mode Switcher
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: Theme.radiusControl
                    color: Theme.card
                    border.width: 1
                    border.color: themeToggleMouse.containsMouse ? Theme.accent : Theme.outline

                    Behavior on border.color { ColorAnimation { duration: Theme.motion } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        SvgIcon {
                            source: Theme.darkMode ? "qrc:/resources/icons/mode-dark.svg" : "qrc:/resources/icons/mode-light.svg"
                            iconSize: 16
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Theme.darkMode ? "Dark Mode" : "Light Mode"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: themeToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.setColorScheme(Theme.darkMode ? "light" : "dark")
                    }
                }

                // Links / Info with comfortable padding and hover styling
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Tide Island for Hyprland"
                    color: linkMouse.containsMouse ? Theme.accent : Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.underline: linkMouse.containsMouse

                    Behavior on color { ColorAnimation { duration: Theme.motion } }

                    MouseArea {
                        id: linkMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://github.com/enhaoswen/Tide-island")
                    }
                }
            }
        }

        // Main Content Area
        Item {
            id: contentArea
            width: parent.width - sidebar.width
            height: parent.height

            General {
                id: generalPage
                anchors.fill: parent
                visible: true
                opacity: 1
            }

            Interaction {
                id: interactionPage
                anchors.fill: parent
                visible: false
                opacity: 0
            }

            FontSettings {
                id: fontPage
                anchors.fill: parent
                visible: false
                opacity: 0
            }

            Shortcut {
                id: shortcutPage
                anchors.fill: parent
                visible: false
                opacity: 0
            }
        }
    }

    // Top-right Close Button
    Rectangle {
        id: closeBtn
        z: 90
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: 32
        height: 32
        radius: 16
        color: closeMouse.pressed ? Theme.pressed : (closeMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12) : Theme.card)
        border.width: 1
        border.color: closeMouse.containsMouse ? Theme.error : Theme.outline

        Behavior on color { ColorAnimation { duration: Theme.motion } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion } }

        SvgIcon {
            anchors.centerIn: parent
            source: "qrc:/resources/icons/close.svg"
            iconSize: 14
            color: closeMouse.containsMouse ? Theme.error : Theme.muted
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: window.close()
        }
    }

    // Config Error Banner (if file corrupted)
    Rectangle {
        id: configErrorBanner

        readonly property bool hasError: ConfigStore.errorString.length > 0

        z: 100
        visible: hasError
        opacity: hasError ? 1 : 0
        anchors.left: parent.left
        anchors.leftMargin: 240
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        height: Math.max(46, errorText.implicitHeight + 16)
        radius: Theme.radiusControl
        color: Theme.errorBg
        border.width: 1
        border.color: Theme.errorBorder

        Behavior on opacity { NumberAnimation { duration: Theme.motion } }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                id: errorText
                width: parent.width - rewriteBtn.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Config error: " + ConfigStore.errorString
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: 12
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }

            ActionButton {
                id: rewriteBtn
                text: "Rewrite & Fix"
                variant: "danger"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: ConfigStore.save()
            }
        }
    }

    component NavItem: Rectangle {
        id: item
        property string iconSource: ""
        property string label: ""
        property int pageIndex: 1
        property bool isSelected: false

        signal clicked()

        width: parent.width
        height: 38
        radius: Theme.radiusControl
        color: item.isSelected ? Theme.accentSoft : (itemMouse.containsMouse ? Theme.hover : "transparent")

        Behavior on color { ColorAnimation { duration: Theme.motion } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            SvgIcon {
                source: item.iconSource
                iconSize: 18
                color: item.isSelected ? Theme.accent : (itemMouse.containsMouse ? Theme.text : Theme.muted)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: item.label
                color: item.isSelected ? Theme.accent : (itemMouse.containsMouse ? Theme.text : Theme.muted)
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: item.isSelected ? Font.DemiBold : Font.Medium
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: Theme.motion } }
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.clicked()
        }
    }
}
