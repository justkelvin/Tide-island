#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>

class UserConfigBackend final : public QObject {
    Q_OBJECT
    QML_NAMED_ELEMENT(UserConfig)
    QML_SINGLETON

    Q_PROPERTY(QString userConfigPath READ userConfigPath CONSTANT FINAL)
    Q_PROPERTY(QString configError READ configError NOTIFY configErrorChanged FINAL)

    Q_PROPERTY(QString iconFontFamily READ iconFontFamily NOTIFY iconFontFamilyChanged FINAL)
    Q_PROPERTY(QString textFontFamily READ textFontFamily NOTIFY textFontFamilyChanged FINAL)
    Q_PROPERTY(QString heroFontFamily READ heroFontFamily NOTIFY heroFontFamilyChanged FINAL)
    Q_PROPERTY(QString timeFontFamily READ timeFontFamily NOTIFY timeFontFamilyChanged FINAL)
    Q_PROPERTY(QString clockFormat READ clockFormat NOTIFY clockFormatChanged FINAL)

    Q_PROPERTY(int dynamicIslandPrimaryButton READ dynamicIslandPrimaryButton NOTIFY dynamicIslandPrimaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandPrimaryAction READ dynamicIslandPrimaryAction NOTIFY dynamicIslandPrimaryActionChanged FINAL)
    Q_PROPERTY(int dynamicIslandSecondaryButton READ dynamicIslandSecondaryButton NOTIFY dynamicIslandSecondaryButtonChanged FINAL)
    Q_PROPERTY(QString dynamicIslandSecondaryAction READ dynamicIslandSecondaryAction NOTIFY dynamicIslandSecondaryActionChanged FINAL)
    Q_PROPERTY(QVariantList dynamicIslandLeftSwipeItems READ dynamicIslandLeftSwipeItems NOTIFY dynamicIslandLeftSwipeItemsChanged FINAL)
    Q_PROPERTY(bool disableAutoExpandOnTrackChange READ disableAutoExpandOnTrackChange NOTIFY disableAutoExpandOnTrackChangeChanged FINAL)
    Q_PROPERTY(int hoverExpandAction READ hoverExpandAction NOTIFY hoverExpandActionChanged FINAL)
    Q_PROPERTY(bool islandAutoHideEnabled READ islandAutoHideEnabled NOTIFY islandAutoHideEnabledChanged FINAL)
    Q_PROPERTY(int islandAutoHideDelayMs READ islandAutoHideDelayMs NOTIFY islandAutoHideDelayMsChanged FINAL)
    Q_PROPERTY(bool islandShowWorkspaceOnAutoHide READ islandShowWorkspaceOnAutoHide NOTIFY islandShowWorkspaceOnAutoHideChanged FINAL)

    Q_PROPERTY(int islandWidth READ islandWidth NOTIFY islandWidthChanged FINAL)
    Q_PROPERTY(int islandHeight READ islandHeight NOTIFY islandHeightChanged FINAL)
    Q_PROPERTY(int islandExclusiveZone READ islandExclusiveZone NOTIFY islandExclusiveZoneChanged FINAL)
    Q_PROPERTY(int islandTopMargin READ islandTopMargin NOTIFY islandTopMarginChanged FINAL)
    Q_PROPERTY(int islandPositionX READ islandPositionX NOTIFY islandPositionXChanged FINAL)
    Q_PROPERTY(int islandBackgroundOpacity READ islandBackgroundOpacity NOTIFY islandBackgroundOpacityChanged FINAL)
    Q_PROPERTY(int bodyFontSize READ bodyFontSize NOTIFY bodyFontSizeChanged FINAL)
    Q_PROPERTY(int titleFontSize READ titleFontSize NOTIFY titleFontSizeChanged FINAL)
    Q_PROPERTY(int iconFontSize READ iconFontSize NOTIFY iconFontSizeChanged FINAL)

public:
    explicit UserConfigBackend(QObject *parent = nullptr);

