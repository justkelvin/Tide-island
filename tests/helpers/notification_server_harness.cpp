// Minimal host for the native notification server, used by the live DBus
// verification script. Prints READY once org.freedesktop.Notifications is
// owned, then runs until killed.
#include <QCoreApplication>
#include <QTextStream>

#include "NotificationServer.h"

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("tide-island-notification-harness"));

    const bool takeOver = app.arguments().contains(QStringLiteral("--take-over"));
    NotificationServer server;
    if (takeOver)
        server.takeOver();

    QTextStream out(stdout);
    if (server.isRegistered()) {
        out << "READY registered=1" << Qt::endl;
    } else {
        out << "READY registered=0" << Qt::endl;
        return 1;
    }
    return app.exec();
}
