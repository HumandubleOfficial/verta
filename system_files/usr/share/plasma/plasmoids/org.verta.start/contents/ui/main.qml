/*
    Verta Start: the app launcher.

    In the dock (Dock layout) it opens Launchpad: every app in a full-screen
    grid over the blurred desktop, with search. On the taskbar (Taskbar
    layout) it opens the Start menu: pinned apps, recent files, all apps and
    search in one glass panel. The "launchpad" setting picks which.

    Built on the same app, search and favourites back ends as KDE's own
    launchers (org.kde.plasma.private.kicker), so pinned apps, search results
    and app actions behave exactly like the stock menu; only the look and the
    layout are Verta's.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: start

    readonly property bool launchpad: Plasmoid.configuration.launchpad

    Plasmoid.icon: Plasmoid.configuration.icon || (launchpad ? "verta-launchpad" : "verta-logo")
    Plasmoid.status: (expanded || (launchpadWindow && launchpadWindow.visible))
        ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus
    // Launchpad is its own full-screen window, so Plasma must not open a popup
    // for it: the button is then the "full" representation, shown in place.
    preferredRepresentation: launchpad ? fullRepresentation : compactRepresentation
    hideOnWindowDeactivate: true
    activationTogglesExpanded: !launchpad

    toolTipMainText: launchpad ? "Apps" : "Start"
    toolTipSubText: ""

    // Every app (all-apps list) and the pinned apps.
    property Kicker.RootModel rootModel: Kicker.RootModel {
        autoPopulate: false
        appletInterface: start
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        highlightNewlyInstalledApps: true

        Component.onCompleted: {
            favoritesModel.initForClient("org.verta.start.favorites.instance-" + Plasmoid.id)
            // First run: pin the default apps. KDE adds the list from
            // kicker-extra-favoritesrc (written in 30-desktop.sh) in front of
            // the one passed here, or uses only that list if it says so.
            if (!Plasmoid.configuration.favoritesPorted) {
                if (favoritesModel.count < 1) {
                    favoritesModel.portOldFavorites(Plasmoid.configuration.favorites)
                }
                Plasmoid.configuration.favoritesPorted = true
            }
        }
    }

    // Search: apps first, then files, settings, calculator, and so on.
    property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        appletInterface: start
        mergeResults: true
        favoritesModel: start.rootModel.favoritesModel
        onRequestUpdateQuery: query => { start.searchText = query }
    }

    // Recently opened files ("Recent" on the home page).
    property Kicker.RecentUsageModel recentModel: Kicker.RecentUsageModel {
        shownItems: Kicker.RecentUsageModel.OnlyDocs
        ordering: Kicker.RecentUsageModel.Recent
    }

    // Lock, sleep, restart, shut down.
    property Kicker.SystemModel systemModel: Kicker.SystemModel {}

    // Launches a .desktop file by name (footer settings button).
    property Kicker.SimpleFavoritesModel launcher: Kicker.SimpleFavoritesModel {
        favorites: ["org.verta.Settings.desktop"]
    }

    property string searchText: ""
    onSearchTextChanged: runnerModel.query = searchText

    // The all-apps model is the root model's first row ("All Applications").
    readonly property var allAppsModel: rootModel.count > 0 ? rootModel.modelForRow(0) : null

    Kicker.ProcessRunner {
        id: processRunner
    }

    compactRepresentation: launchpad ? null : buttonComponent
    fullRepresentation: launchpad ? buttonComponent : menuComponent

    Component {
        id: buttonComponent
        StartButton {}
    }
    Component {
        id: menuComponent
        StartMenu {}
    }

    // Launchpad: made once, the first time it's needed.
    property var launchpadWindow: null
    function toggleLaunchpad() {
        if (!launchpadWindow) {
            const c = Qt.createComponent(Qt.resolvedUrl("Launchpad.qml"))
            if (c.status !== Component.Ready) {
                console.warn("Verta Start: Launchpad failed to load:", c.errorString())
                return
            }
            launchpadWindow = c.createObject(start)
        }
        launchpadWindow.toggle()
    }

    // The Meta (Windows) key.
    Connections {
        target: Plasmoid
        enabled: start.launchpad
        function onActivated() { start.toggleLaunchpad() }
    }

    // Drag an app from Launchpad onto the dock to keep it there.
    Kicker.DragHelper {
        id: dragHelper
        dragIconSize: Kirigami.Units.iconSizes.huge
    }

    function launch(model, row) {
        model.trigger(row, "", null)
        start.expanded = false
        if (launchpadWindow && launchpadWindow.visible) {
            launchpadWindow.toggle()
        }
    }

    onExpandedChanged: isExpanded => {
        if (!isExpanded) {
            searchText = ""
        } else {
            recentModel.refresh()
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Edit Applications…"
            icon.name: "kmenuedit"
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Component.onCompleted: rootModel.refresh()
}
