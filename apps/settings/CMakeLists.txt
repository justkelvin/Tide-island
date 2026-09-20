cmake_minimum_required(VERSION 3.16)
project(tide-island-config-app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS
    Gui
    Qml
    Quick
    QuickControls2
    QuickDialogs2
    Svg
    Core5Compat
)

qt_policy(SET QTP0004 NEW)

set_source_files_properties(
    qml/Theme.qml
    qml/ConfigStore.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_executable(tide-island-config-app
    src/main.cpp
    src/backend.hpp
    src/backend.cpp
    resources.qrc
)

qt_add_qml_module(tide-island-config-app
    URI TideIsland
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml

    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/ConfigStore.qml
        qml/pages/General.qml
        qml/pages/FontSettings.qml
        qml/pages/Interaction.qml
        qml/pages/Shortcut.qml
        qml/components/PagePanel.qml
        qml/components/ConfigTextField.qml
        qml/components/CustomPage.qml
        qml/components/ActionButton.qml
        qml/components/TideSwitch.qml
        qml/components/TideSlider.qml
        qml/components/SegmentedControl.qml
        qml/components/CardGroup.qml
        qml/components/SettingRow.qml
        qml/components/CardDivider.qml
        qml/components/SvgIcon.qml
)

target_include_directories(tide-island-config-app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(tide-island-config-app PRIVATE
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
    Qt6::Svg
    Qt6::Core5Compat
)

install(TARGETS tide-island-config-app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES tide-island-config.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/TideIsland
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml
    PATTERN "*.qrc" EXCLUDE
)