    QString userConfigPath() const;
    QString configError() const;
    QString iconFontFamily() const;
    QString textFontFamily() const;
    QString heroFontFamily() const;
    QString timeFontFamily() const;
    QString clockFormat() const;
    int dynamicIslandPrimaryButton() const;
    QString dynamicIslandPrimaryAction() const;
    int dynamicIslandSecondaryButton() const;
    QString dynamicIslandSecondaryAction() const;
    const QVariantList &dynamicIslandLeftSwipeItems() const;
    bool disableAutoExpandOnTrackChange() const;
    int hoverExpandAction() const;
    bool islandShowWorkspaceOnAutoHide() const;
    bool islandAutoHideEnabled() const;
    int islandAutoHideDelayMs() const;
    int islandWidth() const;
    int islandHeight() const;
    int islandExclusiveZone() const;
    int islandTopMargin() const;
    int islandPositionX() const;
    int islandBackgroundOpacity() const;
    int bodyFontSize() const;
    int titleFontSize() const;
    int iconFontSize() const;

    Q_INVOKABLE int mouseButton(const QVariant &button) const;
    Q_INVOKABLE int mouseButtonsMask(const QVariant &buttons) const;
    Q_INVOKABLE void reload();

signals:
    void configErrorChanged();
    void iconFontFamilyChanged();
    void textFontFamilyChanged();
    void heroFontFamilyChanged();
    void timeFontFamilyChanged();
    void clockFormatChanged();
    void dynamicIslandPrimaryButtonChanged();
    void dynamicIslandPrimaryActionChanged();
    void dynamicIslandSecondaryButtonChanged();
    void dynamicIslandSecondaryActionChanged();
    void dynamicIslandLeftSwipeItemsChanged();
    void disableAutoExpandOnTrackChangeChanged();
    void islandShowWorkspaceOnAutoHideChanged();
    void hoverExpandActionChanged();
    void islandAutoHideEnabledChanged();
    void islandAutoHideDelayMsChanged();
    void islandWidthChanged();
    void islandHeightChanged();
    void islandExclusiveZoneChanged();
    void islandTopMarginChanged();
    void islandPositionXChanged();
    void islandBackgroundOpacityChanged();
    void bodyFontSizeChanged();
    void titleFontSizeChanged();
    void iconFontSizeChanged();

private:
    void scheduleReload();
    void loadConfig();
    void updateWatchedPaths();
    QString configHome() const;

    QString m_userConfigPath;
    QString m_configError;
    QString m_iconFontFamily = QStringLiteral("JetBrainsMono Nerd Font");
    QString m_textFontFamily = QStringLiteral("Inter Display");
    QString m_heroFontFamily = QStringLiteral("Inter Display");
    QString m_timeFontFamily = QStringLiteral("Inter Display");
    QString m_clockFormat = QStringLiteral("12");
    int m_dynamicIslandPrimaryButton = 1;
    QString m_dynamicIslandPrimaryAction = QStringLiteral("toggleExpandedPlayer");
    int m_dynamicIslandSecondaryButton = 3;
    QString m_dynamicIslandSecondaryAction = QString();
    QVariantList m_dynamicIslandLeftSwipeItems;
    bool m_islandShowWorkspaceOnAutoHide = true;
    bool m_disableAutoExpandOnTrackChange = false;
    int m_hoverExpandAction = 1;
    bool m_islandAutoHideEnabled = true;
    int m_islandAutoHideDelayMs = 1000;
    int m_islandWidth = 140;
    int m_islandBackgroundOpacity = 60;
    int m_islandHeight = 38;
    int m_islandExclusiveZone = 45;
    int m_islandTopMargin = 4;
    int m_islandPositionX = 50;
    int m_bodyFontSize = 16;
    int m_titleFontSize = 20;
    int m_iconFontSize = 18;

    QFileSystemWatcher m_watcher;
    QTimer m_reloadTimer;
};
