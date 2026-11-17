/*
    Wi-Fi networks for Quick Settings, through Plasma's NetworkManager
    library (the same one Plasma's network applet uses). Click a network to
    connect: saved and open networks connect straight away; for a new
    secured one a password field opens. The one you're on can be
    disconnected. Wrong passwords and enterprise networks are handled by
    KDE's network prompt.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.networkmanagement as PlasmaNM

ListView {
    id: list

    required property QtObject handler
    property string expanded: ""
    property string error: ""

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

    model: PlasmaNM.AppletProxyModel {
        sourceModel: PlasmaNM.NetworkModel {}
    }

    Connections {
        target: list.handler
        function onConnectionActivationFailed(connectionPath, message) {
            list.error = message
        }
    }

    header: Text {
        width: list.width
        visible: list.error !== ""
        height: visible ? implicitHeight + 10 : 0
        leftPadding: 14
        rightPadding: 14
        wrapMode: Text.Wrap
        text: list.error
        font.family: Theme.font
        font.pixelSize: 12
        color: "#e81123"
    }

    delegate: ListRow {
        id: net
        required property var model
        readonly property bool wifi: model.Type === PlasmaNM.Enums.Wireless
        readonly property bool active: model.ConnectionState === PlasmaNM.Enums.Activated
        readonly property bool secured: model.SecurityType !== PlasmaNM.Enums.NoneSecurity
                                        && model.SecurityType !== PlasmaNM.Enums.OWE
        // A saved network, or one NetworkManager can join without asking.
        readonly property bool needsPassword: !model.Uuid && wifi
                                              && (model.SecurityType === PlasmaNM.Enums.StaticWep
                                                  || model.SecurityType === PlasmaNM.Enums.WpaPsk
                                                  || model.SecurityType === PlasmaNM.Enums.Wpa2Psk
                                                  || model.SecurityType === PlasmaNM.Enums.SAE)
        property bool askPassword: false

        width: list.width
        visible: wifi
        height: wifi ? implicitHeight : 0
        iconName: model.ConnectionIcon
        title: model.ItemUniqueName
        subtitle: active ? (secured ? "Connected, secured" : "Connected")
                : busy ? "Connecting…"
                : secured ? "Secured" : "Open"
        current: active
        busy: model.ConnectionState === PlasmaNM.Enums.Activating
        expanded: list.expanded === model.ItemUniqueName

        onClicked: {
            list.error = ""
            askPassword = false
            list.expanded = expanded ? "" : model.ItemUniqueName
        }
        onExpandedChanged: if (!expanded) password.text = ""

        function connect() {
            list.error = ""
            if (needsPassword && password.text === "") {
                askPassword = true
                password.forceActiveFocus()
            } else if (needsPassword) {
                list.handler.addAndActivateConnection(model.DevicePath, model.SpecificPath, password.text)
                list.expanded = ""
            } else if (!model.Uuid) {
                list.handler.addAndActivateConnection(model.DevicePath, model.SpecificPath)
                list.expanded = ""
            } else {
                list.handler.activateConnection(model.ConnectionPath, model.DevicePath, model.SpecificPath)
                list.expanded = ""
            }
        }

        Text {
            visible: net.askPassword
            text: "Enter the network security key"
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.textDim
        }
        QQC2.TextField {
            id: password
            Layout.fillWidth: true
            visible: net.askPassword
            echoMode: TextInput.Password
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            onAccepted: net.connect()
            Keys.onEscapePressed: list.expanded = ""
            background: Rectangle {
                implicitHeight: 32
                radius: Theme.controlRadius
                color: Theme.field
                border.width: 1
                border.color: Theme.stroke
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: password.activeFocus ? 2 : 1
                    color: password.activeFocus ? Theme.accent : Theme.textFaint
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PillButton {
                visible: net.askPassword
                text: "Cancel"
                onClicked: list.expanded = ""
            }
            PillButton {
                text: net.active ? "Disconnect" : "Connect"
                accent: !net.active
                enabled: !net.askPassword || password.text.length >= 8 || net.model.SecurityType === PlasmaNM.Enums.StaticWep
                onClicked: {
                    if (net.active) {
                        list.handler.deactivateConnection(net.model.ConnectionPath, net.model.DevicePath)
                        list.expanded = ""
                    } else {
                        net.connect()
                    }
                }
            }
        }
    }
}
