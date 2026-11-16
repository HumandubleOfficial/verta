/*
    A pinned app in the Start menu grid: icon over its name. Tiles drift up
    into place one after another when the menu opens; the icon lifts on hover
    and squishes when clicked. Right-click to unpin.

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

    readonly property int itemIndex: index
    readonly property bool highlighted: mouse.containsMouse || (GridView.isCurrentItem && GridView.view.activeFocus)

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
        function onExpandedChanged() { if (start.expanded) tile.enter() }
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
            Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 2.3)
            Layout.preferredHeight: Layout.preferredWidth
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
            enabled: tile.itemIndex > 0
            onClicked: tile.GridView.view.model.moveRow(tile.itemIndex, 0)
        }
        PlasmaComponents3.MenuItem {
            text: "Unpin from Start"
            icon.name: "window-unpin"
            onClicked: start.rootModel.favoritesModel.removeFavorite(model.favoriteId)
        }
    }
}
