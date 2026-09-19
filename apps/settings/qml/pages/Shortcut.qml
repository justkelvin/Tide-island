import QtQuick
import QtQuick.Controls
import TideIsland 1.0
import "../components"

PagePanel {
    id: root

    property int shortcutRevision: 0
    property int captureIndex: -1
    property int captureTokenRevision: 0
    property var captureTokens: []
    readonly property bool supportsHyprlandShortcutSnippets: backend.supportsHyprlandShortcutSnippets()
    readonly property string compositorName: backend.compositorDisplayName()

    property var shortcuts: []

    function allShortcutDefinitions() {
        return [
            {
                "action": "Next Island View",
                "description": "Cycle forward to the next island view (lyrics / custom)",
                "mods": "SUPER",
                "key": "right",
                "target": "tide",
                "method": "swipeRight"
            },
            {
                "action": "Previous Island View",
                "description": "Cycle backward to the previous island view",
                "mods": "SUPER",
                "key": "left",
                "target": "tide",
                "method": "swipeLeft"
            },
            {
                "action": "Clock View",
                "description": "Quickly return to the main clock idle view",
                "mods": "SUPER",
                "key": "down",
                "target": "tide",
                "method": "showClock"
            },
            {
                "action": "Music Player",
                "description": "Toggle the expanded music player controls and artwork",
                "mods": "SUPER",
                "key": "M",
                "target": "tide",
                "method": "togglePlayer"
            },
            {
                "action": "Toggle Island",
                "description": "Force show or hide the island capsule",
                "mods": "SUPER",
                "key": "F",
                "target": "island",
                "method": "toggle"
            }
        ]
    }

    function beginCapture(index) {
        captureIndex = index
        setCaptureTokens([])
        keyCapture.forceActiveFocus()
    }

    function endCapture() {
        captureIndex = -1
        setCaptureTokens([])
    }

    function setCaptureTokens(tokens) {
        captureTokens = tokens
        captureTokenRevision += 1
    }

    function setShortcut(index, mods, key, finishCapture) {
        shortcuts[index].mods = mods
        shortcuts[index].key = key
        shortcutRevision += 1
        applyShortcutBindings()
        if (finishCapture)
            endCapture()
    }

    function disableShortcut(index) {
        setShortcut(index, "", "", true)
    }

    function shortcutIdentity(shortcut) {
        return shortcut.target + ":" + shortcut.method
    }

    function shortcutBindingsForBackend() {
        const bindings = []
        for (let i = 0; i < shortcuts.length; ++i) {
            const shortcut = shortcuts[i]
            bindings.push({
                "mods": shortcut.mods,
                "key": shortcut.key,
                "target": shortcut.target,
                "method": shortcut.method
            })
        }
        return bindings
    }

    function applyShortcutBindings() {
        const bindings = shortcutBindingsForBackend()
        backend.applyShortcutBindings(bindings)
    }

    function loadShortcutBindings() {
        shortcuts = allShortcutDefinitions()

        const saved = backend.shortcutBindings()
        const byIdentity = ({})
        for (let i = 0; i < saved.length; ++i)
            byIdentity[shortcutIdentity(saved[i])] = saved[i]

        for (let j = 0; j < shortcuts.length; ++j) {
            const binding = byIdentity[shortcutIdentity(shortcuts[j])]
            if (!binding)
                continue

            shortcuts[j].mods = binding.mods
            shortcuts[j].key = binding.key
        }

        shortcutRevision += 1
    }

    Component.onCompleted: loadShortcutBindings()

    function shortcutCommand(shortcut) {
        return "/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call "
            + shortcut.target + " " + shortcut.method
    }

    function isModifierToken(value) {
        return value === "SUPER" || value === "SHIFT" || value === "CTRL" || value === "ALT"
    }

    function appendUnique(values, value) {
        if (value.length > 0 && values.indexOf(value) < 0)
            values.push(value)
    }

    function updateCapturedShortcut(tokens) {
        let key = ""
        const mods = []
        for (let i = 0; i < tokens.length; ++i) {
            if (isModifierToken(tokens[i])) {
                appendUnique(mods, tokens[i])
            } else {
                key = tokens[i]
            }
        }

        if (key.length > 0)
            setShortcut(captureIndex, mods.join(" "), key, false)
    }

    function addCaptureToken(token) {
        if (token.length === 0)
            return

        const tokens = captureTokens.slice()
        if (isModifierToken(token)) {
            if (tokens.indexOf(token) < 0 && tokens.length < 3) {
                let keyIndex = -1
                for (let i = 0; i < tokens.length; ++i) {
                    if (!isModifierToken(tokens[i])) {
                        keyIndex = i
                        break
                    }
                }

                if (keyIndex >= 0)
                    tokens.splice(keyIndex, 0, token)
                else
                    tokens.push(token)
            }
        } else {
            let replaced = false
            for (let i = 0; i < tokens.length; ++i) {
                if (!isModifierToken(tokens[i])) {
                    tokens[i] = token
                    replaced = true
                    break
                }
            }

            if (!replaced) {
                if (tokens.length < 3)
                    tokens.push(token)
                else
                    tokens[tokens.length - 1] = token
            }
        }

        if (tokens.length > 3)
            tokens.splice(3)

        setCaptureTokens(tokens)

        let hasKey = false
        for (let j = 0; j < tokens.length; ++j)
            hasKey = hasKey || !isModifierToken(tokens[j])

        if (hasKey)
            updateCapturedShortcut(tokens)
        if (tokens.length >= 3 && hasKey)
            endCapture()
    }

    function hyprKeyName(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode("A".charCodeAt(0) + key - Qt.Key_A)
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode("0".charCodeAt(0) + key - Qt.Key_0)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1)

        switch (key) {
        case Qt.Key_Tab: return "TAB"
        case Qt.Key_Left: return "left"
        case Qt.Key_Right: return "right"
        case Qt.Key_Up: return "up"
        case Qt.Key_Down: return "down"
        case Qt.Key_Space: return "space"
        case Qt.Key_Return:
        case Qt.Key_Enter: return "return"
        case Qt.Key_Backspace: return "backspace"
        case Qt.Key_Delete: return "delete"
        case Qt.Key_Insert: return "insert"
        case Qt.Key_Home: return "home"
        case Qt.Key_End: return "end"
        case Qt.Key_PageUp: return "page_up"
        case Qt.Key_PageDown: return "page_down"
        case Qt.Key_Minus: return "minus"
        case Qt.Key_Equal: return "equal"
        case Qt.Key_BracketLeft: return "bracketleft"
        case Qt.Key_BracketRight: return "bracketright"
        case Qt.Key_Backslash: return "backslash"
        case Qt.Key_Semicolon: return "semicolon"
        case Qt.Key_Apostrophe: return "apostrophe"
        case Qt.Key_Comma: return "comma"
        case Qt.Key_Period: return "period"
        case Qt.Key_Slash: return "slash"
        case Qt.Key_QuoteLeft: return "grave"
        default:
            return text && text.length === 1 ? text : ""
        }
    }

    function displayToken(value) {
        switch (String(value)) {
        case "SUPER": return "Super"
        case "SHIFT": return "Shift"
        case "CTRL": return "Ctrl"
        case "ALT": return "Alt"
        case "TAB": return "Tab"
        case "left": return "← Left"
        case "right": return "→ Right"
        case "up": return "↑ Up"
        case "down": return "↓ Down"
        case "space": return "Space"
        case "return": return "Return"
        case "backspace": return "Backspace"
        case "delete": return "Delete"
        default:
            return String(value).toUpperCase()
        }
    }

    Item {
        id: keyCapture
        focus: root.captureIndex >= 0

        Keys.onPressed: function(event) {
            if (root.captureIndex < 0) return

            if (event.key === Qt.Key_Escape) {
                root.endCapture()
                event.accepted = true
                return
            }

            if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                root.addCaptureToken("SUPER")
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Shift) {
                root.addCaptureToken("SHIFT")
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Control) {
                root.addCaptureToken("CTRL")
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Alt) {
                root.addCaptureToken("ALT")
                event.accepted = true
                return
            }

            const keyName = root.hyprKeyName(event.key, event.text)
            if (keyName.length > 0) {
                root.addCaptureToken(keyName)
                event.accepted = true
            }
        }
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
                    text: "Shortcuts"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Global Hyprland keybindings to interact with and toggle the island."
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
            }

            CardGroup {
                title: "Island Shortcuts"
                description: "Keybindings are managed and applied directly to your Hyprland configuration."

                Repeater {
                    model: root.shortcuts

                    Item {
                        width: parent.width
                        implicitHeight: rowContent.implicitHeight + 8

                        readonly property bool isRecording: root.captureIndex === index
                        readonly property bool hasBinding: modelData.key.length > 0

                        Column {
                            id: rowContent
                            width: parent.width
                            spacing: 12

                            Row {
                                width: parent.width
                                spacing: 16

                                Column {
                                    width: parent.width - actionButtons.width - parent.spacing
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: modelData.action
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        text: modelData.description
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        wrapMode: Text.Wrap
                                        width: parent.width
                                    }
                                }

                                Row {
                                    id: actionButtons
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Key badge or recording indicator
                                    Rectangle {
                                        height: 32
                                        implicitWidth: Math.max(60, badgeText.implicitWidth + 20)
                                        radius: Theme.radiusSmall
                                        color: isRecording ? Theme.accentSoft : Theme.surfaceElevated
                                        border.width: 1
                                        border.color: isRecording ? Theme.accent : Theme.outline

                                        Behavior on color { ColorAnimation { duration: Theme.motion } }
                                        Behavior on border.color { ColorAnimation { duration: Theme.motion } }

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: {
                                                if (isRecording) {
                                                    return root.captureTokens.length > 0
                                                        ? root.captureTokens.map(root.displayToken).join(" + ")
                                                        : "Press keys..."
                                                }
                                                if (!hasBinding)
                                                    return "Unbound"

                                                const parts = []
                                                if (modelData.mods.length > 0)
                                                    parts.push(modelData.mods.split(" ").map(root.displayToken).join(" + "))
                                                if (modelData.key.length > 0)
                                                    parts.push(root.displayToken(modelData.key))
                                                return parts.join(" + ")
                                            }
                                            color: isRecording ? Theme.accent : (hasBinding ? Theme.text : Theme.subtle)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: (isRecording || hasBinding) ? Font.DemiBold : Font.Normal
                                        }
                                    }

                                    ActionButton {
                                        text: isRecording ? "Cancel" : "Record"
                                        variant: isRecording ? "danger" : "secondary"
                                        onClicked: {
                                            if (isRecording)
                                                root.endCapture()
                                            else
                                                root.beginCapture(index)
                                        }
                                    }

                                    ActionButton {
                                        visible: hasBinding && !isRecording
                                        text: "Clear"
                                        variant: "ghost"
                                        onClicked: root.disableShortcut(index)
                                    }
                                }
                            }

                            CardDivider {
                                visible: index < root.shortcuts.length - 1
                            }
                        }
                    }
                }
            }

            CardGroup {
                title: "Compositor Integration"
                description: "Tide Island binds to Hyprland via Quickshell IPC."

                SettingRow {
                    title: "Active Compositor"
                    description: root.supportsHyprlandShortcutSnippets
                        ? "Hyprland detected. Shortcuts are written to hyprland-shortcuts.conf / hyprland.lua automatically."
                        : "Keybinding management requires Hyprland."

                    Rectangle {
                        height: 28
                        implicitWidth: compText.implicitWidth + 18
                        radius: 14
                        color: Theme.accentSoft
                        border.width: 1
                        border.color: Theme.accent

                        Text {
                            id: compText
                            anchors.centerIn: parent
                            text: root.compositorName
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
