#include "NotificationServer.h"
#include "UserConfigBackend.h"

#include <QBuffer>
#include <QDateTime>
#include <QDBusAbstractAdaptor>
#include <QDBusConnectionInterface>
#include <QDBusMetaType>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QIcon>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStringList>
#include <QVariant>

#include <QtQml/qqmlengine.h>

namespace {

constexpr QLatin1String kServiceName("org.freedesktop.Notifications");
constexpr QLatin1String kObjectPath("/org/freedesktop/Notifications");

// Preferred theme/size/context search order for themeIconPath().
QStringList themeSearchOrder()
{
    QStringList themes;
    const QString systemTheme = QIcon::themeName();
    if (!systemTheme.isEmpty())
        themes.append(systemTheme);
    for (const QString &fallback : {QStringLiteral("breeze-dark"), QStringLiteral("breeze"),
                                    QStringLiteral("Adwaita"), QStringLiteral("hicolor")}) {
        if (!themes.contains(fallback))
            themes.append(fallback);
    }
    return themes;
}

QStringList iconBaseDirs()
{
    QStringList dirs;
    for (const QString &dataDir : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        dirs.append(dataDir + QStringLiteral("/icons"));
    dirs.append(QStringLiteral("/usr/share/pixmaps"));
    return dirs;
}

// First existing regular file wins; empty when nothing matches.
QString firstExisting(const QStringList &candidates)
{
    for (const QString &path : candidates) {
        if (QFileInfo(path).isFile())
            return path;
    }
    return QString();
}

QString findThemeIconFile(const QString &name)
{
    if (name.isEmpty() || name.contains(QLatin1Char('/')))
        return QString();

    static const QStringList kExtensions = {QStringLiteral("svg"), QStringLiteral("svgz"),
                                            QStringLiteral("png"), QStringLiteral("xpm")};
    static const QStringList kSizes = {QStringLiteral("48x48"), QStringLiteral("32x32"),
                                       QStringLiteral("64x64"), QStringLiteral("scalable"),
                                       QStringLiteral("32x32@2x"), QStringLiteral("24x24"),
                                       QStringLiteral("22x22"), QStringLiteral("16x16"),
                                       QStringLiteral("96x96"), QStringLiteral("128x128")};
    static const QStringList kContexts = {QStringLiteral("apps"), QStringLiteral("actions"),
                                          QStringLiteral("status"), QStringLiteral("devices"),
                                          QStringLiteral("mimetypes"), QStringLiteral("categories"),
                                          QStringLiteral("emblems")};

    const QStringList baseDirs = iconBaseDirs();
    // Exact filenames first (pixmaps and theme roots for names with extensions).
    QStringList direct;
    for (const QString &base : baseDirs)
        direct.append(base + QLatin1Char('/') + name);
    const QString exact = firstExisting(direct);
    if (!exact.isEmpty())
        return exact;

    for (const QString &base : baseDirs) {
        for (const QString &theme : themeSearchOrder()) {
            const QString themeDir = base + QLatin1Char('/') + theme;
            if (!QFileInfo(themeDir).isDir())
                continue;
            for (const QString &size : kSizes) {
                for (const QString &context : kContexts) {
                    QStringList sized;
                    for (const QString &ext : kExtensions)
                        sized.append(themeDir + QLatin1Char('/') + size + QLatin1Char('/') + context
                                     + QLatin1Char('/') + name + QLatin1Char('.') + ext);
                    const QString hit = firstExisting(sized);
                    if (!hit.isEmpty())
                        return hit;
                }
            }
        }
    }
    return QString();
}

} // namespace

QDBusArgument &operator<<(QDBusArgument &argument, const FdoImageData &image) {
    argument.beginStructure();
    argument << image.width << image.height << image.rowstride << image.hasAlpha
             << image.bitsPerSample << image.channels << image.data;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, FdoImageData &image) {
    argument.beginStructure();
    argument >> image.width >> image.height >> image.rowstride >> image.hasAlpha
        >> image.bitsPerSample >> image.channels >> image.data;
    argument.endStructure();
    return argument;
}

QString NotificationServer::sanitizeNotificationText(const QString &text, bool stripUrls) {
    QString s = text;
    if (s.isNull())
        s.clear();

    if (stripUrls) {
        // Mirror the former QML cleanNotificationText order: URL/origin
        // stripping runs on the raw HTML before tags are removed.
        static const QRegularExpression anchorRe(
            QStringLiteral("^\\s*<a\\b[^>]*>.*?</a>\\s*"),
            QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression domainHeaderRe(
            QStringLiteral("^\\s*([a-zA-Z0-9][-a-zA-Z0-9]*\\.)+[a-zA-Z]{2,}(?::\\d+)?(?:/\\S*)?\\s*\\n+"),
            QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression urlRe(
            QStringLiteral("https?://[^\\s<>]+"),
            QRegularExpression::CaseInsensitiveOption);
        static const QRegularExpression wwwRe(
            QStringLiteral("\\bwww\\.[a-zA-Z0-9][-a-zA-Z0-9]*\\.[a-zA-Z]{2,}[^\\s<>]*"),
            QRegularExpression::CaseInsensitiveOption);
        s.remove(anchorRe);
        s.remove(domainHeaderRe);
        s.remove(urlRe);
        s.remove(wwwRe);
    }

    static const QRegularExpression tagRe(QStringLiteral("<[^>]*>"));
    static const QRegularExpression whitespaceRe(QStringLiteral("\\s+"));
    s.replace(tagRe, QStringLiteral(" "));
    s.replace(QStringLiteral("&nbsp;"), QStringLiteral(" "));
    s.replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    s.replace(QStringLiteral("&quot;"), QStringLiteral("\""));
    s.replace(QStringLiteral("&lt;"), QStringLiteral("<"));
    s.replace(QStringLiteral("&gt;"), QStringLiteral(">"));
    s.replace(whitespaceRe, QStringLiteral(" "));
    s = s.trimmed();

    // If stripping URLs emptied the string, fall back to plain sanitization
    // so link-only notifications are not lost.
    if (stripUrls && s.isEmpty() && !text.trimmed().isEmpty())
        return sanitizeNotificationText(text, false);
    return s;
}

QVariantMap NotificationItem::toMap() const {
    QVariantMap map;
    map.insert(QStringLiteral("id"), id);
    map.insert(QStringLiteral("appName"), appName);
    map.insert(QStringLiteral("appIcon"), appIcon);
    map.insert(QStringLiteral("summary"), summary);
    map.insert(QStringLiteral("body"), body);
    map.insert(QStringLiteral("actions"), actions);
    map.insert(QStringLiteral("urgency"), urgency);
    map.insert(QStringLiteral("category"), category);
    map.insert(QStringLiteral("desktopEntry"), desktopEntry);
    map.insert(QStringLiteral("imagePath"), imagePath);
    map.insert(QStringLiteral("imageDataUrl"), imageDataUrl);
    map.insert(QStringLiteral("resolvedIcon"), resolvedIcon());
    map.insert(QStringLiteral("progress"), progress);
    map.insert(QStringLiteral("resident"), resident);
    map.insert(QStringLiteral("transient"), transient);
    map.insert(QStringLiteral("replyPlaceholder"), replyPlaceholder);
    map.insert(QStringLiteral("createdMs"), createdMs);
    return map;
}

// D-Bus adaptor: isolates the exported org.freedesktop.Notifications surface
// from the QML-facing slots on NotificationServer.
class NotificationServerAdaptor final : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationServerAdaptor(NotificationServer *parent)
        : QDBusAbstractAdaptor(parent), m_server(parent) {}

public slots:
    uint Notify(const QString &appName, uint replacesId, const QString &appIcon,
                const QString &summary, const QString &body,
                const QStringList &actions, const QVariantMap &hints,
                int expireTimeout) {
        return m_server->Notify(appName, replacesId, appIcon, summary, body,
                                actions, hints, expireTimeout);
    }

    void CloseNotification(uint id) {
        m_server->CloseNotification(id);
    }

    QStringList GetCapabilities() {
        return m_server->GetCapabilities();
    }

    QString GetServerInformation(QString &vendor, QString &version, QString &specVersion) {
        const QVariantMap info = m_server->serverInformation();
        vendor = info.value(QStringLiteral("vendor")).toString();
        version = info.value(QStringLiteral("version")).toString();
        specVersion = info.value(QStringLiteral("specVersion")).toString();
        return info.value(QStringLiteral("name")).toString();
    }

signals:
    void ActionInvoked(uint id, const QString &actionKey);
    void NotificationClosed(uint id, uint reason);

private:
    NotificationServer *m_server = nullptr;
};

NotificationServer *NotificationServer::s_instance = nullptr;

NotificationServer::NotificationServer(QObject *parent, bool autoRegister)
    : QAbstractListModel(parent), m_autoRegister(autoRegister) {
    qDBusRegisterMetaType<FdoImageData>();

    m_retryTimer.setSingleShot(true);
    m_retryTimer.setInterval(3000);
    connect(&m_retryTimer, &QTimer::timeout, this, &NotificationServer::onRetryTimeout);

    auto *adaptor = new NotificationServerAdaptor(this);
    m_adaptor = adaptor;
    connect(this, &NotificationServer::ActionInvoked,
            adaptor, &NotificationServerAdaptor::ActionInvoked);
    connect(this, &NotificationServer::NotificationClosed,
            adaptor, &NotificationServerAdaptor::NotificationClosed);

    if (m_autoRegister)
        tryRegister();
}

NotificationServer::~NotificationServer() {
    release();
    if (s_instance == this)
        s_instance = nullptr;
}

NotificationServer *NotificationServer::instance() {
    if (!s_instance) {
        s_instance = new NotificationServer(nullptr, true);
        QQmlEngine::setObjectOwnership(s_instance, QQmlEngine::CppOwnership);
    }
    return s_instance;
}

NotificationServer *NotificationServer::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine) {
    Q_UNUSED(qmlEngine);
    Q_UNUSED(jsEngine);
    return instance();
}

int NotificationServer::rowCount(const QModelIndex &parent) const {
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant NotificationServer::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return QVariant();
    const NotificationItem &item = m_items.at(index.row());
    switch (role) {
    case IdRole: return item.id;
    case AppNameRole: return item.appName;
    case AppIconRole: return item.appIcon;
    case SummaryRole: return item.summary;
    case BodyRole: return item.body;
    case ActionsRole: return item.actions;
    case UrgencyRole: return item.urgency;
    case CategoryRole: return item.category;
    case DesktopEntryRole: return item.desktopEntry;
    case ImagePathRole: return item.imagePath;
    case ImageDataUrlRole: return item.imageDataUrl;
    case ProgressRole: return item.progress;
    case ResidentRole: return item.resident;
    case TransientRole: return item.transient;
    case ReplyPlaceholderRole: return item.replyPlaceholder;
    case CreatedRole: return item.createdMs;
    default: return QVariant();
    }
}

QHash<int, QByteArray> NotificationServer::roleNames() const {
    return {
        {IdRole, "notificationId"},
        {AppNameRole, "appName"},
        {AppIconRole, "appIcon"},
        {SummaryRole, "summary"},
        {BodyRole, "body"},
        {ActionsRole, "actions"},
        {UrgencyRole, "urgency"},
        {CategoryRole, "category"},
        {DesktopEntryRole, "desktopEntry"},
        {ImagePathRole, "imagePath"},
        {ImageDataUrlRole, "imageDataUrl"},
        {ProgressRole, "progress"},
        {ResidentRole, "resident"},
        {TransientRole, "transient"},
        {ReplyPlaceholderRole, "replyPlaceholder"},
        {CreatedRole, "createdMs"},
    };
}

int NotificationServer::activeCount() const {
    return m_items.size();
}

QVariantList NotificationServer::history() const {
    return m_history;
}

bool NotificationServer::isRegistered() const {
    return m_registered;
}

QVariantMap NotificationServer::getNotification(uint id) const {
    const int row = indexOf(id);
    if (row < 0)
        return QVariantMap();
    return m_items.at(row).toMap();
}

bool NotificationServer::contains(uint id) const {
    return indexOf(id) >= 0;
}

void NotificationServer::setAutoRegister(bool enabled) {
    m_autoRegister = enabled;
    if (!m_autoRegister)
        m_retryTimer.stop();
}

uint NotificationServer::Notify(const QString &appName, uint replacesId,
                                const QString &appIcon, const QString &summary,
                                const QString &body, const QStringList &actions,
                                const QVariantMap &hints, int expireTimeout) {
    NotificationItem item;
    const bool stripUrls = UserConfigBackend::instance()->cleanNotificationUrls();
    item.appName = sanitizeNotificationText(appName, false);
    item.appIcon = appIcon;
    item.summary = sanitizeNotificationText(summary, stripUrls);
    item.body = sanitizeNotificationText(body, stripUrls);
    item.actions = actions;
    item.hints = hints;
    item.expireTimeout = expireTimeout;
    parseHints(item);

    if (replacesId != 0 && contains(replacesId)) {
        const int row = indexOf(replacesId);
        item.id = replacesId;
        item.createdMs = m_items.at(row).createdMs;
        m_items[row] = item;
        const QModelIndex modelIndex = index(row, 0);
        emit dataChanged(modelIndex, modelIndex);
        emit notificationUpdated(item.toMap());
        startExpireTimer(item);
        return replacesId;
    }

    item.id = allocateId(0);
    item.createdMs = QDateTime::currentMSecsSinceEpoch();
    beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
    m_items.append(item);
    endInsertRows();
    emit notificationAdded(item.toMap());
    emit activeCountChanged();
    pushHistory(item);
    startExpireTimer(item);
    return item.id;
}

void NotificationServer::CloseNotification(uint id) {
    if (!contains(id))
        return;
    removeNotification(id, 3);
}

QStringList NotificationServer::GetCapabilities() {
    return QStringList{
        QStringLiteral("actions"),
        QStringLiteral("body"),
        QStringLiteral("body-hyperlinks"),
        QStringLiteral("body-markup"),
        QStringLiteral("body-images"),
        QStringLiteral("icon-static"),
        QStringLiteral("image-path"),
        QStringLiteral("image-data"),
        QStringLiteral("persistence"),
        QStringLiteral("inline-reply"),
    };
}

QVariantMap NotificationServer::serverInformation() const {
    return QVariantMap{
        {QStringLiteral("name"), QStringLiteral("Tide Island")},
        {QStringLiteral("vendor"), QStringLiteral("justkelvin")},
        {QStringLiteral("version"), QStringLiteral("1.0.0")},
        {QStringLiteral("specVersion"), QStringLiteral("1.2")},
    };
}

void NotificationServer::invokeAction(uint id, const QString &actionKey) {
    const int row = indexOf(id);
    if (row < 0)
        return;
    const bool resident = m_items.at(row).resident;
    emit ActionInvoked(id, actionKey);
    if (!resident)
        removeNotification(id, 2);
}

void NotificationServer::dismissNotification(uint id) {
    if (!contains(id))
        return;
    removeNotification(id, 2);
}

void NotificationServer::clearAllNotifications() {
    QList<uint> ids;
    ids.reserve(m_items.size());
    for (const NotificationItem &item : m_items)
        ids.append(item.id);
    for (uint id : ids) {
        if (contains(id))
            removeNotification(id, 2);
    }
}

void NotificationServer::removeHistoryItem(uint id) {
    for (int i = 0; i < m_history.size(); ++i) {
        const QVariantMap entry = m_history.at(i).toMap();
        if (entry.value(QStringLiteral("id")).toUInt() == id) {
            m_history.removeAt(i);
            emit historyChanged();
            return;
        }
    }
}

void NotificationServer::clearHistory() {
    if (m_history.isEmpty())
        return;
    m_history.clear();
    emit historyChanged();
}

QString NotificationServer::themeIconPath(const QString &name) const
{
    const QString key = name.trimmed();
    if (key.isEmpty())
        return QString();
    auto it = m_themeIconCache.constFind(key);
    if (it != m_themeIconCache.constEnd())
        return it.value();
    const QString found = findThemeIconFile(key);
    const QString result = found.isEmpty() ? QString() : QStringLiteral("file://") + found;
    m_themeIconCache.insert(key, result);
    return result;
}

bool NotificationServer::tryRegister() {
    if (m_registered)
        return true;
    if (!registerOnBus(false)) {
        if (m_autoRegister && !m_retryTimer.isActive())
            m_retryTimer.start();
        return false;
    }
    return true;
}

bool NotificationServer::takeOver() {
    if (m_registered)
        return true;
    return registerOnBus(true);
}

void NotificationServer::release() {
    m_retryTimer.stop();
    if (!m_registered)
        return;
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.unregisterObject(kObjectPath);
    bus.unregisterService(kServiceName);
    m_registered = false;
    emit registeredChanged();
}

void NotificationServer::onExpireTimeout(uint id) {
    if (!contains(id))
        return;
    removeNotification(id, 1);
}

void NotificationServer::onRetryTimeout() {
    if (m_registered || !m_autoRegister)
        return;
    tryRegister();
}

void NotificationServer::parseHints(NotificationItem &item) const {
    const QVariantMap &hints = item.hints;

    item.urgency = 1;
    auto urgencyIt = hints.find(QStringLiteral("urgency"));
    if (urgencyIt != hints.end()) {
        bool ok = false;
        const uint level = urgencyIt->toUInt(&ok);
        if (ok)
            item.urgency = qBound(0, static_cast<int>(level), 2);
    }

    item.category = hints.value(QStringLiteral("category")).toString();
    item.desktopEntry = hints.value(QStringLiteral("desktop-entry")).toString();

    item.imagePath = hints.value(QStringLiteral("image-path")).toString();
    if (item.imagePath.isEmpty())
        item.imagePath = hints.value(QStringLiteral("image_path")).toString();

    item.replyPlaceholder = hints.value(QStringLiteral("x-kde-reply-placeholder")).toString();

    item.progress = -1;
    auto valueIt = hints.find(QStringLiteral("value"));
    if (valueIt != hints.end()) {
        bool ok = false;
        const int progress = valueIt->toInt(&ok);
        if (ok)
            item.progress = qBound(0, progress, 100);
    }

    item.resident = hints.value(QStringLiteral("resident")).toBool();
    item.transient = hints.value(QStringLiteral("transient")).toBool();

    item.imageDataUrl.clear();
    const QStringList imageKeys{
        QStringLiteral("image-data"),
        QStringLiteral("image_data"),
        QStringLiteral("icon_data"),
    };
    for (const QString &key : imageKeys) {
        auto it = hints.find(key);
        if (it == hints.end())
            continue;
        const QVariant &value = *it;
        FdoImageData raw;
        bool haveImage = false;
        if (value.userType() == qMetaTypeId<QDBusArgument>()) {
            QDBusArgument argument = value.value<QDBusArgument>();
            if (argument.currentType() == QDBusArgument::StructureType) {
                argument >> raw;
                haveImage = true;
            }
        } else if (value.canConvert<FdoImageData>()) {
            raw = value.value<FdoImageData>();
            haveImage = true;
        }
        if (!haveImage)
            continue;
        const QImage image = imageFromData(raw);
        if (image.isNull())
            continue;
        item.imageDataUrl = dataUrlFromImage(image);
        break;
    }
}

QImage NotificationServer::imageFromData(const FdoImageData &raw) const {
    if (raw.width <= 0 || raw.height <= 0 || raw.width > 4096 || raw.height > 4096)
        return QImage();
    if (raw.bitsPerSample != 8)
        return QImage();
    if (raw.channels != 3 && raw.channels != 4)
        return QImage();
    if (raw.rowstride < raw.width * raw.channels)
        return QImage();
    if (raw.data.size() < raw.rowstride * raw.height)
        return QImage();

    const bool withAlpha = raw.hasAlpha && raw.channels == 4;
    QImage image(raw.width, raw.height,
                 withAlpha ? QImage::Format_RGBA8888 : QImage::Format_RGB888);
    if (image.isNull())
        return QImage();

    const char *src = raw.data.constData();
    const int bytesPerPixel = raw.channels;
    for (int y = 0; y < raw.height; ++y) {
        const uchar *srcRow = reinterpret_cast<const uchar *>(src + y * raw.rowstride);
        uchar *dstRow = image.scanLine(y);
        if (withAlpha) {
            memcpy(dstRow, srcRow, static_cast<size_t>(raw.width * bytesPerPixel));
        } else if (raw.channels == 3) {
            memcpy(dstRow, srcRow, static_cast<size_t>(raw.width * 3));
        } else {
            // 4 channels without alpha flag: drop alpha byte per pixel.
            for (int x = 0; x < raw.width; ++x) {
                dstRow[x * 3 + 0] = srcRow[x * 4 + 0];
                dstRow[x * 3 + 1] = srcRow[x * 4 + 1];
                dstRow[x * 3 + 2] = srcRow[x * 4 + 2];
            }
        }
    }
    return image;
}

QString NotificationServer::dataUrlFromImage(const QImage &image) const {
    QByteArray pngBytes;
    QBuffer buffer(&pngBytes);
    if (!buffer.open(QIODevice::WriteOnly))
        return QString();
    if (!image.save(&buffer, "PNG"))
        return QString();
    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(pngBytes.toBase64());
}

uint NotificationServer::allocateId(uint replacesId) {
    if (replacesId != 0 && contains(replacesId))
        return replacesId;
    for (;;) {
        uint candidate = m_nextId++;
        if (m_nextId == 0) // uint rollover: 0 is reserved, skip it
            m_nextId = 1;
        if (candidate == 0)
            continue;
        if (!contains(candidate))
            return candidate;
    }
}

int NotificationServer::indexOf(uint id) const {
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).id == id)
            return i;
    }
    return -1;
}

