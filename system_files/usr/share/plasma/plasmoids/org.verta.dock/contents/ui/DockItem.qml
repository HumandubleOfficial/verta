/*
    One app in Verta Dock: its icon, the open-app indicator, the hover and
    launch animations, its menu, and dragging it around or out.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: task

    required property var model
    required property int index

    width: dock.vertical ? ListView.view.width : dock.cellSize
    height: dock.vertical ? dock.cellSize : ListView.view.height

    readonly property bool isWindow: model.IsWindow === true
    readonly property bool isStartup: model.IsStartup === true
    readonly property bool isActive: model.IsActive === true
    readonly property bool isGroup: model.IsGroupParent === true
    readonly property bool attention: model.IsDemandingAttention === true
    readonly property var launcherUrl: model.LauncherUrlWithoutIcon || ""
    readonly property string name: model.AppName || model.display || ""
    readonly property bool pinned: tasksModel.launcherCount >= 0 && dock.isPinned(launcherUrl)
    readonly property string keepText: dock.taskbar ? "Pin to Taskbar" : "Keep in Dock"
    readonly property string unkeepText: dock.taskbar ? "Unpin from Taskbar" : "Remove from Dock"

    // --- hover -------------------------------------------------------------
    // Dock: the icon under the pointer swells and its neighbours a little,
    // like a magnifying glass sliding along. Taskbar: only the one under the
    // pointer lifts slightly.
    readonly property real reach: dock.cellSize * 2.1
    readonly property real centre: (dock.vertical ? y + height / 2 : x + width / 2)
    readonly property real distance: dock.hoverPos < 0 ? reach : Math.abs(centre - dock.hoverPos)
    property real zoom: dock.taskbar ? (mouse.containsMouse ? 1 : 0)
                                     : (dock.dragSource ? 0 : Math.max(0, 1 - Math.pow(distance / reach, 2)))
    Behavior on zoom {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    property real squeeze: mouse.pressed && !mouse.dragStarted ? 0.86 : 1
    Behavior on squeeze {
        SpringAnimation { spring: 6; damping: 0.3; epsilon: 0.005 }
    }

    // --- launching ---------------------------------------------------------
    // From the click until its first window shows up (at most 8 s), the
    // icon bounces; an app asking for attention bounces three times.
    property bool launching: false
    readonly property bool bouncing: (launching || isStartup) && !isWindow
    readonly property real bounceHeight: Math.round(dock.iconSize * (dock.taskbar ? 0.22 : 0.34))
    onIsWindowChanged: {
        if (isWindow) {
            launching = false
            indicatorPop.restart()
        }
        publishTimer.restart()
    }
    onAttentionChanged: if (attention && !bouncing) nudge.restart()
    Timer {
        id: launchTimeout
        interval: 8000
        onTriggered: task.launching = false
    }

    // --- hover pill (taskbar) ----------------------------------------------
    Rectangle {
        visible: dock.taskbar
        anchors.fill: parent
        anchors.margins: Math.round(Math.min(parent.width, parent.height) * 0.07)
        radius: Kirigami.Units.cornerRadius * 1.6
        color: Kirigami.Theme.textColor
        opacity: mouse.pressed ? 0.14 : (mouse.containsMouse ? 0.09 : (task.isActive ? 0.07 : 0))
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
    }

    // --- the icon ------------------------------------------------------------
    Item {
        id: iconBox
        width: dock.iconSize
        height: dock.iconSize
        anchors.centerIn: parent
        // Leave room under the icon for the open-app indicator.
        anchors.verticalCenterOffset: dock.vertical ? 0 : -Math.round(task.height * (dock.taskbar ? 0.04 : 0.06))
        anchors.horizontalCenterOffset: dock.vertical ? -Math.round(task.width * 0.06) : 0

        transform: [
            Translate {
                // lift a little as it grows
                y: -task.zoom * (dock.taskbar ? 2 : Math.round(dock.iconSize * 0.1))
            },
            Translate {
                id: hop
                y: 0
            }
        ]

        Kirigami.Icon {
            id: icon
            anchors.fill: parent
            source: task.model.decoration
            roundToIconSize: false
            active: mouse.containsMouse
            transformOrigin: dock.vertical ? Item.Center : Item.Bottom
            scale: task.squeeze * (1 + (dock.taskbar ? 0.06 : 0.22) * task.zoom)
        }
    }

    SequentialAnimation {
        id: bounce
        loops: Animation.Infinite
        running: task.bouncing
        NumberAnimation { target: hop; property: "y"; to: -task.bounceHeight; duration: 290; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "y"; to: 0; duration: 290; easing.type: Easing.InQuad }
        PauseAnimation { duration: 70 }
        onRunningChanged: if (!running) settle.restart()
    }
    SequentialAnimation {
        id: nudge
        loops: 3
        NumberAnimation { target: hop; property: "y"; to: -task.bounceHeight; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "y"; to: 0; duration: 260; easing.type: Easing.InQuad }
    }
    NumberAnimation {
        id: settle
        target: hop
        property: "y"
        to: 0
        duration: 160
        easing.type: Easing.OutQuad
    }

    // --- open-app indicator ------------------------------------------------
    // Dock: a dot (brighter for the app in front). Taskbar: a dash that
    // widens and takes the accent colour for the app in front.
    Rectangle {
        id: indicator
        visible: task.isWindow
        anchors.horizontalCenter: dock.vertical ? undefined : parent.horizontalCenter
        anchors.bottom: dock.vertical ? undefined : parent.bottom
        anchors.verticalCenter: dock.vertical ? parent.verticalCenter : undefined
        anchors.right: dock.vertical ? parent.right : undefined
        anchors.bottomMargin: Math.max(2, Math.round(task.height * (dock.taskbar ? 0.07 : 0.035)))
        anchors.rightMargin: 2
        readonly property real along: dock.taskbar ? (task.isActive ? Math.round(dock.iconSize * 0.5) : 6) : 5
        readonly property real across: dock.taskbar ? 3 : 5
        width: dock.vertical ? across : along
        height: dock.vertical ? along : across
        radius: Math.min(width, height) / 2
        color: dock.taskbar && task.isActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        opacity: task.isActive ? 0.95 : (task.isGroup ? 0.8 : 0.55)
        Behavior on width {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack }
        }
        Behavior on height {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack }
        }
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration }
        }
        NumberAnimation on scale {
            id: indicatorPop
            running: false
            from: 0
            to: 1
            duration: 360
            easing.type: Easing.OutBack
        }
    }

    // --- pointer -------------------------------------------------------------
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: task.name
        subText: ""
        location: Plasmoid.location
        active: !mouse.pressed && !dock.dragSource && !task.menuOpen

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            property point pressPos
            property bool dragStarted: false

            onPressed: event => {
                pressPos = Qt.point(event.x, event.y)
                dragStarted = false
                if (event.button === Qt.RightButton) {
                    task.showMenu()
                }
            }
            onPositionChanged: event => {
                if (pressed && !dragStarted && (event.buttons & Qt.LeftButton)
                        && Math.hypot(event.x - pressPos.x, event.y - pressPos.y) > Application.styleHints.startDragDistance) {
                    dragStarted = true
                    task.startDrag()
                }
            }
            onClicked: event => {
                if (dragStarted) {
                    return
                }
                if (event.button === Qt.LeftButton) {
                    task.activate()
                } else if (event.button === Qt.MiddleButton) {
                    task.newInstance()
                }
            }
        }
    }

    Accessible.name: name
    Accessible.role: Accessible.Button

    function modelIndex() {
        return tasksModel.makeModelIndex(index)
    }

    function activate() {
        if (!isWindow) {
            launching = true
            launchTimeout.restart()
            tasksModel.requestActivate(modelIndex())
            return
        }
        if (isGroup) {
            // Step through the app's windows, starting after the one in front.
            const n = model.ChildCount || 0
            let current = -1
            for (let i = 0; i < n; ++i) {
                const child = tasksModel.makeModelIndex(index, i)
                if (tasksModel.data(child, TaskManager.AbstractTasksModel.IsActive) === true) {
                    current = i
                    break
                }
            }
            tasksModel.requestActivate(tasksModel.makeModelIndex(index, (current + 1) % Math.max(1, n)))
        } else if (isActive && !model.IsMinimized) {
            tasksModel.requestToggleMinimized(modelIndex())
        } else {
            tasksModel.requestActivate(modelIndex())
        }
    }
    function newInstance() {
        launching = true
        launchTimeout.restart()
        tasksModel.requestNewInstance(modelIndex())
    }

    // --- minimise target -----------------------------------------------------
    // Tell KWin where this icon is, so minimised windows fly into it.
    function publishGeometry() {
        if (!isWindow || !task.Window.window) {
            return
        }
        const p = task.mapToGlobal(0, 0)
        const rect = Qt.rect(p.x, p.y, width, height)
        if (isGroup) {
            const n = model.ChildCount || 0
            for (let i = 0; i < n; ++i) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(index, i), rect, task)
            }
        } else {
            tasksModel.requestPublishDelegateGeometry(modelIndex(), rect, task)
        }
    }
    Timer {
        id: publishTimer
        interval: 250
        onTriggered: task.publishGeometry()
    }
    onXChanged: publishTimer.restart()
    onYChanged: publishTimer.restart()
    onWidthChanged: publishTimer.restart()
    Component.onCompleted: publishTimer.restart()
    readonly property int childCount: model.ChildCount || 0
    onChildCountChanged: publishTimer.restart()

    // --- drag out / reorder --------------------------------------------------
    // The drag carries the app's .desktop file plus a marker that makes the
    // desktop (and Files) link to it straight away, so it lands where you let
    // go instead of asking "Copy here / Link here".
    Item {
        id: dragProxy
        anchors.fill: iconBox
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.LinkAction | Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.LinkAction
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        Drag.onDragFinished: dropAction => {
            dock.dragSource = null
            tasksModel.syncLaunchers()
        }
    }
    function startDrag() {
        const file = dock.desktopFileUrl(launcherUrl)
        const data = { "application/x-verta-dock-item": String(index) }
        if (file !== "") {
            data["text/uri-list"] = file + "\r\n"
            // KDE's drop handling links bookmarks without asking.
            data["application/x-xbel"] = "<?xml version=\"1.0\"?><xbel/>"
        }
        dragProxy.Drag.mimeData = data
        dock.dragSource = task
        icon.grabToImage(result => {
            dragProxy.Drag.imageSource = result.url
            dragProxy.Drag.active = true
        }, Qt.size(dock.iconSize, dock.iconSize))
    }

    // --- right-click menu ----------------------------------------------------
    property bool menuOpen: false
    function showMenu() {
        const menu = menuComponent.createObject(task)
        const add = (props) => menuItemComponent.createObject(menu, props)

        add({ text: task.name, section: true })
        // The app's own actions ("New Private Window", "New Incognito Window"...).
        const info = dock.appInfoFor(launcherUrl)
        const actions = info ? info.actions.filter(a => a.actionId === "_kicker_jumpListAction") : []
        actions.forEach(a => {
            const item = add({ text: a.text || "", icon: a.icon || "" })
            item.clicked.connect(() => dock.triggerAppAction(launcherUrl, a))
        })
        if (actions.length > 0) {
            add({ separator: true })
        }
        if (launcherUrl.toString() !== "") {
            const open = add({ text: isWindow ? "New Window" : "Open", icon: isWindow ? "window-new" : "media-playback-start" })
            open.clicked.connect(() => isWindow ? task.newInstance() : task.activate())
            const keep = add({ text: pinned ? unkeepText : keepText, icon: pinned ? "window-unpin" : "window-pin" })
            keep.clicked.connect(() => dock.setPinned(launcherUrl, !pinned))
        }
        if (isWindow) {
            add({ separator: true })
            const quit = add({ text: isGroup ? "Quit (" + (model.ChildCount || 0) + " windows)" : "Quit", icon: "application-exit" })
            quit.clicked.connect(() => tasksModel.requestClose(modelIndex()))
        }

        menu.statusChanged.connect(() => {
            if (menu.status === PlasmaExtras.Menu.Closed) {
                task.menuOpen = false
                menu.destroy()
            }
        })
        task.menuOpen = true
        menu.openRelative()
    }
    Component {
        id: menuComponent
        PlasmaExtras.Menu {
            visualParent: task
            placement: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.TopEdge: return PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                case PlasmaCore.Types.LeftEdge: return PlasmaExtras.Menu.RightPosedTopAlignedPopup
                case PlasmaCore.Types.RightEdge: return PlasmaExtras.Menu.LeftPosedTopAlignedPopup
                default: return PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                }
            }
        }
    }
    Component {
        id: menuItemComponent
        PlasmaExtras.MenuItem {}
    }
}
