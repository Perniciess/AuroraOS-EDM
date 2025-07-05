// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef DATABASE_HPP
#define DATABASE_HPP

#include <QString>
#include <vector>

class Database
{
  public:
    static bool saveToDatabase(const QString &fileName,
                               const QString &status,
                               const std::vector<unsigned char> &hash,
                               const QString &sigPath,
                               bool updateExisting);

    static int initialize();
    static QString file_status(const QString &file_path);
    static QString sig_path(const QString &file_path);

    QStringList allFileHashes() const;

  private:
    static int generateDatabaseFolder();
    static bool checkDatabaseFolder();
    static bool checkDatabaseFile();
    static int generateDatabaseFile();
};

#endif // DATABASE_HPP
