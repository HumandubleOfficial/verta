/*
    An on/off switch, Windows 11 style: an outlined pill that fills with the
    accent colour when on, its knob sliding across.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

MouseArea {
    id: sw
    property bool checked: false
    signal toggled()
    implicitWidth: 40
    implicitHeight: 20
    hoverEnabled: true
    onClicked: toggled()
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : "transparent"
        border.width: sw.checked ? 0 : 1
        border.color: Theme.textDim
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Rectangle {
            width: sw.pressed ? 16 : sw.containsMouse ? 14 : 12
            height: sw.pressed ? 12 : width
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - 4 : 4
            color: sw.checked ? Theme.accentText : Theme.textDim
            Behavior on x { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }
}
