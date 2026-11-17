/*
    Verta Start: the app launcher.

    In the dock (Dock layout) it opens Launchpad: every app in a full-screen
    grid over the blurred desktop, with search. On the taskbar (Taskbar
    layout) it opens the Start menu: pinned apps, all apps and search in one
    glass panel in the middle of the screen. The "launchpad" setting picks
    which. Either way the button sits in the bar and the menu is a window of
    its own (Launchpad.qml, StartWindow.qml), made the first time it opens.

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
    Plasmoid.status: (menuOpen || (launchpadWindow && launchpadWindow.visible))
        ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus
    // Launchpad and the Start menu are windows of their own, so Plasma must
    // not open a popup: the button is the "full" representation, shown in place.
    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false

    property bool menuOpen: false        // the Start menu window is showing
    property double menuClosedAt: 0      // when it last closed (see StartButton)

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

    fullRepresentation: StartButton {}

    // Launchpad and the Start menu: each made once, the first time it's needed.
    property var launchpadWindow: null
    property var menuWindow: null
    function makeWindow(file) {
        const c = Qt.createComponent(Qt.resolvedUrl(file))
        if (c.status !== Component.Ready) {
            console.warn("Verta Start:", file, "failed to load:", c.errorString())
            return null
        }
        return c.createObject(start)
    }
    function toggleLaunchpad() {
        if (!launchpadWindow) {
            launchpadWindow = makeWindow("Launchpad.qml")
        }
        if (launchpadWindow) {
            launchpadWindow.toggle()
        }
    }
    function toggleMenu() {
        if (!menuWindow) {
            menuWindow = makeWindow("StartWindow.qml")
        }
        if (menuWindow) {
            menuWindow.toggle()
        }
    }
    function closeMenu() {
        if (menuWindow) {
            menuWindow.close()
        }
    }
    // The button and the Meta (Windows) key.
    function toggle() {
        if (launchpad) {
            toggleLaunchpad()
        } else {
            toggleMenu()
        }
    }

    Connections {
        target: Plasmoid
        function onActivated() { start.toggle() }
    }

    // Drag an app from Launchpad onto the dock to keep it there.
    Kicker.DragHelper {
        id: dragHelper
        dragIconSize: Kirigami.Units.iconSizes.huge
    }

    function launch(model, row) {
        model.trigger(row, "", null)
        closeMenu()
        if (launchpadWindow && launchpadWindow.visible) {
            launchpadWindow.toggle()
        }
    }

    // A new launcher type or a theme switch rebuilds the button; the menu
    // window follows the widget and goes with it.
    Component.onDestruction: {
        if (menuWindow) {
            menuWindow.destroy()
        }
        if (launchpadWindow) {
            launchpadWindow.destroy()
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
