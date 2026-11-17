/*
    The taskbar, Windows 11 style: a full-width acrylic bar along the bottom
    of the screen. In the middle: Start, Search, Task View and your pinned and
    open apps. On the right: network and sound, the clock, and a thin strip
    that shows the desktop.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtCore
import org.kde.layershell as LayerShell
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Window {
    id: bar

    required property var targetScreen
    required property QtObject shell

    screen: targetScreen
    width: targetScreen.width
    height: Theme.taskbarHeight
    visible: true
    color: "transparent"

    LayerShell.Window.scope: "verta-taskbar"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: height
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    function updateBlur() {
        Host.setBlur(bar, 0, 0, width, height, 0)
    }
    onWidthChanged: updateBlur()
    onVisibleChanged: if (visible) Qt.callLater(updateBlur)
    Component.onCompleted: Qt.callLater(updateBlur)

    // Pinned apps, the same on every screen.
    Settings {
        id: pins
        category: "Taskbar"
        property var launchers: [
            "applications:org.kde.dolphin.desktop",
            "applications:org.mozilla.firefox.desktop",
            "applications:steam.desktop",
            "applications:com.heroicgameslauncher.hgl.desktop",
            "applications:org.kde.discover.desktop",
            "applications:org.kde.konsole.desktop",
            "applications:org.verta.Settings.desktop"
        ]
    }

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: appsModel
        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: bar.targetScreen ? Qt.rect(bar.targetScreen.virtualX, bar.targetScreen.virtualY,
                                                   bar.targetScreen.width, bar.targetScreen.height) : Qt.rect(0, 0, 0, 0)
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByScreen: false
        filterByActivity: true
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        hideActivatedLaunchers: true
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false

        onLauncherListChanged: {
            if (JSON.stringify(launcherList) !== JSON.stringify(pins.launchers)) {
                pins.launchers = launcherList
            }
        }
        Component.onCompleted: launcherList = pins.launchers
    }

    // Acrylic: KWin blurs what's behind, this tints it.
    Rectangle {
        anchors.fill: parent
        color: Theme.taskbar
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.stroke
        }
    }

    // Start, Search, Task View and the apps, centred as a group.
    Row {
        id: middle
        anchors.centerIn: parent
        spacing: 4

        BarButton {
            iconName: "verta-logo"
            mask: false
            iconSize: 26
            lit: bar.openHere(bar.shell.startMenu)
            tipText: "Start"
            onClicked: bar.shell.toggleStart(bar.screen, false)
            Accessible.name: "Start"
        }
        BarButton {
            iconName: "search"
            onClicked: bar.shell.toggleStart(bar.screen, true)
            tipText: "Search"
            Accessible.name: "Search"
        }
        BarButton {
            iconName: "window-duplicate"
            onClicked: bar.shell.kwinShortcut("Overview")
            tipText: "Task View"
            Accessible.name: "Task View"
        }

        ListView {
            id: tasks
            width: count * (44 + spacing)
            height: 44
            anchors.verticalCenter: parent.verticalCenter
            orientation: ListView.Horizontal
            interactive: false
            spacing: 4
            model: appsModel
            delegate: TaskButton {
                id: taskButton
                tasksModel: appsModel
                onContainsMouseChanged: bar.hover(taskButton, taskButton.model.display || "")
                onPressedChanged: if (pressed) tip.close()
            }

            // A new app grows into place, a closed one shrinks away.
            add: Transition {
                NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
            }
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0.5; duration: Theme.fast }
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast }
            }
            displaced: Transition {
                NumberAnimation { properties: "x"; duration: Theme.normal; easing.type: Easing.OutCubic }
                NumberAnimation { properties: "scale,opacity"; to: 1; duration: Theme.fast }
            }
        }
    }

    // Network and sound, the clock, show desktop.
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Tray: Steam, Discord and other apps running in the background.
        Repeater {
            model: Tray
            delegate: MouseArea {
                id: trayIcon
                required property int index
                required property string icon
                required property string status
                required property bool hasMenu
                required property bool itemIsMenu
                required property string toolTip
                visible: status !== "Passive"
                width: visible ? 32 : 0
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                Hover { area: trayIcon }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    source: trayIcon.icon
                    scale: trayIcon.pressed ? 0.84 : 1
                    Behavior on scale { NumberAnimation { duration: 110 } }
                }
                onClicked: mouse => {
                    const p = trayIcon.mapToGlobal(width / 2, 0)
                    if (mouse.button === Qt.MiddleButton) {
                        Tray.secondaryActivate(index, p.x, p.y)
                    } else if (mouse.button === Qt.LeftButton && !(itemIsMenu && hasMenu)) {
                        Tray.activate(index, p.x, p.y)
                    } else if (hasMenu) {
                        bar.showTrayMenu(index, trayIcon)
                    } else {
                        Tray.contextMenu(index, p.x, p.y)
                    }
                }
                onWheel: wheel => Tray.scroll(index, wheel.angleDelta.y)
                onContainsMouseChanged: bar.hover(trayIcon, toolTip)
                onPressedChanged: if (pressed) tip.close()
            }
        }

        MouseArea {
            id: status
            width: statusRow.implicitWidth + 20
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            onClicked: bar.shell.toggleFlyout(bar.shell.quickSettings, bar.screen)
            onWheel: wheel => {
                const qs = bar.shell.quickSettings
                qs.setVolume(Math.max(0, Math.min(100, qs.volume + (wheel.angleDelta.y > 0 ? 2 : -2))))
            }
            Accessible.name: "Quick settings"

            Hover {
                area: status
                lit: bar.openHere(bar.shell.quickSettings)
            }
            onContainsMouseChanged: {
                const qs = bar.shell.quickSettings
                const net = qs.network !== "" ? qs.network : "Not connected"
                bar.hover(status, net + "
Volume: " + (qs.muted ? "muted" : qs.volume + "%"))
            }
            onPressedChanged: if (pressed) tip.close()
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: 10
                Loader {
                    width: 16; height: 16
                    source: "NetworkIcon.qml"
                }
                Kirigami.Icon {
                    readonly property var qs: bar.shell.quickSettings
                    width: 16; height: 16
                    source: qs.muted || qs.volume === 0 ? "audio-volume-muted"
                          : qs.volume < 34 ? "audio-volume-low"
                          : qs.volume < 67 ? "audio-volume-medium" : "audio-volume-high"
                    isMask: true
                    color: Theme.text
                }
            }
        }

        MouseArea {
            id: clockButton
            property date now: new Date()
            width: clockColumn.implicitWidth + 20
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            onClicked: bar.shell.toggleFlyout(bar.shell.calendar, bar.screen)
            Accessible.name: clockTime.text + " " + clockDate.text

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockButton.now = new Date()
            }
            Hover {
                area: clockButton
                lit: bar.openHere(bar.shell.calendar)
            }
            onContainsMouseChanged: bar.hover(clockButton, clockButton.now.toLocaleDateString(Qt.locale(), Locale.LongFormat))
            onPressedChanged: if (pressed) tip.close()
            Column {
                id: clockColumn
                anchors.centerIn: parent
                Text {
                    id: clockTime
                    anchors.right: parent.right
                    text: clockButton.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text
                }
                Text {
                    id: clockDate
                    anchors.right: parent.right
                    text: clockButton.now.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text
                }
            }
        }

        // The sliver at the very right edge shows the desktop.
        MouseArea {
            id: showDesktop
            width: 12
            height: bar.height
            hoverEnabled: true
            onClicked: bar.shell.kwinShortcut("Show Desktop")
            onContainsMouseChanged: bar.hover(showDesktop, "Show desktop")
            Accessible.name: "Show desktop"
            Rectangle {
                width: 1
                height: parent.height * 0.4
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textFaint
                opacity: showDesktop.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            }
        }
    }

    // Whether a flyout or the Start menu is open on this taskbar's screen.
    function openHere(window) {
        return window.shown && !!window.screen && window.screen.name === bar.screen.name
    }

    // One tooltip for the whole taskbar. It waits a moment, then appears
    // above whatever the pointer rests on, and goes when it moves away.
    function hover(item, text) {
        if (item.containsMouse && text !== "" && !item.pressed) {
            tip.close()
            tip.parent = item
            tip.text = text
            tip.open()
        } else if (tip.parent === item) {
            tip.close()
        }
    }
    QQC2.ToolTip {
        id: tip
        popupType: QQC2.Popup.Window
        delay: 600
        timeout: 8000
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: -height - 10
        leftPadding: 8
        rightPadding: 8
        topPadding: 6
        bottomPadding: 6
        contentItem: Text {
            text: tip.text
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
        }
        background: Rectangle {
            radius: Theme.controlRadius
            color: Theme.dark ? "#2b2b2b" : "#f9f9f9"
            border.width: 1
            border.color: Theme.stroke
        }
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.fast }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 80 }
        }
    }

    // A tray app's menu, built fresh each time from what the app sends.
    QQC2.Menu {
        id: trayMenu
        popupType: QQC2.Popup.Window
    }
    Component {
        id: trayMenuItem
        QQC2.MenuItem {
            property int row
            property int itemId
            onTriggered: Tray.menuClicked(row, itemId)
        }
    }
    Component {
        id: traySeparator
        QQC2.MenuSeparator {}
    }
    Component {
        id: traySubMenu
        QQC2.Menu {
            popupType: QQC2.Popup.Window
        }
    }
    function fillTrayMenu(menu, nodes, row) {
        for (const node of nodes) {
            if (node.separator) {
                menu.addItem(traySeparator.createObject(menu))
            } else if (node.children.length > 0) {
                const sub = traySubMenu.createObject(menu, { title: node.label })
                fillTrayMenu(sub, node.children, row)
                menu.addMenu(sub)
            } else {
                menu.addItem(trayMenuItem.createObject(menu, {
                    text: node.label, enabled: node.enabled, checkable: node.checkable,
                    checked: node.checked, row: row, itemId: node.id
                }))
            }
        }
    }
    function showTrayMenu(row, item) {
        while (trayMenu.count > 0) {
            const old = trayMenu.takeItem(0)
            if (old) {
                old.destroy()
            }
        }
        fillTrayMenu(trayMenu, Tray.menu(row), row)
        if (trayMenu.count > 0) {
            trayMenu.popup(item, 0, -trayMenu.implicitHeight - 6)
        }
    }

    // A rounded hover/press highlight behind a taskbar control.
    component Hover: Rectangle {
        required property MouseArea area
        property bool lit: false
        anchors.fill: parent
        radius: Theme.controlRadius
        color: area.pressed ? Theme.pressed : (area.containsMouse || lit) ? Theme.hover : "transparent"
        border.width: lit || area.containsMouse ? 1 : 0
        border.color: Theme.stroke
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }

    // Start, Search and Task View.
    component BarButton: MouseArea {
        id: button
        property string iconName
        property bool mask: true
        property bool lit: false
        property int iconSize: 22
        property string tipText
        width: 44
        height: 40
        anchors.verticalCenter: parent.verticalCenter
        hoverEnabled: true

        Hover { area: button; lit: button.lit }
        onContainsMouseChanged: bar.hover(button, button.tipText)
        onPressedChanged: if (pressed) tip.close()
        Kirigami.Icon {
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            source: button.iconName
            isMask: button.mask
            color: Theme.text
            // Pressed icons sink a little and spring back.
            scale: button.pressed ? 0.84 : 1
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        }
    }
}
