#include "backend.hpp"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QTemporaryFile>
#include <QVariant>
#include <QVariantList>

namespace {
constexpr auto shortcutBindingsKey = "shortcutBindings";
constexpr auto colorSchemeKey = "appearance/colorScheme";
constexpr auto tideShortcutPrefix = "/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call ";
constexpr auto legacyTideShortcutPrefix = "/usr/bin/quickshell ipc -p /usr/share/tide-island call ";
constexpr auto quickshellPath = "/usr/bin/quickshell";
constexpr auto tideQmlPath = "/usr/share/tide-island";

struct ShortcutBinding {
    QString mods;
    QString key;
    QString target;
    QString method;
};

QVariantMap shortcutMap(const QString &mods, const QString &key, const QString &target, const QString &method)
{
    return {
        {QStringLiteral("mods"), mods},
        {QStringLiteral("key"), key},
        {QStringLiteral("target"), target},
        {QStringLiteral("method"), method},
    };
}

bool isOverviewBinding(const ShortcutBinding &binding)
{
    return binding.target.compare(QStringLiteral("overview"), Qt::CaseInsensitive) == 0;
}

QVariantList defaultShortcutBindings()
{
    return {
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("right"), QStringLiteral("tide"), QStringLiteral("swipeRight")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("left"), QStringLiteral("tide"), QStringLiteral("swipeLeft")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("down"), QStringLiteral("tide"), QStringLiteral("showClock")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("M"), QStringLiteral("tide"), QStringLiteral("togglePlayer")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("N"), QStringLiteral("tide"), QStringLiteral("toggleNotificationCenter")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("F"), QStringLiteral("island"), QStringLiteral("toggle")),
    };
}

QString configHome()
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    return QDir::homePath() + QStringLiteral("/.config");
}

QString configAppSettingsPath()
{
    return configHome() + QStringLiteral("/tide-island/config-app.ini");
}

QString normalizedColorScheme(const QString &colorScheme)
{
    return colorScheme.trimmed().compare(QStringLiteral("dark"), Qt::CaseInsensitive) == 0
        ? QStringLiteral("dark")
        : QStringLiteral("light");
}

QString expandedPath(const QString &path)
{
    return path.startsWith(QStringLiteral("~/")) ? QDir::homePath() + path.sliced(1) : path;
}

QString cleanShortcutPart(const QVariant &value)
{
    QString text = value.toString().trimmed();
    text.replace(u'\n', u' ');
    text.replace(u'\r', u' ');
    text.replace(u',', u' ');
    return text.simplified();
}

ShortcutBinding bindingFromVariant(const QVariant &value)
{
    const QVariantMap map = value.toMap();
    return {
        cleanShortcutPart(map.value(QStringLiteral("mods"))),
        cleanShortcutPart(map.value(QStringLiteral("key"))),
        cleanShortcutPart(map.value(QStringLiteral("target"))),
        cleanShortcutPart(map.value(QStringLiteral("method"))),
    };
}

QVariantList filteredShortcutBindings(const QVariantList &shortcutBindings)
{
    QVariantList filtered;
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        if (isOverviewBinding(binding))
            continue;
        filtered.append(value);
    }
    return filtered;
}

bool isIslandBinding(const ShortcutBinding &binding)
{
    return binding.target.compare(QStringLiteral("island"), Qt::CaseInsensitive) == 0;
}

ShortcutBinding migratedShortcutBinding(ShortcutBinding binding)
{
    if (isIslandBinding(binding)
        && binding.method.compare(QStringLiteral("toggle"), Qt::CaseInsensitive) == 0
        && binding.mods.compare(QStringLiteral("SUPER"), Qt::CaseInsensitive) == 0
        && binding.key.compare(QStringLiteral("I"), Qt::CaseInsensitive) == 0) {
        binding.key = QStringLiteral("F");
    }

    if (binding.target.compare(QStringLiteral("tide"), Qt::CaseInsensitive) == 0
        && binding.method.compare(QStringLiteral("showLyrics"), Qt::CaseInsensitive) == 0
        && binding.mods.compare(QStringLiteral("SUPER"), Qt::CaseInsensitive) == 0
        && binding.key.compare(QStringLiteral("right"), Qt::CaseInsensitive) == 0) {
        binding.method = QStringLiteral("swipeRight");
    }

    if (binding.target.compare(QStringLiteral("tide"), Qt::CaseInsensitive) == 0
        && binding.method.compare(QStringLiteral("showCustom"), Qt::CaseInsensitive) == 0
        && binding.mods.compare(QStringLiteral("SUPER"), Qt::CaseInsensitive) == 0
        && binding.key.compare(QStringLiteral("left"), Qt::CaseInsensitive) == 0) {
        binding.method = QStringLiteral("swipeLeft");
    }

    return binding;
}

