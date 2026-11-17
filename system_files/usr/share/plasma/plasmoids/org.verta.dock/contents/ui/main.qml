/*
    Verta Dock: your pinned and open apps, in the dock (Dock layout) or the
    taskbar (Taskbar layout).

      Dock:     big icons that swell under the pointer like a magnifying
                glass, a small dot under each open app, a bounce while an
                app starts.
      Taskbar:  a soft pill behind the icon under the pointer, a dash under
                open apps that widens for the one in front, a hop while an
                app starts.

    Click an app to open or switch to it (click the one in front to minimise
    it; an app with several windows steps through them). Middle-click opens
    a new window. Right-click for its actions, Keep in Dock and Quit.
    Drag icons to reorder them, drag an app from Launchpad or the Start menu
    in to keep it, or drag one out onto the desktop to put it there: it lands
    on the grid where you let go, without asking whether to copy or link.

    Plasma's own task manager is compiled into Plasma and can't be restyled,
    so this is Verta's, built on the same task model (pinned apps, grouping,
    window activation and minimise targets behave the same).

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: dock

    readonly property bool taskbar: Plasmoid.configuration.style === "taskbar"
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real thickness: vertical ? width : height
    readonly property int iconSize: Math.max(16, Math.round(thickness * (taskbar ? 0.64 : 0.82)))
    readonly property int cellSize: Math.max(20, Math.round(thickness * (taskbar ? 0.96 : 0.88)))

    // Where the pointer is along the row (-1: not over the dock), for the
    // magnifying effect, and the app being dragged to a new place.
    property real hoverPos: -1
    property Item dragSource: null

    preferredRepresentation: fullRepresentation

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }
    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByScreen: false
        filterByActivity: true

        // Pinned apps stay where they are; an app's windows take its place.
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false

        onLauncherListChanged: {
            if (launcherList.join("\n") !== Plasmoid.configuration.launchers.join("\n")) {
                Plasmoid.configuration.launchers = launcherList
            }
        }
        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
    }
    // Pins written from outside (the layout scripts in Settings write them
    // right after adding the dock).
    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged() {
            if (tasksModel.launcherList.join("\n") !== Plasmoid.configuration.launchers.join("\n")) {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
        }
    }

    // An app's .desktop file and its actions ("New Private Window"...),
    // looked up when needed through the Start menu's app back end.
    Kicker.SimpleFavoritesModel {
        id: appInfo
    }
    Instantiator {
        id: appInfoRows
        model: appInfo
        delegate: QtObject {
            readonly property string url: model.url ? model.url.toString() : ""
            readonly property var actions: model.actionList || []
        }
    }
    function storageId(launcherUrl) {
        const s = launcherUrl ? launcherUrl.toString() : ""
        if (s.startsWith("applications:")) {
            return s.substring("applications:".length).split("?")[0]
        }
        if (s.startsWith("file:") && s.endsWith(".desktop")) {
            return decodeURIComponent(s.substring(s.lastIndexOf("/") + 1))
        }
        return ""
    }
    function appInfoFor(launcherUrl) {
        const id = storageId(launcherUrl)
        if (id === "") {
            return null
        }
        appInfo.favorites = [id]
        return appInfoRows.count > 0 ? appInfoRows.objectAt(0) : null
    }
    // A file:// URL of the app's .desktop file (what the desktop can link to).
    function desktopFileUrl(launcherUrl) {
        const s = launcherUrl ? launcherUrl.toString() : ""
        if (s.startsWith("file:")) {
            return s.split("?")[0]
        }
        const info = appInfoFor(launcherUrl)
        return info ? info.url : ""
    }
    function triggerAppAction(launcherUrl, action) {
        if (appInfoFor(launcherUrl)) {
            appInfo.trigger(0, action.actionId, action.actionArgument)
        }
    }

    function isPinned(launcherUrl) {
        return launcherUrl && launcherUrl.toString() !== "" && tasksModel.launcherPosition(launcherUrl) !== -1
    }
    function setPinned(launcherUrl, pinned) {
        if (pinned) {
            tasksModel.requestAddLauncher(launcherUrl)
        } else {
            tasksModel.requestRemoveLauncher(launcherUrl)
        }
    }

    fullRepresentation: Item {
        id: rep

        readonly property real length: list.count * dock.cellSize
        Layout.minimumWidth: dock.vertical ? -1 : length
        Layout.preferredWidth: dock.vertical ? -1 : length
        Layout.maximumWidth: dock.vertical ? -1 : length
        Layout.minimumHeight: dock.vertical ? length : -1
        Layout.preferredHeight: dock.vertical ? length : -1
        Layout.maximumHeight: dock.vertical ? length : -1
        Layout.fillWidth: false
        Layout.fillHeight: false

        ListView {
            id: list
            anchors.fill: parent
            orientation: dock.vertical ? ListView.Vertical : ListView.Horizontal
            interactive: false
            boundsBehavior: Flickable.StopAtBounds
            model: tasksModel
            delegate: DockItem {}

            // A newly opened app grows into its place, a closed one shrinks
            // away, and the others glide aside.
            add: Transition {
                NumberAnimation { property: "scale"; from: 0.2; to: 1; duration: 320; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0.2; duration: 180; easing.type: Easing.InCubic }
                NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; to: 1; duration: 200 }
                NumberAnimation { property: "opacity"; to: 1; duration: 200 }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: hover
            }
            Binding {
                target: dock
                property: "hoverPos"
                value: hover.hovered ? (dock.vertical ? hover.point.position.y : hover.point.position.x) : -1
            }
        }

        // Drops: reorder (an icon dragged inside the dock), keep an app
        // (a .desktop file from Launchpad, the Start menu or Files), or open
        // files with the app under the pointer.
        DropArea {
            anchors.fill: parent

            function rowAt(x, y) {
                const pos = dock.vertical ? y : x
                return Math.max(0, Math.min(list.count - 1, Math.floor(pos / dock.cellSize)))
            }

            onPositionChanged: drag => {
                if (dock.dragSource) {
                    const to = rowAt(drag.x, drag.y)
                    if (to !== dock.dragSource.index) {
                        tasksModel.move(dock.dragSource.index, to)
                    }
                }
            }
            onDropped: drop => {
                if (dock.dragSource) {
                    tasksModel.syncLaunchers()
                    drop.accept(Qt.MoveAction)
                    return
                }
                if (!drop.hasUrls) {
                    return
                }
                const apps = drop.urls.filter(u => u.toString().endsWith(".desktop"))
                if (apps.length > 0) {
                    const to = rowAt(drop.x, drop.y)
                    apps.forEach(u => {
                        tasksModel.requestAddLauncher(u)
                        const from = tasksModel.launcherPosition(u)
                        if (from >= 0 && list.count > 0) {
                            tasksModel.move(from, Math.min(to + 1, list.count - 1))
                        }
                    })
                    tasksModel.syncLaunchers()
                } else if (list.count > 0) {
                    tasksModel.requestOpenUrls(tasksModel.makeModelIndex(rowAt(drop.x, drop.y)), drop.urls)
                }
                drop.accept(Qt.CopyAction)
            }
        }
    }
}
