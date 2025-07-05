// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clauseimport QtQuick 2.0

#include "database.hpp"
#include "../config/config.hpp"
#include "../signature/digitalsignature.hpp"
#include <QDebug>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

int Database::initialize()
{
    if (checkDatabaseFolder() == false)
    {
        if (generateDatabaseFolder() == 1)
        {
            qDebug() << "[DEBUG|DATABASE] Ошибка инициализации базы данных. Не удалось создать папку.\n";
            return 1;
        };
    };

    if (checkDatabaseFile() == false)
    {
        if (generateDatabaseFile() == 1)
        {
            qDebug() << "[DEBUG|DATABASE] Не удалось создать базу данных.\n";
            return 1;
        };
    };
    return 0;
}

bool Database::checkDatabaseFolder()
{
    if (!fs::exists(Config::databaseFolder()))
    {
        return false;
    };
    return true;
}

bool Database::checkDatabaseFile()
{
    if (!fs::exists(Config::databaseFile()))
    {
        qDebug() << "[DEBUG|DATABASE] Файл базы данных отсутствует";
        return false;
    }
    return true;
}

int Database::generateDatabaseFile()
{
    QJsonObject dbStructure;
    dbStructure["records"] = QJsonObject();
    QFile dbFile(QString::fromStdString(Config::databaseFile().string()));
    if (!dbFile.open(QIODevice::WriteOnly))
    {
        qDebug() << "[DEBUG|DATABASE] Ошибка во время создания базы данных";
        return 1;
    }
    dbFile.write(QJsonDocument(dbStructure).toJson(QJsonDocument::Indented));
    dbFile.close();

    qDebug() << "[DEBUG|DATABASE] Файл базы данных создан успешно" << QString::fromStdString(Config::databaseFile().string());
    return 0;
}

int Database::generateDatabaseFolder()
{
    if (fs::create_directory(Config::databaseFolder()))
    {
        qDebug() << "[DEBUG|DATABASE] Папка создана: ", Config::databaseFolder();
    }
    else
    {
        return 1;
    };

    return 0;
}

bool Database::saveToDatabase(const QString &fileName,
                              const QString &status,
                              const std::vector<unsigned char> &hash,
                              const QString &sigPath,
                              bool updateExisting)
{
    QJsonObject db;
    QString dbFilePath = QString::fromStdString(Config::databaseFile().string());
    QFile dbFile(dbFilePath);

    if (dbFile.exists() && dbFile.open(QIODevice::ReadOnly))
    {
        QJsonDocument doc = QJsonDocument::fromJson(dbFile.readAll());
        dbFile.close();
        if (!doc.isNull())
        {
            db = doc.object();
        }
    }

    if (!db.contains("records"))
    {
        db["records"] = QJsonObject();
    }

    QJsonObject records = db["records"].toObject();
    QString existingId;

    if (updateExisting)
    {
        for (const QString &key : records.keys())
        {
            QJsonObject record = records[key].toObject();
            if (record["file_name"].toString() == fileName)
            {
                existingId = key;
                break;
            }
        }
    }

    QString id = existingId.isEmpty() ? QUuid::createUuid().toString() : existingId;

    QJsonObject record;
    if (records.contains(id))
    {
        record = records[id].toObject();
    }

    record["file_name"] = fileName;
    record["file_sig"] = sigPath;
    record["status"] = status;

    if (!hash.empty())
    {
        record["file_hash"] = QString(QByteArray(reinterpret_cast<const char *>(hash.data()), hash.size()).toHex());
    }

    records[id] = record;
    db["records"] = records;

    if (!dbFile.open(QIODevice::WriteOnly))
    {
        qDebug() << "[DEBUG|DATABASE] Ошибка открытия базы данных для записи";
        return false;
    }

    dbFile.write(QJsonDocument(db).toJson(QJsonDocument::Indented));
    dbFile.close();
    return true;
}

QString Database::file_status(const QString &file_path)
{
    QString dbFilePath = QString::fromStdString(Config::databaseFile().string());
    QFile dbFile(dbFilePath);

    if (!dbFile.exists() || !dbFile.open(QIODevice::ReadOnly))
    {
        return QString();
    }

    QJsonDocument doc = QJsonDocument::fromJson(dbFile.readAll());
    dbFile.close();

    if (doc.isNull() || !doc.isObject())
    {
        return QString();
    }

    QJsonObject db = doc.object();
    if (!db.contains("records") || !db["records"].isObject())
    {
        return QString();
    }

    QJsonObject records = db.value("records").toObject();

    for (const QString &key : records.keys())
    {
        QJsonObject record = records.value(key).toObject();
        if (record.contains("file_name") && record["file_name"].toString() == file_path)
        {
            return record["status"].toString();
        }
    }

    DigitalSignature signer;
    auto hash = signer.calculateSHA256(file_path);

    saveToDatabase(file_path, "not viewed", hash, "", false);

    return "not viewed";
}

QString Database::sig_path(const QString &file_path)
{
    QString dbFilePath = QString::fromStdString(Config::databaseFile().string());
    QFile dbFile(dbFilePath);

    if (!dbFile.exists() || !dbFile.open(QIODevice::ReadOnly))
    {
        return QString();
    }

    QJsonDocument doc = QJsonDocument::fromJson(dbFile.readAll());
    dbFile.close();

    if (doc.isNull() || !doc.isObject())
    {
        return QString();
    }

    QJsonObject db = doc.object();
    if (!db.contains("records") || !db["records"].isObject())
    {
        return QString();
    }

    QJsonObject records = db.value("records").toObject();

    for (const QString &key : records.keys())
    {
        QJsonObject record = records.value(key).toObject();
        if (record.contains("file_name") && record["file_name"].toString() == file_path)
        {
            return record["file_sig"].toString();
        }
    }
    return QString();
}

QStringList Database::allFileHashes() const
{
    QStringList hashes;
    QString dbFilePath = QString::fromStdString(Config::databaseFile().string());
    QFile dbFile(dbFilePath);

    if (!dbFile.exists() || !dbFile.open(QIODevice::ReadOnly))
        return hashes;

    QJsonDocument doc = QJsonDocument::fromJson(dbFile.readAll());
    dbFile.close();

    if (!doc.isObject())
        return hashes;

    QJsonObject db = doc.object();
    if (!db.contains("records") || !db["records"].isObject())
        return hashes;

    QJsonObject records = db["records"].toObject();
    for (const auto &key : records.keys())
    {
        QJsonObject record = records[key].toObject();
        if (record.contains("file_hash"))
        {
            hashes << record["file_hash"].toString();
        }
    }

    return hashes;
}
