#include <QFile>
#include <QJSEngine>
#include <QJSValue>
#include <QtTest>

class RestingPresentationTests final : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void mediaValidity_data();
    void mediaValidity();
    void hoverRouting_data();
    void hoverRouting();
    void visibilityGating();

private:
    QJSValue call(const QString &name, const QJSValueList &arguments = {});
    QJSEngine m_engine;
};

void RestingPresentationTests::initTestCase()
{
    QFile source(QStringLiteral(RESTING_PRESENTATION_LOGIC_SOURCE));
    QVERIFY2(source.open(QIODevice::ReadOnly | QIODevice::Text), qPrintable(source.errorString()));
    QString script = QString::fromUtf8(source.readAll());
    script.remove(QStringLiteral(".pragma library"));
    const QJSValue result = m_engine.evaluate(script, source.fileName());
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
}

QJSValue RestingPresentationTests::call(const QString &name, const QJSValueList &arguments)
{
    const QJSValue function = m_engine.globalObject().property(name);
    if (!function.isCallable()) {
        QTest::qFail(qPrintable(name + QStringLiteral(" is not callable")), __FILE__, __LINE__);
        return {};
    }
    const QJSValue result = function.call(arguments);
    if (result.isError()) {
        QTest::qFail(qPrintable(result.toString()), __FILE__, __LINE__);
        return {};
    }
    return result;
}

void RestingPresentationTests::mediaValidity_data()
{
    QTest::addColumn<bool>("hasPlayer");
    QTest::addColumn<bool>("playbackSupported");
    QTest::addColumn<QString>("title");
    QTest::addColumn<QString>("url");
    QTest::addColumn<bool>("expected");

    QTest::newRow("missing-player") << false << false << QString() << QString() << false;
    QTest::newRow("stopped-player") << true << false << QStringLiteral("Track") << QString() << false;
    QTest::newRow("playing-with-title") << true << true << QStringLiteral("Track") << QString() << true;
    QTest::newRow("paused-with-title") << true << true << QStringLiteral("Track") << QString() << true;
    QTest::newRow("stale-browser-track-id-only") << true << true << QString() << QString() << false;
    QTest::newRow("url-only-metadata") << true << true << QString() << QStringLiteral("file:///music.ogg") << false;
}

void RestingPresentationTests::mediaValidity()
{
    QFETCH(bool, hasPlayer);
    QFETCH(bool, playbackSupported);
    QFETCH(QString, title);
    QFETCH(QString, url);
    QFETCH(bool, expected);

    const bool useful = call(QStringLiteral("hasUsefulMediaMetadata"), {title, url}).toBool();
    QCOMPARE(call(QStringLiteral("hasPresentableMedia"), {hasPlayer, playbackSupported, useful}).toBool(), expected);
}

void RestingPresentationTests::hoverRouting_data()
{
    QTest::addColumn<QString>("state");
    QTest::addColumn<int>("legacyAction");
    QTest::addColumn<bool>("dashboardEnabled");
    QTest::addColumn<QString>("idleContent");
    QTest::addColumn<bool>("media");
    QTest::addColumn<QString>("expected");

    QTest::newRow("idle-dashboard") << "normal" << 1 << true << "informationDashboard" << false << "dashboard";
    QTest::newRow("playing-media") << "normal" << 1 << true << "informationDashboard" << true << "media";
    QTest::newRow("paused-media") << "lyrics" << 1 << true << "informationDashboard" << true << "media";
    QTest::newRow("legacy-control-center") << "normal" << 2 << true << "informationDashboard" << false << "controlCenter";
    QTest::newRow("disabled") << "normal" << 0 << true << "informationDashboard" << false << "none";
    QTest::newRow("dashboard-disabled") << "normal" << 1 << false << "informationDashboard" << false << "none";
    QTest::newRow("notification-blocks") << "notification" << 1 << true << "informationDashboard" << true << "none";
    QTest::newRow("utility-blocks") << "control_center" << 1 << true << "informationDashboard" << false << "none";
}

void RestingPresentationTests::hoverRouting()
{
    QFETCH(QString, state);
    QFETCH(int, legacyAction);
    QFETCH(bool, dashboardEnabled);
    QFETCH(QString, idleContent);
    QFETCH(bool, media);
    QFETCH(QString, expected);

    QCOMPARE(call(QStringLiteral("hoverTarget"), {state, legacyAction, dashboardEnabled, idleContent, media}).toString(), expected);
}

void RestingPresentationTests::visibilityGating()
{
    QVERIFY(!call(QStringLiteral("shouldPollSystemStats"), {false, false, true}).toBool());
    QVERIFY(!call(QStringLiteral("shouldPollSystemStats"), {false, true, false}).toBool());
    QVERIFY(call(QStringLiteral("shouldPollSystemStats"), {true, false, false}).toBool());
    QVERIFY(call(QStringLiteral("shouldPollSystemStats"), {false, true, true}).toBool());
    QVERIFY(!call(QStringLiteral("shouldPollStorage"), {false, true}).toBool());
    QVERIFY(call(QStringLiteral("shouldPollStorage"), {true, true}).toBool());
}

QTEST_MAIN(RestingPresentationTests)
#include "resting_presentation_tests.moc"
