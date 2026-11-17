/*
    Verta Shell: one taskbar per screen and one Start menu.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQml

QtObject {
    id: root

    // The Start menu opens on the screen whose Start button was clicked.
    property StartMenu startMenu: StartMenu {
        shell: root
    }

    // Quick Settings (network and sound) and the calendar (the clock).
    property QuickSettings quickSettings: QuickSettings {
        shell: root
    }
    property Calendar calendar: Calendar {
        shell: root
    }

    // Notification pop-ups (Verta Shell is the notification server).
    property NotificationPopups notificationPopups: NotificationPopups {
        shell: root
        dnd: root.quickSettings.dnd
        suppressed: root.startMenu.shown || root.quickSettings.shown || root.calendar.shown
    }

    property Instantiator taskbars: Instantiator {
        model: Qt.application.screens
        delegate: Taskbar {
            required property var modelData
            targetScreen: modelData
            shell: root
        }
    }

    // The Windows key (or anything else calling org.verta.Shell.toggleStart).
    property Connections keys: Connections {
        target: Host
        function onStartRequested() {
            root.toggleStart(root.startMenu.screen || Qt.application.screens[0], false)
        }
        function onFlyoutRequested(name) {
            const [which, page] = name.split(":")
            const flyout = root[which]
            if (!flyout) {
                return
            }
            if (page !== undefined) {
                // Straight to a list in Quick Settings; stays open if it is.
                if (!flyout.shown) {
                    root.toggleFlyout(flyout, flyout.screen || Qt.application.screens[0])
                }
                flyout.page = page
            } else {
                root.toggleFlyout(flyout, flyout.screen || Qt.application.screens[0])
            }
        }
    }

    // Only one of the Start menu and the flyouts is open at a time.
    function closeAll(except) {
        [startMenu, quickSettings, calendar].forEach(f => {
            if (f !== except && f.shown) {
                f.close()
            }
        })
    }

    function toggleStart(screen, search) {
        if (startMenu.shown) {
            startMenu.close()
        } else {
            closeAll(startMenu)
            startMenu.open(screen, search === true)
        }
    }

    function toggleFlyout(flyout, screen) {
        if (flyout.shown) {
            flyout.close()
        } else {
            closeAll(flyout)
            flyout.open(screen)
        }
    }

    // Plasma's own shortcuts in KWin (Task View, Show desktop).
    function kwinShortcut(name) {
        Host.run("qdbus-qt6", ["org.kde.kglobalaccel", "/component/kwin",
                                "org.kde.kglobalaccel.Component.invokeShortcut", name])
    }
}