void NotificationServer::startExpireTimer(const NotificationItem &item) {
    stopExpireTimer(item.id);
    if (item.expireTimeout == 0)
        return; // persistent
    if (item.urgency == 2)
        return; // critical persists until dismissed
    const int timeoutMs = item.expireTimeout == -1 ? kDefaultTimeoutMs : item.expireTimeout;
    if (timeoutMs <= 0)
        return;
    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(timeoutMs);
    const uint id = item.id;
    connect(timer, &QTimer::timeout, this, [this, id]() { onExpireTimeout(id); });
    m_timers.insert(id, timer);
    timer->start();
}

void NotificationServer::stopExpireTimer(uint id) {
    QTimer *timer = m_timers.take(id);
    if (!timer)
        return;
    timer->stop();
    timer->deleteLater();
}

void NotificationServer::removeNotification(uint id, uint reason) {
    const int row = indexOf(id);
    if (row < 0)
        return;
    stopExpireTimer(id);
    beginRemoveRows(QModelIndex(), row, row);
    m_items.removeAt(row);
    endRemoveRows();
    emit NotificationClosed(id, reason);
    emit notificationRemoved(id, reason);
    emit activeCountChanged();
}

void NotificationServer::pushHistory(const NotificationItem &item) {
    if (item.transient)
        return;
    m_history.prepend(item.toMap());
    while (m_history.size() > kMaxHistory)
        m_history.removeLast();
    emit historyChanged();
}

