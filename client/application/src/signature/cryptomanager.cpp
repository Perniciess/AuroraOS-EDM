// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "cryptomanager.hpp"
#include "../config/config.hpp"
#include <QDebug>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/pem.h>

int CryptoManager::initialize()
{

    if (checkKeysFolder() == false)
    {
        if (generateKeysFolder() == 1)
        {
            qDebug() << "[DEBUG|MANAGER] Ошибка инициализации. Создание папки для ключей не "
                          "удалось.\n";
            return 1;
        };
    };

    if (checkSignatureFolder() == false)
    {
        if (generateSignatureFolder() == 1)
        {
            qDebug() << "[DEBUG|MANAGER] Ошибка инициализации. Создание папки для подписей "
                          "не удалось.\n";
            return 1;
        };
    };

    if (checkKeys() == false)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка инициализации. Создание ключей не удалось.\n";
        return 1;
    }

    return 0;
}

bool CryptoManager::checkKeysFolder()
{
    if (!fs::exists(Config::keysFolder()))
    {
        return false;
    };
    return true;
}

bool CryptoManager::checkSignatureFolder()
{
    if (!fs::exists(Config::signatureFolder()))
    {
        return false;
    };
    return true;
}

bool CryptoManager::checkKeys()
{
    if (!fs::exists(Config::privateKey()) || !fs::exists(Config::publicKey()))
    {
        qDebug() << "[DEBUG|MANAGER] Один или оба ключа отсутствуют\n";
        if (generateKeys() == 0)
        {
            qDebug() << "[DEBUG|MANAGER] Ключи успешно сгенерированы\n";
            return true;
        }
        else
        {
            qDebug() << "[DEBUG|MANAGER] Ошибка генерации ключей\n";
            return false;
        };
    }
    qDebug() << "[DEBUG|MANAGER] Оба ключа присутствуют\n";
    return true;
}

int CryptoManager::generateKeysFolder()
{
    if (fs::create_directory(Config::keysFolder()))
    {
        qDebug() << "[DEBUG|MANAGER] Папка ключей создана: ", Config::keysFolder();
    }
    else
    {
        return 1;
    };

    return 0;
}

int CryptoManager::generateSignatureFolder()
{
    if (fs::create_directory(Config::signatureFolder()))
    {
        qDebug() << "[DEBUG|MANAGER] Папка подписей создана: ", Config::signatureFolder();
    }
    else
    {
        return 1;
    };

    return 0;
}

int CryptoManager::generateKeys()
{
    if (OPENSSL_init_crypto(0, nullptr) == 0)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. OPENSSL not initialized.\n";
        return 1;
    }

    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nullptr);
    if (!ctx)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка создания контекста.\n";
        return 1;
    }

    if (EVP_PKEY_keygen_init(ctx) <= 0 || EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка инициализации генератора "
                      "или RSA.\n";
        return 1;
    }

    EVP_PKEY *private_key = nullptr;
    if (EVP_PKEY_keygen(ctx, &private_key) <= 0)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка создания приватного ключа.\n";
        return 1;
    }

    FILE *privateKeyFile = fopen(Config::privateKey().c_str(), "wb");
    if (!privateKeyFile)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка создания файла для "
                      "приватного ключа.\n";
        EVP_PKEY_free(private_key);
        return 1;
    }

    if (PEM_write_PrivateKey(privateKeyFile, private_key, nullptr, nullptr, 0, nullptr, nullptr) !=
        1)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка записи приватного ключа "
                      "в файл.\n";
        fclose(privateKeyFile);
        return 1;
    }
    fclose(privateKeyFile);

    FILE *publicKeyFile = fopen(Config::publicKey().c_str(), "wb");
    if (!publicKeyFile)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка создания файла для "
                      "публичного ключа.\n";
        return 1;
    }
    if (PEM_write_PUBKEY(publicKeyFile, private_key) != 1)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания ключей. Ошибка записи публичного ключа "
                      "в файл.\n";
        fclose(publicKeyFile);
        return 1;
    }
    fclose(publicKeyFile);

    qDebug() << "[DEBUG|MANAGER] Старт генерации сертификата\n";
    generateCertificate(private_key);

    EVP_PKEY_free(private_key);
    EVP_PKEY_CTX_free(ctx);
    ERR_free_strings();
    OPENSSL_cleanup();

    return 0;
}

bool CryptoManager::generateCertificate(EVP_PKEY *private_key)
{
    X509 *x509 = X509_new();
    if (!x509)
        return false;

    X509_set_version(x509, 2);

    ASN1_INTEGER_set(X509_get_serialNumber(x509), 1);

    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 31536000L);

    X509_set_pubkey(x509, private_key);

    X509_NAME *name = X509_get_subject_name(x509);
    X509_NAME_add_entry_by_txt(name, "C", MBSTRING_ASC, (const unsigned char *)"RU", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "O", MBSTRING_ASC, (const unsigned char *)"My Company", -1, -1,
                               0);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, (const unsigned char *)"example.com", -1,
                               -1, 0);

    X509_set_issuer_name(x509, name);

    if (!X509_sign(x509, private_key, EVP_sha256()))
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания сертификата.\n";
        X509_free(x509);
        return false;
    }

    FILE *certFile = fopen(Config::certificate().c_str(), "wb");
    if (!certFile)
    {
        qDebug() << "[DEBUG|MANAGER] Ошибка создания сертификата. Ошибка записи сертификата "
                      "в файл.\n";
        X509_free(x509);
        return false;
    }

    bool success = PEM_write_X509(certFile, x509) == 1;
    fclose(certFile);
    X509_free(x509);

    return success;
}
