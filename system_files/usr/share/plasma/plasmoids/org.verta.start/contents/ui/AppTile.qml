/*
    An app in the Start menu grids (pinned, and all apps): icon over its name.
    Tiles drift up into place one after another when the menu opens; the icon
    lifts on hover and squishes when clicked. Right-click to pin or unpin.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

Item {
    id: tile

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    property bool pinnedTile: false         // in the Pinned grid (else All apps)
    readonly property int itemIndex: index
    readonly property bool highlighted: mouse.containsMouse || (GridView.isCurrentItem && GridView.view.activeFocus)
    readonly property string favoriteId: model.favoriteId || ""
    // (count is read so this updates when pins change)
    readonly property bool isPinned: pinnedTile || (favoriteId !== "" && start.rootModel.favoritesModel.count >= 0
                                                    && start.rootModel.favoritesModel.isFavorite(favoriteId))

    // Entrance: a short stagger, then rise and fade in.
    opacity: 0
    transform: Translate { id: rise; y: 10 }
    function enter() {
        entrance.stop()
        tile.opacity = 0
        rise.y = 10
        entrance.start()
    }
    SequentialAnimation {
        id: entrance
        PauseAnimation { duration: Math.min(tile.itemIndex, 11) * 16 }
        ParallelAnimation {
            NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: rise; property: "y"; to: 0; duration: 320; easing.type: Easing.OutQuint }
        }
    }
    Component.onCompleted: enter()
    Connections {
        target: start
        function onMenuOpenChanged() { if (start.menuOpen) tile.enter() }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Kirigami.Units.cornerRadius * 1.6
        color: Kirigami.Theme.textColor
        opacity: mouse.pressed ? 0.13 : (tile.highlighted ? 0.075 : 0)
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.smallSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            // Big, like a phone's home screen. Not rounded down to the next
            // stock icon size (that drew them at 32 px).
            Layout.preferredWidth: Math.min(Math.round(Kirigami.Units.gridUnit * 3), tile.height * 0.6)
            Layout.preferredHeight: Layout.preferredWidth
            roundToIconSize: false
            source: model.decoration
            animated: false
            scale: mouse.pressed ? 0.9 : (tile.highlighted ? 1.08 : 1)
            transform: Translate {
                y: tile.highlighted && !mouse.pressed ? -2 : 0
                Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack } }
            }
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack } }
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: model.display
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.92
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) {
                contextMenu.popup()
            } else {
                start.launch(tile.GridView.view.model, tile.itemIndex)
            }
        }
    }

    PlasmaComponents3.ToolTip {
        text: model.description || ""
        visible: mouse.containsMouse && text !== "" && text !== model.display
        delay: Kirigami.Units.toolTipDelay * 2
    }

    PlasmaComponents3.Menu {
        id: contextMenu
        PlasmaComponents3.MenuItem {
            text: "Open"
            icon.name: "media-playback-start"
            onClicked: start.launch(tile.GridView.view.model, tile.itemIndex)
        }
        PlasmaComponents3.MenuItem {
            text: "Move to front"
            icon.name: "go-first"
            visible: tile.pinnedTile
            height: visible ? implicitHeight : 0
            enabled: tile.itemIndex > 0
            onClicked: tile.GridView.view.model.moveRow(tile.itemIndex, 0)
        }
        PlasmaComponents3.MenuItem {
            text: tile.isPinned ? "Unpin from Start" : "Pin to Start"
            icon.name: tile.isPinned ? "window-unpin" : "window-pin"
            visible: tile.favoriteId !== ""
            height: visible ? implicitHeight : 0
            onClicked: {
                if (tile.isPinned) {
                    start.rootModel.favoritesModel.removeFavorite(tile.favoriteId)
                } else {
                    start.rootModel.favoritesModel.addFavorite(tile.favoriteId)
                }
            }
        }
    }
}
