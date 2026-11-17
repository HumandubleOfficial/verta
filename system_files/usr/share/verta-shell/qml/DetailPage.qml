/*
    A Quick Settings sub-page (Wi-Fi, Bluetooth, Sound output): a back arrow
    and title, an optional on/off switch, the list, and links to settings at
    the bottom.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

Item {
    id: page
    property string title
    property bool hasSwitch: false
    property bool switchOn: false
    property string placeholder        // shown instead of the list, e.g. "Wi-Fi is off"
    property var links: []             // [{ text, program, args }]
    default property alias content: body.data
    signal back()
    signal switched()
    signal linkActivated()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 16
            Layout.topMargin: 10
            Layout.bottomMargin: 6
            spacing: 6
            IconButton {
                iconName: "go-previous"
                onClicked: page.back()
                Accessible.name: "Back"
            }
            Text {
                Layout.fillWidth: true
                text: page.title
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Switch {
                visible: page.hasSwitch
                checked: page.switchOn
                onToggled: page.switched()
                Accessible.name: page.title
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            clip: true
            visible: page.placeholder === ""
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.placeholder !== ""
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
            text: page.placeholder
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.textDim
        }

        Repeater {
            model: page.links
            MouseArea {
                id: link
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                hoverEnabled: true
                Accessible.role: Accessible.Link
                Accessible.name: modelData.text
                onClicked: {
                    Host.run(modelData.program, modelData.args || [])
                    page.linkActivated()
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: link.modelData.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.underline: link.containsMouse
                    color: Theme.accent
                }
            }
        }
        Item { Layout.preferredHeight: 6 }
    }
}
