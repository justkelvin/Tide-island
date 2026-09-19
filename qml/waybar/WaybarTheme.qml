import QtCore
import QtQuick
import Quickshell.Io
import IslandBackend

Item {
    id: root

    property color mainBackground: StyleTokens.black

    function refresh() {
        const css = waybarThemeFile.text();
        const match = css.match(/@define-color\s+main-bg\s+(#[0-9a-fA-F]{6})\s*;/);
        if (match)
            mainBackground = match[1];
    }

    FileView {
        id: waybarThemeFile

        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/waybar/theme.css"
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.refresh()
        onTextChanged: root.refresh()
    }
}
