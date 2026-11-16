/*
    The Start button. On the taskbar: the Verta logo on a soft rounded pill
    that lights up on hover. In the dock: the Apps icon at full dock size,
    lifting a little on hover. Either way it squishes when pressed and springs
    back.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

MouseArea {
    id: button

    readonly property bool vertical: Plasmoid.formFactor === 3 // PlasmaCore.Types.Vertical
    property bool wasExpanded: false

    Layout.minimumWidth: vertical ? -1 : height
    Layout.maximumWidth: vertical ? -1 : height
    Layout.minimumHeight: vertical ? width : -1
    Layout.maximumHeight: vertical ? width : -1

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    onPressed: wasExpanded = start.expanded
    onClicked: toggle(wasExpanded)

    function toggle(was) {
        if (start.launchpad) {
            start.toggleLaunchpad()
        } else {
            start.expanded = !was
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            toggle(start.expanded)
            event.accepted = true
        }
    }
    Accessible.name: start.launchpad ? "Apps" : "Start"
    Accessible.role: Accessible.Button

    // Hover / open pill.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Math.min(parent.width, parent.height) * 0.1)
        radius: Kirigami.Units.cornerRadius * 1.6
        color: Kirigami.Theme.textColor
        visible: !start.launchpad
        opacity: start.expanded ? 0.14 : (button.containsMouse ? 0.09 : 0)
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
    }

    Kirigami.Icon {
        id: logo
        anchors.centerIn: parent
        width: Math.round(Math.min(parent.width, parent.height) * (start.launchpad ? 0.8 : 0.56))
        height: width
        source: Plasmoid.icon
        active: button.containsMouse

        // Squish on press, spring back with a little overshoot on release;
        // in the dock it also grows a touch under the pointer.
        scale: button.pressed ? 0.8 : (start.launchpad && button.containsMouse ? 1.08 : 1)
        Behavior on scale {
            SpringAnimation { spring: 5; damping: 0.28; epsilon: 0.005 }
        }
    }
}
