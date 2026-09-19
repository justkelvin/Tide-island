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
    Test
)

qt_policy(SET QTP0004 NEW)

qt_add_executable(tide-island-config-app
    src/main.cpp
    src/backend.hpp
    src/backend.cpp
    resources.qrc
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
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/shortcut_config_tests.cpp")
    add_executable(tide_island_shortcut_config_tests
        tests/shortcut_config_tests.cpp
        src/backend.hpp
        src/backend.cpp
    )

    target_include_directories(tide_island_shortcut_config_tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )

    target_link_libraries(tide_island_shortcut_config_tests PRIVATE
        Qt6::Gui
        Qt6::Test
    )

    add_test(NAME tide_island_shortcut_config COMMAND tide_island_shortcut_config_tests)
endif()

add_subdirectory(qml)

install(TARGETS tide-island-config-app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES tide-island-config.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

add_test(NAME tide_island_config_qml
    COMMAND tide-island-config-app --validate-qml
)
set_tests_properties(tide_island_config_qml PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
