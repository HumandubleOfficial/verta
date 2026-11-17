/*
    A small square button with a symbolic icon (back, settings, mute, ...).

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

MouseArea {
    id: button
    property string iconName
    property int iconSize: 16
    implicitWidth: 32
    implicitHeight: 32
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight
    hoverEnabled: true
    Accessible.role: Accessible.Button

    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: button.pressed ? Theme.pressed : button.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        source: button.iconName
        isMask: true
        color: Theme.text
        opacity: button.enabled ? 1 : 0.4
    }
}
