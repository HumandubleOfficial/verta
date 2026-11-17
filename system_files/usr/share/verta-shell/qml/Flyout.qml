/*
    A flyout above the taskbar (Quick Settings, the calendar): an acrylic
    panel that rises into place and closes on Esc or a click anywhere else.
    Put the content inside; it fills the panel.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.layershell as LayerShell

Window {
    id: flyout

    required property QtObject shell
    property bool shown: false
    property int panelWidth: 360
    property int panelHeight: 400
    readonly property int gap: 12
    default property alias content: inner.data
    signal opened()

    width: panelWidth + gap
    height: panelHeight + gap
    visible: false
    color: "transparent"

    LayerShell.Window.scope: "verta-flyout"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    function open(targetScreen) {
        if (targetScreen) {
            screen = targetScreen
            catcher.screen = targetScreen
        }
        catcher.visible = true
        visible = true
        shown = true
        frame.opacity = 0
        slide.y = 30
        openAnimation.restart()
        frame.forceActiveFocus()
        opened()
        Qt.callLater(updateBlur)
    }
    function close() {
        if (shown) {
            shown = false
            closeAnimation.restart()
        }
    }
    function toggle(targetScreen) {
        shown ? close() : open(targetScreen)
    }
    function updateBlur() {
        Host.setBlur(flyout, 0, 0, panelWidth, panelHeight, Theme.radius)
    }
    onPanelHeightChanged: if (visible) Qt.callLater(updateBlur)

    ParallelAnimation {
        id: openAnimation
        NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.normal + 60; easing.type: Easing.OutQuint }
        NumberAnimation { target: frame; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnimation
        ParallelAnimation {
            NumberAnimation { target: slide; property: "y"; to: 24; duration: Theme.fast; easing.type: Easing.InCubic }
            NumberAnimation { target: frame; property: "opacity"; to: 0; duration: Theme.fast; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                flyout.visible = false
                catcher.visible = false
            }
        }
    }

    property Window catcher: Window {
        id: catcher
        visible: false
        color: "transparent"
        LayerShell.Window.scope: "verta-flyout-catcher"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                                   | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: flyout.close()
        }
    }

    Item {
        id: frame
        width: flyout.panelWidth
        height: flyout.panelHeight
        transform: Translate { id: slide }
        focus: true
        Keys.onEscapePressed: flyout.close()

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: Theme.flyout
            border.width: 1
            border.color: Theme.stroke
        }
        Item {
            id: inner
            anchors.fill: parent
        }
    }
}
