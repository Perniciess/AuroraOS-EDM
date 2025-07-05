// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: stubItem

    property string title

    Loader {
        anchors.fill: parent

        sourceComponent: stubComponent
        active: true
    }

    Component {
        id: stubComponent

        Column {
            Label {
                anchors {
                    right: parent.right
                    left: parent.left
                    rightMargin: Theme.horizontalPageMargin
                    leftMargin: Theme.horizontalPageMargin
                }

                text: stubItem.title
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraLarge
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
