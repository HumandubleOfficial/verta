/*
    Verta Menu: the left end of Verta's menu bar.

      [V]  Firefox  |  File  Edit  View ...  (the app's menus: Global Menu widget)

    The Verta logo opens the system menu: About This Computer, Settings,
    App Store, Force Quit, Sleep, Restart, Shut Down, Lock Screen, Log Out.
    The name of the app in front (in bold) opens a small menu for its window:
    New Window, Minimise, Zoom, Quit.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // --- the app in front ------------------------------------------------
    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled
    }
    readonly property var front: tasks.activeTask
    readonly property bool hasFront: front && front.valid
    readonly property string frontName: {
        if (!hasFront) {
            return "Desktop"
        }
        const name = tasks.data(front, TaskManager.AbstractTasksModel.AppName)
            || tasks.data(front, Qt.DisplayRole) || ""
        return name !== "" ? name : "Desktop"
    }

    // --- running commands ------------------------------------------------
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }
    function run(command) {
        shell.connectSource(command)
    }
    function prompt(kind) {   // KDE's own confirmation screens
        run("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt." + kind)
    }

    fullRepresentation: RowLayout {
        id: bar
        spacing: 0
        Layout.minimumWidth: implicitWidth
        Layout.maximumWidth: implicitWidth
        Layout.fillHeight: true

        // ---- Verta logo -------------------------------------------------
        MenuButton {
            id: logoButton
            Layout.preferredWidth: Math.round(height * 1.45)
            open: systemMenu.status === PlasmaExtras.Menu.Open
            onClicked: systemMenu.openRelative()
            Accessible.name: "Verta menu"

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small
                height: width
                source: "verta-logo-symbolic"
                fallback: "verta-logo"
                isMask: true
                color: Kirigami.Theme.textColor
            }
        }

        // ---- the app in front --------------------------------------------
        MenuButton {
            id: appButton
            Layout.preferredWidth: appLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
            open: appMenu.status === PlasmaExtras.Menu.Open
            enabled: root.hasFront
            onClicked: appMenu.openRelative()
            Accessible.name: root.frontName

            PlasmaComponents3.Label {
                id: appLabel
                anchors.centerIn: parent
                text: root.frontName
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Kirigami.Units.gridUnit * 12)
                opacity: 1
            }
        }

        PlasmaExtras.Menu {
            id: systemMenu
            visualParent: logoButton
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

            PlasmaExtras.MenuItem {
                text: "About This Computer"
                icon: "verta-logo"
                onClicked: root.run("verta-settings --page about")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Settings…"
                icon: "org.verta.Settings"
                onClicked: root.run("verta-settings")
            }
            PlasmaExtras.MenuItem {
                text: "App Store…"
                icon: "org.kde.discover"
                onClicked: root.run("plasma-discover")
            }
            PlasmaExtras.MenuItem {
                text: "Software Update…"
                icon: "system-software-update"
                onClicked: root.run("verta-settings --page updates")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Force Quit…"
                icon: "process-stop"
                onClicked: root.run("plasma-systemmonitor --page-id applications")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Sleep"
                icon: "system-suspend"
                onClicked: root.run("systemctl suspend")
            }
            PlasmaExtras.MenuItem {
                text: "Restart…"
                icon: "system-reboot"
                onClicked: root.prompt("promptReboot")
            }
            PlasmaExtras.MenuItem {
                text: "Shut Down…"
                icon: "system-shutdown"
                onClicked: root.prompt("promptShutDown")
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Lock Screen"
                icon: "system-lock-screen"
                onClicked: root.run("loginctl lock-session")
            }
            PlasmaExtras.MenuItem {
                text: "Log Out…"
                icon: "system-log-out"
                onClicked: root.prompt("promptLogout")
            }
        }

        PlasmaExtras.Menu {
            id: appMenu
            visualParent: appButton
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

            PlasmaExtras.MenuItem {
                text: "New Window"
                icon: "window-new"
                onClicked: tasks.requestNewInstance(root.front)
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Minimise"
                icon: "window-minimize"
                onClicked: tasks.requestToggleMinimized(root.front)
            }
            PlasmaExtras.MenuItem {
                text: "Zoom"
                icon: "window-maximize"
                onClicked: tasks.requestToggleMaximized(root.front)
            }
            PlasmaExtras.MenuItem { separator: true }
            PlasmaExtras.MenuItem {
                text: "Quit " + root.frontName
                icon: "application-exit"
                onClicked: tasks.requestClose(root.front)
            }
        }
    }

    // A menu-bar button: a soft rounded highlight while hovered or open.
    component MenuButton: MouseArea {
        id: button
        property bool open: false
        Layout.fillHeight: true
        hoverEnabled: true
        Accessible.role: Accessible.ButtonMenu

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Math.round(parent.height * 0.12)
            anchors.bottomMargin: anchors.topMargin
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: button.open ? 0.16 : (button.containsMouse && button.enabled ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
    }
}
