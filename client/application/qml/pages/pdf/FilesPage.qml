// SPDX-FileCopyrightText: 2022 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import ru.auroraos.ElectronicDocumentManagement 1.0
import "../../components"

Page {
    id: root

    property real timeFormat: Format.Timepoint
    readonly property var statesNames: ["loading", "work", "documentsNotFound"]
    property SortModel filesModel: SortModel {
        function escapeRegExp(text) {
            return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&');
        }

        objectName: "sortModel"
        sourceModel: FilesModel {
            onGraphChanged: {
                root.state = documentsCount > 0 ? root.statesNames[1] : root.statesNames[2];
                if (pageStack.currentPage === null || pageStack.currentPage.objectName === root.objectName)
                    return;
                var contentPage = pageStack.find(function (page) {
                    if (page.objectName === "contentPage")
                        return page;
                });
                if (contentPage !== undefined)
                    contentPage.checkCurrentFile();
            }
            onDataChanged: {
                root.timeFormat = "";
                root.timeFormat = Format.Timepoint;
            }

            Component.onCompleted: {
                root.state = statesNames[0];
                reset();
            }

            objectName: "filesModel"
        }
        filterRegExp: RegExp(escapeRegExp(filesView.searchText), "i")
    }

    onVisibleChanged: {
        if (visible) {
            filesView.model.modelReset();
        }
    }

    function chooseFile(path, status) {
        if (status === "not viewed") {
            filesModel.sourceModel.markFileAsViewed(path);
        }
        while (pageStack.depth > 1) {
            pageStack.pop(undefined, PageStackAction.Immediate);
        }
        pageStack.push(Qt.resolvedUrl("ContentPage.qml"), {
            "pdfPath": path
        });
    }

    objectName: "filesPage"
    allowedOrientations: Orientation.All

    BusyIndicator {
        id: documentListLoadIndicator

        objectName: "busyIndicator"
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
    }

    Label {
        id: documentsNotFoundLabel

        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }
        objectName: "errorLabel"
        enabled: filesView.count <= 0
        visible: enabled
        color: Theme.highlightColor
        textFormat: Text.PlainText
        text: qsTr("Документы не найдены")
        font.pixelSize: Theme.fontSizeExtraLarge
    }

    SilicaListView {
        id: filesView

        property string searchText

        onCountChanged: root.state = filesView.count > 0 ? root.statesNames[1] : root.statesNames[2]

        Component.onCompleted: currentIndex = -1

        objectName: "filesView"
        anchors.fill: parent
        delegate: fileDelegateComponent
        header: filesViewHeaderComponent
        model: root.filesModel
    }

    Component {
        id: filesViewHeaderComponent

        Column {
            width: parent.width
            spacing: 0

            property alias searchText: searchField.text

            Item {
                width: parent.width
                height: Theme.itemSizeSmall + Theme.paddingMedium

                Rectangle {
                    id: backgroundRect
                    anchors {
                        fill: parent
                        leftMargin: Theme.paddingLarge
                        rightMargin: Theme.paddingLarge
                        bottomMargin: Theme.paddingMedium
                    }
                    radius: 6
                    color: Theme.rgba(Theme.secondaryColor, 0.3)

                    SearchField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: Theme.paddingMedium

                        onTextChanged: filesView.searchText = text
                        onActiveChanged: if (active)
                            forceActiveFocus()
                        EnterKey.onClicked: focus = false

                        objectName: "searchField"
                        placeholderText: qsTr("Поиск")
                        placeholderColor: Theme.primaryColor
                        transitionDuration: 400
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase | Qt.ImhNoPredictiveText
                        EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rgba(Theme.primaryColor, 0.5)
            }

            MyMenu {
                onClicked: {
                    pageStack.push(Qt.resolvedUrl(pageUrl));
                }
            }
        }
    }

    Component {
        id: fileDelegateComponent

        ListItem {
            id: fileDelegate
            contentHeight: Math.max(Theme.itemSizeMedium, mainColumn.implicitHeight) + 2 * Theme.paddingMedium
            onClicked: root.chooseFile(model.path, model.status)

            objectName: "delegateItem"

            Column {
                id: mainColumn
                objectName: "delegateColumn"
                anchors {
                    left: parent.left
                    leftMargin: Theme.horizontalPageMargin
                    right: iconRow.left
                    rightMargin: Theme.paddingMedium
                    verticalCenter: parent.verticalCenter
                    top: parent.top
                    topMargin: Theme.paddingMedium
                }
                spacing: Theme.paddingSmall

                Label {
                    objectName: "filenameLabel"
                    width: parent.width
                    color: fileDelegate.highlighted ? Theme.highlightColor : Theme.primaryColor
                    text: filesView.searchText.length > 0 ? Theme.highlightText(model.fileName, filesView.searchText, Theme.highlightColor) : model.fileName
                    textFormat: filesView.searchText.length > 0 ? Text.StyledText : Text.PlainText
                    font.pixelSize: Theme.fontSizeMedium
                    truncationMode: TruncationMode.Fade
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Item {
                    objectName: "fileInfoItem"
                    width: parent.width
                    height: statusLabel.height

                    Label {
                        id: statusLabel
                        text: model.status
                        font.pixelSize: Theme.fontSizeSmall
                        color: fileDelegate.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                }
            }

            Row {
                id: iconRow
                spacing: Theme.paddingSmall
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    verticalCenter: parent.verticalCenter
                }

                IconButton {
                    objectName: "statusIcon"
                    visible: model.status === "not viewed"
                    icon.source: "image://theme/icon-m-hide-password"
                }

                IconButton {
                    objectName: "signIcon"
                    visible: model.status === "viewed"
                    icon.source: "image://theme/icon-splus-accept"
                    icon.color: Theme.primaryColor

                    property DigitalSignature digitalSignature: DigitalSignature {
                        id: digitalSigner
                    }

                    onClicked: {
                        digitalSigner.signFile(model.path);
                        filesView.model.modelReset();
                    }
                }

                IconButton {
                    objectName: "uploadIcon"
                    visible: model.status === "signed"
                    icon.source: "image://theme/icon-splus-device-upload"
                    icon.color: Theme.primaryColor

                    onClicked: {
                        webSocket.sendFile(model.path);
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.rgba(Theme.primaryColor, 0.5)
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    ShareAction {
        id: shareAction
        objectName: "shareAction"
    }

    Connections {
        target: webSocket
        onFileStatusChanged: {
            filesModel.sourceModel.updateFileStatus(filePath, status);
        }
    }

    Connections {
        onFileOpenRequested: {
            chooseFile(path);
        }
        target: dbusAdaptor
    }

    states: [
        State {
            name: "loading"

            PropertyChanges {
                target: documentsNotFoundLabel
                visible: false
            }
            PropertyChanges {
                target: documentListLoadIndicator
                visible: true
                running: true
            }
        },
        State {
            name: "work"

            PropertyChanges {
                target: documentsNotFoundLabel
                visible: false
            }
            PropertyChanges {
                target: documentListLoadIndicator
                visible: false
                running: false
            }
        },
        State {
            name: "documentsNotFound"

            PropertyChanges {
                target: documentsNotFoundLabel
                visible: true
            }
            PropertyChanges {
                target: documentListLoadIndicator
                visible: false
                running: false
            }
        }
    ]
}
