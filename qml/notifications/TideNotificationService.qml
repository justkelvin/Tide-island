import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "NotificationLogic.js" as NotificationLogic

Item {
    id: root

    property bool nativeEnabled: true
    readonly property alias model: notificationModel
    property alias dndEnabled: persistentNotificationState.doNotDisturb
    property int historyCount: 0
    property int nextInternalId: -1
    property var server: null
    property var expirationTimers: ({})
    property var pendingRefreshes: ({})

    signal popupRequested(var notificationId)
    signal entryChanged(var notificationId)

    visible: false
    width: 0
    height: 0

    PersistentProperties {
        id: persistentNotificationState
        reloadableId: "tide-notification-state"
        property bool doNotDisturb: false
    }

    ListModel {
        id: notificationModel
        dynamicRoles: true
    }

    Component {
        id: expirationTimerComponent

        Timer {
            property real notificationId: 0
            repeat: false
            onTriggered: root.expireNotification(notificationId)
        }
    }

    Component {
        id: serverComponent

        NotificationServer {
            keepOnReload: true
            persistenceSupported: false
            bodySupported: true
            // Tide intentionally renders plain text. Clients must not assume
            // that arbitrary HTML is accepted or interpreted.
            bodyMarkupSupported: false
            bodyHyperlinksSupported: false
            bodyImagesSupported: false
            actionsSupported: true
            actionIconsSupported: true
            imageSupported: true
            inlineReplySupported: true

            onNotification: notification => root.ingestNotification(notification)
        }
    }

    function recreateServer() {
        if (server) {
            server.destroy();
            server = null;
        }

        if (!nativeEnabled) {
            console.info("[Tide Notifications] Native notification ownership is disabled by configuration.");
            return;
        }

        console.info("[Tide Notifications] Requesting org.freedesktop.Notifications ownership. "
            + "If another daemon owns the name, Quickshell will report the D-Bus error here.");
        server = serverComponent.createObject(root);
        if (!server)
            console.error("[Tide Notifications] Could not create Quickshell NotificationServer.");
        else
            Qt.callLater(root.restoreTrackedNotifications);
    }

    function restoreTrackedNotifications() {
        if (!server || !server.trackedNotifications)
            return;
        const tracked = server.trackedNotifications.values || [];
        for (let index = 0; index < tracked.length; ++index) {
            const notification = tracked[index];
            if (notification && findIndex(notification.id) < 0)
                ingestNotification(notification);
        }
    }

    function stringValue(value) {
        return NotificationLogic.stringValue(value);
    }

    function findIndex(notificationId) {
        return NotificationLogic.findIndex(notificationModel, notificationId);
    }

    function entryById(notificationId) {
        const index = findIndex(notificationId);
        return index >= 0 ? notificationModel.get(index) : null;
    }

    function domainProvenance(bodyText) {
        return NotificationLogic.domainProvenance(bodyText);
    }

    function actionSnapshot(notification) {
        const identifiers = [];
        const texts = [];
        const actions = notification && notification.actions ? notification.actions : [];
        for (let index = 0; index < actions.length; ++index) {
            const action = actions[index];
            if (!action)
                continue;
            identifiers.push(stringValue(action.identifier));
            texts.push(stringValue(action.text));
        }
        return { identifiers: identifiers, texts: texts };
    }

    function hintedImage(notification) {
        if (!notification || !notification.hints)
            return "";
        const hints = notification.hints;
        const keys = ["image-path", "image_path", "image-url", "image_url"];
        for (let index = 0; index < keys.length; ++index) {
            const value = stringValue(hints[keys[index]]);
            if (value !== "")
                return value;
        }
        return "";
    }

    function normalizeImageSource(source) {
        const value = stringValue(source);
        if (value === "")
            return "";
        if (value[0] === "/")
            return "file://" + value;
        if (value.indexOf("://") >= 0 || value.indexOf("image://") === 0)
            return value;
        return Quickshell.iconPath(value, "dialog-information");
    }

    function visualSource(notification) {
        let source = stringValue(notification.image);
        if (source === "")
            source = hintedImage(notification);
        if (source === "")
            source = stringValue(notification.appIcon);
        if (source === "" && stringValue(notification.desktopEntry) !== "") {
            const desktop = DesktopEntries.byId(stringValue(notification.desktopEntry));
            if (desktop)
                source = stringValue(desktop.icon);
        }
        return normalizeImageSource(source);
    }

    function urgencyName(urgency) {
        if (Number(urgency) === Number(NotificationUrgency.Critical))
            return "critical";
        if (Number(urgency) === Number(NotificationUrgency.Low))
            return "low";
        return "normal";
    }

    function closeReasonName(reason) {
        if (Number(reason) === Number(NotificationCloseReason.Expired))
            return "expired";
        if (Number(reason) === Number(NotificationCloseReason.Dismissed))
            return "dismissed";
        return "close-requested";
    }

    function buildSnapshot(notification, existing) {
        const now = Date.now();
        const rawBody = stringValue(notification.body);
        const provenance = domainProvenance(rawBody);
        const actions = actionSnapshot(notification);
        const notificationId = Number(notification.id);
        const transientValue = notification["transient"];
        const isTransient = transientValue === undefined
            ? !!notification.isTransient
            : !!transientValue;
        return {
            notificationId: notificationId,
            appName: stringValue(notification.appName),
            desktopEntry: stringValue(notification.desktopEntry),
            appIcon: stringValue(notification.appIcon),
            summary: stringValue(notification.summary),
            rawBody: rawBody,
            body: provenance.body,
            sourceName: provenance.source,
            image: stringValue(notification.image),
            visualSource: visualSource(notification),
            urgency: Number(notification.urgency),
            urgencyName: urgencyName(notification.urgency),
            receivedAt: existing ? Number(existing.receivedAt) : now,
            updatedAt: now,
            expireTimeout: Number(notification.expireTimeout),
            resident: !!notification.resident,
            transient: isTransient,
            actionIdentifiers: actions.identifiers,
            actionTexts: actions.texts,
            hasActionIcons: !!notification.hasActionIcons,
            hasDefaultAction: actions.identifiers.indexOf("default") >= 0,
            hasInlineReply: !!notification.hasInlineReply,
            inlineReplyPlaceholder: stringValue(notification.inlineReplyPlaceholder),
            hints: notification.hints || ({}),
            read: existing ? !!existing.read : false,
            popupVisible: NotificationLogic.shouldShowPopup(dndEnabled),
            closed: false,
            closedReason: "",
            inHistory: !isTransient,
            liveActionable: true,
            liveNotification: notification
        };
    }

    function ingestNotification(notification) {
        if (!notification)
            return;

        notification.tracked = true;
        const notificationId = Number(notification.id);
        let index = findIndex(notificationId);
        const existing = index >= 0 ? notificationModel.get(index) : null;
        const snapshot = buildSnapshot(notification, existing);

        if (index >= 0) {
            stopExpirationTimer(notificationId);
            if (existing.liveNotification
                    && existing.liveNotification !== notification)
                existing.liveNotification.tracked = false;
            notificationModel.set(index, snapshot);
            if (index > 0)
                notificationModel.move(index, 0, 1);
        } else {
            notificationModel.insert(0, snapshot);
        }

        notification.closed.connect(function(reason) {
            root.handleClosed(notificationId, notification, reason);
        });
        connectUpdateSignals(notificationId, notification);

        enforceHistoryLimit();
        scheduleExpiration(notificationId);
        recalculateHistoryCount();
        entryChanged(notificationId);
        if (snapshot.popupVisible)
            popupRequested(notificationId);
    }

    function connectUpdateSignals(notificationId, notification) {
        const refresh = function() {
            root.scheduleRefresh(notificationId, notification);
        };
        notification.expireTimeoutChanged.connect(refresh);
        notification.appNameChanged.connect(refresh);
        notification.appIconChanged.connect(refresh);
        notification.summaryChanged.connect(refresh);
        notification.bodyChanged.connect(refresh);
        notification.urgencyChanged.connect(refresh);
        notification.actionsChanged.connect(refresh);
        notification.hasActionIconsChanged.connect(refresh);
        notification.residentChanged.connect(refresh);
        notification.transientChanged.connect(refresh);
        notification.desktopEntryChanged.connect(refresh);
        notification.imageChanged.connect(refresh);
        notification.hasInlineReplyChanged.connect(refresh);
        notification.inlineReplyPlaceholderChanged.connect(refresh);
        notification.hintsChanged.connect(refresh);
    }

    function scheduleRefresh(notificationId, generation) {
        pendingRefreshes[notificationId] = generation;
        Qt.callLater(function() {
            const pendingGeneration = root.pendingRefreshes[notificationId];
            if (!pendingGeneration)
                return;
            delete root.pendingRefreshes[notificationId];
            root.refreshNotification(notificationId, pendingGeneration);
        });
    }

    function refreshNotification(notificationId, generation) {
        let index = findIndex(notificationId);
        if (index < 0)
            return;
        const existing = notificationModel.get(index);
        if (existing.liveNotification !== generation || !existing.liveActionable)
            return;

        generation.tracked = true;
        const snapshot = buildSnapshot(generation, existing);
        stopExpirationTimer(notificationId);
        notificationModel.set(index, snapshot);
        if (index > 0)
            notificationModel.move(index, 0, 1);
        enforceHistoryLimit();
        scheduleExpiration(notificationId);
        recalculateHistoryCount();
        entryChanged(notificationId);
        if (snapshot.popupVisible)
            popupRequested(notificationId);
    }

    function publishInternal(appName, summary, body) {
        const notificationId = nextInternalId--;
        const now = Date.now();
        const provenance = domainProvenance(body);
        notificationModel.insert(0, {
            notificationId: notificationId,
            appName: stringValue(appName),
            desktopEntry: "",
            appIcon: "",
            summary: stringValue(summary),
            rawBody: stringValue(body),
            body: provenance.body,
            sourceName: provenance.source,
            image: "",
            visualSource: Quickshell.iconPath("dialog-information", "dialog-information"),
            urgency: Number(NotificationUrgency.Normal),
            urgencyName: "normal",
            receivedAt: now,
            updatedAt: now,
            expireTimeout: -1,
            resident: false,
            transient: false,
            actionIdentifiers: [],
            actionTexts: [],
            hasActionIcons: false,
            hasDefaultAction: false,
            hasInlineReply: false,
            inlineReplyPlaceholder: "",
            hints: ({}),
            read: false,
            popupVisible: NotificationLogic.shouldShowPopup(dndEnabled),
            closed: true,
            closedReason: "internal",
            inHistory: true,
            liveActionable: false,
            liveNotification: null
        });
        enforceHistoryLimit();
        recalculateHistoryCount();
        entryChanged(notificationId);
        if (!dndEnabled)
            popupRequested(notificationId);
        return notificationId;
    }

    function effectiveExpirationInterval(entry) {
        return NotificationLogic.effectiveExpirationInterval(
            entry.expireTimeout,
            entry.urgencyName
        );
    }

    function popupDisplayTimeout(notificationId) {
        const entry = entryById(notificationId);
        if (!entry)
            return 4200;
        return NotificationLogic.popupDisplayTimeout(
            entry.expireTimeout,
            entry.urgencyName
        );
    }

    function scheduleExpiration(notificationId) {
        const entry = entryById(notificationId);
        if (!entry || !entry.liveActionable)
            return;
        const interval = effectiveExpirationInterval(entry);
        if (interval <= 0)
            return;
        const timer = expirationTimerComponent.createObject(root, {
            notificationId: notificationId,
            interval: interval
        });
        if (!timer)
            return;
        expirationTimers[notificationId] = timer;
        timer.start();
    }

    function stopExpirationTimer(notificationId) {
        const timer = expirationTimers[notificationId];
        if (!timer)
            return;
        timer.stop();
        timer.destroy();
        delete expirationTimers[notificationId];
    }

    function expireNotification(notificationId) {
        stopExpirationTimer(notificationId);
        const entry = entryById(notificationId);
        if (!entry || !entry.liveActionable || !entry.liveNotification)
            return;
        const live = entry.liveNotification;
        live.expire();
        const current = entryById(notificationId);
        if (current && current.liveActionable && current.liveNotification === live)
            handleClosed(notificationId, live, NotificationCloseReason.Expired);
    }

    function handleClosed(notificationId, generation, reason) {
        const index = findIndex(notificationId);
        if (index < 0)
            return;
        const entry = notificationModel.get(index);
        if (entry.liveNotification !== generation)
            return;

        stopExpirationTimer(notificationId);
        if (entry.transient || !entry.inHistory) {
            notificationModel.remove(index);
            generation.tracked = false;
            recalculateHistoryCount();
            entryChanged(notificationId);
            return;
        }

        notificationModel.setProperty(index, "popupVisible", false);
        notificationModel.setProperty(index, "closed", true);
        notificationModel.setProperty(index, "closedReason", closeReasonName(reason));
        notificationModel.setProperty(index, "liveActionable", false);
        notificationModel.setProperty(index, "liveNotification", null);
        generation.tracked = false;
        entryChanged(notificationId);
    }

    function hidePopup(notificationId) {
        const index = findIndex(notificationId);
        if (index < 0)
            return;
        const entry = notificationModel.get(index);
        if (!entry.popupVisible)
            return;
        notificationModel.setProperty(index, "popupVisible", false);
        if (entry.transient && !entry.liveActionable)
            notificationModel.remove(index);
        entryChanged(notificationId);
    }

    function markRead(notificationId) {
        const index = findIndex(notificationId);
        if (index < 0)
            return;
        notificationModel.setProperty(index, "read", true);
        entryChanged(notificationId);
    }

    function markAllRead() {
        for (let index = 0; index < notificationModel.count; ++index) {
            if (notificationModel.get(index).inHistory)
                notificationModel.setProperty(index, "read", true);
        }
    }

    function actionByIdentifier(entry, identifier) {
        if (!entry || !entry.liveActionable || !entry.liveNotification)
            return null;
        const actions = entry.liveNotification.actions || [];
        for (let index = 0; index < actions.length; ++index) {
            if (actions[index] && stringValue(actions[index].identifier) === stringValue(identifier))
                return actions[index];
        }
        return null;
    }

    function invokeAction(notificationId, identifier) {
        const entry = entryById(notificationId);
        const action = actionByIdentifier(entry, identifier);
        if (!action)
            return false;
        action.invoke();
        hidePopup(notificationId);
        if (!entry.resident)
            dismissNotification(notificationId);
        return true;
    }

    function invokeDefault(notificationId) {
        return invokeAction(notificationId, "default");
    }

    function sendInlineReply(notificationId, text) {
        const entry = entryById(notificationId);
        const replyText = stringValue(text);
        if (!entry || !entry.liveActionable || !entry.liveNotification
                || !entry.hasInlineReply || replyText.trim() === "")
            return false;
        entry.liveNotification.sendInlineReply(replyText);
        hidePopup(notificationId);
        if (!entry.resident)
            dismissNotification(notificationId);
        return true;
    }

    function dismissNotification(notificationId) {
        const index = findIndex(notificationId);
        if (index < 0)
            return;
        const entry = notificationModel.get(index);
        const live = entry.liveActionable ? entry.liveNotification : null;
        stopExpirationTimer(notificationId);
        notificationModel.remove(index);
        recalculateHistoryCount();
        entryChanged(notificationId);
        if (live) {
            live.dismiss();
            live.tracked = false;
        }
    }

    function clearAll() {
        const liveNotifications = [];
        for (let index = 0; index < notificationModel.count; ++index) {
            const entry = notificationModel.get(index);
            stopExpirationTimer(entry.notificationId);
            if (entry.liveActionable && entry.liveNotification)
                liveNotifications.push(entry.liveNotification);
        }
        notificationModel.clear();
        recalculateHistoryCount();
        for (let liveIndex = 0; liveIndex < liveNotifications.length; ++liveIndex) {
            liveNotifications[liveIndex].dismiss();
            liveNotifications[liveIndex].tracked = false;
        }
    }

    function setDndEnabled(enabled) {
        dndEnabled = !!enabled;
    }

    function recalculateHistoryCount() {
        let count = 0;
        for (let index = 0; index < notificationModel.count; ++index) {
            if (notificationModel.get(index).inHistory)
                ++count;
        }
        historyCount = count;
    }

    function enforceHistoryLimit() {
        recalculateHistoryCount();
        while (historyCount > 50) {
            let removed = false;
            for (let index = notificationModel.count - 1; index >= 0; --index) {
                const entry = notificationModel.get(index);
                if (!entry.inHistory)
                    continue;
                if (entry.liveActionable) {
                    notificationModel.setProperty(index, "inHistory", false);
                    removed = true;
                    break;
                }
                stopExpirationTimer(entry.notificationId);
                notificationModel.remove(index);
                removed = true;
                break;
            }
            if (!removed)
                break;
            recalculateHistoryCount();
        }
    }

    onNativeEnabledChanged: recreateServer()

    onDndEnabledChanged: {
        if (!dndEnabled)
            return;
        for (let index = 0; index < notificationModel.count; ++index) {
            const entry = notificationModel.get(index);
            if (!entry.popupVisible)
                continue;
            notificationModel.setProperty(index, "popupVisible", false);
            entryChanged(entry.notificationId);
        }
    }

    Component.onCompleted: recreateServer()
    Component.onDestruction: {
        const keys = Object.keys(expirationTimers);
        for (let index = 0; index < keys.length; ++index)
            stopExpirationTimer(keys[index]);
    }
}
