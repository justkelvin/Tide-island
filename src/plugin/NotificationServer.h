#pragma once

#include <QAbstractListModel>
#include <QByteArray>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QHash>
#include <QImage>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqml.h>

class QQmlEngine;
class QJSEngine;

// Raw in-memory image struct for the FreeDesktop (iiibiiay) hint:
// (width, height, rowstride, has_alpha, bits_per_sample, channels, data).
struct FdoImageData {
    int width = 0;
    int height = 0;
    int rowstride = 0;
    bool hasAlpha = false;
    int bitsPerSample = 0;
    int channels = 0;
    QByteArray data;
};

QDBusArgument &operator<<(QDBusArgument &argument, const FdoImageData &image);
const QDBusArgument &operator>>(const QDBusArgument &argument, FdoImageData &image);

Q_DECLARE_METATYPE(FdoImageData)

struct NotificationItem {
    uint id = 0;
    QString appName;
    QString appIcon;
    QString summary;
    QString body;
    QStringList actions;
    QVariantMap hints;
    int expireTimeout = -1;

    // Parsed hint fields.
    int urgency = 1; // 0=Low, 1=Normal, 2=Critical
    QString category;
    QString desktopEntry;
    QString imagePath;
    QString imageDataUrl;
    int progress = -1; // 0..100, -1 when absent
    bool resident = false;
    bool transient = false;
    QString replyPlaceholder;
    qint64 createdMs = 0;

    QString resolvedIcon() const {
        if (!appIcon.isEmpty()) return appIcon;
        if (!imagePath.isEmpty()) return imagePath;
        if (!imageDataUrl.isEmpty()) return imageDataUrl;
        return QString();
    }

    QVariantMap toMap() const;
};

// Native FreeDesktop Notifications server (org.freedesktop.Notifications v1.2).
// Standalone QML singleton consumed directly by shell.qml / StateMachine.
class NotificationServer final : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged FINAL)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged FINAL)
    Q_PROPERTY(bool registered READ isRegistered NOTIFY registeredChanged FINAL)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        AppNameRole,
        AppIconRole,
        SummaryRole,
        BodyRole,
        ActionsRole,
        UrgencyRole,
        CategoryRole,
        DesktopEntryRole,
        ImagePathRole,
        ImageDataUrlRole,
        ProgressRole,
        ResidentRole,
        TransientRole,
        ReplyPlaceholderRole,
        CreatedRole
    };
    Q_ENUM(Roles)

    // autoRegister=false is for unit tests that exercise pure logic without
    // touching the session bus.
    explicit NotificationServer(QObject *parent = nullptr, bool autoRegister = true);
    ~NotificationServer() override;

    static NotificationServer *instance();
    static NotificationServer *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // QAbstractListModel: active notifications, newest last.
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeCount() const;
    QVariantList history() const;
    bool isRegistered() const;

    // Test/helpers.
    QVariantMap getNotification(uint id) const;
    bool contains(uint id) const;
    void setAutoRegister(bool enabled);

    // C++ port of the former StateMachine.cleanNotificationText: strips HTML
    // tags, unescapes entities, and (when stripUrls) removes standalone URLs.
    // Public and static so unit tests can exercise it without a config.
    static QString sanitizeNotificationText(const QString &text, bool stripUrls);

public slots:
    // --- FreeDesktop D-Bus methods (exported via the adaptor) ---
    uint Notify(const QString &appName, uint replacesId, const QString &appIcon,
                const QString &summary, const QString &body,
                const QStringList &actions, const QVariantMap &hints,
                int expireTimeout);
    void CloseNotification(uint id);
    QStringList GetCapabilities();
    // Note: the D-Bus GetServerInformation method (4 string out-args) lives on
    // the non-QML adaptor in the .cpp: QString& out-params are not valid QML
    // method types and break the QML type registration build.
    Q_INVOKABLE QVariantMap serverInformation() const;

    // --- QML-facing actions ---
    Q_INVOKABLE void invokeAction(uint id, const QString &actionKey);
    Q_INVOKABLE void dismissNotification(uint id);
    Q_INVOKABLE void clearAllNotifications();
    Q_INVOKABLE bool tryRegister();
    Q_INVOKABLE bool takeOver();
    Q_INVOKABLE void release();

signals:
    // FreeDesktop D-Bus signals (relayed through the adaptor).
    void ActionInvoked(uint id, const QString &actionKey);
    void NotificationClosed(uint id, uint reason);

    // QML bridge.
    void notificationAdded(const QVariantMap &item);
    void notificationUpdated(const QVariantMap &item);
    void notificationRemoved(uint id, uint reason);
    void activeCountChanged();
    void historyChanged();
    void registeredChanged();

private slots:
    void onExpireTimeout(uint id);
    void onRetryTimeout();

private:
    void parseHints(NotificationItem &item) const;
    QImage imageFromData(const FdoImageData &raw) const;
    QString dataUrlFromImage(const QImage &image) const;
    uint allocateId(uint replacesId);
    int indexOf(uint id) const;
    void startExpireTimer(const NotificationItem &item);
    void stopExpireTimer(uint id);
    void removeNotification(uint id, uint reason);
    void pushHistory(const NotificationItem &item);
    bool registerOnBus(bool replaceExisting);

    static NotificationServer *s_instance;

    QList<NotificationItem> m_items;
    QHash<uint, QTimer *> m_timers;
    QVariantList m_history;
    uint m_nextId = 1;
    bool m_registered = false;
    bool m_autoRegister = true;
    QTimer m_retryTimer;
    QObject *m_adaptor = nullptr;

    static const int kDefaultTimeoutMs = 5000;
    static const int kMaxHistory = 50;
};
