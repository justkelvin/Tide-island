#include "UserConfigBackend.h"

#include <QFile>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

class UserConfigBackendTests final : public QObject {
    Q_OBJECT

private slots:
    void defaultsAreBackwardCompatible();
    void dashboardSettingsAreValidatedAndBounded();
};

void UserConfigBackendTests::defaultsAreBackwardCompatible()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());

    UserConfigBackend config;
    QCOMPARE(config.restingContent(), QStringLiteral("clock"));
    QCOMPARE(config.idleHoverContent(), QStringLiteral("informationDashboard"));
    QVERIFY(config.restingDashboardEnabled());
    QCOMPARE(config.restingDashboardHoverDelayMs(), 350);
    QVERIFY(config.restingDashboardItems().contains(QStringLiteral("date")));
    QVERIFY(config.restingDashboardItems().contains(QStringLiteral("cpu")));
    QVERIFY(!config.weatherEnabled());
    QCOMPARE(config.weatherProvider(), QStringLiteral("none"));
    QCOMPARE(config.weatherUnits(), QStringLiteral("metric"));
    QCOMPARE(config.weatherRefreshIntervalMs(), 1800000);
}

void UserConfigBackendTests::dashboardSettingsAreValidatedAndBounded()
{
    QTemporaryDir configHome;
    QVERIFY(configHome.isValid());
    qputenv("XDG_CONFIG_HOME", configHome.path().toLocal8Bit());
    const QString directory = configHome.path() + QStringLiteral("/tide-island");
    QVERIFY(QDir().mkpath(directory));

    QJsonObject object{
        {QStringLiteral("restingContent"), QStringLiteral("unsupported")},
        {QStringLiteral("idleHoverContent"), QStringLiteral("none")},
        {QStringLiteral("restingDashboardEnabled"), false},
        {QStringLiteral("restingDashboardItems"), QJsonArray{QStringLiteral("date"), QStringLiteral("date"), QStringLiteral("invalid"), QStringLiteral("workspace")}},
        {QStringLiteral("restingDashboardHoverDelayMs"), 9000},
        {QStringLiteral("weatherEnabled"), true},
        {QStringLiteral("weatherProvider"), QStringLiteral("mock")},
        {QStringLiteral("weatherUnits"), QStringLiteral("imperial")},
        {QStringLiteral("weatherRefreshIntervalMs"), 1000},
        {QStringLiteral("unknownFutureKey"), QStringLiteral("preserved-by-settings-app")},
    };
    QFile file(directory + QStringLiteral("/userconfig.json"));
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(QJsonDocument(object).toJson());
    file.close();

    UserConfigBackend config;
    QCOMPARE(config.restingContent(), QStringLiteral("clock"));
    QCOMPARE(config.idleHoverContent(), QStringLiteral("none"));
    QVERIFY(!config.restingDashboardEnabled());
    QCOMPARE(config.restingDashboardItems(), QVariantList({QStringLiteral("date"), QStringLiteral("workspace")}));
    QCOMPARE(config.restingDashboardHoverDelayMs(), 2000);
    QVERIFY(config.weatherEnabled());
    QCOMPARE(config.weatherProvider(), QStringLiteral("mock"));
    QCOMPARE(config.weatherUnits(), QStringLiteral("imperial"));
    QCOMPARE(config.weatherRefreshIntervalMs(), 900000);
}

QTEST_MAIN(UserConfigBackendTests)
#include "user_config_backend_tests.moc"
