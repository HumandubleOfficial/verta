/*
    The Start menu popup.

      [ Search apps, files and settings                 ]
      Pinned                                   All apps >
      [app] [app] [app] [app] [app] [app]
      [app] [app] [app] [app] [app] [app]
      Recent
      [file]                 [file]
      ---------------------------------------------------
      (o) Name                      settings lock sleep restart power

    Typing anything searches; Up/Down pick a result and Enter opens it.
    "All apps" slides in an A-Z list. Right-click an app to pin or unpin it.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigamiaddons.components as KirigamiComponents

Item {
    id: menu

    readonly property real unit: Kirigami.Units.gridUnit
    readonly property bool searching: start.searchText.length > 0
    property string page: "home"            // "home" or "all"

    Layout.minimumWidth: unit * 32
    Layout.preferredWidth: unit * 34
    Layout.maximumWidth: unit * 34
    Layout.minimumHeight: unit * 34
    Layout.preferredHeight: unit * 36
    Layout.maximumHeight: unit * 36

    // Back to the home page, empty search, focus in the search field every
    // time the menu opens.
    Connections {
        target: start
        function onExpandedChanged() {
            if (start.expanded) {
                menu.page = "home"
                searchField.text = ""
                searchField.forceActiveFocus()
            }
        }
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
        spacing: Kirigami.Units.largeSpacing

        // --- search ------------------------------------------------------
        PlasmaComponents3.TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            implicitHeight: Math.round(menu.unit * 2.3)
            leftPadding: Math.round(menu.unit * 2.2)
            placeholderText: "Search apps, files and settings"
            focus: true
            onTextChanged: start.searchText = text

            background: Rectangle {
                radius: height / 2
                color: Qt.alpha(Kirigami.Theme.textColor, searchField.activeFocus ? 0.10 : 0.07)
                border.width: 1
                border.color: searchField.activeFocus ? Qt.alpha(Kirigami.Theme.highlightColor, 0.8)
                                                      : Qt.alpha(Kirigami.Theme.textColor, 0.10)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                Kirigami.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(menu.unit * 0.75)
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: "search"
                    opacity: 0.6
                }
            }

            Keys.onPressed: event => {
                const view = menu.searching ? results : (menu.page === "all" ? allApps : pinned)
                if (event.key === Qt.Key_Down) {
                    if (menu.searching) {
                        results.incrementCurrentIndex()
                    } else {
                        view.forceActiveFocus()
                        if (view.currentIndex < 0) view.currentIndex = 0
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
                    } else if (menu.page !== "home") {
                        menu.page = "home"
                    } else {
                        start.expanded = false
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

            // Home: pinned apps and recent files.
            Page {
                id: home
                shown: !menu.searching && menu.page === "home"
                direction: -1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    SectionHeader {
                        text: "Pinned"
                        actionText: "All apps"
                        actionIcon: "go-next"
                        onActionClicked: menu.page = "all"
                    }

                    GridView {
                        id: pinned
                        Layout.fillWidth: true
                        Layout.preferredHeight: cellHeight * 3
                        Layout.maximumHeight: cellHeight * 3
                        interactive: contentHeight > height
                        clip: true
                        cellWidth: Math.floor(width / 6)
                        cellHeight: Math.round(menu.unit * 5.2)
                        model: start.rootModel.favoritesModel
                        currentIndex: -1
                        keyNavigationEnabled: true
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: AppTile {}
                        Keys.onReturnPressed: if (currentIndex >= 0) start.launch(model, currentIndex)
                        Keys.onUpPressed: event => {
                            if (currentIndex < 6) { searchField.forceActiveFocus(); currentIndex = -1 }
                            else moveCurrentIndexUp()
                        }

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            visible: pinned.count === 0
                            text: "Right-click any app in All apps to pin it here"
                            opacity: 0.6
                        }
                    }

                    SectionHeader {
                        text: "Recent"
                        Layout.topMargin: Kirigami.Units.smallSpacing
                    }

                    GridView {
                        id: recent
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        interactive: false
                        clip: true
                        cellWidth: Math.floor(width / 2)
                        cellHeight: Math.round(menu.unit * 2.8)
                        model: start.recentModel
                        delegate: AppRow {
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight
                            visible: index < 6
                            isCurrent: false
                            subtitle: model.description || ""
                            onActivated: start.launch(start.recentModel, index)
                        }

                        PlasmaComponents3.Label {
                            anchors.centerIn: parent
                            visible: recent.count === 0
                            text: "Files you open will show up here"
                            opacity: 0.6
                        }
                    }
                }
            }

            // All apps, A to Z.
            Page {
                id: all
                shown: !menu.searching && menu.page === "all"
                direction: 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    SectionHeader {
                        text: "All apps"
                        actionText: "Back"
                        actionIcon: "go-previous"
                        actionFirst: true
                        onActionClicked: menu.page = "home"
                    }

                    PlasmaComponents3.ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PlasmaComponents3.ScrollBar.horizontal.policy: PlasmaComponents3.ScrollBar.AlwaysOff

                        ListView {
                            id: allApps
                            model: start.allAppsModel
                            currentIndex: -1
                            keyNavigationEnabled: true
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            section.property: "display"
                            section.criteria: ViewSection.FirstCharacter
                            section.delegate: PlasmaComponents3.Label {
                                required property string section
                                width: ListView.view.width
                                height: Math.round(menu.unit * 1.5)
                                leftPadding: Kirigami.Units.largeSpacing
                                verticalAlignment: Text.AlignBottom
                                bottomPadding: 2
                                text: section.toUpperCase()
                                font.weight: Font.DemiBold
                                color: Kirigami.Theme.highlightColor
                            }
                            delegate: AppRow {
                                width: ListView.view.width
                                height: Math.round(menu.unit * 2.4)
                                isCurrent: ListView.isCurrentItem && allApps.activeFocus
                                pinnable: true
                                onActivated: start.launch(start.allAppsModel, index)
                            }
                            Keys.onReturnPressed: if (currentIndex >= 0) start.launch(model, currentIndex)
                            Keys.onUpPressed: event => {
                                if (currentIndex <= 0) { searchField.forceActiveFocus(); currentIndex = -1 }
                                else decrementCurrentIndex()
                            }
                        }
                    }
                }
            }

            // Search results.
            Page {
                id: search
                shown: menu.searching
                direction: 0

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

        // --- footer: you, settings and power ---------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: -Kirigami.Units.largeSpacing
            Layout.rightMargin: -Kirigami.Units.largeSpacing
            Layout.bottomMargin: -Kirigami.Units.largeSpacing
            implicitHeight: Math.round(menu.unit * 3.4)
            color: Qt.alpha(Kirigami.Theme.textColor, 0.04)

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing * 2
                anchors.rightMargin: Kirigami.Units.largeSpacing * 2
                spacing: Kirigami.Units.smallSpacing * 2

                KirigamiComponents.Avatar {
                    Layout.preferredWidth: Math.round(menu.unit * 1.9)
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
    }

    // A page that slides and fades in from its side (direction -1: left,
    // 1: right, 0: rises from below).
    component Page: Item {
        property bool shown: false
        property int direction: 0
        width: pages.width
        height: pages.height
        visible: opacity > 0
        opacity: shown ? 1 : 0
        enabled: shown
        transform: Translate {
            x: shown ? 0 : direction * menu.unit * 3
            y: shown || direction !== 0 ? 0 : menu.unit
            Behavior on x { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
    }

    // "Pinned ............ All apps >"
    component SectionHeader: RowLayout {
        id: header
        property alias text: title.text
        property string actionText: ""
        property string actionIcon: ""
        property bool actionFirst: false
        signal actionClicked()
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
        layoutDirection: actionFirst ? Qt.RightToLeft : Qt.LeftToRight

        PlasmaComponents3.Label {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: header.actionFirst ? Text.AlignRight : Text.AlignLeft
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
        }
        PillButton {
            visible: header.actionText !== ""
            text: header.actionText
            icon: header.actionIcon
            iconFirst: header.actionFirst
            onClicked: header.actionClicked()
        }
    }

    // Small rounded text button ("All apps >", "< Back").
    component PillButton: MouseArea {
        id: pill
        property string text
        property string icon
        property bool iconFirst: false
        implicitWidth: row.implicitWidth + menu.unit
        implicitHeight: Math.round(menu.unit * 1.6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: pill.pressed ? 0.16 : (pill.containsMouse ? 0.10 : 0.06)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 2
            layoutDirection: pill.iconFirst ? Qt.RightToLeft : Qt.LeftToRight
            PlasmaComponents3.Label {
                text: pill.text
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Layout.preferredWidth
                source: pill.icon
                // nudges toward where it leads on hover
                transform: Translate {
                    x: pill.containsMouse ? (pill.iconFirst ? -2 : 2) : 0
                    Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
                }
            }
        }
        scale: pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
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
