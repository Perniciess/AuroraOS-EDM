// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "websocket.hpp"
#include "../config/config.hpp"
#include "../database/database.hpp"
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

QT_USE_NAMESPACE

WebSocket::WebSocket(QObject *parent) : QObject(parent) {}

WebSocket::WebSocket(const QUrl &url, QObject *parent) : QObject(parent), m_url(url)
{
    connect(&m_webSocket, &QWebSocket::connected, this, &WebSocket::onConnected);
    connect(&m_webSocket,
            static_cast<void (QWebSocket::*)(const QList<QSslError> &)>(&QWebSocket::sslErrors),
            this,
            &WebSocket::onSslErrors);
    connect(
        &m_webSocket, &QWebSocket::textMessageReceived, this, &WebSocket::onTextMessageReceived);
    m_webSocket.open(QUrl(url));
    connect(&m_webSocket,
            &QWebSocket::binaryMessageReceived,
            this,
            &WebSocket::onBinaryMessageReceived);
}

QUrl WebSocket::url() const
{
    return m_url;
}

void WebSocket::setUrl(const QUrl &url)
{
    if (m_url == url)
        return;

    m_url = url;
    emit urlChanged();
}

void WebSocket::onConnected()
{
    qDebug() << "[DEBUG|WEBSOCKET] WebSocket connected";
}

void WebSocket::sendFile(const QString &file_path)
{
    sendPDF(file_path);
    sendSig(file_path);
    sendCert();
}

void WebSocket::sendPDF(const QString &file_path)
{
    m_lastSentFilePath = file_path;
    QFile file(file_path);
    if (!file.open(QIODevice::ReadOnly))
    {
        return;
    }

    QFileInfo fileInfo(file);
    m_webSocket.sendTextMessage("FILENAME:" + fileInfo.completeBaseName());

    const int chunkSize = 64 * 1024;
    while (!file.atEnd())
    {
        QByteArray chunk = file.read(chunkSize);
        m_webSocket.sendBinaryMessage(chunk);
    }

    file.close();
    m_webSocket.sendTextMessage("EOF_PDF");
}

void WebSocket::sendSig(const QString &file_path)
{
    QString sigPath = Database::sig_path(file_path);

    QFile file(sigPath);
    if (!file.open(QIODevice::ReadOnly))
    {
        return;
    }
    const int chunkSize = 64 * 1024;
    while (!file.atEnd())
    {
        QByteArray chunk = file.read(chunkSize);
        m_webSocket.sendBinaryMessage(chunk);
    }
    file.close();
    m_webSocket.sendTextMessage("EOF_HASH");
}

void WebSocket::sendCert()
{
    QString certPath = QString::fromStdString(Config::certificate().string());

    QFile file(certPath);
    if (!file.open(QIODevice::ReadOnly))
    {
        return;
    }
    const int chunkSize = 64 * 1024;
    while (!file.atEnd())
    {
        QByteArray chunk = file.read(chunkSize);
        m_webSocket.sendBinaryMessage(chunk);
    }
    file.close();
    m_webSocket.sendTextMessage("EOF_CERT");
}

void WebSocket::getFilesList()
{
    if (m_webSocket.state() == QAbstractSocket::ConnectedState)
    {
        m_webSocket.sendTextMessage("GET_FILES_LIST");
    }
}

void WebSocket::onTextMessageReceived(const QString &message)
{
    if (message.startsWith("FILE_LIST:"))
    {
        QString jsonString = message.mid(10);
        qDebug() << "[DEBUG|WEBSOCKET] Received FILE_LIST content:" << jsonString;
        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError)
        {
            return;
        }

        QVariantList fileList;
        if (doc.isArray())
        {
            for (const QJsonValue &val : doc.array())
            {
                QJsonObject obj = val.toObject();
                QVariantMap map;
                map["file_name"] = obj.value("file_name").toString();
                map["file_status"] = obj.value("file_status").toString();
                map["file_hash"] = obj.value("fileHash").toString();
                fileList.append(map);
            }
            m_filesList = fileList;
            emit filesListChanged();
        }
    }
    else if (message == "FILE_SAVED_SUCCESS")
    {
        if (!m_lastSentFilePath.isEmpty())
        {
            std::vector<unsigned char> emptyHash;
            Database::saveToDatabase(m_lastSentFilePath,
                                     "process",
                                     emptyHash,
                                     Database::sig_path(m_lastSentFilePath),
                                     true);

            emit fileStatusChanged(m_lastSentFilePath, "process");
        }
    }
    else if (message.trimmed() == "Успешная авторизация")
    {
        emit authorized();
    }

    else if (message.startsWith("FILE_NAME:"))
    {
        QString fileName = message.mid(10);
        m_currentDownloadFileName = fileName;
        m_currentDownloadData.clear();
        qDebug() << "[DEBUG|WEBSOCKET] Preparing to download file:" << fileName;
    }

    else if (message == "FILE_NOT_FOUND")
    {
        qDebug() << "[DEBUG|WEBSOCKET] Requested file not found on server";
        emit downloadError(tr("File not found on server"));
    }
    else if (message == "INVALID_FILE_ID")
    {
        qDebug() << "[DEBUG|WEBSOCKET] Invalid file ID requested";
        emit downloadError(tr("Invalid file ID"));
    }
    else if (message == "EOF_FILE")
    {
        QString savePath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) +
                           "/" + m_currentDownloadFileName;

        QFile file(savePath);
        if (file.open(QIODevice::WriteOnly))
        {
            file.write(m_currentDownloadData);
            file.close();
            qDebug() << "[DEBUG|WEBSOCKET] File saved to:" << savePath;
            emit fileDownloaded(savePath);
        }
        else
        {
            qDebug() << "[DEBUG|WEBSOCKET] Failed to save file to:" << savePath;
            emit downloadError(tr("Could not save file"));
        }

        m_currentDownloadData.clear();
        m_currentDownloadFileName.clear();
    }
}

QStringList WebSocket::getLocalFileHashes()
{
    return m_database.allFileHashes();
}

void WebSocket::setPassword(const QString &password)
{
    m_password = password;

    if (m_webSocket.state() == QAbstractSocket::ConnectedState)
    {
        m_webSocket.sendTextMessage(m_password);
    }
    else
    {
        connect(&m_webSocket,
                &QWebSocket::connected,
                this,
                [this]()
                {
                    m_webSocket.sendTextMessage(m_password);
                });
    }
}

void WebSocket::downloadFile(int fileId)
{
    if (m_webSocket.state() == QAbstractSocket::ConnectedState)
    {
        qDebug() << "[DEBUG|WEBSOCKET] Requesting file with ID:" << fileId;
        m_webSocket.sendTextMessage(QString("GET FILE:%1").arg(fileId));
    }
    else
    {
        qDebug() << "[DEBUG|WEBSOCKET] Cannot download file - not connected to server";
    }
}

void WebSocket::onBinaryMessageReceived(const QByteArray &message)
{
    m_currentDownloadData.append(message);
}

void WebSocket::onSslErrors(const QList<QSslError> &errors)
{
    Q_UNUSED(errors);
    m_webSocket.ignoreSslErrors();
}
