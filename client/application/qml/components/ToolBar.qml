// SPDX-FileCopyrightText: 2023 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0
import Aurora.Controls 1.0

Item {
    id: root

    property bool opened: true
    property int pagesCount
    property int pageIndex

    readonly property int animationDuration: 300

    signal openPopupMenu(var item)
    signal openPopupNotes(var item)
    signal openNavigationPage
    signal openSearchPhrasePage

    height: Theme.itemSizeMedium
    opacity: opened && visible ? 1.0 : 0.0

    Behavior on opacity { FadeAnimation { duration: animationDuration } }

    Rectangle {
        anchors.top: root.top

        width: parent.width
        height: Theme._lineWidth
        opacity: Theme.opacityFaint
        color: palette.primaryColor
    }

    Item {
        y: opened ? 0 : height
        width: parent.width
        height: parent.height

        Behavior on y {
            NumberAnimation {
                duration: animationDuration
                easing.type: Easing.InOutQuad
            }
        }

        ToolbarButton {
            id: notesButton

            onClicked: openPopupNotes(notesButton)

            anchors {
                left: parent.left
                leftMargin: Theme.paddingMedium
                verticalCenter: parent.verticalCenter
            }
            icon.source: "image://theme/icon-splus-note"
        }

        // TODO: Will be added when amberpdf is updated
        //ToolbarButton {
        //    onClicked: root.openSearchPhrasePage()

        //    anchors {
        //        left: notesButton.right
        //        leftMargin: Theme.paddingMedium
        //        verticalCenter: parent.verticalCenter
        //    }
        //    icon.source: "image://theme/icon-m-search"
        //}

        Button {
            onClicked: root.openNavigationPage()

            anchors.centerIn: parent
            height: Theme.itemSizeMedium
            width: (root.width - Theme.horizontalPageMargin * 2) / 3
            backgroundColor: "transparent"
            border.color: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)

            Row {
                anchors.centerIn: parent

                Label {
                    text: qsTr("%1 | ").arg(Math.max(1, pageIndex + 1))
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                }
                Label {
                    text: qsTr("%1").arg(pagesCount)
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    color: Theme.rgba(Theme.primaryColor, Theme.opacityHigh)
                }
            }
        }

        ToolbarButton {
            id: moreButton

            onClicked: root.openPopupMenu(moreButton)

            anchors {
                right: parent.right
                rightMargin: Theme.paddingLarge
                verticalCenter: parent.verticalCenter
            }
            icon.source: "image://theme/icon-splus-more"
        }
    }
}