QVariantList normalizedShortcutBindings(const QVariantList &shortcutBindings)
{
    QVariantList normalized;
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = migratedShortcutBinding(bindingFromVariant(value));
        if (binding.target.isEmpty() || binding.method.isEmpty())
            continue;
        if (isIslandBinding(binding) && binding.method.compare(QStringLiteral("toggle"), Qt::CaseInsensitive) != 0)
            continue;

        normalized.append(shortcutMap(binding.mods, binding.key, binding.target, binding.method));
    }
    return normalized;
}

QString shortcutIdentity(const ShortcutBinding &binding)
{
    return binding.target.toLower() + u':' + binding.method.toLower();
}

QVariantList mergedShortcutBindings(const QVariantList &baseBindings, const QVariantList &updates)
{
    QVariantList merged = normalizedShortcutBindings(baseBindings);
    const QVariantList normalizedUpdates = normalizedShortcutBindings(updates);

    for (const QVariant &value : normalizedUpdates) {
        const QString identity = shortcutIdentity(bindingFromVariant(value));
        bool replaced = false;
        for (qsizetype index = 0; index < merged.size(); ++index) {
            if (shortcutIdentity(bindingFromVariant(merged.at(index))) == identity) {
                merged[index] = value;
                replaced = true;
                break;
            }
        }
        if (!replaced)
            merged.append(value);
    }

    return merged;
}

QString shortcutCommand(const ShortcutBinding &binding)
{
    return QString::fromLatin1(tideShortcutPrefix) + binding.target + u' ' + binding.method;
}

QStringList shortcutCommandArgs(const ShortcutBinding &binding)
{
    return {
        QString::fromLatin1(quickshellPath),
        QStringLiteral("ipc"),
        QStringLiteral("--any-display"),
        QStringLiteral("-p"),
        QString::fromLatin1(tideQmlPath),
        QStringLiteral("call"),
        binding.target,
        binding.method,
    };
}

QString hyprlandConfBindLine(const ShortcutBinding &binding)
{
    return QStringLiteral("bind = %1, %2, exec, %3")
        .arg(binding.mods, binding.key, shortcutCommand(binding));
}

QString kdlQuote(QString value);

QString hyprlandLuaShortcutBlock(const QVariantList &shortcutBindings)
{
    QStringList lines;
    lines.append(QStringLiteral("-- Tide Island shortcuts: begin (managed by Tide Island Config App)."));
    lines.append(QStringLiteral("-- Empty shortcuts are disabled and intentionally omitted."));
    for (const QVariant &value : shortcutBindings) {
        ShortcutBinding binding = bindingFromVariant(value);
        if (binding.key.isEmpty())
            continue;

        binding.mods.replace(u'+', u' ');
        const QStringList modifiers = binding.mods.split(u' ', Qt::SkipEmptyParts);
        QStringList chordParts = modifiers;
        chordParts.append(binding.key);

        lines.append(QStringLiteral("hl.bind(%1, hl.dsp.exec_cmd(%2))")
            .arg(kdlQuote(chordParts.join(QStringLiteral(" + "))), kdlQuote(shortcutCommand(binding))));
    }
    lines.append(QStringLiteral("-- Tide Island shortcuts: end."));
    return lines.join(u'\n');
}

QString kdlQuote(QString value)
{
    value.replace(u'\\', QStringLiteral("\\\\"));
    value.replace(u'"', QStringLiteral("\\\""));
    value.replace(u'\n', QStringLiteral("\\n"));
    value.replace(u'\r', QStringLiteral("\\r"));
    return u'"' + value + u'"';
}

