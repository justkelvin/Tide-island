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

# Settings App QML Validation Test
if(TARGET tide-island-config-app)
    add_test(NAME tide_island_config_qml
        COMMAND tide-island-config-app --validate-qml
    )
    set_tests_properties(tide_island_config_qml PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )
endif()
