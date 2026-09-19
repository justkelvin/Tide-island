pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property bool darkMode: backend.colorScheme === "dark"

    // Modern Nala-inspired color palette
    // Dark: Deep refined charcoal/slate with vibrant periwinkle/blue accent
    // Light: Clean porcelain/snow with crisp cobalt/indigo accent
    readonly property color surface: darkMode ? "#16171d" : "#f4f5f8"
    readonly property color surfaceElevated: darkMode ? "#1c1e26" : "#eaecef"
    readonly property color card: darkMode ? "#22242e" : "#ffffff"
    readonly property color cardHover: darkMode ? "#282b37" : "#f8f9fc"
    readonly property color cardBorder: darkMode ? "#2f323f" : "#e0e3eb"
    readonly property color outline: darkMode ? "#2f323f" : "#e0e3eb"
    readonly property color outlineFocused: darkMode ? accent : accent

    readonly property color text: darkMode ? "#e6e6ea" : "#181922"
    readonly property color muted: darkMode ? "#8e929f" : "#686d7e"
    readonly property color subtle: darkMode ? "#5c6070" : "#9499aa"
    readonly property color divider: darkMode ? "#262833" : "#eaecf2"

    readonly property color accent: darkMode ? "#8aadf4" : "#4361ee"
    readonly property color accentHover: darkMode ? "#9bb9f8" : "#3653dc"
    readonly property color accentPressed: darkMode ? "#799de0" : "#2d48cb"
    readonly property color onAccent: darkMode ? "#14151b" : "#ffffff"
    readonly property color accentSoft: darkMode ? Qt.rgba(0.54, 0.68, 0.96, 0.14) : Qt.rgba(0.26, 0.38, 0.93, 0.10)
    readonly property color accentSoftHover: darkMode ? Qt.rgba(0.54, 0.68, 0.96, 0.22) : Qt.rgba(0.26, 0.38, 0.93, 0.16)

    readonly property color hover: darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color pressed: darkMode ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.08)

    readonly property color error: darkMode ? "#f38ba8" : "#d23c58"
    readonly property color danger: error
    readonly property color errorBg: darkMode ? Qt.rgba(0.95, 0.55, 0.66, 0.12) : Qt.rgba(0.82, 0.24, 0.35, 0.08)
    readonly property color errorBorder: darkMode ? Qt.rgba(0.95, 0.55, 0.66, 0.28) : Qt.rgba(0.82, 0.24, 0.35, 0.20)
    readonly property color success: darkMode ? "#a6e3a1" : "#28965a"
    readonly property color warning: darkMode ? "#f9e2af" : "#d9822b"

    // Backward-compatibility aliases so existing bindings don't break
    readonly property color totalBgColor: surface
    readonly property color componentBgColor: surfaceElevated
    readonly property color cardBgColor: card
    readonly property color cardBorderColor: cardBorder
    readonly property color inputBgColor: surfaceElevated
    readonly property color inputHoverBgColor: cardHover
    readonly property color inputBorderColor: outline
    readonly property color inputHoverBorderColor: muted
    readonly property color focusBorderColor: accent
    readonly property color focusRingColor: accentSoft
    readonly property color textColor: text
    readonly property color secondaryTextColor: muted
    readonly property color subtleTextColor: subtle
    readonly property color splitLineColor: divider
    readonly property color buttonColor: accent
    readonly property color buttonHoverColor: accentHover
    readonly property color buttonPressedColor: accentPressed
    readonly property color buttonTextColor: onAccent
    readonly property color mutedButtonColor: card
    readonly property color mutedButtonHoverColor: cardHover
    readonly property color mutedButtonTextColor: text
    readonly property color controlHoverColor: hover
    readonly property color controlPressedColor: pressed
    readonly property color accentColor: accent
    readonly property color accentDarkColor: accentPressed
    readonly property color accentSoftColor: accentSoft
    readonly property color selectedColor: accent
    readonly property color errorTextColor: error
    readonly property color errorBorderColor: errorBorder
    readonly property color errorBgColor: errorBg

    // Geometry & Radius constants
    readonly property real radiusSmall: 8
    readonly property real radiusControl: 10
    readonly property real radiusCard: 14
    readonly property real radiusPill: 20

    // Animation timings
    readonly property int motion: 150
    readonly property int animationDuration: 150

    // Typography (Modern sans-serif Inter throughout)
    readonly property FontLoader textFont: FontLoader {
        source: "qrc:/resources/fonts/InterVariable.ttf"
    }

    readonly property string fontFamily: textFont.status === FontLoader.Ready ? textFont.name : "Inter"
    readonly property string textFontFamily: fontFamily
    readonly property string titleFontFamily: fontFamily
    readonly property string interFontFamily: fontFamily
    readonly property string loraFontFamily: fontFamily
}
