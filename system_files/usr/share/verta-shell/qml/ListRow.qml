/*
    One row in a Quick Settings list (a network, a Bluetooth device, a sound
    output): icon, name and a status line. Click to select or to expand it;
    whatever is put inside appears under it when expanded (buttons, a
    password field). The row that's in use gets an accent bar on the left.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: row
    property string iconName
    property string title
    property string subtitle
    property bool current: false       // connected / the default output
    property bool expanded: false
    property bool busy: false
    default property alias extra: extraColumn.data
    signal clicked()

    implicitHeight: column.implicitHeight
    radius: Theme.controlRadius
    color: expanded ? Theme.card : mouse.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {    // "in use" bar
        visible: row.current
        x: 0
        y: 14
        width: 3
        height: 20
        radius: 1.5
        color: Theme.accent
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        MouseArea {
            id: mouse
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            hoverEnabled: true
            onClicked: row.clicked()
            Accessible.role: Accessible.ListItem
            Accessible.name: row.title + ", " + row.subtitle

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 12
                Kirigami.Icon {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    source: row.iconName
                    isMask: true
                    color: Theme.text
                    opacity: row.busy ? 0.4 : 1
                    SequentialAnimation on opacity {
                        running: row.busy
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 500 }
                        NumberAnimation { to: 0.35; duration: 500 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: row.title
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: row.current ? Font.DemiBold : Font.Normal
                        color: Theme.text
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.subtitle
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }
            }
        }
        ColumnLayout {
            id: extraColumn
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            visible: row.expanded
            spacing: 8
        }
    }
}
