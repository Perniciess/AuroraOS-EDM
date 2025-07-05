// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef TRACKERQUERYWORKER_HPP
#define TRACKERQUERYWORKER_HPP

#include <QDBusReply>
#include <QObject>
#include <QRunnable>

class TrackerQueryWorker : public QObject, public QRunnable
{
    Q_OBJECT

  public:
    TrackerQueryWorker();
    ~TrackerQueryWorker() override;

    void run() override;

  signals:
    void done(QStringList);
};

#endif // TRACKERQUERYWORKER_HPP
