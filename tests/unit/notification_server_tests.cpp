#include <QtTest/QtTest>
#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "NotificationServer.h"
#include "UserConfigBackend.h"

namespace {

constexpr auto kService = "org.freedesktop.Notifications";
constexpr auto kPath = "/org/freedesktop/Notifications";
constexpr auto kInterface = "org.freedesktop.Notifications";

bool isolatedBusAvailable() {
    return qEnvironmentVariableIsSet("TIDE_ISLAND_NOTIFICATIONS_TEST_BUS");
}

QVariantMap hintsWithUrgency(int level) {
    QVariantMap hints;
    hints.insert(QStringLiteral("urgency"), static_cast<uint>(level));
    return hints;
}

FdoImageData makeTestImage() {
    FdoImageData raw;
    raw.width = 2;
    raw.height = 2;
    raw.rowstride = 2 * 4;
    raw.hasAlpha = true;
    raw.bitsPerSample = 8;
    raw.channels = 4;
    // 2x2 RGBA pixels: red, green, blue, white.
    const uchar pixels[] = {
        255, 0, 0, 255, 0, 255, 0, 255,
        0, 0, 255, 255, 255, 255, 255, 255,
    };
    raw.data = QByteArray(reinterpret_cast<const char *>(pixels), sizeof(pixels));
    return raw;
}

} // namespace

class NotificationServerTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() {
        qDBusRegisterMetaType<FdoImageData>();
        // Isolate UserConfigBackend from the real ~/.config so the URL-flag
        // tests are deterministic (absent file -> cleanNotificationUrls=true).
        QVERIFY(m_configDir.isValid());
        qputenv("XDG_CONFIG_HOME", m_configDir.path().toUtf8());
    }

    void serverInformationIsConformant() {
        NotificationServer server(nullptr, false);
        const QVariantMap info = server.serverInformation();
        QCOMPARE(info.value(QStringLiteral("name")).toString(), QStringLiteral("Tide Island"));
        QCOMPARE(info.value(QStringLiteral("vendor")).toString(), QStringLiteral("justkelvin"));
        QCOMPARE(info.value(QStringLiteral("version")).toString(), QStringLiteral("1.0.0"));
        QCOMPARE(info.value(QStringLiteral("specVersion")).toString(), QStringLiteral("1.2"));
    }

    void capabilitiesAreConformant() {
        NotificationServer server(nullptr, false);
        const QStringList caps = server.GetCapabilities();
        for (const QString &expected : {QStringLiteral("actions"), QStringLiteral("body"),
                                        QStringLiteral("body-hyperlinks"), QStringLiteral("body-markup"),
                                        QStringLiteral("body-images"), QStringLiteral("icon-static"),
                                        QStringLiteral("image-path"), QStringLiteral("image-data"),
                                        QStringLiteral("persistence"), QStringLiteral("inline-reply")}) {
            QVERIFY2(caps.contains(expected), qPrintable(QStringLiteral("missing: ") + expected));
        }
    }

    void sanitizerStripsHtmlAndEntities() {
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("<b>Hello</b> <i>world</i>"), false),
                 QStringLiteral("Hello world"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("&quot;Hi&quot; &amp; &lt;tag&gt;&nbsp;end"), false),
                 QStringLiteral("\"Hi\" & <tag> end"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("  lots   \n  space\t\tgap "), false),
                 QStringLiteral("lots space gap"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(QString(), false), QString());
        QCOMPARE(NotificationServer::sanitizeNotificationText(QStringLiteral("plain"), false),
                 QStringLiteral("plain"));
    }

    void sanitizerStripsUrlsWhenEnabled() {
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("visit https://example.com/x now"), true),
                 QStringLiteral("visit now"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("see www.example.com/x here"), true),
                 QStringLiteral("see here"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("<a href=\"https://x\">example.com</a> real text"), true),
                 QStringLiteral("real text"));
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("visit https://example.com/x now"), false),
                 QStringLiteral("visit https://example.com/x now"));
    }

    void sanitizerFallsBackForLinkOnlyText() {
        QCOMPARE(NotificationServer::sanitizeNotificationText(
                     QStringLiteral("https://example.com"), true),
                 QStringLiteral("https://example.com"));
    }

    void notifyCleansAllTextFields() {
        NotificationServer server(nullptr, false);
        const uint id = server.Notify(QStringLiteral("<b> noisy app </b>"), 0, QString(),
                                      QStringLiteral("<b>Title</b> https://example.com/x"),
                                      QStringLiteral("<i>Body</i> &amp; more"), {}, {}, 60000);
        const QVariantMap item = server.getNotification(id);
        QCOMPARE(item.value(QStringLiteral("appName")).toString(), QStringLiteral("noisy app"));
        QCOMPARE(item.value(QStringLiteral("summary")).toString(), QStringLiteral("Title"));
        QCOMPARE(item.value(QStringLiteral("body")).toString(), QStringLiteral("Body & more"));
    }

    void notifyHonorsDisabledUrlCleaning() {
        const QString tideDir = m_configDir.path() + QStringLiteral("/tide-island");
        QVERIFY(QDir().mkpath(tideDir));
        QFile configFile(tideDir + QStringLiteral("/userconfig.json"));
        QVERIFY(configFile.open(QIODevice::WriteOnly | QIODevice::Text));
        configFile.write("{\"cleanNotificationUrls\": false}");
        configFile.close();

        UserConfigBackend::instance()->reload();
        QCOMPARE(UserConfigBackend::instance()->cleanNotificationUrls(), false);

        NotificationServer server(nullptr, false);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(),
                                      QStringLiteral("see https://example.com/x"),
                                      QStringLiteral("b"), {}, {}, 60000);
        QCOMPARE(server.getNotification(id).value(QStringLiteral("summary")).toString(),
                 QStringLiteral("see https://example.com/x"));

        QFile::remove(tideDir + QStringLiteral("/userconfig.json"));
        UserConfigBackend::instance()->reload();
        QCOMPARE(UserConfigBackend::instance()->cleanNotificationUrls(), true);
    }

    void idsAreMonotonicAndNonZero() {
        NotificationServer server(nullptr, false);
        const uint first = server.Notify(QStringLiteral("App"), 0, QString(), QStringLiteral("A"),
                                         QStringLiteral("Body"), {}, {}, -1);
        const uint second = server.Notify(QStringLiteral("App"), 0, QString(), QStringLiteral("B"),
                                          QStringLiteral("Body"), {}, {}, -1);
        const uint third = server.Notify(QStringLiteral("App"), 0, QString(), QStringLiteral("C"),
                                         QStringLiteral("Body"), {}, {}, -1);
        QVERIFY(first != 0);
        QVERIFY(second != 0);
        QVERIFY(third != 0);
        QVERIFY(second > first);
        QVERIFY(third > second);
        QCOMPARE(server.activeCount(), 3);
        QCOMPARE(server.rowCount(), 3);
    }

    void replacesIdUpdatesInPlace() {
        NotificationServer server(nullptr, false);
        QSignalSpy added(&server, &NotificationServer::notificationAdded);
        QSignalSpy updated(&server, &NotificationServer::notificationUpdated);

        const uint id = server.Notify(QStringLiteral("App"), 0, QString(), QStringLiteral("Title"),
                                      QStringLiteral("v1"), {}, {}, 60000);
        QCOMPARE(added.size(), 1);
        QCOMPARE(server.activeCount(), 1);

        const uint same = server.Notify(QStringLiteral("App"), id, QString(), QStringLiteral("Title"),
                                        QStringLiteral("v2"), {}, {}, 60000);
        QCOMPARE(same, id);
        QCOMPARE(server.activeCount(), 1);
        QCOMPARE(updated.size(), 1);
        QCOMPARE(server.getNotification(id).value(QStringLiteral("body")).toString(),
                 QStringLiteral("v2"));
    }

    void replacesUnknownIdAllocatesNew() {
        NotificationServer server(nullptr, false);
        const uint id = server.Notify(QStringLiteral("App"), 424242, QString(), QStringLiteral("T"),
                                      QStringLiteral("B"), {}, {}, 60000);
        QVERIFY(id != 424242);
        QVERIFY(id != 0);
        QVERIFY(server.contains(id));
    }

    void urgencyHintParsing() {
        NotificationServer server(nullptr, false);

        const uint low = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                       QStringLiteral("b"), {}, hintsWithUrgency(0), 60000);
        const uint normal = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                          QStringLiteral("b"), {}, hintsWithUrgency(1), 60000);
        const uint critical = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                            QStringLiteral("b"), {}, hintsWithUrgency(2), 60000);
        const uint missing = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                           QStringLiteral("b"), {}, {}, 60000);

        QCOMPARE(server.getNotification(low).value(QStringLiteral("urgency")).toInt(), 0);
        QCOMPARE(server.getNotification(normal).value(QStringLiteral("urgency")).toInt(), 1);
        QCOMPARE(server.getNotification(critical).value(QStringLiteral("urgency")).toInt(), 2);
        QCOMPARE(server.getNotification(missing).value(QStringLiteral("urgency")).toInt(), 1);
    }

    void imagePathHintParsing() {
        NotificationServer server(nullptr, false);
        QVariantMap hints;
        hints.insert(QStringLiteral("image-path"), QStringLiteral("/tmp/preview.png"));
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, hints, 60000);
        QCOMPARE(server.getNotification(id).value(QStringLiteral("imagePath")).toString(),
                 QStringLiteral("/tmp/preview.png"));

        QVariantMap legacy;
        legacy.insert(QStringLiteral("image_path"), QStringLiteral("/tmp/legacy.png"));
        const uint legacyId = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                            QStringLiteral("b"), {}, legacy, 60000);
        QCOMPARE(server.getNotification(legacyId).value(QStringLiteral("imagePath")).toString(),
                 QStringLiteral("/tmp/legacy.png"));
    }

    void imageDataHintDecodesToDataUrl() {
        NotificationServer server(nullptr, false);
        QVariantMap hints;
        hints.insert(QStringLiteral("image-data"), QVariant::fromValue(makeTestImage()));
        const uint id = server.Notify(QStringLiteral("Discord"), 0, QString(), QStringLiteral("Msg"),
                                      QStringLiteral("hello"), {}, hints, 60000);
        const QString url = server.getNotification(id).value(QStringLiteral("imageDataUrl")).toString();
        QVERIFY2(url.startsWith(QStringLiteral("data:image/png;base64,")),
                 qPrintable(QStringLiteral("got: ") + url.left(64)));
    }

    void progressValueHintParsing() {
        NotificationServer server(nullptr, false);
        QVariantMap hints;
        hints.insert(QStringLiteral("value"), 72);
        const uint id = server.Notify(QStringLiteral("Chrome"), 0, QString(), QStringLiteral("DL"),
                                      QStringLiteral("file"), {}, hints, 60000);
        QCOMPARE(server.getNotification(id).value(QStringLiteral("progress")).toInt(), 72);

        const uint absent = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                          QStringLiteral("b"), {}, {}, 60000);
        QCOMPARE(server.getNotification(absent).value(QStringLiteral("progress")).toInt(), -1);
    }

    void residentTransientAndReplyHints() {
        NotificationServer server(nullptr, false);
        QVariantMap hints;
        hints.insert(QStringLiteral("resident"), true);
        hints.insert(QStringLiteral("transient"), true);
        hints.insert(QStringLiteral("desktop-entry"), QStringLiteral("discord"));
        hints.insert(QStringLiteral("category"), QStringLiteral("im.received"));
        hints.insert(QStringLiteral("x-kde-reply-placeholder"), QStringLiteral("Reply..."));
        const int historyBefore = server.history().size();
        const uint id = server.Notify(QStringLiteral("Discord"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, hints, 60000);
        const QVariantMap item = server.getNotification(id);
        QCOMPARE(item.value(QStringLiteral("resident")).toBool(), true);
        QCOMPARE(item.value(QStringLiteral("transient")).toBool(), true);
        QCOMPARE(item.value(QStringLiteral("desktopEntry")).toString(), QStringLiteral("discord"));
        QCOMPARE(item.value(QStringLiteral("category")).toString(), QStringLiteral("im.received"));
        QCOMPARE(item.value(QStringLiteral("replyPlaceholder")).toString(), QStringLiteral("Reply..."));
        // Transient notifications bypass history.
        QCOMPARE(server.history().size(), historyBefore);
    }

    void expiryEmitsClosedReasonExpired() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, {}, 60);
        QVERIFY(closed.wait(3000));
        QCOMPARE(closed.size(), 1);
        QCOMPARE(closed.at(0).at(0).toUInt(), id);
        QCOMPARE(closed.at(0).at(1).toUInt(), 1u);
        QVERIFY(!server.contains(id));
    }

    void defaultTimeoutUsesServerDefault() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, {}, -1);
        // Default is 5s; must still be alive well before that.
        QTest::qWait(200);
        QVERIFY(server.contains(id));
        QCOMPARE(closed.size(), 0);
        server.dismissNotification(id);
    }

    void persistentTimeoutNeverExpires() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, {}, 0);
        QTest::qWait(200);
        QVERIFY(server.contains(id));
        QCOMPARE(closed.size(), 0);
        server.dismissNotification(id);
    }

    void criticalUrgencyPersists() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, hintsWithUrgency(2), 80);
        QTest::qWait(250);
        QVERIFY2(server.contains(id), "critical notification must ignore expiry timers");
        QCOMPARE(closed.size(), 0);
        server.dismissNotification(id);
    }

    void closeNotificationEmitsReasonClosedByCall() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        QSignalSpy removed(&server, &NotificationServer::notificationRemoved);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, {}, 60000);
        server.CloseNotification(id);
        QCOMPARE(closed.size(), 1);
        QCOMPARE(closed.at(0).at(0).toUInt(), id);
        QCOMPARE(closed.at(0).at(1).toUInt(), 3u);
        QCOMPARE(removed.size(), 1);
        QCOMPARE(removed.at(0).at(1).toUInt(), 3u);
        QVERIFY(!server.contains(id));
    }

    void closeUnknownIdIsNoop() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        server.CloseNotification(999999);
        QCOMPARE(closed.size(), 0);
    }

    void userDismissalEmitsReasonDismissed() {
        NotificationServer server(nullptr, false);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"), {}, {}, 60000);
        server.dismissNotification(id);
        QCOMPARE(closed.size(), 1);
        QCOMPARE(closed.at(0).at(1).toUInt(), 2u);
        QVERIFY(!server.contains(id));
    }

    void invokeActionEmitsAndDismissesUnlessResident() {
        NotificationServer server(nullptr, false);
        QSignalSpy invoked(&server, &NotificationServer::ActionInvoked);

        const uint id = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                      QStringLiteral("b"),
                                      {QStringLiteral("reply"), QStringLiteral("Reply")}, {}, 60000);
        server.invokeAction(id, QStringLiteral("reply"));
        QCOMPARE(invoked.size(), 1);
        QCOMPARE(invoked.at(0).at(0).toUInt(), id);
        QCOMPARE(invoked.at(0).at(1).toString(), QStringLiteral("reply"));
        QVERIFY(!server.contains(id)); // non-resident dismisses

        QVariantMap residentHints;
        residentHints.insert(QStringLiteral("resident"), true);
        const uint residentId = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("t"),
                                              QStringLiteral("b"),
                                              {QStringLiteral("default"), QStringLiteral("Open")},
                                              residentHints, 60000);
        server.invokeAction(residentId, QStringLiteral("default"));
        QCOMPARE(invoked.size(), 2);
        QVERIFY(server.contains(residentId)); // resident stays
        server.dismissNotification(residentId);
    }

    void clearAllDismissesEverything() {
        NotificationServer server(nullptr, false);
        server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("1"), QString(), {}, {}, 60000);
        server.Notify(QStringLiteral("B"), 0, QString(), QStringLiteral("2"), QString(), {}, {}, 60000);
        QCOMPARE(server.activeCount(), 2);
        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        server.clearAllNotifications();
        QCOMPARE(server.activeCount(), 0);
        QCOMPARE(closed.size(), 2);
    }

    void removeHistoryItemRemovesSingleEntry() {
        NotificationServer server(nullptr, false);
        QSignalSpy changed(&server, &NotificationServer::historyChanged);
        const uint first = server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("one"),
                                         QString(), {}, {}, 60000);
        const uint second = server.Notify(QStringLiteral("B"), 0, QString(), QStringLiteral("two"),
                                          QString(), {}, {}, 60000);
        QCOMPARE(server.history().size(), 2);
        server.removeHistoryItem(second);
        QCOMPARE(server.history().size(), 1);
        QCOMPARE(server.history().at(0).toMap().value(QStringLiteral("id")).toUInt(), first);
        QVERIFY(changed.size() >= 1);
        // Unknown id is a no-op.
        const int before = server.history().size();
        server.removeHistoryItem(999999);
        QCOMPARE(server.history().size(), before);
    }

    void clearHistoryEmptiesHistoryOnly() {
        NotificationServer server(nullptr, false);
        QSignalSpy changed(&server, &NotificationServer::historyChanged);
        server.Notify(QStringLiteral("A"), 0, QString(), QStringLiteral("1"), QString(), {}, {}, 60000);
        server.Notify(QStringLiteral("B"), 0, QString(), QStringLiteral("2"), QString(), {}, {}, 60000);
        QCOMPARE(server.history().size(), 2);
        QCOMPARE(server.activeCount(), 2);
        server.clearHistory();
        QCOMPARE(server.history().size(), 0);
        // Active notifications stay; clearAllNotifications() is a separate call.
        QCOMPARE(server.activeCount(), 2);
        QVERIFY(changed.size() >= 1);
        server.clearAllNotifications();
    }

    void modelRolesExposeNotificationFields() {
        NotificationServer server(nullptr, false);
        const uint id = server.Notify(QStringLiteral("Discord"), 0, QStringLiteral("discord"),
                                      QStringLiteral("Ping"), QStringLiteral("hey"), {}, {}, 60000);
        QCOMPARE(server.rowCount(), 1);
        const QModelIndex row = server.index(0, 0);
        QVERIFY(row.isValid());
        QCOMPARE(server.data(row, NotificationServer::IdRole).toUInt(), id);
        QCOMPARE(server.data(row, NotificationServer::AppNameRole).toString(),
                 QStringLiteral("Discord"));
        QCOMPARE(server.data(row, NotificationServer::SummaryRole).toString(),
                 QStringLiteral("Ping"));
        QVERIFY(server.roleNames().value(NotificationServer::SummaryRole) == "summary");
    }

    void dbusSanitizedTextRoundTrip() {
        // End-to-end over the wire is covered by dbusRoundTripOnIsolatedBus;
        // here assert the direct-call path cleans markup (default flag on).
        NotificationServer server(nullptr, false);
        const uint id = server.Notify(QStringLiteral("A"), 0, QString(),
                                      QStringLiteral("<b>Wired</b>"), QStringLiteral("x"),
                                      {}, {}, 60000);
        QCOMPARE(server.getNotification(id).value(QStringLiteral("summary")).toString(),
                 QStringLiteral("Wired"));
    }

    void dbusRoundTripOnIsolatedBus() {
        if (!isolatedBusAvailable())
            QSKIP("Set TIDE_ISLAND_NOTIFICATIONS_TEST_BUS=1 under dbus-run-session to run the live bus test");

        NotificationServer server(nullptr, true);
        QVERIFY2(server.isRegistered(), "server must own org.freedesktop.Notifications on the isolated bus");

        QDBusInterface iface(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                             QString::fromLatin1(kInterface), QDBusConnection::sessionBus());
        QVERIFY2(iface.isValid(), qPrintable(iface.lastError().message()));

        QDBusMessage infoReply = iface.call(QStringLiteral("GetServerInformation"));
        QVERIFY2(infoReply.type() == QDBusMessage::ReplyMessage,
                 qPrintable(infoReply.errorMessage()));
        QCOMPARE(infoReply.arguments().size(), 4);
        QCOMPARE(infoReply.arguments().at(0).toString(), QStringLiteral("Tide Island"));
        QCOMPARE(infoReply.arguments().at(3).toString(), QStringLiteral("1.2"));

        QDBusMessage capsReply = iface.call(QStringLiteral("GetCapabilities"));
        QVERIFY(capsReply.type() == QDBusMessage::ReplyMessage);
        QVERIFY(capsReply.arguments().at(0).toStringList().contains(QStringLiteral("actions")));

        QSignalSpy added(&server, &NotificationServer::notificationAdded);
        QDBusMessage notifyReply = iface.call(
            QStringLiteral("Notify"), QStringLiteral("BusApp"), uint(0), QString(),
            QStringLiteral("BusTitle"), QStringLiteral("BusBody"), QStringList(),
            QVariantMap(), int(-1));
        QVERIFY2(notifyReply.type() == QDBusMessage::ReplyMessage,
                 qPrintable(notifyReply.errorMessage()));
        const uint id = notifyReply.arguments().at(0).toUInt();
        QVERIFY(id != 0);
        QCOMPARE(added.size(), 1);
        QVERIFY(server.contains(id));

        QSignalSpy closed(&server, &NotificationServer::NotificationClosed);
        QDBusMessage closeReply = iface.call(QStringLiteral("CloseNotification"), id);
        QVERIFY(closeReply.type() == QDBusMessage::ReplyMessage);
        QCOMPARE(closed.size(), 1);
        QCOMPARE(closed.at(0).at(1).toUInt(), 3u);
    }

private:
    QTemporaryDir m_configDir;
};

QTEST_MAIN(NotificationServerTests)
#include "notification_server_tests.moc"
