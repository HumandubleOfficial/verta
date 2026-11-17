/*
    The Start menu's window: one glass panel in the middle of the screen
    (Taskbar layout), not a popup stuck to the taskbar.

    It is a Plasma dialog, so it gets the Verta glass, its blur and its round
    corners like every other popup; KWin's Verta Motion effect makes it rise
    and grow into place (it knows the window by its title, "Verta Start").
    Clicking anywhere else closes it.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.Dialog {
    id: win

    title: "Verta Start"
    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    visible: false

    mainItem: StartMenu {
        id: menu
    }

    onVisibleChanged: {
        start.menuOpen = visible
        if (!visible) {
            start.menuClosedAt = Date.now()
            start.searchText = ""
        }
    }

    function open() {
        place()
        visible = true
        requestActivate()
        menu.reset()
    }
    function close() {
        visible = false
    }
    function toggle() {
        if (visible) {
            close()
        } else {
            open()
        }
    }

    // Centre of the screen the button is on, a little above the middle so it
    // sits clear of the taskbar.
    function place() {
        const c = Plasmoid.containment
        const screen = c ? c.screenGeometry : Qt.rect(0, 0, 1920, 1080)
        x = Math.round(screen.x + (screen.width - width) / 2)
        y = Math.round(screen.y + Math.max(0, (screen.height - height) / 2 - screen.height * 0.03))
    }
    onWidthChanged: if (visible) place()
    onHeightChanged: if (visible) place()
}
