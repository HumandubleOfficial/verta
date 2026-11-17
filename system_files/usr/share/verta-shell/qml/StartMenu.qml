/*
    The Start menu, Windows 11 style: an acrylic panel above the taskbar,
    centred, with a search box, your pinned apps (All apps lists every app
    A to Z), recommended files, and your name and the power button along the
    bottom. Start typing to search apps, files and settings; Enter opens the
    top result. Esc, Start or a click anywhere else closes it.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.kicker as Kicker

Window {
    id: menu

    required property QtObject shell
    property bool shown: false
    property string page: "home"     // "home", "all" or "search"
    readonly property int panelWidth: 640
    readonly property int panelHeight: Math.min(720, (screen ? screen.height : 900) - Theme.taskbarHeight - 24)
    readonly property int gap: 12    // between the menu and the taskbar

    width: panelWidth
    height: panelHeight + gap
    visible: false
    color: "transparent"

    LayerShell.Window.scope: "verta-start"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    // Bottom only: centred, and placed just above the taskbar (it keeps out
    // of the taskbar's reserved strip).
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    function open(targetScreen, search) {
        if (targetScreen) {
            screen = targetScreen
            catcher.screen = targetScreen
        }
        page = "home"
        searchField.text = ""
        catcher.visible = true
        visible = true
        shown = true
        panel.opacity = 0
        slide.y = 40
        openAnimation.restart()
        searchField.forceActiveFocus()
        Qt.callLater(updateBlur)
    }
    function close() {
        if (!shown) {
            return
        }
        shown = false
        closeAnimation.restart()
    }
    function launch(model, row) {
        model.trigger(row, "", null)
        close()
    }
    function updateBlur() {
        Host.setBlur(menu, 0, 0, panelWidth, panelHeight, Theme.radius)
    }

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.normal + 60; easing.type: Easing.OutQuint }
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnimation
        ParallelAnimation {
            NumberAnimation { target: slide; property: "y"; to: 30; duration: Theme.fast; easing.type: Easing.InCubic }
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: Theme.fast; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                menu.visible = false
                catcher.visible = false
            }
        }
    }

    // A clear full-screen layer under the menu: a click anywhere outside the
    // menu (including the taskbar) lands here and closes it.
    property Window catcher: Window {
        id: catcher
        visible: false
        color: "transparent"
        LayerShell.Window.scope: "verta-start-catcher"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                                   | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: menu.close()
        }
    }

    // ---- Data ------------------------------------------------------------

    Settings {
        id: settings
        category: "StartMenu"
        property var pinned: [
            "org.kde.dolphin.desktop", "org.mozilla.firefox.desktop", "steam.desktop",
            "com.heroicgameslauncher.hgl.desktop", "net.lutris.Lutris.desktop", "org.kde.discover.desktop",
            "org.verta.Settings.desktop", "org.kde.konsole.desktop", "org.kde.kate.desktop",
            "org.kde.spectacle.desktop", "org.kde.plasma-systemmonitor.desktop", "com.usebottles.bottles.desktop"
        ]
    }
    Kicker.SimpleFavoritesModel {
        id: pinnedModel
        favorites: settings.pinned
    }
    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        Component.onCompleted: refresh()
    }
    readonly property var allApps: rootModel.count > 0 ? rootModel.modelForRow(0) : null
    Kicker.RecentUsageModel {
        id: recentModel
        shownItems: Kicker.RecentUsageModel.OnlyDocs
    }
    Kicker.RunnerModel {
        id: runnerModel
        mergeResults: true
        query: searchField.text
    }
    readonly property var results: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    Kicker.SystemModel {
        id: systemModel
    }
    KCoreAddons.KUser {
        id: kuser
    }

    // ---- Look --------------------------------------------------------------

    Item {
        id: panel
        width: menu.panelWidth
        height: menu.panelHeight
        transform: Translate { id: slide }

        Keys.onEscapePressed: menu.close()

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.flyout
            border.width: 1
            border.color: Theme.stroke
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Search box.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 28
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                Layout.preferredHeight: 36
                radius: height / 2
                color: Theme.field
                border.width: 1
                border.color: searchField.activeFocus ? Theme.accent : Theme.stroke

                Kirigami.Icon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: "search"
                    isMask: true
                    color: Theme.textDim
                }
                TextInput {
                    id: searchField
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    clip: true
                    onTextChanged: menu.page = text.length > 0 ? "search" : "home"
                    Keys.onEscapePressed: menu.close()
                    Keys.onReturnPressed: if (menu.results && menu.results.count > 0) menu.launch(menu.results, 0)
                    Keys.onEnterPressed: if (menu.results && menu.results.count > 0) menu.launch(menu.results, 0)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchField.text.length === 0
                        text: "Search for apps, settings and documents"
                        font: searchField.font
                        color: Theme.textFaint
                    }
                }
            }

            // Pages.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 20
                clip: true

                // Home: Pinned, then Recommended.
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    spacing: 8
                    visible: menu.page === "home"

                    SectionHeader {
                        title: "Pinned"
                        action: "All apps"
                        onActionClicked: menu.page = "all"
                    }
                    GridView {
                        id: pinnedGrid
                        Layout.fillWidth: true
                        Layout.preferredHeight: cellHeight * 3
                        cellWidth: Math.floor(width / 6)
                        cellHeight: 84
                        interactive: false
                        clip: true
                        model: pinnedModel
                        delegate: AppTile {
                            width: pinnedGrid.cellWidth
                            height: pinnedGrid.cellHeight
                            onClicked: menu.launch(pinnedModel, index)
                        }
                    }

                    SectionHeader {
                        Layout.topMargin: 12
                        title: "Recommended"
                    }
                    GridView {
                        id: recentGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth: Math.floor(width / 2)
                        cellHeight: 56
                        interactive: false
                        clip: true
                        model: recentModel
                        delegate: RowTile {
                            width: recentGrid.cellWidth - 8
                            height: recentGrid.cellHeight - 4
                            onClicked: menu.launch(recentModel, index)
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width * 0.7
                            visible: recentGrid.count === 0
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: "Files you open will show up here."
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: Theme.textDim
                        }
                    }
                }

                // All apps, A to Z.
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 24
                    spacing: 8
                    visible: menu.page === "all"

                    SectionHeader {
                        title: "All apps"
                        action: "Back"
                        onActionClicked: menu.page = "home"
                    }
                    ListView {
                        id: allList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: menu.allApps
                        boundsBehavior: Flickable.StopAtBounds
                        section.property: "display"
                        section.criteria: ViewSection.FirstCharacter
                        section.delegate: Text {
                            required property string section
                            height: 32
                            leftPadding: 12
                            verticalAlignment: Text.AlignVCenter
                            text: section.toUpperCase()
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                        delegate: RowTile {
                            width: allList.width - 8
                            height: 44
                            onClicked: menu.launch(menu.allApps, index)
                        }
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                    }
                }

                // Search results.
                ListView {
                    id: resultsList
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    visible: menu.page === "search"
                    clip: true
                    model: menu.results
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: RowTile {
                        width: resultsList.width
                        height: 48
                        highlighted: index === 0
                        onClicked: menu.launch(menu.results, index)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40
                        visible: resultsList.count === 0 && !runnerModel.querying
                        text: "No results for “" + searchField.text + "”"
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.textDim
                    }
                }
            }

            // Footer: you, and the power button.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: Theme.footer
                bottomLeftRadius: Theme.radius
                bottomRightRadius: Theme.radius

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.divider
                }

                MouseArea {
                    id: userButton
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: userRow.implicitWidth + 24
                    height: 40
                    hoverEnabled: true
                    onClicked: menu.launch(settingsLauncher, 0)
                    Kicker.SimpleFavoritesModel {
                        id: settingsLauncher
                        favorites: ["org.verta.Settings.desktop"]
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.controlRadius
                        color: userButton.containsMouse ? Theme.hover : "transparent"
                    }
                    Row {
                        id: userRow
                        anchors.centerIn: parent
                        spacing: 12
                        Kirigami.Avatar {
                            width: 32; height: 32
                            name: kuser.fullName || kuser.loginName
                            source: kuser.faceIconUrl
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: kuser.fullName || kuser.loginName
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: Theme.text
                        }
                    }
                }

                MouseArea {
                    id: powerButton
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40
                    hoverEnabled: true
                    onClicked: powerMenu.popup(powerButton, 0, -powerMenu.implicitHeight - 4)
                    Accessible.name: "Power"
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.controlRadius
                        color: powerButton.containsMouse ? Theme.hover : "transparent"
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18; height: 18
                        source: "system-shutdown"
                        isMask: true
                        color: Theme.text
                    }
                    QQC2.Menu {
                        id: powerMenu
                        popupType: QQC2.Popup.Window
                        Instantiator {
                            model: systemModel
                            delegate: QQC2.MenuItem {
                                required property int index
                                required property var model
                                text: model.display
                                onTriggered: menu.launch(systemModel, index)
                            }
                            onObjectAdded: (index, object) => powerMenu.insertItem(index, object)
                            onObjectRemoved: (index, object) => powerMenu.removeItem(object)
                        }
                    }
                }
            }
        }
    }

    // ---- Pieces --------------------------------------------------------------

    component SectionHeader: RowLayout {
        id: header
        property string title
        property string action: ""
        signal actionClicked()
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            leftPadding: 12
            text: header.title
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
        }
        MouseArea {
            id: actionButton
            visible: header.action !== ""
            Layout.preferredWidth: actionLabel.implicitWidth + 24
            Layout.preferredHeight: 26
            hoverEnabled: true
            onClicked: header.actionClicked()
            Rectangle {
                anchors.fill: parent
                radius: Theme.controlRadius
                color: actionButton.containsMouse ? Theme.hover : Theme.card
                border.width: 1
                border.color: Theme.stroke
            }
            Text {
                id: actionLabel
                anchors.centerIn: parent
                text: header.action + (header.action === "Back" ? "" : "  ›")
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text
            }
        }
    }

    // An app in the Pinned grid: icon over its name.
    component AppTile: MouseArea {
        id: tile
        required property int index
        required property var model
        hoverEnabled: true
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.controlRadius
            color: tile.pressed ? Theme.pressed : tile.containsMouse ? Theme.hover : "transparent"
        }
        Kirigami.Icon {
            id: tileIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12
            width: 32; height: 32
            source: tile.model.decoration
            scale: tile.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: 110 } }
        }
        Text {
            anchors.top: tileIcon.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.model.display || ""
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text
        }
    }

    // A row with an icon, a name and (for files) where it is: All apps,
    // Recommended and search results.
    component RowTile: MouseArea {
        id: row
        required property int index
        required property var model
        property bool highlighted: false
        hoverEnabled: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: row.pressed ? Theme.pressed : (row.containsMouse || row.highlighted) ? Theme.hover : "transparent"
        }
        Kirigami.Icon {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28
            source: row.model.decoration
        }
        Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: row.model.display || ""
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
            }
            Text {
                width: parent.width
                elide: Text.ElideMiddle
                visible: text !== ""
                text: row.model.description || ""
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.textDim
            }
        }
    }
}
