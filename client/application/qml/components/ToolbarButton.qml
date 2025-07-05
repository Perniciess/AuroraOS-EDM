// SPDX-FileCopyrightText: 2024 Open Mobile Platform LLC <community@omp.ru>
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick 2.0
import Sailfish.Silica 1.0

IconButton {
    property bool selected

    icon.sourceSize: Qt.size(Theme.iconSizeSmallPlus, Theme.iconSizeSmallPlus)
    highlighted: down || selected

    Rectangle {
        anchors.fill: parent

        color: palette.highlightColor
        opacity: parent.highlighted ? Theme.opacityFaint : 0
        radius: Theme.dp(6)
        z: -1
    }
}
