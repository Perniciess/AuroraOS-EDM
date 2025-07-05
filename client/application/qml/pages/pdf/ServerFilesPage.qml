// SPDX-FileCopyrightText: 2024 Your Company
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import ru.auroraos.ElectronicDocumentManagement 1.0
import "../../components"

Page {
    id: root

    objectName: "serverFilesPage"
    allowedOrientations: Orientation.All

    property var serverFilesModel: ListModel {}

    Connections {
        target: webSocket
        onFilesListChanged: {
            if (!webSocket.filesList || webSocket.filesList.length === 0)
                return;

            serverFilesModel.clear();
            var localHashes = webSocket.getLocalFileHashes();

            for (var i = 0; i < webSocket.filesList.length; ++i) {
                var file = webSocket.filesList[i];
                if (!file.file_hash)
                    continue;

                var fileHash = file.file_hash.trim();
                if (localHashes.indexOf(fileHash) === -1) {
                    serverFilesModel.append({
                        fileId: file.id || (i + 1),
                        file_name: file.file_name || "Unknown",
                        file_status: file.file_status || "unknown",
                        file_hash: fileHash
                    });
                }
            }
        }
    }

    Component.onCompleted: {
        webSocket.getFilesList();
    }

    SilicaListView {
        id: serverListView
        anchors.fill: parent
        model: serverFilesModel

        MyMenu {
            onClicked: pageStack.push(Qt.resolvedUrl(pageUrl))
        }

        delegate: ListItem {
            id: fileItem
            objectName: "serverFileItem"
            contentHeight: textColumn.height + 2 * Theme.paddingMedium
            width: parent.width

            Column {
                id: textColumn
                anchors {
                    left: parent.left
                    right: downloadButton.left
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                }
                spacing: Theme.paddingSmall * 2

                Label {
                    id: fileText
                    width: parent.width
                    text: model.file_name
                    font.pixelSize: Theme.fontSizeMedium
                    color: fileItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Label {
                    id: statusLabel
                    width: parent.width
                    text: qsTr("Status: ") + model.file_status
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.secondaryColor
                }
            }

            IconButton {
                id: downloadButton
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }
                icon.source: "image://theme/icon-splus-device-download"
                onClicked: {
                    if (typeof model.fileId === 'undefined')
                        return;
                    webSocket.downloadFile(model.fileId);
                }
            }

            Rectangle {
                width: parent.width - 2 * Theme.horizontalPageMargin
                height: 1
                color: Theme.rgba(Theme.primaryColor, 0.5)
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
            }
        }

        Connections {
            target: webSocket
        }
    }
}
