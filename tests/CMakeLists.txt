cmake_minimum_required(VERSION 3.16)

# ==============================================================================
# Tide Island Test Suites
# ==============================================================================

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    DBus
    Network
    Test
)

# ------------------------------------------------------------------------------
# Unit Tests
# ------------------------------------------------------------------------------

# UserConfigBackend Unit Tests
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/user_config_backend_tests.cpp")
    add_executable(user_config_backend_tests
        unit/user_config_backend_tests.cpp
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.h
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.cpp
    )

    target_include_directories(user_config_backend_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/src/plugin
    )

    target_link_libraries(user_config_backend_tests PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Test
    )

    add_test(NAME user_config_backend COMMAND user_config_backend_tests)
endif()

# Shortcut Config Unit Tests (Settings App Backend)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/shortcut_config_tests.cpp")
    add_executable(tide_island_shortcut_config_tests
        unit/shortcut_config_tests.cpp
        ${CMAKE_SOURCE_DIR}/apps/settings/src/backend.hpp
        ${CMAKE_SOURCE_DIR}/apps/settings/src/backend.cpp
    )

    target_include_directories(tide_island_shortcut_config_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/apps/settings/src
    )

    target_link_libraries(tide_island_shortcut_config_tests PRIVATE
        Qt6::Gui
        Qt6::Test
    )

    add_test(NAME tide_island_shortcut_config COMMAND tide_island_shortcut_config_tests)
endif()

# Diagnostics Unit Tests (Settings App Diagnostics Backend)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/diagnostics_tests.cpp")
    add_executable(tide_island_diagnostics_tests
        unit/diagnostics_tests.cpp
        ${CMAKE_SOURCE_DIR}/apps/settings/src/diagnostics.hpp
        ${CMAKE_SOURCE_DIR}/apps/settings/src/diagnostics.cpp
    )

    target_include_directories(tide_island_diagnostics_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/apps/settings/src
    )

    target_link_libraries(tide_island_diagnostics_tests PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Test
    )

    add_test(NAME tide_island_diagnostics COMMAND tide_island_diagnostics_tests)
endif()

# Optional LyricsCore Unit Tests (if present)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/lyricsmpris_core_tests.cpp")
    add_executable(lyricsmpris_tests
        unit/lyricsmpris_core_tests.cpp
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris/CjkVariantNormalizer.h
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris/CjkVariantNormalizer.cpp
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris/LyricsCore.h
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris/LyricsCore.cpp
    )

    target_include_directories(lyricsmpris_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris
    )

    target_link_libraries(lyricsmpris_tests PRIVATE
        Qt6::Core
        Qt6::Test
    )

    add_test(NAME lyricsmpris_core COMMAND lyricsmpris_tests)
endif()

# ------------------------------------------------------------------------------
# Integration / Runtime Tests
# ------------------------------------------------------------------------------

find_package(Qt6 REQUIRED COMPONENTS QuickTest)
add_executable(tide_island_qml_tests helpers/qml_test_runner.cpp)
target_link_libraries(tide_island_qml_tests PRIVATE Qt6::QuickTest)
add_dependencies(tide_island_qml_tests IslandBackendplugin)
add_test(NAME countdown_qml
    COMMAND tide_island_qml_tests
        -input "${CMAKE_CURRENT_SOURCE_DIR}/qml"
        -import "${CMAKE_BINARY_DIR}"
)
set_tests_properties(countdown_qml PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
    TIMEOUT 30
)

# LyricsMPRIS D-Bus Runtime Tests
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/lyricsmpris_runtime_tests.cpp" AND TARGET lyricsmpris)
    add_executable(lyricsmpris_runtime_tests
        unit/lyricsmpris_runtime_tests.cpp
    )

    target_link_libraries(lyricsmpris_runtime_tests PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Network
        Qt6::Test
    )

    target_include_directories(lyricsmpris_runtime_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/src/daemons/lyricsmpris
    )

    add_dependencies(lyricsmpris_runtime_tests lyricsmpris)

    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    add_test(
        NAME lyricsmpris_runtime
        COMMAND "${DBUS_RUN_SESSION_EXECUTABLE}" --
            "${CMAKE_COMMAND}" -E env
            TIDE_ISLAND_RUNTIME_TEST_ISOLATED=1
            "LYRICSMPRIS_TEST_EXECUTABLE=$<TARGET_FILE:lyricsmpris>"
            "$<TARGET_FILE:lyricsmpris_runtime_tests>"
    )
    set_tests_properties(lyricsmpris_runtime PROPERTIES TIMEOUT 20)
endif()

# Native Notification Server Unit Tests (isolated bus via dbus-run-session)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/unit/notification_server_tests.cpp")
    add_executable(notification_server_tests
        unit/notification_server_tests.cpp
        ${CMAKE_SOURCE_DIR}/src/plugin/NotificationServer.h
        ${CMAKE_SOURCE_DIR}/src/plugin/NotificationServer.cpp
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.h
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.cpp
    )

    target_include_directories(notification_server_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/src/plugin
    )

    target_link_libraries(notification_server_tests PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::DBus
        Qt6::Test
    )

    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    add_test(
        NAME notification_server
        COMMAND "${DBUS_RUN_SESSION_EXECUTABLE}" --
            "${CMAKE_COMMAND}" -E env
            TIDE_ISLAND_NOTIFICATIONS_TEST_BUS=1
            "$<TARGET_FILE:notification_server_tests>"
    )
    set_tests_properties(notification_server PROPERTIES TIMEOUT 60)
endif()

# Notification Server Live Harness (host process for the DBus script)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/helpers/notification_server_harness.cpp")
    add_executable(notification_server_harness
        helpers/notification_server_harness.cpp
        ${CMAKE_SOURCE_DIR}/src/plugin/NotificationServer.h
        ${CMAKE_SOURCE_DIR}/src/plugin/NotificationServer.cpp
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.h
        ${CMAKE_SOURCE_DIR}/src/plugin/UserConfigBackend.cpp
    )

    target_include_directories(notification_server_harness PRIVATE
        ${CMAKE_SOURCE_DIR}/src/plugin
    )

    target_link_libraries(notification_server_harness PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::DBus
    )

    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    find_program(GDBUS_EXECUTABLE NAMES gdbus REQUIRED)
    find_program(NOTIFY_SEND_EXECUTABLE NAMES notify-send REQUIRED)
    find_program(DBUS_MONITOR_EXECUTABLE NAMES dbus-monitor REQUIRED)
    find_program(PYTHON3_PROGRAM NAMES python3 REQUIRED)
    add_test(
        NAME notification_server_live
        COMMAND "${DBUS_RUN_SESSION_EXECUTABLE}" --
            "${CMAKE_COMMAND}" -E env
            "PATH=$ENV{PATH}"
            "${PYTHON3_PROGRAM}"
            "${CMAKE_SOURCE_DIR}/scripts/test_dbus_notifications.py"
            --harness "$<TARGET_FILE:notification_server_harness>"
    )
    set_tests_properties(notification_server_live PROPERTIES TIMEOUT 90)
endif()

# Settings App QML Validation Test
if(TARGET tide-island-config-app)
    add_test(NAME tide_island_config_qml
        COMMAND tide-island-config-app --validate-qml
    )
    set_tests_properties(tide_island_config_qml PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
endif()
