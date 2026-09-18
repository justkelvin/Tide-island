#include "backend.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>
#include <QTest>

namespace {
bool writeTextFile(const QString &path, const QByteArray &contents, QFileDevice::Permissions permissions = {})
{
    QFileInfo info(path);
    if (!QDir().mkpath(info.absolutePath()))
        return false;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
        return false;
    file.write(contents);
    file.close();

    if (permissions != QFileDevice::Permissions{})
        return file.setPermissions(permissions);
    return true;
}

QString readTextFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return QString();
    return QString::fromUtf8(file.readAll());
}
}

class ShortcutConfigTests : public QObject {
    Q_OBJECT

private slots:
    void defaultsDoNotIncludeWorkspaceOverview();
    void defaultsCycleIslandViewsWithArrowKeys();
    void legacyArrowShortcutsMigrateToBidirectionalCycle();
    void defaultsIncludeNotificationHistory();
    void disabledShortcutPersistsAndIsNotGenerated();
    void disabledShortcutUpdatesActiveHyprlandLuaBlock();
    void configAppColorSchemePersists();
};

void ShortcutConfigTests::defaultsDoNotIncludeWorkspaceOverview()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    QCOMPARE(backend.compositorDisplayName(), QStringLiteral("Hyprland"));

    bool foundOverview = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundOverview = foundOverview
            || (binding.value(QStringLiteral("target")).toString() == QStringLiteral("overview")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("toggle"));
    }
    QVERIFY(!foundOverview);
}

void ShortcutConfigTests::defaultsCycleIslandViewsWithArrowKeys()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    bool foundNextView = false;
    bool foundPreviousView = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundNextView = foundNextView
            || (binding.value(QStringLiteral("mods")).toString() == QStringLiteral("SUPER")
                && binding.value(QStringLiteral("key")).toString() == QStringLiteral("right")
                && binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("swipeRight"));
        foundPreviousView = foundPreviousView
            || (binding.value(QStringLiteral("mods")).toString() == QStringLiteral("SUPER")
                && binding.value(QStringLiteral("key")).toString() == QStringLiteral("left")
                && binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("swipeLeft"));
    }

    QVERIFY(foundNextView);
    QVERIFY(foundPreviousView);
}

void ShortcutConfigTests::legacyArrowShortcutsMigrateToBidirectionalCycle()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    QVariantMap config;
    config.insert(QStringLiteral("shortcutBindings"), QVariantList{
        QVariantMap{
            {QStringLiteral("mods"), QStringLiteral("SUPER")},
            {QStringLiteral("key"), QStringLiteral("right")},
            {QStringLiteral("target"), QStringLiteral("tide")},
            {QStringLiteral("method"), QStringLiteral("showLyrics")},
        },
        QVariantMap{
            {QStringLiteral("mods"), QStringLiteral("SUPER")},
            {QStringLiteral("key"), QStringLiteral("left")},
            {QStringLiteral("target"), QStringLiteral("tide")},
            {QStringLiteral("method"), QStringLiteral("showCustom")},
        },
    });
    QVERIFY(backend.save(config));

    Backend reloaded;
    bool migratedRight = false;
    bool migratedLeft = false;
    for (const QVariant &value : reloaded.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        migratedRight = migratedRight
            || (binding.value(QStringLiteral("key")).toString() == QStringLiteral("right")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("swipeRight"));
        migratedLeft = migratedLeft
            || (binding.value(QStringLiteral("key")).toString() == QStringLiteral("left")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("swipeLeft"));
    }

    QVERIFY(migratedRight);
    QVERIFY(migratedLeft);
}

void ShortcutConfigTests::defaultsIncludeNotificationHistory()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    Backend backend;
    bool foundNotificationHistory = false;
    for (const QVariant &value : backend.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        foundNotificationHistory = foundNotificationHistory
            || (binding.value(QStringLiteral("mods")).toString() == QStringLiteral("SUPER")
                && binding.value(QStringLiteral("key")).toString() == QStringLiteral("N")
                && binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
                && binding.value(QStringLiteral("method")).toString() == QStringLiteral("toggleNotificationCenter"));
    }
    QVERIFY(foundNotificationHistory);
}

void ShortcutConfigTests::configAppColorSchemePersists()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    Backend backend;
    QCOMPARE(backend.colorScheme(), QStringLiteral("light"));
    backend.setColorScheme(QStringLiteral("dark"));
    QCOMPARE(backend.colorScheme(), QStringLiteral("dark"));

    Backend reloaded;
    QCOMPARE(reloaded.colorScheme(), QStringLiteral("dark"));
    reloaded.setColorScheme(QStringLiteral("unsupported"));
    QCOMPARE(reloaded.colorScheme(), QStringLiteral("light"));
}

