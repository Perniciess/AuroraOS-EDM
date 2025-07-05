// SPDX-FileCopyrightText: 2023 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Share 1.0
import Aurora.Controls 1.0
import ru.omp.amberpdf 1.0
import ru.auroraos.ElectronicDocumentManagement 1.0
import "../../components"


Page {
    id: root

    property string pdfPath
    property int _maxSize: Math.max(Screen.width, Screen.height)
    readonly property var statesNames: ["correctWork", "loadingDocument", "badFile", "fileNotFound"]

    function checkCurrentFile() {
        fileInfo.refresh();
        if (fileInfo.isExist())
            return;
        state = root.statesNames[3];
    }

    function splitDocumentName() {
        return fileInfo.fileName + fileInfo.lastModified + fileInfo.size

    }

    function loadViewPosition() {
        var zoom = ApplicationSettings.getDocumentZoom(splitDocumentName())
        var position = ApplicationSettings.getDocumentPosition(splitDocumentName())

        pdfPagesView.zoom = zoom
        pdfPagesView.contentX = position.x
        pdfPagesView.contentY = position.y
        pdfPagesView.correctPosition()
    }

    onStatusChanged: {
        if (pageStack.currentPage.objectName === objectName) {
            if (status === PageStatus.Active && state === statesNames[1]) {
                pdfPagesView.pdfPath = pdfPath;
            }
        }
    }

    allowedOrientations: Orientation.All
    objectName: "contentPage"
    state: root.statesNames[1]

    TextArea {
        id: errorText

        width: parent.width
        visible: root.state !== root.statesNames[0]
        color: Theme.highlightColor
        readOnly: true
        horizontalAlignment: TextEdit.AlignHCenter
        font.pixelSize: Theme.fontSizeExtraLarge
        anchors {
            verticalCenter: parent.verticalCenter
            horizontalCenter: parent.horizontalCenter
        }

        background: Rectangle {
            color: "transparent"
            border.color: "transparent"
        }
    }

    PageHeader {
        id: pageHeader

        title: fileInfo.fileName
        rightMargin: Theme.horizontalPageMargin + infoIcon.width + Theme.paddingSmall
        titleColor: infoIcon.highlighted ? palette.highlightColor : Theme.primaryColor
        width: root.width
        y: toolBar.opened ? 0 : -height
        z: pdfPagesView.z + 1

        Rectangle {
            id: pageHeaderBackground

            z: -1
            color: pdfPagesView.zoom > 1.0
                   ? Theme.rgba(Theme.overlayBackgroundColor, Theme.opacityOverlay)
                   : "transparent"
            anchors.fill: parent

            Behavior on color  {
                ColorAnimation {
                    duration: toolBar.animationDuration
                }
            }
        }

        HighlightImage {
            id: infoIcon

            source: "image://theme/icon-m-about"
            highlightColor: palette.highlightColor
            highlighted: headerMouseArea.pressed
            anchors {
                right: parent.right
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
        }

        Behavior on y  {
            NumberAnimation {
                id: headerOpenCloseAnimation
                duration: toolBar.animationDuration
            }
        }

        MouseArea {
            id: headerMouseArea

            anchors.fill: parent

            onClicked: pageStack.push(Qt.resolvedUrl("DetailsPage.qml"), {
                    "pageCount": root.state === root.statesNames[1] ? qsTr("Loading") : pdfPagesView.count,
                    "fileInfo": fileInfo
                })
        }
    }

    PdfView {
        id: pdfPagesView

        property real previousStatus: PdfDocument.Null

        documentProvider: pdfiumProvider
        clip: true
        width: parent.width
        catchBound: pageHeader.height
        annotationsPaint: true
        notesPaint: true
        anchors.horizontalCenter: parent.horizontalCenter

        onClickedUrl: Qt.openUrlExternally(url)
        onNoteActivate: pageStack.push(Qt.resolvedUrl("NotePage.qml"), { noteText: noteText, author: author, pageNumber: pageIndex + 1 })
        onStatusChanged: {
            if (previousStatus === status)
                return

            switch(previousStatus) {
            case PdfDocument.Null:
                root.state = (status === PdfDocument.Loading ? root.statesNames[1] : root.statesNames[2])
                break
            case PdfDocument.Loading:
                loadViewPosition()
                timerLoadViewPosition.start()

                timer.start()
                root.state = (status === PdfDocument.Ready ? root.statesNames[0] : root.statesNames[2])
                break
            case PdfDocument.Ready:
                root.state = root.statesNames[3]
                previousStatus = PdfDocument.Error
                break
            }


            if (previousStatus !== PdfDocument.Error)
                previousStatus = status
        }

        Binding {
            target: pdfPagesView
            property: "height"
            value: root.height - pageHeader.height - toolBar.height
        }
        Binding {
            target: pdfPagesView
            property: "y"
            value: pageHeader.height
        }

        Behavior on height {
            enabled: !timer.running
            NumberAnimation {
                duration: root.state === root.statesNames[0] ? toolBar.animationDuration : 0
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on y {
            enabled: !timer.running
            NumberAnimation {
                duration: root.state === root.statesNames[0] ? toolBar.animationDuration : 0
                easing.type: Easing.InOutQuad
            }
        }

        Timer {
            id: timer

            running: false
            repeat: false
            interval: 1000
        }

        Timer {
            id: timerLoadViewPosition

            onTriggered: loadViewPosition()

            interval: 150
        }
    }

    ToolBar {
        id: toolBar

        anchors.bottom: parent.bottom

        width: parent.width
        opened: true

        pageIndex: pdfPagesView.currentIndex
        pagesCount: pdfPagesView.count

        onOpenPopupMenu: popupMenu.openPopup(item)
        onOpenPopupNotes: popupMenuNotes.openPopup(item)

        onOpenNavigationPage: {
           var navigationPage = pageStack.push(Qt.resolvedUrl("NavigationPage.qml"), {
                                                    count: pdfPagesView.count,
                                                    bookmarks: pdfPagesView.bookmarksModel
                                                })
           navigationPage.pageSelected.connect(function(page) { pdfPagesView.goToPage(page - 1) })
           navigationPage.sectionSelected.connect(function(page) {
               pdfPagesView.goToPage(page)
           })
        }

        onOpenSearchPhrasePage: {
            var searchPage = pageStack.push(Qt.resolvedUrl(
                                                "SearchPhrasePage.qml"), {
                                                "pdfPagesView": pdfPagesView
                                            })
            searchPage.pageSelected.connect(function (page) {
                pdfPagesView.goToPage(page)
            })
        }
    }

    PdfDocument {
        id: pdfiumProvider

        objectName: "pdfDocument"
    }

    PopupMenu {
        id: popupMenu

        property var delegate

        function openPopup(d) {
            d.selected = true
            delegate = d
            open(d)
        }

        onOpenedChanged: delegate.selected = opened

        preferredWidth: Screen.width * 0.8

        PopupMenuCheckableItem {
            onCheckedChanged: {
                pdfPagesView.orientation = (pdfPagesView.orientation === Qt.Vertical ? Qt.Horizontal : Qt.Vertical);
                ApplicationSettings.setVerticalScroll(splitDocumentName(), pdfPagesView.orientation === Qt.Vertical);
            }

            checked: pdfPagesView.orientation === Qt.Horizontal
            text: qsTr("Scroll pages horizontally")
        }

        PopupMenuDividerItem {}

        PopupMenuItem {
            onClicked: {
                shareAction.resources = [Qt.resolvedUrl(fileInfo.path)]
                shareAction.trigger()
            }

            icon.source: "image://theme/icon-splus-share"
            text: qsTr("Share")
        }
    }

    PopupMenuNotes {
        id: popupMenuNotes

        onShowNotes: pdfPagesView.notesPaint = show
        onNoteActivate: pageStack.push(Qt.resolvedUrl("NotePage.qml"), { noteText: noteText, author: author, pageNumber: pageIndex + 1 })
        onOpened: pagesWithNotesModel.sourceModel = pdfPagesView.pagesWithNotesModel

        pagesWithNotesModel: PageWithNotesSortModel {
            filterParameter: PageWithNotesSortModel.Count
        }

        isShowNotes: pdfPagesView.notesPaint
        preferredWidth: Screen.width * 0.8
    }


    FileInfo {
        id: fileInfo

        objectName: "fileInfo"
        path: root.pdfPath
    }

    ShareAction {
        id: shareAction
        objectName: "shareAction"
    }

    states: [
        State {
            name: root.statesNames[0]

            PropertyChanges {
                target: pdfPagesView
                visible: true
            }
        },
        State {
            name: root.statesNames[1]

            PropertyChanges {
                target: pdfPagesView
                visible: false
            }
        },
        State {
            name: root.statesNames[2]

            PropertyChanges {
                target: root
                pdfPath: ""
            }
            PropertyChanges {
                target: errorText
                text: qsTr("Could not open document")
            }
            PropertyChanges {
                target: pdfPagesView
                enabled: false
            }
            PropertyChanges {
                target: toolBar
                opened: false
            }
        },
        State {
            name: root.statesNames[3]

            PropertyChanges {
                target: root
                pdfPath: ""
            }
            PropertyChanges {
                target: errorText
                text: qsTr("File not found")
            }
            PropertyChanges {
                target: pdfPagesView
                enabled: false
            }
            PropertyChanges {
                target: toolBar
                opened: false
            }
        }
    ]
}
