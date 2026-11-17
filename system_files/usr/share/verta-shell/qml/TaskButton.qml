/*
    One app on the taskbar: pinned, open, or both.

    Click: open it, switch to it, or minimise it if it's in front (an app
    with several windows steps through them). Middle-click: new window.
    Right-click: the app's own actions, pin or unpin, close.

    A short dash under an open app; a wider accent-coloured one under the app
    in front; orange when an app needs your attention.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

MouseArea {
    id: task

    required property var model
    required property int index
    required property QtObject tasksModel

    readonly property bool isWindow: model.IsWindow === true
    readonly property bool isActive: model.IsActive === true
    readonly property bool starting: model.IsStartup === true
    readonly property bool attention: model.IsDemandingAttention === true
    readonly property var launcherUrl: model.LauncherUrlWithoutIcon

    width: 44
    height: 40
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    Accessible.name: model.display || ""
    Accessible.role: Accessible.Button

    function modelIndex() {
        return tasksModel.makeModelIndex(index)
    }

    function activate() {
        if (!isWindow) {
            tasksModel.requestNewInstance(modelIndex())
            launchHop.restart()
        } else if (model.IsGroupParent) {
            // Step through the app's windows.
            const count = model.ChildCount || 0
            let next = 0
            for (let i = 0; i < count; ++i) {
                if (tasksModel.data(tasksModel.makeModelIndex(index, i), TaskManager.AbstractTasksModel.IsActive)) {
                    next = (i + 1) % count
                    break
                }
            }
            tasksModel.requestActivate(tasksModel.makeModelIndex(index, next))
        } else if (isActive) {
            tasksModel.requestToggleMinimized(modelIndex())
        } else {
            tasksModel.requestActivate(modelIndex())
        }
    }

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
            activate()
        } else if (mouse.button === Qt.MiddleButton) {
            tasksModel.requestNewInstance(modelIndex())
            launchHop.restart()
        } else {
            menu.popup(task, 0, -menu.implicitHeight - 6)
        }
    }

    // Where minimised windows fly to (Verta Minimise).
    function publishGeometry() {
        if (!isWindow || !Window.window) {
            return
        }
        const p = task.mapToGlobal(0, 0)
        tasksModel.requestPublishDelegateGeometry(modelIndex(), Qt.rect(p.x, p.y, width, height), task)
    }
    onXChanged: geometryTimer.restart()
    onIsWindowChanged: geometryTimer.restart()
    Timer {
        id: geometryTimer
        interval: 250
        onTriggered: task.publishGeometry()
    }

    // Background: hover, the app in front, or asking for attention.
    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: task.attention ? Qt.rgba(1, 0.55, 0.1, 0.32)
             : task.pressed ? Theme.pressed
             : task.containsMouse ? Theme.hover
             : task.isActive ? Theme.selected
             : "transparent"
        border.width: task.isActive || task.containsMouse || task.attention ? 1 : 0
        border.color: Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        width: 24
        height: 24
        source: task.model.decoration
        // Pressed: sinks a little; launching: a quick hop.
        scale: task.pressed ? 0.84 : 1
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        transform: Translate { id: hop }
    }
    SequentialAnimation {
        id: launchHop
        NumberAnimation { target: hop; property: "y"; to: -6; duration: 140; easing.type: Easing.OutQuad }
        NumberAnimation { target: hop; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBounce }
    }
    // Keep hopping while the app takes a moment to start.
    Timer {
        running: task.starting && !task.isWindow
        interval: 700
        repeat: true
        onTriggered: launchHop.restart()
    }

    // Running indicator.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        height: 3
        radius: 1.5
        width: task.isActive ? 16 : (task.isWindow ? 6 : 0)
        visible: width > 0
        color: task.attention ? "#ff9a2e" : task.isActive ? Theme.accent : Theme.textFaint
        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    QQC2.Menu {
        id: menu
        popupType: QQC2.Popup.Window

        QQC2.MenuItem {
            text: task.model.AppName || task.model.display || ""
            icon.name: ""
            enabled: true
            onTriggered: {
                tasksModel.requestNewInstance(task.modelIndex())
                launchHop.restart()
            }
        }
        QQC2.MenuSeparator {}
        QQC2.MenuItem {
            readonly property bool pinned: task.launcherUrl && task.launcherUrl.toString() !== ""
                                            && tasksModel.launcherPosition(task.launcherUrl) !== -1
            text: pinned ? "Unpin from taskbar" : "Pin to taskbar"
            visible: task.launcherUrl && task.launcherUrl.toString() !== ""
            height: visible ? implicitHeight : 0
            onTriggered: pinned ? tasksModel.requestRemoveLauncher(task.launcherUrl)
                                : tasksModel.requestAddLauncher(task.launcherUrl)
        }
        QQC2.MenuItem {
            text: (task.model.ChildCount || 0) > 1 ? "Close all windows" : "Close window"
            visible: task.isWindow
            height: visible ? implicitHeight : 0
            onTriggered: tasksModel.requestClose(task.modelIndex())
        }
    }
}
