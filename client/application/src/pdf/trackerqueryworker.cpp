// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "trackerqueryworker.hpp"
#include "dbusconstants.hpp"
#include <QDBusInterface>
#include <QDBusUnixFileDescriptor>
#include <QRegularExpression>
#include <QTemporaryFile>
#include <QTextStream>
#include <QUrl>

TrackerQueryWorker::TrackerQueryWorker() {}

TrackerQueryWorker::~TrackerQueryWorker() {}

void TrackerQueryWorker::run()
{
    QTemporaryFile tmpFile;
    tmpFile.open();
    QDBusUnixFileDescriptor buffer(tmpFile.handle());
    QMap<QString, QVariant> answerMap;
    static const QString method(QStringLiteral("Query"));
    QDBusInterface dbus_iface(TRACKER_SERVICE, TRACKER_PATH, TRACKER_INTERFACE,
                              QDBusConnection::sessionBus());
    QDBusReply<QDBusArgument> replay =
        dbus_iface.call(method, SPARQL_QUERY, QVariant::fromValue(buffer), answerMap);

    const auto returnValue = replay.value();
    static const QRegularExpression re(QStringLiteral("(file:\\/\\/).+(.pdf)"));
    QStringList freshData;
    QTextStream stream(&tmpFile);
    stream.seek(0);
    auto lineCount = 0;
    auto fileSize = tmpFile.size();
    while (!stream.atEnd() && lineCount < fileSize)
    {
        ++lineCount;
        auto string = stream.readLine();
        auto strings = string.split(".pdf", QString::KeepEmptyParts);
        for (const auto &str : strings)
        {
            auto matchIt = re.globalMatch(str + ".pdf");
            while (matchIt.hasNext())
            {
                auto match = matchIt.next();
                auto path = match.captured(0).remove(QStringLiteral("file://"));
                path = QUrl::fromPercentEncoding(path.toUtf8());
                if (QFile::exists(path))
                    freshData.append(path);
            }
        }
    }

    emit done(freshData);
}
