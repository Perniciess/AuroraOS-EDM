// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clauseimport QtQuick 2.0

import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.auroraos.ElectronicDocumentManagement 1.0

Page {
    id: loginPage
    objectName: "mainPage"
    allowedOrientations: Orientation.All

    property string passwordInput: ""
    property bool keyboardVisible: Qt.inputMethod.visible

    signal authorized

    Image {
        source: "image://theme/icon-l-file-pdf-dark"
        width: 3 * Theme.iconSizeLarge
        height: 3 * Theme.iconSizeLarge
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: columnField.top
        anchors.bottomMargin: 200
        visible: !keyboardVisible

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
        opacity: keyboardVisible ? 0 : 1
    }

    Column {
        id: columnField
        spacing: Theme.paddingSmall
        anchors.centerIn: parent
        anchors.topMargin: Theme.iconSizeLarge + Theme.paddingLarge

        TextField {
            id: passwordField
            echoMode: TextInput.Password
            placeholderText: qsTr("Введите пароль")
            width: loginPage.width * 0.9
            onTextChanged: loginPage.passwordInput = text
            description: "Текст подсказки или сообщение об ошибке"
            placeholderColor: Theme.primaryColor
            horizontalAlignment: TextInput.AlignHCenter
            rightItem: IconButton {
                width: icon.width
                height: icon.height
                icon.source: "image://theme/icon-splus-forward-mail"
                onClicked: {
                    webSocket.setPassword(loginPage.passwordInput);
                }
            }
        }
    }

    Connections {
        target: webSocket
        onAuthorized: {
            pageStack.clear();
            pageStack.push(Qt.resolvedUrl("pdf/FilesPage.qml"));
        }
    }
}
