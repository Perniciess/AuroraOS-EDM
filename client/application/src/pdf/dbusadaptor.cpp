// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QStringList>
#include <QUrl>

#include "dbusadaptor.hpp"

DBusAdaptor::DBusAdaptor(QObject *parent) : QDBusAbstractAdaptor(parent)
{

    QDBusConnection dbusConnection = QDBusConnection::sessionBus();
    if (!dbusConnection.interface()->isServiceRegistered(
            QStringLiteral("ru.auroraos.ElectronicDocumentManagement")))
    {
        dbusConnection.registerObject(
            QStringLiteral("/ru/ru.auroraos/ElectronicDocumentManagement"), parent);
        dbusConnection.registerService(QStringLiteral("ru.auroraos.ElectronicDocumentManagement"));
    }
}

void DBusAdaptor::openFile(const QStringList &args)
{
    if (args.isEmpty())
        return;

    QString path;
    for (const auto &arg : args)
    {
        if (arg.isEmpty())
            continue;

        path = arg;
        break;
    }

    path = QUrl::fromPercentEncoding(path.toUtf8());
    path.remove(QStringLiteral("file://"));

    emit fileOpenRequested(path);
}
