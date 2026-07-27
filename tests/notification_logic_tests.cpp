#include <QFile>
#include <QJSValue>
#include <QJSEngine>
#include <QtTest>

class NotificationLogicTests final : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void multilineAndProvenance();
    void bodyPresentation();
    void replacementAndHistoryCap();
    void expirationPolicy();
    void dndPolicy();

private:
    QJSValue call(const QString &name, const QJSValueList &arguments = {});

    QJSEngine m_engine;
};

void NotificationLogicTests::initTestCase()
{
    QFile source(QStringLiteral(NOTIFICATION_LOGIC_SOURCE));
    QVERIFY2(source.open(QIODevice::ReadOnly | QIODevice::Text), qPrintable(source.errorString()));
    QString script = QString::fromUtf8(source.readAll());
    script.remove(QStringLiteral(".pragma library"));
    const QJSValue result = m_engine.evaluate(script, source.fileName());
    QVERIFY2(!result.isError(), qPrintable(result.toString()));
}

QJSValue NotificationLogicTests::call(const QString &name, const QJSValueList &arguments)
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

void NotificationLogicTests::multilineAndProvenance()
{
    const QString original = QStringLiteral("cleverpush.com\nLine one\nLine two\nEmoji 👋\nمرحبا");
    const QJSValue result = call(QStringLiteral("domainProvenance"), {original});
    QCOMPARE(result.property(QStringLiteral("source")).toString(), QStringLiteral("cleverpush.com"));
    QCOMPARE(result.property(QStringLiteral("body")).toString(),
             QStringLiteral("Line one\nLine two\nEmoji 👋\nمرحبا"));

    const QString message = QStringLiteral("Keep <b>literal</b> &amp; text\nwith newlines");
    const QJSValue unchanged = call(QStringLiteral("domainProvenance"), {message});
    QCOMPARE(unchanged.property(QStringLiteral("body")).toString(), message);
    QVERIFY(unchanged.property(QStringLiteral("source")).toString().isEmpty());
}

void NotificationLogicTests::bodyPresentation()
{
    const QJSValue bodyOnly = call(
        QStringLiteral("presentationText"),
        {QString(), QStringLiteral("Line one\nLine two\nLine three"), QStringLiteral("Notification")}
    );
    QCOMPARE(bodyOnly.property(QStringLiteral("title")).toString(), QStringLiteral("Line one"));
    QCOMPARE(bodyOnly.property(QStringLiteral("body")).toString(), QStringLiteral("Line two\nLine three"));

    const QJSValue titled = call(
        QStringLiteral("presentationText"),
        {QStringLiteral("Title"), QStringLiteral("Line one\nLine two"), QStringLiteral("Notification")}
    );
    QCOMPARE(titled.property(QStringLiteral("title")).toString(), QStringLiteral("Title"));
    QCOMPARE(titled.property(QStringLiteral("body")).toString(), QStringLiteral("Line one\nLine two"));

    const QJSValue singleLine = call(
        QStringLiteral("presentationText"),
        {QString(), QStringLiteral("Only body"), QStringLiteral("Notification")}
    );
    QCOMPARE(singleLine.property(QStringLiteral("title")).toString(), QStringLiteral("Only body"));
    QVERIFY(singleLine.property(QStringLiteral("body")).toString().isEmpty());
}

void NotificationLogicTests::replacementAndHistoryCap()
{
    QJSValue entries = m_engine.newArray();
    QJSValue first = m_engine.newObject();
    first.setProperty(QStringLiteral("notificationId"), 7);
    first.setProperty(QStringLiteral("body"), QStringLiteral("10%"));
    first.setProperty(QStringLiteral("inHistory"), true);
    entries.setProperty(0, first);

    QJSValue replacement = m_engine.newObject();
    replacement.setProperty(QStringLiteral("notificationId"), 7);
    replacement.setProperty(QStringLiteral("body"), QStringLiteral("90%"));
    replacement.setProperty(QStringLiteral("inHistory"), true);

    QJSValue result = call(QStringLiteral("upsertSnapshots"), {entries, replacement, 50});
    QCOMPARE(result.property(QStringLiteral("length")).toInt(), 1);
    QCOMPARE(result.property(0).property(QStringLiteral("body")).toString(), QStringLiteral("90%"));

    for (int index = 0; index < 55; ++index) {
        QJSValue snapshot = m_engine.newObject();
        snapshot.setProperty(QStringLiteral("notificationId"), index + 100);
        snapshot.setProperty(QStringLiteral("inHistory"), true);
        result = call(QStringLiteral("upsertSnapshots"), {result, snapshot, 50});
    }
    QCOMPARE(result.property(QStringLiteral("length")).toInt(), 50);
}

void NotificationLogicTests::expirationPolicy()
{
    QCOMPARE(call(QStringLiteral("effectiveExpirationInterval"), {-1, QStringLiteral("normal")}).toInt(), 7000);
    QCOMPARE(call(QStringLiteral("effectiveExpirationInterval"), {0, QStringLiteral("normal")}).toInt(), 0);
    QCOMPARE(call(QStringLiteral("effectiveExpirationInterval"), {-1, QStringLiteral("critical")}).toInt(), 0);
    QCOMPARE(call(QStringLiteral("effectiveExpirationInterval"), {1250, QStringLiteral("critical")}).toInt(), 1250);
    QCOMPARE(call(QStringLiteral("popupDisplayTimeout"), {-1, QStringLiteral("critical")}).toInt(), 0);
    QCOMPARE(call(QStringLiteral("popupDisplayTimeout"), {9000, QStringLiteral("critical")}).toInt(), 9000);
    QCOMPARE(call(QStringLiteral("popupDisplayTimeout"), {9000, QStringLiteral("normal")}).toInt(), 4200);
}

void NotificationLogicTests::dndPolicy()
{
    QVERIFY(call(QStringLiteral("shouldShowPopup"), {false}).toBool());
    QVERIFY(!call(QStringLiteral("shouldShowPopup"), {true}).toBool());
}

QTEST_MAIN(NotificationLogicTests)
#include "notification_logic_tests.moc"
