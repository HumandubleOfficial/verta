/*
    Quick Settings, Windows 11 style: opens from the network and sound icons
    on the taskbar. Toggles for Wi-Fi, Bluetooth, Game mode (performance
    power profile), Night light, Do not disturb and Dark mode; a volume
    slider (the speaker mutes); what's playing; and a way into Settings.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris

Flyout {
    id: qs

    panelWidth: 360
    panelHeight: content.implicitHeight + 32 + footer.height

    property bool hasWifi: false
    property bool wifiOn: false
    property string network: ""
    property int volume: 0
    property bool muted: false
    property string profile: ""
    property bool nightLight: false
    property bool darkMode: true
    readonly property bool hasBluetooth: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational

    NotificationManager.Settings {
        id: notificationSettings
    }
    readonly property bool dnd: {
        const until = notificationSettings.notificationsInhibitedUntil
        return (until && !isNaN(until.getTime()) && Date.now() < until.getTime())
            || notificationSettings.notificationsInhibitedByApplication
    }
    Mpris.Mpris2Model {
        id: players
    }
    readonly property var player: players.currentPlayer
    readonly property bool hasMedia: player ? (player.playbackStatus > Mpris.PlaybackStatus.Stopped && (player.track || "") !== "") : false

    onOpened: refresh()
    Component.onCompleted: refresh()

    // The taskbar's speaker icon follows volume changes made elsewhere.
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: qs.readVolume()
    }
    function readVolume() {
        Host.sh("wpctl get-volume @DEFAULT_AUDIO_SINK@", out => {
            const m = out.match(/Volume:\s*([\d.]+)/)
            if (m) qs.volume = Math.round(parseFloat(m[1]) * 100)
            qs.muted = out.indexOf("[MUTED]") >= 0
        })
    }

    function refresh() {
        readVolume()
        Host.sh("nmcli -t -f TYPE,STATE,CONNECTION device", out => {
            let wifi = false, name = ""
            out.split("\n").forEach(line => {
                const f = line.split(":")
                if (f[0] === "wifi") wifi = true
                if (f[1] === "connected" && name === "" && (f[0] === "wifi" || f[0] === "ethernet")) {
                    name = f.slice(2).join(":")
                }
            })
            qs.hasWifi = wifi
            qs.network = name
        })
        Host.sh("nmcli radio wifi", out => { qs.wifiOn = out === "enabled" })
        Host.sh("busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile", out => {
            const m = out.match(/"([^"]+)"/)
            qs.profile = m ? m[1] : ""
        })
        Host.sh("kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default org.verta.desktop", out => {
            qs.darkMode = out !== "org.verta.light"
        })
        Host.sh("kreadconfig6 --file kwinrc --group NightColor --key Active --default false", out => {
            qs.nightLight = out === "true"
        })
    }
    Timer {
        id: refreshSoon
        interval: 1200
        onTriggered: qs.refresh()
    }

    function toggleWifi() {
        wifiOn = !wifiOn
        Host.sh("nmcli radio wifi " + (wifiOn ? "on" : "off"), () => refreshSoon.restart())
    }
    function toggleBluetooth() {
        BluezQt.Manager.bluetoothBlocked = btOn
        if (!BluezQt.Manager.bluetoothBlocked && BluezQt.Manager.usableAdapter) {
            BluezQt.Manager.usableAdapter.powered = true
        }
    }
    function toggleGameMode() {
        const next = profile === "performance" ? "balanced" : "performance"
        profile = next
        Host.sh("busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s " + next,
                () => refreshSoon.restart())
    }
    function toggleNightLight() {
        nightLight = !nightLight
        Host.sh("kwriteconfig6 --file kwinrc --group NightColor --key Active " + (nightLight ? "true" : "false")
                + " && kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant"
                + " && dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure")
    }
    function toggleDnd() {
        if (dnd) {
            notificationSettings.notificationsInhibitedUntil = undefined
            notificationSettings.revokeApplicationInhibitions()
        } else {
            const until = new Date()
            until.setFullYear(until.getFullYear() + 1)
            notificationSettings.notificationsInhibitedUntil = until
        }
        notificationSettings.save()
    }
    function toggleDarkMode() {
        darkMode = !darkMode
        Host.sh("plasma-apply-lookandfeel --apply " + (darkMode ? "org.verta.desktop" : "org.verta.light"))
    }
    function setVolume(percent) {
        volume = percent
        Host.sh("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + percent + "%")
        if (muted && percent > 0) {
            muted = false
            Host.sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
        }
    }
    function toggleMute() {
        muted = !muted
        Host.sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (muted ? "1" : "0"))
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 16

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 14
            columnSpacing: 12

            QuickToggle {
                visible: qs.hasWifi
                iconName: qs.wifiOn ? "network-wireless-signal-excellent" : "network-wireless-disconnected"
                label: qs.wifiOn && qs.network !== "" ? qs.network : "Wi-Fi"
                checked: qs.wifiOn
                onToggled: qs.toggleWifi()
            }
            QuickToggle {
                visible: qs.hasBluetooth
                iconName: qs.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                label: "Bluetooth"
                checked: qs.btOn
                onToggled: qs.toggleBluetooth()
            }
            QuickToggle {
                visible: qs.profile !== ""
                iconName: "input-gamepad"
                label: "Game mode"
                checked: qs.profile === "performance"
                onToggled: qs.toggleGameMode()
            }
            QuickToggle {
                iconName: "redshift-status-on"
                label: "Night light"
                checked: qs.nightLight
                onToggled: qs.toggleNightLight()
            }
            QuickToggle {
                iconName: "notifications-disabled"
                label: "Do not disturb"
                checked: qs.dnd
                onToggled: qs.toggleDnd()
            }
            QuickToggle {
                iconName: "weather-clear-night"
                label: "Dark mode"
                checked: qs.darkMode
                onToggled: qs.toggleDarkMode()
            }
        }

        // Volume.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MouseArea {
                id: speaker
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                hoverEnabled: true
                onClicked: qs.toggleMute()
                Accessible.name: qs.muted ? "Unmute" : "Mute"
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.controlRadius
                    color: speaker.containsMouse ? Theme.hover : "transparent"
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    isMask: true
                    color: Theme.text
                    source: qs.muted || qs.volume === 0 ? "audio-volume-muted"
                          : qs.volume < 34 ? "audio-volume-low"
                          : qs.volume < 67 ? "audio-volume-medium" : "audio-volume-high"
                }
            }
            QQC2.Slider {
                id: volumeSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 1
                value: qs.volume
                onMoved: qs.setVolume(Math.round(value))
                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: volumeSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.45)
                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                }
                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    width: 20; height: 20
                    radius: 10
                    color: Theme.dark ? "#454545" : "#ffffff"
                    border.width: 1
                    border.color: Theme.stroke
                    Rectangle {
                        anchors.centerIn: parent
                        width: volumeSlider.pressed ? 10 : volumeSlider.hovered ? 14 : 12
                        height: width
                        radius: width / 2
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: Theme.fast } }
                    }
                }
            }
            Text {
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
                text: qs.volume
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textDim
            }
        }

        // What's playing.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            visible: qs.hasMedia
            radius: Theme.controlRadius
            color: Theme.card
            border.width: 1
            border.color: Theme.stroke
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                Image {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    source: qs.player ? qs.player.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: qs.player ? qs.player.track : ""
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: qs.player ? qs.player.artist : ""
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
                MediaButton { iconName: "media-skip-backward"; onClicked: qs.player.Previous() }
                MediaButton {
                    iconName: qs.player && qs.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "media-playback-pause" : "media-playback-start"
                    onClicked: qs.player.PlayPause()
                }
                MediaButton { iconName: "media-skip-forward"; onClicked: qs.player.Next() }
            }
        }

    }

    // Footer strip: what you're connected to, and Settings.
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1       // inside the panel's outline
        height: 48
        color: Theme.footer
        bottomLeftRadius: Theme.radius - 1
        bottomRightRadius: Theme.radius - 1
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.divider
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            Kirigami.Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: qs.network !== "" ? "network-connect" : "network-disconnect"
                isMask: true
                color: Theme.textDim
            }
            Text {
                Layout.fillWidth: true
                text: qs.network !== "" ? qs.network : "Not connected"
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textDim
            }
            MouseArea {
                id: settingsButton
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                hoverEnabled: true
                Accessible.name: "Settings"
                onClicked: {
                    Host.run("verta-settings", [])
                    qs.close()
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.controlRadius
                    color: settingsButton.containsMouse ? Theme.hover : "transparent"
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 16; height: 16
                    source: "configure"
                    isMask: true
                    color: Theme.text
                }
            }
        }
    }

    // A Windows 11 quick action: a rounded button that fills with the
    // accent colour when on, its name underneath.
    component QuickToggle: ColumnLayout {
        id: toggle
        property string iconName
        property string label
        property bool checked: false
        signal toggled()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6

        MouseArea {
            id: toggleButton
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            hoverEnabled: true
            onClicked: toggle.toggled()
            Accessible.name: toggle.label
            Accessible.role: Accessible.CheckBox
            Accessible.checked: toggle.checked
            Rectangle {
                anchors.fill: parent
                radius: Theme.controlRadius
                color: toggle.checked ? (toggleButton.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                     : toggleButton.containsMouse ? Theme.hover : Theme.card
                border.width: toggle.checked ? 0 : 1
                border.color: Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18; height: 18
                source: toggle.iconName
                isMask: true
                color: toggle.checked ? Theme.accentText : Theme.text
                scale: toggleButton.pressed ? 0.86 : 1
                Behavior on scale { NumberAnimation { duration: 110 } }
            }
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: toggle.label
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text
        }
    }

    component MediaButton: MouseArea {
        id: mediaButton
        property string iconName
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        hoverEnabled: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: mediaButton.containsMouse ? Theme.hover : "transparent"
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 16; height: 16
            source: mediaButton.iconName
            isMask: true
            color: Theme.text
        }
    }
}
