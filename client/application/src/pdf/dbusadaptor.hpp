// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef DBUSADAPTOR_HPP
#define DBUSADAPTOR_HPP

#include <QDBusAbstractAdaptor>

class DBusAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "ru.auroraos.ElectronicDocumentManagement")

  public:
    explicit DBusAdaptor(QObject *parent = nullptr);

  public slots:
    Q_NOREPLY void openFile(const QStringList &args);

  signals:
    void fileOpenRequested(QString path);
};

#endif // DBUSADAPTOR_HPP
