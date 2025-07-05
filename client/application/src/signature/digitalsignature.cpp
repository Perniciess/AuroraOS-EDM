// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "digitalsignature.hpp"
#include "../config/config.hpp"
#include "../database/database.hpp"
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <vector>

DigitalSignature::DigitalSignature(QObject *parent) : QObject(parent)
{
    OpenSSL_add_all_algorithms();
}

DigitalSignature::~DigitalSignature()
{
    EVP_cleanup();
}

std::vector<unsigned char> DigitalSignature::calculateSHA256(const QString &filePath)
{
    unsigned char hash[EVP_MAX_MD_SIZE];
    unsigned int hashLength = 0;

    EVP_MD_CTX *mdctx = EVP_MD_CTX_new();
    if (!mdctx)
        return {};

    if (EVP_DigestInit_ex(mdctx, EVP_sha256(), nullptr) != 1)
    {
        EVP_MD_CTX_free(mdctx);
        return {};
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
    {
        EVP_MD_CTX_free(mdctx);
        return {};
    }

    char buffer[4096];
    qint64 bytesRead;
    while ((bytesRead = file.read(buffer, 4096)) > 0)
    {
        if (EVP_DigestUpdate(mdctx, buffer, bytesRead) != 1)
        {
            file.close();
            EVP_MD_CTX_free(mdctx);
            return {};
        }
    }

    if (EVP_DigestFinal_ex(mdctx, hash, &hashLength) != 1)
    {
        file.close();
        EVP_MD_CTX_free(mdctx);
        return {};
    }

    file.close();
    EVP_MD_CTX_free(mdctx);

    return std::vector<unsigned char>(hash, hash + hashLength);
}

bool DigitalSignature::signHash(const std::vector<unsigned char> &hash, const QString &outputFile)
{
    QFile keyFile(QString::fromStdString(Config::privateKey().string()));
    if (!keyFile.open(QIODevice::ReadOnly))
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось открыть закрытый ключ:" << keyFile.errorString();
        return false;
    }

    QByteArray keyData = keyFile.readAll();
    keyFile.close();

    BIO *bio = BIO_new_mem_buf(keyData.constData(), keyData.size());
    if (!bio)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось создать BIO bufer";
        return false;
    }

    EVP_PKEY *privateKey = PEM_read_bio_PrivateKey(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);

    if (!privateKey)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось прочитать ключ из данных PEM";
        return false;
    }

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(privateKey, nullptr);
    if (!ctx)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось создать контекст";
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (EVP_PKEY_sign_init(ctx) <= 0)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось инициаилизровать подпись";
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (EVP_PKEY_CTX_set_signature_md(ctx, EVP_sha256()) <= 0)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось установить подпись";
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    size_t signatureLen;
    if (EVP_PKEY_sign(ctx, nullptr, &signatureLen, hash.data(), hash.size()) <= 0)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось определить длину подписи";
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    std::vector<unsigned char> signature(signatureLen);
    if (EVP_PKEY_sign(ctx, signature.data(), &signatureLen, hash.data(), hash.size()) <= 0)
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось подписать хэш";
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    QFile output(outputFile);
    if (!output.open(QIODevice::WriteOnly))
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось открыть файл для записи подписанного хэша:"
                   << output.errorString();
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    qint64 bytesWritten =
        output.write(reinterpret_cast<const char *>(signature.data()), signatureLen);
    output.close();

    if (bytesWritten != static_cast<qint64>(signatureLen))
    {
        qDebug() << "[DEBUG|SIGNATURE] Не удалось записать подпись в файл";
        EVP_PKEY_CTX_free(ctx);
        EVP_PKEY_free(privateKey);
        return false;
    }

    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(privateKey);

    return true;
}

bool DigitalSignature::signFile(const QString &fileName)
{
    const QFileInfo fileInfo(fileName);

    if (!fileInfo.exists() || fileInfo.size() == 0)
    {
        qDebug() << "[DEBUG|SIGNATURE] Файла не существует или он пустой";
        return false;
    }

    QString signatureDir = QString::fromStdString(Config::signatureFolder().string());
    QDir dir(signatureDir);

    QString signatureFileName = fileInfo.fileName() + ".sig";
    QString signatureFilePath = dir.filePath(signatureFileName);

    std::vector<unsigned char> hash = calculateSHA256(fileInfo.absoluteFilePath());
    if (hash.empty())
    {
        qDebug() << "[DEBUG|SIGNATURE] Ошибка вычисления хэша";
        return false;
    }

    signHash(hash, signatureFilePath);

    Database db;
    if (!db.saveToDatabase(fileInfo.absoluteFilePath(), "signed", hash, signatureFilePath, true))
    {
        return false;
    }

    return true;
}
