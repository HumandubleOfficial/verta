/*
    A text button: Connect, Disconnect, ... Accent-filled for the main action.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

MouseArea {
    id: button
    property string text
    property bool accent: false
    implicitWidth: Math.max(96, label.implicitWidth + 28)
    implicitHeight: 32
    hoverEnabled: true
    Accessible.name: text
    Accessible.role: Accessible.Button

    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: button.accent
            ? (button.pressed ? Qt.darker(Theme.accent, 1.12) : button.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
            : (button.pressed ? Theme.pressed : button.containsMouse ? Theme.hover : Theme.card)
        border.width: button.accent ? 0 : 1
        border.color: Theme.stroke
        opacity: button.enabled ? 1 : 0.5
    }
    Text {
        id: label
        anchors.centerIn: parent
        text: button.text
        font.family: Theme.font
        font.pixelSize: 13
        color: button.accent ? Theme.accentText : Theme.text
    }
}
