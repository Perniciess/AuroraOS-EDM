// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Aurora.Controls 1.0

PopupMenu {
    property alias pagesWithNotesModel: allNotesView.model
    property alias isShowNotes: showItem.checked
    property var delegate

    signal showNotes(bool show)
    signal noteActivate(string noteText, string author, int pageIndex)

    function openPopup(d) {
        d.selected = true
        delegate = d
        open(d)
    }

    onOpenedChanged: delegate.selected = opened
    onNoteActivate: close()

    preferredHeight: Theme.itemSizeSmall * 7

    PopupMenuCheckableItem {
        id: showItem

        onCheckedChanged: showNotes(checked)

        text: qsTr("Show notes")
    }

    PopupMenuDividerItem {}

    Item {
        width: parent.width
        height: Theme.itemSizeMedium + Theme.paddingLarge * 2
        visible: !allNotesView.count

        InfoLabel {
            anchors.centerIn: parent

            text: qsTr("No notes")
            height: Theme.itemSizeMedium
        }
    }

    ListView {
        id: allNotesView

        spacing: Theme.paddingSmall
        clip: true
        width: parent.width
        height: contentHeight
        visible: count

        delegate: ListView {
            id: notesView

            property int viewPageIndex: pageIndex

            width: parent.width
            height: contentHeight
            interactive: false
            visible: notesCount
            clip: true
            model: notesModel
            spacing: Theme.paddingSmall
            delegate: noteDelegate
        }

        VerticalScrollDecorator {  }

        Component {
            id: noteDelegate

            ListItem {
                id: delegateContainer

                property int viewPageIndex: ListView.view.viewPageIndex

                onClicked: noteActivate(model.content, model.author, viewPageIndex)

                width: parent.width - 2 * Theme.paddingMedium
                anchors.horizontalCenter: parent.horizontalCenter
                contentHeight: delegateColumn.height + Theme.paddingSmall * 2

                Rectangle {
                    anchors.fill: parent
                    color: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
                    radius: Theme.paddingSmall
                }

                Column {
                    id: delegateColumn

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: Theme.paddingSmall
                        leftMargin: Theme.paddingMedium
                        rightMargin: Theme.paddingMedium
                    }

                    spacing: Theme.paddingSmall

                    Label {
                        id: contentLabel

                        width: parent.width

                        text: model.content
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        visible: text
                    }

                    Row {
                        height: Theme.iconSizeSmallPlus
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            anchors.verticalCenter: parent.verticalCenter

                            text: qsTr("Page %1").arg(viewPageIndex + 1)
                            width: parent.width / 2 - parent.spacing / 2
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Rectangle {
                            id: noteColorIndicator

                            anchors.verticalCenter: parent.verticalCenter
                            color: model.color
                            height: Theme.dp(20)
                            width: height
                            radius: Theme.dp(3)
                        }

                        Label {
                            id: field

                            anchors.verticalCenter: parent.verticalCenter
                            text: author
                            width: parent.width / 2 - parent.spacing / 2 - noteColorIndicator.width - parent.spacing
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryColor
                            truncationMode: TruncationMode.Fade
                        }
                    }

                }

                menu: Component {
                    // TODO: Future features
                    ContextMenu {
                        hasContent: false
                        MenuItem {
                            text: qsTr("Show in document")
                        }
                        MenuItem {
                            text: qsTr("Edit")
                        }
                        MenuItem {
                            text: qsTr("Delete note")
                        }
                    }
                }
            }
        }
    }
}
