import QtQuick
import Quickshell
import "qml/notifications"

Scope {
    TideNotificationService {
        nativeEnabled: true

        onPopupRequested: notificationId => {
            const entry = entryById(notificationId);
            if (!entry)
                return;
            console.log("TIDE_NOTIFICATION_SMOKE "
                + JSON.stringify({
                    notificationId: entry.notificationId,
                    summary: entry.summary,
                    body: entry.body,
                    historyCount: historyCount
                }));
        }
    }
}
