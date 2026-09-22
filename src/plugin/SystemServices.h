#pragma once

#include <QObject>
#include <QByteArray>
#include <QProcess>
#include <QSet>
#include <QString>
#include <QTimer>
#include <QVariant>
#include <QVariantList>
#include <QtQml/qqml.h>

#include <functional>

class SystemServices final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool screenRecordingActive READ screenRecordingActive NOTIFY screenRecordingActiveChanged FINAL)
    Q_PROPERTY(QVariantList cavaLevels READ cavaLevels NOTIFY cavaLevelsChanged FINAL)

public:
    explicit SystemServices(QObject *parent = nullptr);
    ~SystemServices() override;

    bool screenRecordingActive() const;
    QVariantList cavaLevels() const;

    Q_INVOKABLE void requestScreenRecordingSnapshot();
    Q_INVOKABLE void requestHyprlandSnapshot(const QString &requestId, const QString &subject);
    Q_INVOKABLE void requestBrightness();
    Q_INVOKABLE void setBrightness(double value);
    Q_INVOKABLE void requestVolume();
    Q_INVOKABLE void setVolume(double value);
    Q_INVOKABLE void requestSystemStats();
    Q_INVOKABLE double storageUsage() const;
    Q_INVOKABLE void requestStorage();
    Q_INVOKABLE void setCavaClientActive(const QString &clientId, bool active);
    Q_INVOKABLE void ensureUserConfigAvailable();
    Q_INVOKABLE void playTimerAlarm();

signals:
    void screenRecordingActiveChanged();
    void hyprlandSnapshotReady(const QString &requestId,
                               const QString &subject,
                               const QString &payloadJson,
                               const QString &errorString);
    void brightnessSnapshotReady(double value, const QString &errorString);
    void brightnessSetFinished(double value, bool success, const QString &errorString);
    void volumeSnapshotReady(double value, bool muted, const QString &errorString);
    void volumeSetFinished(double value, bool success, const QString &errorString);
    void systemStatsReady(double cpuUsage, double ramUsage, const QString &errorString);
    void storageSnapshotReady(double value, const QString &errorString);
    void cavaLevelsChanged();

private:
    struct CommandResult {
        int exitCode = -1;
        QProcess::ExitStatus exitStatus = QProcess::NormalExit;
        QByteArray stdoutData;
        QByteArray stderrData;
        QString errorString;
        bool timedOut = false;
    };

    using CommandCallback = std::function<void(const CommandResult &)>;

    QProcess *startCommand(const QString &program,
                           const QStringList &arguments,
                           int timeoutMs,
                           CommandCallback callback,
                           const QByteArray &stdinData = QByteArray());
    QString findExecutable(const QString &program) const;
    QString commandErrorText(const QString &program, const CommandResult &result) const;

    void startPipeWireMonitor();
    void startRecordingPortalMonitor();
    void stopProcess(QProcess *&process);
    void setPortalPipeWireActive(bool active);
    void updateScreenRecordingActive();

    void handlePipeWireOutput();
    void handleRecordingPortalOutput();
    void processLines(QByteArray &buffer, const QByteArray &chunk, const std::function<void(const QString &)> &handler);
    void handlePipeWireLine(const QString &line);
    void handleRecordingPortalLine(const QString &line);
    void applyPipeWireSnapshot(const QString &text);

    QString extractHeaderPath(const QString &line) const;
    QString extractObjectPath(const QString &line) const;
    bool screenCastMemberHasSessionArgument(const QString &memberName) const;
    bool pipeWireBlockLooksLikeScreenCast(const QString &blockText) const;

    double parseBrightnessOutput(const QString &text, bool *ok) const;
    void parseVolumeOutput(const QString &text, double *value, bool *muted, bool *ok) const;

    void startCava();
    void stopCava();
    void handleCavaOutput();
    void handleCavaLine(const QString &line);

    bool m_shuttingDown = false;

    QProcess *m_pipeWireMonitor = nullptr;
    QProcess *m_recordingPortalMonitor = nullptr;
    QProcess *m_recordingSnapshot = nullptr;
    QProcess *m_cavaProcess = nullptr;

    QTimer m_pipeWireRestartTimer;
    QTimer m_recordingPortalRestartTimer;
    QTimer m_recordingSnapshotDebounceTimer;
    QTimer m_cavaRestartTimer;

    QByteArray m_pipeWireBuffer;
    QByteArray m_recordingPortalBuffer;
    QByteArray m_cavaBuffer;

    bool m_screenRecordingActive = false;
    bool m_portalPipeWireActive = false;
    QSet<QString> m_activeScreenCastSessions;
    QString m_pendingScreenCastMember;
    QString m_pendingSessionCandidate;

    qint64 m_lastCpuTotal = -1;
    qint64 m_lastCpuIdle = -1;

    QVariantList m_cavaLevels;
    QSet<QString> m_cavaClients;
    bool m_cavaMissingWarned = false;
    bool m_configAppLaunchRequested = false;
};
