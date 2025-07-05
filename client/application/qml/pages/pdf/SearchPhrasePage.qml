// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.auroraos.ElectronicDocumentManagement 1.0
import "../../components"

Page {
    id: root
    property var pdfPagesView

    signal pageSelected(int s)
    allowedOrientations: Orientation.All

    PageHeader {
        id: header

        title: qsTr("Phrase search")
    }

    TextField {
        id: textField

        anchors {
            top: header.bottom
            left: parent.left
            topMargin: Theme.horizontalPageMargin
        }

        text: pdfPagesView.searchPhraseModel.getPhrase()
        label: qsTr("Find a phrase")
        rightItem: IconButton {
            onClicked: {
                root.state = "searching";
                var onSearchPhraseModelChangedHandler = function (newModel) {
                    pdfPagesView.onSearchPhraseModelChanged.disconnect(onSearchPhraseModelChangedHandler);
                    resultList.update();
                    root.state = "readyForSearch";
                };
                pdfPagesView.onSearchPhraseModelChanged.connect(onSearchPhraseModelChangedHandler);
                pdfPagesView.findPhrase(textField.text);
            }
            enabled: textField.text.length > 0

            icon.source: "image://theme/icon-m-search"
        }
    }

    BusyLabel {
        id: progressCircle

        text: qsTr("Searching for phrase") + " \"" + textField.text + "\""
    }

    EmptyListStub {
        id: emptyConfigurationsStub

        anchors {
            top: textField.bottom
            left: parent.left
            right: parent.right
        }

        title: qsTr("Not found")
        visible: pdfPagesView.searchPhraseModel.rowCount() <= 0 && pdfPagesView.searchPhraseModel.getPhrase() !== ""
    }

    SilicaListView {
        id: resultList

        anchors {
            top: textField.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom

            leftMargin: Theme.paddingLarge
            rightMargin: Theme.paddingLarge
            topMargin: Theme.itemSizeSmall * 2 / 3
            bottomMargin: Theme.itemSizeSmall / 2
        }
        model: pdfPagesView.searchPhraseModel

        delegate: ListItem {
            anchors.leftMargin: Theme.paddingLarge
            anchors.rightMargin: Theme.paddingLarge

            Text {
                text: value
                color: palette.primaryColor
            }
            Text {
                text: phrasePageIndex + 1
                color: palette.primaryColor
                width: parent.width
                horizontalAlignment: Qt.AlignRight
            }
            onClicked: {
                pageSelected(phrasePageIndex);
                pageStack.pop();
            }
        }
    }

    states: [
        State {
            name: "readyForSearch"

            PropertyChanges {
                target: resultList
                enabled: true
            }
            PropertyChanges {
                target: root
                backNavigation: true
            }
            PropertyChanges {
                target: textField
                enabled: true
            }
            PropertyChanges {
                target: progressCircle
                running: false
            }
            PropertyChanges {
                target: resultList
                visible: true
            }
        },
        State {
            name: "searching"

            PropertyChanges {
                target: resultList
                visible: false
            }
            PropertyChanges {
                target: textField
                enabled: false
            }
            PropertyChanges {
                target: root
                backNavigation: false
            }
            PropertyChanges {
                target: progressCircle
                running: true
            }
        }
    ]
}
