/*
    One row in the Start menu's lists (all apps, search results, recent
    files): icon, name and an optional second line. Right-click to pin or
    unpin an app.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: row

    property bool isCurrent: false
    property string subtitle: ""
    property bool pinnable: false
    signal activated()

    readonly property string favoriteId: model.favoriteId || ""
    // (count is read so this updates when pins change)
    readonly property bool isPinned: favoriteId !== "" && start.rootModel.favoritesModel.count >= 0
                                     && start.rootModel.favoritesModel.isFavorite(favoriteId)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: Kirigami.Units.cornerRadius * 1.4
        color: row.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: mouse.pressed ? 0.16 : (row.isCurrent ? 0.22 : (mouse.containsMouse ? 0.075 : 0))
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.preferredWidth: row.subtitle !== "" ? Kirigami.Units.iconSizes.medium : Math.round(Kirigami.Units.iconSizes.medium * 0.9)
            Layout.preferredHeight: Layout.preferredWidth
            source: model.decoration
            animated: false
            scale: mouse.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: model.display
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: row.subtitle !== "" && row.subtitle !== model.display
                text: row.subtitle
                elide: Text.ElideMiddle
                maximumLineCount: 1
                opacity: 0.6
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
        Kirigami.Icon {
            visible: row.isPinned && row.pinnable
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Layout.preferredWidth
            source: "window-pin"
            opacity: 0.45
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) {
                if (row.pinnable && row.favoriteId !== "") contextMenu.popup()
            } else {
                row.activated()
            }
        }
    }

    PlasmaComponents3.Menu {
        id: contextMenu
        PlasmaComponents3.MenuItem {
            text: "Open"
            icon.name: "media-playback-start"
            onClicked: row.activated()
        }
        PlasmaComponents3.MenuItem {
            text: row.isPinned ? "Unpin from Start" : "Pin to Start"
            icon.name: row.isPinned ? "window-unpin" : "window-pin"
            onClicked: {
                if (row.isPinned) {
                    start.rootModel.favoritesModel.removeFavorite(row.favoriteId)
                } else {
                    start.rootModel.favoritesModel.addFavorite(row.favoriteId)
                }
            }
        }
    }
}
