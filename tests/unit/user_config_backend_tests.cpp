#include <QtTest/QtTest>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QSignalSpy>

#include "UserConfigBackend.h"

class UserConfigBackendTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        // Ensure clean test environment
    }

    void testDefaultValues() {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        qputenv("XDG_CONFIG_HOME", tempDir.path().toUtf8());

        UserConfigBackend config;

        QCOMPARE(config.islandWidth(), 140);
        QCOMPARE(config.islandHeight(), 38);
        QCOMPARE(config.islandTopMargin(), 4);
        QCOMPARE(config.islandBackgroundOpacity(), 60);
        QCOMPARE(config.islandExclusiveZone(), 45);
        QCOMPARE(config.islandPositionX(), 50);
        QCOMPARE(config.islandAutoHideEnabled(), true);
        QCOMPARE(config.islandAutoHideDelayMs(), 1000);
        QCOMPARE(config.islandShowWorkspaceOnAutoHide(), true);
        QCOMPARE(config.cleanNotificationUrls(), true);
        QCOMPARE(config.clockFormat(), QStringLiteral("12"));
        QCOMPARE(config.dynamicIslandPrimaryButton(), 1);
        QCOMPARE(config.dynamicIslandPrimaryAction(), QStringLiteral("toggleExpandedPlayer"));
        QCOMPARE(config.dynamicIslandSecondaryButton(), 3);
        QCOMPARE(config.iconFontFamily(), QStringLiteral("JetBrainsMono Nerd Font"));
        QCOMPARE(config.textFontFamily(), QStringLiteral("Inter Display"));
        QVERIFY(config.configError().isEmpty());
    }

    void testJsonWithCommentsAndClamping() {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        qputenv("XDG_CONFIG_HOME", tempDir.path().toUtf8());

        const QString tideDir = tempDir.path() + QStringLiteral("/tide-island");
        QDir().mkpath(tideDir);
        const QString configPath = tideDir + QStringLiteral("/userconfig.json");

        QFile file(configPath);
        QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Text));

        // Write JSON containing both single-line and block comments, plus out-of-bound values
        const QByteArray jsonContent =
            "{\n"
            "    // Appearance settings\n"
            "    \"islandWidth\": 180,\n"
            "    \"islandHeight\": 42,\n"
            "    /* Background opacity clamped 0-100 */\n"
            "    \"islandBackgroundOpacity\": 150,\n"
            "    /* Auto hide delay clamped 100-10000 */\n"
            "    \"islandAutoHideDelayMs\": 50,\n"
            "    \"cleanNotificationUrls\": false,\n"
            "    \"clockFormat\": \"24\",\n"
            "    \"dynamicIslandPrimaryButton\": 2\n"
            "}\n";
        file.write(jsonContent);
        file.close();

        UserConfigBackend config;

        QCOMPARE(config.islandWidth(), 180);
        QCOMPARE(config.islandHeight(), 42);
        // 150 clamped to 100
        QCOMPARE(config.islandBackgroundOpacity(), 100);
        // 50 clamped to minimum 100
        QCOMPARE(config.islandAutoHideDelayMs(), 100);
        QCOMPARE(config.cleanNotificationUrls(), false);
        QCOMPARE(config.clockFormat(), QStringLiteral("24"));
        QCOMPARE(config.dynamicIslandPrimaryButton(), 2);
        QVERIFY(config.configError().isEmpty());
    }

    void testMouseButtonsMapping() {
        UserConfigBackend config;

        QCOMPARE(config.mouseButton(1), static_cast<int>(Qt::LeftButton));
        QCOMPARE(config.mouseButton(2), static_cast<int>(Qt::MiddleButton));
        QCOMPARE(config.mouseButton(3), static_cast<int>(Qt::RightButton));
        QCOMPARE(config.mouseButton(QStringLiteral("left")), static_cast<int>(Qt::LeftButton));
        QCOMPARE(config.mouseButton(QStringLiteral("right")), static_cast<int>(Qt::RightButton));
        QCOMPARE(config.mouseButton(QStringLiteral("middle")), static_cast<int>(Qt::MiddleButton));
        QCOMPARE(config.mouseButton(99), 99);
        QCOMPARE(config.mouseButton(QStringLiteral("invalid")), static_cast<int>(Qt::NoButton));

        const QVariantList buttons = {1, 3};
        const int expectedMask = Qt::LeftButton | Qt::RightButton;
        QCOMPARE(config.mouseButtonsMask(buttons), expectedMask);
    }
};

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
