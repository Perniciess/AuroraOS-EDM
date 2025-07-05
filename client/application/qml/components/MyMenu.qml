// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.2
import Sailfish.Silica 1.0

Item {
    id: bottomMenu
    width: parent.width

    PushUpMenu {
        MenuItem {
            text: "Локальные файлы"
            onClicked: {
                bottomMenu.clicked("FilesPage.qml");
            }
        }
        MenuItem {
            text: "Удаленные файлы"
            onClicked: {
                bottomMenu.clicked("ServerFilesPage.qml");
            }
        }
    }

    signal clicked(string pageUrl)
}
