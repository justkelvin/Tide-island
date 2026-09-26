#include "diagnostics.hpp"

#include <QDateTime>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QProcess>

namespace {
constexpr auto notificationsService = "org.freedesktop.Notifications";
constexpr auto notificationsPath = "/org/freedesktop/Notifications";
constexpr auto notificationsInterface = "org.freedesktop.Notifications";
constexpr auto dbusService = "org.freedesktop.DBus";
constexpr auto dbusPath = "/org/freedesktop/DBus";
constexpr auto dbusInterface = "org.freedesktop.DBus";
constexpr auto tideService = "tide-island";
constexpr int dbusTimeoutMs = 2500;
constexpr int processTimeoutMs = 5000;
}

Diagnostics::Diagnostics(QObject *parent)
    : QObject(parent)
{
}

bool Diagnostics::serverOwned() const
{
    return m_serverOwned;
}

QString Diagnostics::serverOwner() const
{
    return m_serverOwner;
}

QString Diagnostics::serverName() const
{
    return m_serverName;
}

QString Diagnostics::serverVendor() const
{
    return m_serverVendor;
}

QString Diagnostics::serverVersion() const
{
    return m_serverVersion;
}

QString Diagnostics::serverSpecVersion() const
{
    return m_serverSpecVersion;
}

bool Diagnostics::serverIsTideIsland() const
{
    return m_serverOwned && isTideIslandServer(m_serverName, m_serverVendor);
}

QString Diagnostics::serviceActive() const
{
    return m_serviceActive;
}

QString Diagnostics::serviceEnabled() const
{
    return m_serviceEnabled;
}

QString Diagnostics::logText() const
{
    return m_logText;
}

QString Diagnostics::lastUpdated() const
{
    return m_lastUpdated;
}

bool Diagnostics::busy() const
{
    return m_busy;
}

QString Diagnostics::errorString() const
{
    return m_errorString;
}

void Diagnostics::refresh()
{
    if (m_busy)
        return;
    m_busy = true;
    emit changed();

    refreshServerStatus();
    refreshServiceStatus();
    refreshLogs();

    m_lastUpdated = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));
    m_busy = false;
    emit changed();
}

QString Diagnostics::normalizeState(const QString &raw)
{
    const QString state = raw.trimmed();
    return state.isEmpty() ? QStringLiteral("unknown") : state;
}

bool Diagnostics::isTideIslandServer(const QString &name, const QString &vendor)
{
    return name.compare(QStringLiteral("Tide Island"), Qt::CaseInsensitive) == 0
        && vendor.compare(QStringLiteral("justkelvin"), Qt::CaseInsensitive) == 0;
}

void Diagnostics::refreshServerStatus()
{
    m_serverOwned = false;
    m_serverOwner.clear();
    m_serverName.clear();
    m_serverVendor.clear();
    m_serverVersion.clear();
    m_serverSpecVersion.clear();

    const QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        setErrorString(QStringLiteral("Could not connect to the session bus."));
        return;
    }

    QDBusInterface dbus(QString::fromLatin1(dbusService),
                        QString::fromLatin1(dbusPath),
                        QString::fromLatin1(dbusInterface), bus);
    dbus.setTimeout(dbusTimeoutMs);
    const QDBusReply<bool> ownedReply = dbus.call(QStringLiteral("NameHasOwner"),
                                                  QString::fromLatin1(notificationsService));
    if (!ownedReply.isValid()) {
        setErrorString(QStringLiteral("NameHasOwner failed: %1").arg(ownedReply.error().message()));
        return;
    }
    if (!ownedReply.value()) {
        setErrorString(QString());
        return;
    }

    m_serverOwned = true;
    const QDBusReply<QString> ownerReply = dbus.call(QStringLiteral("GetNameOwner"),
                                                     QString::fromLatin1(notificationsService));
    if (ownerReply.isValid())
        m_serverOwner = ownerReply.value();

    QDBusInterface server(QString::fromLatin1(notificationsService),
                          QString::fromLatin1(notificationsPath),
                          QString::fromLatin1(notificationsInterface), bus);
    server.setTimeout(dbusTimeoutMs);
    const QDBusMessage infoReply = server.call(QStringLiteral("GetServerInformation"));
    if (infoReply.type() == QDBusMessage::ReplyMessage && infoReply.arguments().size() == 4) {
        m_serverName = infoReply.arguments().at(0).toString();
        m_serverVendor = infoReply.arguments().at(1).toString();
        m_serverVersion = infoReply.arguments().at(2).toString();
        m_serverSpecVersion = infoReply.arguments().at(3).toString();
    }
    setErrorString(QString());
}

void Diagnostics::refreshServiceStatus()
{
    m_serviceActive = normalizeState(runCommand(QStringLiteral("systemctl"),
                                                {QStringLiteral("--user"), QStringLiteral("is-active"),
                                                 QString::fromLatin1(tideService)},
                                                processTimeoutMs));
    m_serviceEnabled = normalizeState(runCommand(QStringLiteral("systemctl"),
                                                 {QStringLiteral("--user"), QStringLiteral("is-enabled"),
                                                  QString::fromLatin1(tideService)},
                                                 processTimeoutMs));
}

void Diagnostics::refreshLogs()
{
    const QString output = runCommand(QStringLiteral("journalctl"),
                                      {QStringLiteral("--user"), QStringLiteral("-u"),
                                       QString::fromLatin1(tideService), QStringLiteral("-n"),
                                       QStringLiteral("80"), QStringLiteral("--no-pager")},
                                      processTimeoutMs);
    m_logText = output.isEmpty() ? QStringLiteral("(no log output)") : output;
}

void Diagnostics::setErrorString(const QString &errorString)
{
    if (m_errorString == errorString)
        return;
    m_errorString = errorString;
}

QString Diagnostics::runCommand(const QString &program, const QStringList &arguments, int timeoutMs)
{
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.start();
    if (!process.waitForFinished(timeoutMs) || process.exitStatus() != QProcess::NormalExit)
        return QString();
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}