bool NotificationServer::registerOnBus(bool replaceExisting) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning() << "[NotificationServer] session bus is not connected; cannot register"
                   << kServiceName;
        return false;
    }

    if (!bus.registerObject(kObjectPath, this, QDBusConnection::ExportAdaptors)) {
        qWarning() << "[NotificationServer] failed to register object" << kObjectPath
                   << bus.lastError().message();
        return false;
    }

    QDBusConnectionInterface *iface = bus.interface();
    if (!iface) {
        bus.unregisterObject(kObjectPath);
        qWarning() << "[NotificationServer] no D-Bus interface available";
        return false;
    }

    const auto option = replaceExisting
        ? QDBusConnectionInterface::ReplaceExistingService
        : QDBusConnectionInterface::DontQueueService;
    const auto reply = iface->registerService(kServiceName, option);
    if (reply.value() != QDBusConnectionInterface::ServiceRegistered) {
        bus.unregisterObject(kObjectPath);
        qWarning() << "[NotificationServer]" << kServiceName
                   << "already owned by another daemon (Dunst/Mako?); retrying in background."
                   << (iface->lastError().isValid() ? iface->lastError().message() : QString());
        return false;
    }

    m_registered = true;
    m_retryTimer.stop();
    qInfo() << "[NotificationServer] registered" << kServiceName << "at" << kObjectPath;
    emit registeredChanged();
    return true;
}

#include "NotificationServer.moc"
