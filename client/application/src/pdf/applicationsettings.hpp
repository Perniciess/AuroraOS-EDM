// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#ifndef APPLICATIONSETTINGS_HPP
#define APPLICATIONSETTINGS_HPP

#include <QObject>
#include <QPointF>
#include <QScopedPointer>
#include <QSettings>

class QQmlEngine;
class QJSEngine;
class ApplicationSettings : public QObject
{
    Q_OBJECT

  public:
    static void registerSingleton(const char *uri);
    static QObject *singletonProvider(QQmlEngine *engine, QJSEngine *);

  public slots:
    bool notesPaint(const QString &name) const;
    bool verticalScroll(const QString &name) const;
    void setNotesPaint(const QString &name, bool notesPaint);
    void setVerticalScroll(const QString &name, bool verticalScroll);
    void setDocumentZoomAndPosition(const QString &name, qreal zoom, const QPointF &position);
    float getDocumentZoom(const QString &name) const;
    QPointF getDocumentPosition(const QString &name) const;
    void setDocumentLastOpen(const QString &name);

  signals:
    void notesPaintChanged(bool notesPaint);
    void verticalScrollChanged(bool verticalScroll);

  private:
    explicit ApplicationSettings(QObject *parent = nullptr);
    QScopedPointer<QSettings> m_settings;
};

#endif // APPLICATIONSETTINGS_HPP
