#pragma once

#include <QObject>
#include <QString>

// Live debug info for the native notification server and the user service.
// Blocking calls use short timeouts; refresh() is safe to call on demand.
class Diagnostics final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool serverOwned READ serverOwned NOTIFY changed)
    Q_PROPERTY(QString serverOwner READ serverOwner NOTIFY changed)
    Q_PROPERTY(QString serverName READ serverName NOTIFY changed)
    Q_PROPERTY(QString serverVendor READ serverVendor NOTIFY changed)
    Q_PROPERTY(QString serverVersion READ serverVersion NOTIFY changed)
    Q_PROPERTY(QString serverSpecVersion READ serverSpecVersion NOTIFY changed)
    Q_PROPERTY(bool serverIsTideIsland READ serverIsTideIsland NOTIFY changed)
    Q_PROPERTY(QString serviceActive READ serviceActive NOTIFY changed)
    Q_PROPERTY(QString serviceEnabled READ serviceEnabled NOTIFY changed)
    Q_PROPERTY(QString logText READ logText NOTIFY changed)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString errorString READ errorString NOTIFY changed)

public:
    explicit Diagnostics(QObject *parent = nullptr);

    bool serverOwned() const;
    QString serverOwner() const;
    QString serverName() const;
    QString serverVendor() const;
    QString serverVersion() const;
    QString serverSpecVersion() const;
    bool serverIsTideIsland() const;
    QString serviceActive() const;
    QString serviceEnabled() const;
    QString logText() const;
    QString lastUpdated() const;
    bool busy() const;
    QString errorString() const;

    Q_INVOKABLE void refresh();

    // Pure helpers (unit-tested).
    static QString normalizeState(const QString &raw);
    static bool isTideIslandServer(const QString &name, const QString &vendor);

signals:
    void changed();

private:
    void refreshServerStatus();
    void refreshServiceStatus();
    void refreshLogs();
    void setErrorString(const QString &errorString);
    static QString runCommand(const QString &program, const QStringList &arguments, int timeoutMs);

    bool m_serverOwned = false;
    QString m_serverOwner;
    QString m_serverName;
    QString m_serverVendor;
    QString m_serverVersion;
    QString m_serverSpecVersion;
    QString m_serviceActive = QStringLiteral("unknown");
    QString m_serviceEnabled = QStringLiteral("unknown");
    QString m_logText;
    QString m_lastUpdated;
    QString m_errorString;
    bool m_busy = false;
};