void ShortcutConfigTests::disabledShortcutPersistsAndIsNotGenerated()
{
    QTemporaryDir configHome;
    QTemporaryDir fakeBin;
    QVERIFY(configHome.isValid());
    QVERIFY(fakeBin.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", fakeBin.path().toLocal8Bit() + ':' + originalPath);
    QVERIFY(writeTextFile(fakeBin.path() + QStringLiteral("/hyprctl"),
        "#!/bin/sh\nexit 0\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    Backend backend;
    QVariantList bindings = backend.shortcutBindings();
    bool disabledPlayer = false;
    for (QVariant &value : bindings) {
        QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
            && binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            binding.insert(QStringLiteral("mods"), QString());
            binding.insert(QStringLiteral("key"), QString());
            value = binding;
            disabledPlayer = true;
        }
    }
    QVERIFY(disabledPlayer);

    QVariantMap config;
    config.insert(QStringLiteral("shortcutBindings"), bindings);
    QVERIFY(backend.save(config));

    Backend reloaded;
    bool foundDisabledPlayer = false;
    for (const QVariant &value : reloaded.shortcutBindings()) {
        const QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("target")).toString() == QStringLiteral("tide")
            && binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            QVERIFY(binding.value(QStringLiteral("mods")).toString().isEmpty());
            QVERIFY(binding.value(QStringLiteral("key")).toString().isEmpty());
            foundDisabledPlayer = true;
        }
    }
    QVERIFY(foundDisabledPlayer);

    QVERIFY(reloaded.applyShortcutBindings(reloaded.shortcutBindings()));
    const QString managedConfig = readTextFile(configHome.path() + QStringLiteral("/tide-island/hyprland-shortcuts.conf"));
    QVERIFY(managedConfig.contains(QStringLiteral("toggleNotificationCenter")));
    QVERIFY(!managedConfig.contains(QStringLiteral("togglePlayer")));

    qputenv("PATH", originalPath);
}

void ShortcutConfigTests::disabledShortcutUpdatesActiveHyprlandLuaBlock()
{
    QTemporaryDir configHome;
    QTemporaryDir fakeBin;
    QVERIFY(configHome.isValid());
    QVERIFY(fakeBin.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    qputenv("TIDE_ISLAND_COMPOSITOR", "hyprland");

    const QByteArray originalPath = qgetenv("PATH");
    qputenv("PATH", fakeBin.path().toLocal8Bit() + ':' + originalPath);
    QVERIFY(writeTextFile(fakeBin.path() + QStringLiteral("/hyprctl"),
        "#!/bin/sh\n"
        "if test \"$1\" = binds; then echo 'dispatcher: __lua'; fi\n"
        "exit 0\n",
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner));

    const QString luaConfig = configHome.path() + QStringLiteral("/hypr/hyprland.lua");
    QVERIFY(writeTextFile(luaConfig,
        "local preserved = true\n\n"
        "-- Tide Island shortcuts.\n"
        "-- legacy generated block\n"
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"old player\"))\n\n"
        "for i = 1, 10 do\n"
        "    local key = i % 10\n"
        "end\n"));

    Backend backend;
    QVariantList bindings = backend.shortcutBindings();
    for (QVariant &value : bindings) {
        QVariantMap binding = value.toMap();
        if (binding.value(QStringLiteral("method")).toString() == QStringLiteral("togglePlayer")) {
            binding.insert(QStringLiteral("mods"), QString());
            binding.insert(QStringLiteral("key"), QString());
            value = binding;
        }
    }
    QVERIFY(backend.applyShortcutBindings(bindings));

    const QString updatedLua = readTextFile(luaConfig);
    QVERIFY(updatedLua.contains(QStringLiteral("local preserved = true")));
    QVERIFY(updatedLua.contains(QStringLiteral("Tide Island shortcuts: begin")));
    QVERIFY(updatedLua.contains(QStringLiteral("for i = 1, 10 do")));
    QVERIFY(updatedLua.contains(QStringLiteral("toggleNotificationCenter")));
    QVERIFY(!updatedLua.contains(QStringLiteral("togglePlayer")));

    qputenv("PATH", originalPath);
}

QTEST_GUILESS_MAIN(ShortcutConfigTests)

#include "shortcut_config_tests.moc"
