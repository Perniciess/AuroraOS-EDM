// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "config.hpp"
#include <QByteArray>
#include <QString>

const fs::path &Config::basePath()
{
    static const QByteArray utf8Path =
        Aurora::Application::organizationFilesDir(true).path().toUtf8();
    static const fs::path path = fs::path(utf8Path.constData());
    return path;
}

const fs::path &Config::keysFolder()
{
    static const fs::path path = basePath() / "keys";
    return path;
}

const fs::path &Config::signatureFolder()
{
    static const fs::path path = basePath() / "signature";
    return path;
}

const fs::path &Config::privateKey()
{
    static const fs::path path = keysFolder() / "private_key.pem";
    return path;
}

const fs::path &Config::publicKey()
{
    static const fs::path path = keysFolder() / "public_key.pem";
    return path;
}

const fs::path &Config::certificate()
{
    static const fs::path path = keysFolder() / "certificate.pem";
    return path;
}

const fs::path &Config::databaseFolder()
{
    static const fs::path path = basePath() / "database";
    return path;
}

const fs::path &Config::databaseFile()
{
    static const fs::path path = databaseFolder() / "database.json";
    return path;
}
