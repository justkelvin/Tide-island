cmake_minimum_required(VERSION 3.16)
project(TideIsland VERSION 1.0.35 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network DBus Test Concurrent)
find_library(UDEV_LIB NAMES udev REQUIRED)

add_executable(lyricsmpris
    src/daemons/lyricsmpris/main.cpp
    src/daemons/lyricsmpris/CjkVariantNormalizer.h
    src/daemons/lyricsmpris/CjkVariantNormalizer.cpp
    src/daemons/lyricsmpris/LyricsCore.h
    src/daemons/lyricsmpris/LyricsCore.cpp
    src/daemons/lyricsmpris/ProviderNetworkPolicy.h
    src/daemons/lyricsmpris/LyricsMprisApp.h
    src/daemons/lyricsmpris/LyricsMprisApp.cpp
)

target_include_directories(lyricsmpris PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/daemons/lyricsmpris
)

target_link_libraries(lyricsmpris PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::DBus
)

add_subdirectory(apps/settings)

# Main Native Plugin Module (Combining all C++ components)
qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend
    SOURCES
        src/plugin/SysBackend.h
        src/plugin/SysBackend.cpp
        src/plugin/SystemServices.h
        src/plugin/SystemServices.cpp
        src/plugin/StyleTokensBackend.h
        src/plugin/StyleTokensBackend.cpp
        src/plugin/UserConfigBackend.h
        src/plugin/UserConfigBackend.cpp
)

# The QML plugin is installed below lib/qt6/qml/IslandBackend while its backing
# library lives directly in lib. Keep installed packages independent of the
# build tree and make the relationship relocatable.
set_target_properties(IslandBackendplugin PROPERTIES
    INSTALL_RPATH "\$ORIGIN/../../.."
)

target_include_directories(IslandBackend PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/plugin
)

target_link_libraries(IslandBackend PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
    Qt6::DBus
    Qt6::Concurrent
    ${UDEV_LIB}
)

enable_testing()
add_subdirectory(tests)

# Installation Rules
include(GNUInstallDirs)

# Install Quickshell entry points and QML component folders to /usr/share/tide-island
install(FILES
    shell.qml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island
)
install(DIRECTORY qml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island
    FILES_MATCHING
        PATTERN "*.qml"
        PATTERN "*.js"
        PATTERN "*.svg"
        PATTERN "*.json"
)

# Install IslandBackend backing library to /usr/lib
install(TARGETS IslandBackend
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install IslandBackend plugin to Qt6 QML directory
install(TARGETS IslandBackendplugin
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install qmldir and other generated files for IslandBackend
install(FILES 
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/IslandBackend.qmltypes
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
)


# Install launcher
configure_file(packaging/tide-island-launcher ${CMAKE_CURRENT_BINARY_DIR}/tide-island @ONLY)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/tide-island DESTINATION ${CMAKE_INSTALL_BINDIR})

# Install helper executables
install(TARGETS lyricsmpris
    RUNTIME DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island/bin
)

# Install desktop entry
install(FILES packaging/tide-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# Install systemd user service
install(FILES packaging/tide-island.service DESTINATION lib/systemd/user)
