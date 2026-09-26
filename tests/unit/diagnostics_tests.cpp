#include "diagnostics.hpp"

#include <QSignalSpy>
#include <QTest>

class DiagnosticsTests : public QObject {
    Q_OBJECT

private slots:
    void normalizeStateTrimsAndFallsBack();
    void tideIslandDetectionIsCaseInsensitive();
    void refreshCompletesAndUpdates();
};

void DiagnosticsTests::normalizeStateTrimsAndFallsBack()
{
    QCOMPARE(Diagnostics::normalizeState(QStringLiteral("active\n")), QStringLiteral("active"));
    QCOMPARE(Diagnostics::normalizeState(QStringLiteral("  inactive  ")), QStringLiteral("inactive"));
    QCOMPARE(Diagnostics::normalizeState(QString()), QStringLiteral("unknown"));
    QCOMPARE(Diagnostics::normalizeState(QStringLiteral("   ")), QStringLiteral("unknown"));
}

void DiagnosticsTests::tideIslandDetectionIsCaseInsensitive()
{
    QVERIFY(Diagnostics::isTideIslandServer(QStringLiteral("Tide Island"), QStringLiteral("justkelvin")));
    QVERIFY(Diagnostics::isTideIslandServer(QStringLiteral("tide island"), QStringLiteral("JustKelvin")));
    QVERIFY(!Diagnostics::isTideIslandServer(QStringLiteral("dunst"), QStringLiteral("knopwob")));
    QVERIFY(!Diagnostics::isTideIslandServer(QStringLiteral("Tide Island"), QStringLiteral("other")));
    QVERIFY(!Diagnostics::isTideIslandServer(QString(), QString()));
}

void DiagnosticsTests::refreshCompletesAndUpdates()
{
    Diagnostics diagnostics;
    QSignalSpy changed(&diagnostics, &Diagnostics::changed);
    diagnostics.refresh();
    QVERIFY(!diagnostics.busy());
    QVERIFY(!diagnostics.lastUpdated().isEmpty());
    QVERIFY(changed.size() >= 2);
    // Service/log probes degrade gracefully, never crash or stay busy.
    QVERIFY(!diagnostics.serviceActive().isEmpty());
    QVERIFY(!diagnostics.logText().isEmpty());
}

QTEST_MAIN(DiagnosticsTests)
#include "diagnostics_tests.moc"
