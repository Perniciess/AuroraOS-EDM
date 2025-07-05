// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

#include <auroraapp.h>
#include "database/database.hpp"
#include "pdf/applicationsettings.hpp"
#include "pdf/dbusadaptor.hpp"
#include "pdf/fileinfo.hpp"
#include "pdf/filesmodel.hpp"
#include "pdf/sortmodel.hpp"
#include "signature/cryptomanager.hpp"
#include "signature/digitalsignature.hpp"
#include "websocket/websocket.hpp"
#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>
#include <QSharedPointer>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> application(Aurora::Application::application(argc, argv));
    application->setOrganizationName(QStringLiteral("ru.auroraos"));
    application->setApplicationName(QStringLiteral("EDM"));

    int cryptoInitResult = CryptoManager::initialize();
    int databaseInitResult = Database::initialize();

    qmlRegisterType<FilesModel>("ru.auroraos.ElectronicDocumentManagement", 1, 0, "FilesModel");
    qmlRegisterType<SortModel>("ru.auroraos.ElectronicDocumentManagement", 1, 0, "SortModel");
    qmlRegisterType<FileInfo>("ru.auroraos.ElectronicDocumentManagement", 1, 0, "FileInfo");

    qmlRegisterType<DigitalSignature>("ru.auroraos.ElectronicDocumentManagement", 1, 0, "DigitalSignature");
    qmlRegisterType<WebSocket>("ru.auroraos.ElectronicDocumentManagement", 1, 0, "WebSocket");

    ApplicationSettings::registerSingleton("ru.auroraos.ElectronicDocumentManagement");

    QUrl wsUrl("wss://147.45.110.162:8765");
    QSharedPointer<WebSocket> webSocket(new WebSocket(wsUrl));

    QScopedPointer<QQuickView> view(Aurora::Application::createView());

    DBusAdaptor dbusAdaptor(view.data());
    view->rootContext()->setContextProperty(QStringLiteral("dbusAdaptor"), &dbusAdaptor);
    view->rootContext()->setContextProperty(QStringLiteral("webSocket"), webSocket.data());

    view->setSource(Aurora::Application::pathTo(QStringLiteral("qml/ru.auroraos.ElectronicDocumentManagement.qml")));
    view->show();

    return application->exec();
}
