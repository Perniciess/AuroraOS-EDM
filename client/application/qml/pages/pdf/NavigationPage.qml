// SPDX-FileCopyrightText: 2023 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import QtQml.Models 2.1
import Sailfish.Silica 1.0
import "../../components"

Page {
    id: root

    property int count: -1
    property var bookmarks: []

    signal pageSelected(int s)
    signal sectionSelected(int page)

    allowedOrientations: Orientation.All
    objectName: "navigationPage"

    PageHeader {
        id: pageHeader
        objectName: "pageHeader"
        title: qsTr("Document navigation")
    }

    SectionHeader {
        id: sectionsHeader
        anchors.top: pageHeader.bottom
        text: qsTr("Chapter list")
    }

    Item {
        id: chapterListItem
        anchors {
            bottom: pageInputBlock.top
            left: parent.left
            right: parent.right
            top: sectionsHeader.bottom
            leftMargin: Theme.paddingLarge
            rightMargin: Theme.paddingLarge
            topMargin: Theme.itemSizeSmall * 2 / 3
            bottomMargin: Theme.itemSizeSmall / 2
        }

        DelegateModel {
            id: visualModel
            property var lessThan: [
                function(left, right) { return left.pageIndex < right.pageIndex; }
            ]

            property int sortOrder: 0
            onSortOrderChanged: items.setGroups(0, items.count, "unsorted")

            function insertPosition(lessThan, item) {
                var lower = 0
                var upper = items.count
                while (lower < upper) {
                    const middle = Math.floor(lower + (upper - lower) / 2)
                    const result = lessThan(item.model, items.get(middle).model)
                    if (result) {
                        upper = middle
                    } else {
                        lower = middle + 1
                    }
                }
                return lower
            }

            function sort(lessThan) {
                while (unsortedItems.count > 0) {
                    const item = unsortedItems.get(0)
                    const index = insertPosition(lessThan, item)

                    item.groups = "items"
                    items.move(item.itemsIndex, index)
                }
            }

            items.includeByDefault: false
            groups: DelegateModelGroup {
                id: unsortedItems
                name: "unsorted"

                includeByDefault: true
                onChanged: {
                    if (visualModel.sortOrder == visualModel.lessThan.length)
                        setGroups(0, count, "items")
                    else
                        visualModel.sort(visualModel.lessThan[visualModel.sortOrder])
                }
            }
            model: bookmarks
            delegate:  ListItem {
                Text {
                    text: chapterList.repeatSpace(level - 1) + title
                    anchors {
                        left: parent.left
                        top: parent.top
                    }
                    wrapMode: Text.WordWrap
                    width: chapterListItem.width - 3 * Theme.paddingLarge
                    color: palette.primaryColor
                }
                Text {
                    text: pageIndex
                    anchors.right: parent.right
                    anchors.top: parent.top
                    color: palette.primaryColor
                }
                onClicked: {
                    sectionSelected(pageIndex)
                    pageStack.pop()
                }
            }
        }

        EmptyListStub {
            id: emptyConfigurationsStub

            anchors {
                top: parent.top
                topMargin: Theme.horizontalPageMargin
                left: parent.left
                right: parent.right
            }

            title: qsTr("No chapters")
            visible: bookmarks.rowCount() <= 0
        }

        SilicaListView {
            id: chapterList
            anchors.fill: parent
            model: visualModel

            function repeatSpace(count) {
                var res = "";
                for (var i = 0; i < count; i++)
                    res += "\t";
                return res;
            }
        }
    }

    Item {
        id: pageInputBlock
        objectName: "pageInputBlock"
        anchors {
            bottom: root.bottom
            left: parent.left
            right: parent.right
        }
        height: blockHeader.height + textField.height + Theme.paddingLarge + Theme.paddingMedium

        Rectangle {
            objectName: "background"
            anchors.fill: parent
            color: "black"
            opacity: 0.4
        }

        SectionHeader {
            id: blockHeader

            objectName: "blockHeader"
            text: qsTr("Go to page")
        }

        TextField {
            id: textField

            EnterKey.onClicked: {
                pageSelected(text);
                pageStack.pop();
            }

            objectName: "textField"
            placeholderText: qsTr("Enter page number")
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator {
                top: root.count
                bottom: 1
            }
            errorHighlight: !acceptableInput && text.length !== 0
            font.pixelSize: Theme.fontSizeLarge
            EnterKey.enabled: acceptableInput
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.highlighted: acceptableInput
            anchors {
                top: blockHeader.bottom
                left: parent.left
                right: parent.right
            }

            labelComponent: Column {
                objectName: "labelColumn"
                width: parent.width

                Label {
                    objectName: "pageNumberLabel"
                    width: parent.width
                    text: qsTr("Page number")
                    opacity: textField.length > 0 ? 1.0 : 0.0
                    height: contentHeight * opacity
                    font.pixelSize: Theme.fontSizeSmall

                    Behavior on opacity {
                        FadeAnimation {}
                    }
                }

                Label {
                    objectName: "countLabel"
                    width: parent.width
                    text: qsTr("Document has %n page(s)", "", root.count)
                    color: palette.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