QByteArray stripJsonComments(const QByteArray &input){
    QByteArray output;
    output.reserve(input.size());

    enum class State {
        Normal,
        String,
        LineComment,
        BlockComment,
    };

    State state = State::Normal;
    bool escaped = false;

    for (qsizetype i = 0; i < input.size(); ++i) {
        const char ch = input.at(i);
        const char next = i + 1 < input.size() ? input.at(i + 1) : '\0';

        switch (state) {
        case State::Normal:
            if (ch == '"') {
                output.append(ch);
                state = State::String;
            } else if (ch == '/' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::LineComment;
            } else if (ch == '/' && next == '*') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::BlockComment;
            } else {
                output.append(ch);
            }
            break;
        case State::String:
            output.append(ch);
            if (escaped) {
                escaped = false;
            } else if (ch == '\\') {
                escaped = true;
            } else if (ch == '"') {
                state = State::Normal;
            }
            break;
        case State::LineComment:
            if (ch == '\n' || ch == '\r') {
                output.append(ch);
                state = State::Normal;
            } else {
                output.append(' ');
            }
            break;
        case State::BlockComment:
            if (ch == '*' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::Normal;
            } else if (ch == '\n' || ch == '\r') {
                output.append(ch);
            } else {
                output.append(' ');
            }
            break;
        }
    }

    return output;
}

UserConfigMap toUserConfigMap(const QVariantMap &userConfig){
    UserConfigMap result;
    result.reserve(static_cast<std::size_t>(userConfig.size()));

    for (auto it = userConfig.cbegin(); it != userConfig.cend(); ++it)
        result.emplace(it.key(), it.value());

    return result;
}
}

std::size_t QStringHash::operator()(const QString &key) const noexcept{
    return static_cast<std::size_t>(qHash(key));
}

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json"))
{
    QSettings settings(configAppSettingsPath(), QSettings::IniFormat);
    m_colorScheme = normalizedColorScheme(
        settings.value(QString::fromLatin1(colorSchemeKey), QStringLiteral("light")).toString());
    load();
}

QString Backend::userConfigPath() const{
    return m_userConfigPath;
}

QString Backend::errorString() const{
    return m_errorString;
}

QVariantMap Backend::userConfig() const{
    return toVariantMap();
}

QString Backend::colorScheme() const{
    return m_colorScheme;
}

void Backend::setColorScheme(const QString &colorScheme){
    const QString normalized = normalizedColorScheme(colorScheme);
    if (m_colorScheme == normalized)
        return;

    m_colorScheme = normalized;
    QSettings settings(configAppSettingsPath(), QSettings::IniFormat);
    settings.setValue(QString::fromLatin1(colorSchemeKey), m_colorScheme);
    settings.sync();
    emit colorSchemeChanged();
}

