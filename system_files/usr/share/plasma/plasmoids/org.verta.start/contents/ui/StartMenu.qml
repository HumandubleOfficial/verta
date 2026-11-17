/*
    The Start menu: one glass panel in the middle of the screen.

      (search)  Search apps, files and settings
      +--------------------------------------------------+
      |  [app]   [app]   [app]   [app]   [app]   Pinned  |
      +--------------------------------------------------+
      All apps
      [app]   [app]   [app]   [app]   [app]      A to Z, scrolls
      [app]   [app]   [app]   [app]   [app]
      (o) Name                 settings lock sleep restart power

    Typing anything searches apps, files, settings and the calculator;
    Up/Down pick a result and Enter opens it. Down from the search field
    walks the app grid with the arrow keys. Right-click an app to pin or
    unpin it. No edge-to-edge bands or rules: the glass is one clean sheet.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigamiaddons.components as KirigamiComponents

Item {
    id: menu

    readonly property real unit: Kirigami.Units.gridUnit
    readonly property bool searching: start.searchText.length > 0
    readonly property int columns: 5
    readonly property real cellWidth: Math.floor(apps.width / columns)
    readonly property real cellHeight: Math.round(unit * 5.4)

    width: Math.round(unit * 37)
    height: Math.round(unit * 34)
    Layout.minimumWidth: width
    Layout.maximumWidth: width
    Layout.minimumHeight: height
    Layout.maximumHeight: height

    // Every time the menu opens: empty search, top of the list, typing goes
    // to the search field.
    function reset() {
        searchField.text = ""
        apps.currentIndex = -1
        apps.positionViewAtBeginning()
        searchField.forceActiveFocus()
    }

    Connections {
        target: start
        function onSearchTextChanged() {
            if (searchField.text !== start.searchText) {
                searchField.text = start.searchText
            }
        }
    }

    KCoreAddons.KUser {
        id: kuser
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // --- search: big and quiet, like a title ---------------------------
        PlasmaComponents3.TextField {
            id: searchField
            Layout.fillWidth: true
            implicitHeight: Math.round(menu.unit * 2.8)
            leftPadding: Math.round(menu.unit * 2.3)
            placeholderText: "Search apps, files and settings"
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.45
            font.weight: Font.Normal
            focus: true
            onTextChanged: start.searchText = text

            background: Item {
                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(menu.unit * 0.4)
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: "search"
                    opacity: searchField.activeFocus ? 0.85 : 0.6
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down) {
                    if (menu.searching) {
                        results.incrementCurrentIndex()
                    } else {
                        apps.forceActiveFocus()
                        if (apps.currentIndex < 0) apps.currentIndex = 0
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Up && menu.searching) {
                    results.decrementCurrentIndex()
                    event.accepted = true
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && menu.searching) {
                    if (results.count > 0) {
                        start.launch(results.model, Math.max(0, results.currentIndex))
                    }
                    event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    if (text.length > 0) {
                        text = ""
                    } else {
                        start.closeMenu()
                    }
                    event.accepted = true
                }
            }
        }

        // --- pages -------------------------------------------------------
        Item {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Home: pinned apps on a soft card, then every app A to Z.
            Page {
                shown: !menu.searching

                PlasmaComponents3.ScrollView {
                    anchors.fill: parent
                    PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                    GridView {
                        id: apps
                        model: start.allAppsModel
                        cellWidth: menu.cellWidth
                        cellHeight: menu.cellHeight
                        currentIndex: -1
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        delegate: AppTile {}
                        Keys.onReturnPressed: if (currentIndex >= 0) start.launch(model, currentIndex)
                        Keys.onEnterPressed: if (currentIndex >= 0) start.launch(model, currentIndex)
                        Keys.onUpPressed: event => {
                            if (currentIndex < menu.columns) { searchField.forceActiveFocus(); currentIndex = -1 }
                            else moveCurrentIndexUp()
                        }
                        Keys.onEscapePressed: start.closeMenu()

                        header: ColumnLayout {
                            width: apps.width
                            spacing: Kirigami.Units.smallSpacing

                            SectionLabel {
                                text: "Pinned"
                                visible: pinned.count > 0
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: pinned.height + Kirigami.Units.smallSpacing * 2
                                visible: pinned.count > 0
                                radius: Kirigami.Units.cornerRadius * 2.2
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.055)

                                GridView {
                                    id: pinned
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: Math.ceil(count / menu.columns) * cellHeight
                                    interactive: false
                                    cellWidth: Math.floor(width / menu.columns)
                                    cellHeight: menu.cellHeight
                                    model: start.rootModel.favoritesModel
                                    delegate: AppTile { pinnedTile: true }
                                }
                            }
                            SectionLabel {
                                text: "All apps"
                                Layout.topMargin: Kirigami.Units.smallSpacing
                            }
                        }
                    }
                }
            }

            // Search results.
            Page {
                shown: menu.searching

                PlasmaComponents3.ScrollView {
                    anchors.fill: parent
                    PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                    ListView {
                        id: results
                        model: start.runnerModel.count > 0 ? start.runnerModel.modelForRow(0) : null
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        onCountChanged: currentIndex = 0
                        delegate: AppRow {
                            width: ListView.view.width
                            height: Math.round(menu.unit * 2.8)
                            isCurrent: ListView.isCurrentItem
                            subtitle: model.description || ""
                            pinnable: true
                            onActivated: start.launch(results.model, index)
                        }
                    }
                }

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: results.count === 0 && !start.runnerModel.querying
                    text: "No results for “" + start.searchText + "”"
                    opacity: 0.6
                }
            }
        }

        // --- you, settings and power -------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(menu.unit * 2.6)
            Layout.leftMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing * 2

            KirigamiComponents.Avatar {
                Layout.preferredWidth: Math.round(menu.unit * 1.8)
                Layout.preferredHeight: Layout.preferredWidth
                name: kuser.fullName || kuser.loginName
                source: kuser.faceIconUrl
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: kuser.fullName || kuser.loginName
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            RoundButton {
                icon: "org.verta.Settings"
                tip: "Settings"
                onClicked: start.launch(start.launcher, 0)
            }
            Repeater {
                model: start.systemModel
                delegate: RoundButton {
                    visible: ["lock-screen", "suspend", "reboot", "shutdown"].includes(model.favoriteId)
                    icon: model.decoration
                    tip: model.display
                    onClicked: start.launch(start.systemModel, index)
                }
            }
        }
    }

    // A page that fades and rises into place.
    component Page: Item {
        property bool shown: false
        width: pages.width
        height: pages.height
        visible: opacity > 0
        opacity: shown ? 1 : 0
        enabled: shown
        transform: Translate {
            y: shown ? 0 : menu.unit * 0.6
            Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
    }

    // "Pinned", "All apps".
    component SectionLabel: PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        topPadding: Kirigami.Units.smallSpacing
        font.weight: Font.DemiBold
        opacity: 0.75
    }

    // Round icon button with a tooltip (footer).
    component RoundButton: MouseArea {
        id: round
        property var icon
        property string tip
        Layout.preferredWidth: Math.round(menu.unit * 2.1)
        Layout.preferredHeight: Layout.preferredWidth
        hoverEnabled: true
        Accessible.name: tip
        Accessible.role: Accessible.Button
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Kirigami.Theme.textColor
            opacity: round.pressed ? 0.16 : (round.containsMouse ? 0.10 : 0)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            source: round.icon
            scale: round.pressed ? 0.85 : 1
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutBack } }
        }
        PlasmaComponents3.ToolTip {
            text: round.tip
            visible: round.containsMouse && round.tip !== ""
        }
    }
}
