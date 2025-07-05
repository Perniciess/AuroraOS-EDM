// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef WEBSOCKET_HPP
#define WEBSOCKET_HPP

#include "../database/database.hpp"
#include <QObject>
#include <QtWebSockets/QWebSocket>
#include <QSslError>
#include <QList>

QT_FORWARD_DECLARE_CLASS(QWebSocket)

class WebSocket : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged);
    Q_PROPERTY(QVariantList filesList READ filesList NOTIFY filesListChanged);

  public:
    explicit WebSocket(QObject *parent = nullptr);
    explicit WebSocket(const QUrl &url, QObject *parent = nullptr);

    Q_INVOKABLE void sendFile(const QString &file_path);
    Q_INVOKABLE void getFilesList();
    Q_INVOKABLE QStringList getLocalFileHashes();
    Q_INVOKABLE void setPassword(const QString &password);

    QUrl url() const;
    void setUrl(const QUrl &url);

    void sendPDF(const QString &file_path);
    void sendSig(const QString &file_path);
    void sendCert();
    void requestFile(const QString &fileId);

    QVariantList filesList() const
    {
        return m_filesList;
    }

  signals:
    void closed();
    void urlChanged();
    void filesListChanged();
    void fileStatusChanged(const QString &filePath, const QString &status);
    void authorized();

    void fileDownloaded(const QString &filePath);
    void downloadError(const QString &errorMessage);

  private slots:
    void onConnected();
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &message);
    void onSslErrors(const QList<QSslError> &errors);

  private:
    QWebSocket m_webSocket;
    QUrl m_url;
    QString m_password;
    QVariantList m_filesList;
    QString m_lastSentFilePath;
    Database m_database;

    QByteArray m_currentDownloadData;
    QString m_currentDownloadFileName;

  public slots:
    void downloadFile(int fileId);
};

#endif // WEBSOCKET_HPP