bool Backend::save(const QVariantMap &userConfig){
    const QFileInfo configInfo(m_userConfigPath);
    QDir directory(configInfo.absolutePath());
    if (!directory.exists() && !QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    const QJsonDocument document = QJsonDocument::fromVariant(userConfig);
    if (!document.isObject()) {
        setErrorString(QStringLiteral("User config must be a JSON object."));
        return false;
    }

    QSaveFile file(m_userConfigPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    file.write(document.toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    setUserConfig(userConfig);
    setErrorString(QString());
    return true;
}

bool Backend::copyToClipboard(const QString &text){
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        setErrorString(QStringLiteral("Clipboard is not available."));
        return false;
    }

    clipboard->setText(text);
    setErrorString(QString());
    return true;
}

QVariantList Backend::shortcutBindings() const{
    QVariantList bindings = defaultShortcutBindings();
    const auto it = m_userConfig.find(QString::fromLatin1(shortcutBindingsKey));
    if (it != m_userConfig.end())
        bindings = mergedShortcutBindings(bindings, it->second.toList());

    return filteredShortcutBindings(bindings);
}

QString Backend::currentCompositor() const{
    return QStringLiteral("hyprland");
}

QString Backend::compositorDisplayName() const{
    return QStringLiteral("Hyprland");
}

bool Backend::supportsHyprlandShortcutSnippets() const{
    return true;
}

QString Backend::nightLightBackendName() const{
    return QStringLiteral("hyprsunset");
}

bool Backend::applyShortcutBindings(const QVariantList &shortcutBindings){
    const QVariantList updates = normalizedShortcutBindings(shortcutBindings);
    if (updates.isEmpty()) {
        setErrorString(QStringLiteral("Shortcut bindings are empty."));
        return false;
    }

    QVariantList savedBindings = defaultShortcutBindings();
    const auto savedIt = m_userConfig.find(QString::fromLatin1(shortcutBindingsKey));
    if (savedIt != m_userConfig.end())
        savedBindings = mergedShortcutBindings(savedBindings, savedIt->second.toList());
    const QVariantList completeBindings = mergedShortcutBindings(savedBindings, updates);
    const QVariantList compositorBindings = filteredShortcutBindings(completeBindings);

    QVariantMap data = toVariantMap();
    data.insert(QString::fromLatin1(shortcutBindingsKey), completeBindings);

    if (!save(data))
        return false;

    if (!writeManagedShortcutConfig(compositorBindings))
        return false;

    if (!ensureManagedShortcutSource())
        return false;

    if (hyprlandUsesLuaConfig() && !writeManagedShortcutLuaConfig(compositorBindings))
        return false;

    if (!reloadHyprland()) {
        setErrorString(QStringLiteral("Saved shortcuts, but Hyprland did not reload. Run hyprctl reload or restart Hyprland."));
        return false;
    }

    setErrorString(QString());
    return true;
}

QString Backend::hyprlandConfigPath() const{
    const QString override = QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_HYPRLAND_CONFIG"));
    if (!override.isEmpty())
        return expandedPath(override);

    return configHome() + QStringLiteral("/hypr/hyprland.conf");
}

QString Backend::hyprlandLuaConfigPath() const{
    const QString override = QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_HYPRLAND_LUA_CONFIG"));
    if (!override.isEmpty())
        return expandedPath(override);

    return configHome() + QStringLiteral("/hypr/hyprland.lua");
}

QString Backend::managedShortcutConfigPath() const{
    return configHome() + QStringLiteral("/tide-island/hyprland-shortcuts.conf");
}

bool Backend::writeManagedShortcutConfig(const QVariantList &shortcutBindings){
    const QFileInfo configInfo(managedShortcutConfigPath());
    if (!QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    QStringList lines;
    lines.append(QStringLiteral("# Generated by Tide Island. Edit shortcuts in the Tide Island config app."));
    lines.append(QStringLiteral("# These binds call Quickshell IPC; the same commands can be reused in scripts."));
    lines.append(QStringLiteral("# Island command: island toggle."));
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        if (binding.key.isEmpty())
            continue;
        lines.append(hyprlandConfBindLine(binding));
    }
    lines.append(QString());

    QSaveFile file(configInfo.absoluteFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    file.write(lines.join(u'\n').toUtf8());
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    return true;
}

bool Backend::hyprlandUsesLuaConfig() const{
    if (!QFileInfo::exists(hyprlandLuaConfigPath()))
        return false;

    QProcess process;
    process.setProgram(QStringLiteral("hyprctl"));
    process.setArguments({QStringLiteral("binds")});
    process.start();
    if (!process.waitForFinished(3000)
        || process.exitStatus() != QProcess::NormalExit
        || process.exitCode() != 0) {
        return false;
    }

    return process.readAllStandardOutput().contains("dispatcher: __lua");
}

bool Backend::writeManagedShortcutLuaConfig(const QVariantList &shortcutBindings){
    const QFileInfo configInfo(hyprlandLuaConfigPath());
    QFile input(configInfo.absoluteFilePath());
    if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not read %1: %2")
            .arg(configInfo.absoluteFilePath(), input.errorString()));
        return false;
    }

    QString config = QString::fromUtf8(input.readAll());
    input.close();
    const QString block = hyprlandLuaShortcutBlock(shortcutBindings);
    const QString beginMarker = QStringLiteral("-- Tide Island shortcuts: begin (managed by Tide Island Config App).");
    const QString endMarker = QStringLiteral("-- Tide Island shortcuts: end.");

    const qsizetype begin = config.indexOf(beginMarker);
    const qsizetype end = begin < 0 ? -1 : config.indexOf(endMarker, begin);
    if (begin >= 0 && end >= 0) {
        config.replace(begin, end + endMarker.size() - begin, block);
    } else {
        const QRegularExpression legacyPattern(
            QStringLiteral("(?ms)^-- Tide Island shortcuts\\..*?(?=^for i = 1, 10 do)"));
        const QRegularExpressionMatch legacyMatch = legacyPattern.match(config);
        if (legacyMatch.hasMatch()) {
            config.replace(legacyMatch.capturedStart(), legacyMatch.capturedLength(), block + QStringLiteral("\n\n"));
        } else {
            if (!config.endsWith(u'\n'))
                config.append(u'\n');
            config.append(u'\n');
            config.append(block);
            config.append(u'\n');
        }
    }

    QSaveFile output(configInfo.absoluteFilePath());
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2")
            .arg(configInfo.absoluteFilePath(), output.errorString()));
        return false;
    }
    output.write(config.toUtf8());
    if (!output.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2")
            .arg(configInfo.absoluteFilePath(), output.errorString()));
        return false;
    }

    return true;
}

