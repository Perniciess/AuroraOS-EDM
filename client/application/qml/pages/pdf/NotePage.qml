// SPDX-FileCopyrightText: 2020-2023 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: root

    property alias noteText: noteText.value
    property alias author: authorName.value
    property alias pageNumber: pageNumber.value

    allowedOrientations: Orientation.All
    objectName: "navigationPage"

    SilicaFlickable {
        objectName: "noteFlickable"
        contentHeight: contentColumn.height + Theme.paddingLarge
        anchors.fill: parent

        Column {
            id: contentColumn

            objectName: "noteColumn"
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                objectName: "notePageHeader"
                title: qsTr("Note")
            }

            DetailItem {
                id: noteText

                label: qsTr("Content")
                alignment: Qt.AlignLeft
                forceValueBelow: true
                palette {
                    secondaryHighlightColor: Theme.secondaryColor
                    highlightColor: Theme.primaryColor
                }
            }

            DetailItem {
                id: pageNumber

                label: qsTr("Page")
                alignment: Qt.AlignLeft
                forceValueBelow: true
                palette {
                    secondaryHighlightColor: Theme.secondaryColor
                    highlightColor: Theme.primaryColor
                }
            }

            DetailItem {
                id: authorName

                label: qsTr("Author name")
                alignment: Qt.AlignLeft
                forceValueBelow: true
                palette {
                    secondaryHighlightColor: Theme.secondaryColor
                    highlightColor: Theme.primaryColor
                }
            }
        }
    }
}
