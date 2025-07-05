// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include "fileinfo.hpp"
#include <QDateTime>
#include <QFileInfo>
#include <QUrl>

FileInfo::FileInfo(QObject *parent) : QObject(parent) {}

QString FileInfo::baseName() const
{
    return m_fileInfo.baseName();
}

QString FileInfo::fileName() const
{
    return m_fileInfo.fileName();
}

QString FileInfo::path() const
{
    return m_fileInfo.absoluteFilePath();
}

void FileInfo::setPath(QString path)
{
    m_fileInfo.setFile(QUrl::fromPercentEncoding(path.toUtf8()));
    emit pathChanged(path);
}

bool FileInfo::isExist() const
{
    return m_fileInfo.exists();
}

void FileInfo::refresh()
{
    m_fileInfo.refresh();
}
