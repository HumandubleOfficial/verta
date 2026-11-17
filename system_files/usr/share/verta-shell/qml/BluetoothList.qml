/*
    Paired Bluetooth devices for Quick Settings (BluezQt): headsets,
    controllers, mice. Click one to connect or disconnect it; its battery
    shows when the device reports one. New devices are added with KDE's
    Bluetooth wizard (the link under the list).

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.bluezqt as BluezQt

ListView {
    id: list
    property string expanded: ""
    property int pairedCount: 0

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

    model: BluezQt.DevicesModel {}

    function countPaired() {
        let n = 0
        for (let i = 0; i < contentItem.children.length; i++) {
            const c = contentItem.children[i]
            if (c.device && c.device.paired) n++
        }
        pairedCount = n
    }
    onCountChanged: Qt.callLater(countPaired)

    delegate: ListRow {
        id: dev
        required property var model
        readonly property var device: model.Device
        property bool working: false
        readonly property bool paired: device ? device.paired : false
        onPairedChanged: Qt.callLater(list.countPaired)

        width: list.width
        visible: paired
        height: paired ? implicitHeight : 0
        iconName: device && device.icon ? device.icon : "preferences-system-bluetooth"
        title: device ? device.name : ""
        subtitle: {
            if (!device) return ""
            if (working) return device.connected ? "Disconnecting…" : "Connecting…"
            let s = device.connected ? "Connected" : "Paired"
            if (device.connected && device.battery) s += " · " + device.battery.percentage + "% battery"
            return s
        }
        current: device ? device.connected : false
        busy: working
        expanded: device ? list.expanded === device.address : false
        onClicked: list.expanded = expanded ? "" : device.address

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            PillButton {
                text: dev.current ? "Disconnect" : "Connect"
                accent: !dev.current
                enabled: !dev.working
                onClicked: {
                    dev.working = true
                    const call = dev.current ? dev.device.disconnectFromDevice() : dev.device.connectToDevice()
                    if (call) {
                        call.finished.connect(() => { dev.working = false })
                    } else {
                        dev.working = false
                    }
                    list.expanded = ""
                }
            }
        }
    }
}
