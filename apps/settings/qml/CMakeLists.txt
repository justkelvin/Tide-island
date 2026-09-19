set_source_files_properties(Theme.qml ConfigStore.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(tide-island-config-app
    URI TideIsland
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml

    QML_FILES
        Main.qml
        Theme.qml
        ConfigStore.qml
        pages/General.qml
        pages/FontSettings.qml
        pages/Interaction.qml
        pages/Shortcut.qml
        components/PagePanel.qml
        components/ConfigTextField.qml
        components/CustomPage.qml
)

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/TideIsland
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml
    PATTERN "*.qrc" EXCLUDE
)