bool Backend::ensureManagedShortcutSource(){
    const QFileInfo configInfo(hyprlandConfigPath());
    if (!QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    QString existing;
    QFile input(configInfo.absoluteFilePath());
    if (input.exists()) {
        if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
            setErrorString(QStringLiteral("Could not read %1: %2").arg(configInfo.absoluteFilePath(), input.errorString()));
            return false;
        }
        existing = QString::fromUtf8(input.readAll());
    }

    const QString sourcePath = managedShortcutConfigPath();
    const QString sourceLine = QStringLiteral("source = %1").arg(sourcePath);
    const QStringList inputLines = existing.split(u'\n');
    QStringList outputLines;
    outputLines.reserve(inputLines.size() + 4);

    bool sourcePresent = false;
    for (const QString &line : inputLines) {
        const QString trimmed = line.trimmed();
        if (trimmed == sourceLine) {
            sourcePresent = true;
            outputLines.append(line);
            continue;
        }

        if (trimmed.contains(QString::fromLatin1(tideShortcutPrefix))
            || trimmed.contains(QString::fromLatin1(legacyTideShortcutPrefix)))
            continue;
        if (trimmed == QStringLiteral("# Tide Island shortcuts")
            || trimmed == QStringLiteral("# Tide Island shortcut bindings"))
            continue;

        outputLines.append(line);
    }

    if (!sourcePresent) {
        if (!outputLines.isEmpty() && !outputLines.last().trimmed().isEmpty())
            outputLines.append(QString());
        outputLines.append(QStringLiteral("# Tide Island shortcut bindings"));
        outputLines.append(QStringLiteral("# Generated binds are stored in ~/.config/tide-island/hyprland-shortcuts.conf."));
        outputLines.append(QStringLiteral("# They call Quickshell IPC and can also be reused from your own scripts."));
        outputLines.append(sourceLine);
    }

    QString output = outputLines.join(u'\n');
    if (!output.endsWith(u'\n'))
        output.append(u'\n');

    QSaveFile file(configInfo.absoluteFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    file.write(output.toUtf8());
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    return true;
}

bool Backend::reloadHyprland(){
    QProcess process;
    process.setProgram(QStringLiteral("hyprctl"));
    process.setArguments({QStringLiteral("reload")});
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
    process.start();
    return process.waitForFinished(5000)
        && process.exitStatus() == QProcess::NormalExit
        && process.exitCode() == 0;
}

void Backend::load(){
    QFile file(m_userConfigPath);
    if (!file.exists()) {
        setUserConfig({});
        setErrorString(QString());
        return;
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setUserConfig({});
        setErrorString(QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, file.errorString()));
        return;
    }

    const QByteArray contents = file.readAll();
    if (contents.trimmed().isEmpty()) {
        setUserConfig({});
        setErrorString(QString());
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(stripJsonComments(contents), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        setUserConfig({});
        setErrorString(QStringLiteral("Invalid JSON in %1 at offset %2: %3")
            .arg(m_userConfigPath)
            .arg(parseError.offset)
            .arg(parseError.errorString()));
        return;
    }

    if (!document.isObject()) {
        setUserConfig({});
        setErrorString(QStringLiteral("Invalid JSON in %1: root value must be an object.").arg(m_userConfigPath));
        return;
    }

    setUserConfig(document.object().toVariantMap());
    setErrorString(QString());
}

void Backend::setErrorString(const QString &errorString){
    if (m_errorString == errorString)
        return;

    m_errorString = errorString;
    emit errorStringChanged();
}

QVariantMap Backend::toVariantMap() const{
    QVariantMap result;
    for (const auto &[key, value] : m_userConfig)
        result.insert(key, value);
    return result;
}

void Backend::setUserConfig(const QVariantMap &userConfig){
    m_userConfig = toUserConfigMap(userConfig);
}
