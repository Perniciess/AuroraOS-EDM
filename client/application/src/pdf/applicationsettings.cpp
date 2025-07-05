// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include <QSettings>
#include <QStandardPaths>
#include <QtQml>

#include "applicationsettings.hpp"

#define SETTINGS_FILE_PATH                                                                         \
    QStringLiteral("%1/%2")                                                                        \
        .arg(QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation))                  \
        .arg("settings.conf")

static const QString s_verticalScrollSettingsName = QStringLiteral("verticalScroll");
static const QString s_notesPaintSettingsName = QStringLiteral("notesPaint");
static const QString s_documentSectionName = QStringLiteral("Documents");
static const QString s_documentZoom = QStringLiteral("zoom");
static const QString s_documentPosition = QStringLiteral("position");
static const QString s_documentLastOpen = QStringLiteral("lastOpen");

static ApplicationSettings *s_instance;

ApplicationSettings::ApplicationSettings(QObject *parent) : QObject(parent)
{
    m_settings.reset(new QSettings(SETTINGS_FILE_PATH, QSettings::Format::NativeFormat, this));
}

bool ApplicationSettings::notesPaint(const QString &name) const
{
    m_settings->beginGroup(s_documentSectionName);
    auto notesPaint =
        m_settings->value(QString("%1/%2").arg(name).arg(s_notesPaintSettingsName), true).toBool();
    m_settings->endGroup();

    return notesPaint;
}

bool ApplicationSettings::verticalScroll(const QString &name) const
{
    m_settings->beginGroup(s_documentSectionName);
    auto verticalScroll =
        m_settings->value(QString("%1/%2").arg(name).arg(s_verticalScrollSettingsName), true)
            .toBool();
    m_settings->endGroup();

    return verticalScroll;
}

void ApplicationSettings::registerSingleton(const char *uri)
{
    qmlRegisterSingletonType<ApplicationSettings>(uri, 1, 0, "ApplicationSettings",
                                                  ApplicationSettings::singletonProvider);
}

QObject *ApplicationSettings::singletonProvider(QQmlEngine *engine, QJSEngine *)
{
    if (!s_instance)
        s_instance = new ApplicationSettings(engine);

    return s_instance;
}

void ApplicationSettings::setNotesPaint(const QString &name, bool notesPaint)
{
    m_settings->beginGroup(s_documentSectionName);
    m_settings->setValue(QString("%1/%2").arg(name).arg(s_notesPaintSettingsName),
                         qVariantFromValue(notesPaint));
    m_settings->endGroup();
}

void ApplicationSettings::setVerticalScroll(const QString &name, bool verticalScroll)
{
    m_settings->beginGroup(s_documentSectionName);
    m_settings->setValue(QString("%1/%2").arg(name).arg(s_verticalScrollSettingsName),
                         qVariantFromValue(verticalScroll));
    m_settings->endGroup();
}

void ApplicationSettings::setDocumentZoomAndPosition(const QString &name,
                                                     qreal zoom,
                                                     const QPointF &position)
{
    m_settings->beginGroup(s_documentSectionName);
    m_settings->setValue(QString("%1/%2").arg(name).arg(s_documentZoom),
                         qVariantFromValue(float(zoom)));
    m_settings->setValue(QString("%1/%2").arg(name).arg(s_documentPosition),
                         qVariantFromValue(position));
    m_settings->endGroup();
}

float ApplicationSettings::getDocumentZoom(const QString &name) const
{
    m_settings->beginGroup(s_documentSectionName);
    auto zoom = m_settings->value(QString("%1/%2").arg(name).arg(s_documentZoom), 1.0f).toFloat();
    m_settings->endGroup();

    return zoom;
}

QPointF ApplicationSettings::getDocumentPosition(const QString &name) const
{
    m_settings->beginGroup(s_documentSectionName);
    auto position =
        m_settings->value(QString("%1/%2").arg(name).arg(s_documentPosition), QPointF(0.0, 0.0))
            .toPointF();
    m_settings->endGroup();

    return position;
}

void ApplicationSettings::setDocumentLastOpen(const QString &name)
{
    m_settings->beginGroup(s_documentSectionName);
    m_settings->setValue(QString("%1/%2").arg(name).arg(s_documentLastOpen),
                         qVariantFromValue(QDateTime::currentDateTimeUtc()));
    m_settings->endGroup();
}
