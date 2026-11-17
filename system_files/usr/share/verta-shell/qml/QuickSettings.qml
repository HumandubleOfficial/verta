/*
    Quick Settings, Windows 11 style: opens from the network, sound and
    battery icons on the taskbar (or Windows key + A).

    Toggles for Wi-Fi, Bluetooth, Game mode (performance power profile),
    Night light, Do not disturb and Dark mode. Wi-Fi and Bluetooth have a ›
    that opens their list (pick a network and type its password, connect a
    headset); the volume slider has one for the sound output. Brightness on
    laptops and screens that support it, what's playing, and the battery and
    Settings along the bottom.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.plasma.private.brightnesscontrolplugin as BrightnessControl

Flyout {
    id: qs

    panelWidth: 360
    panelHeight: (page === "" ? content.implicitHeight + 32 : 440) + footer.height

    // "" (the toggles), "wifi", "bluetooth" or "sound".
    property string page: ""
    onShownChanged: if (!shown) page = ""
    onPageChanged: {
        pageIn.restart()
        if (page === "wifi") nmHandler.requestScan()
    }

    // Network (Plasma's NetworkManager library).
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.EnabledConnections { id: nmEnabled }
    PlasmaNM.AvailableDevices { id: nmDevices }
    PlasmaNM.NetworkStatus {
        id: nmStatus
        onActiveConnectionsChanged: qs.readNetwork()
    }
    readonly property bool hasWifi: nmDevices.wirelessDeviceAvailable
    readonly property bool wifiOn: nmEnabled.wirelessEnabled
    property string network: ""

    // Bluetooth.
    readonly property bool hasBluetooth: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: BluezQt.Manager.bluetoothOperational

    // Sound (wpctl talks to PipeWire directly).
    property int volume: 0
    property bool muted: false

    // Battery (laptops, handhelds): -1 when there is none.
    property int battery: -1
    property bool charging: false
    readonly property string batteryIcon: {
        if (battery < 0) return ""
        const level = ("00" + Math.min(100, Math.round(battery / 10) * 10)).slice(-3)
        return "battery-" + level + (charging ? "-charging" : "")
    }

    // Screen brightness (laptops, and monitors that allow it over DDC/CI).
    BrightnessControl.ScreenBrightnessControl {
        id: screenBrightness
        Component.onCompleted: {
            try { isSilent = true } catch (e) {}   // no on-screen pop-up while dragging
        }
    }

    property string profile: ""
    property bool nightLight: false
    property bool darkMode: true

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

    // The taskbar's speaker and battery icons follow changes made elsewhere.
    Timer {
        interval: 4000
        running: true
        repeat: true
        property int ticks: 0
        onTriggered: {
            qs.readVolume()
            if (++ticks % 8 === 0) qs.readBattery()
        }
    }
    function readVolume() {
        Host.sh("wpctl get-volume @DEFAULT_AUDIO_SINK@", out => {
            const m = out.match(/Volume:\s*([\d.]+)/)
            if (m) qs.volume = Math.round(parseFloat(m[1]) * 100)
            qs.muted = out.indexOf("[MUTED]") >= 0
        })
    }
    function readBattery() {
        Host.sh("for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] && cat \"$b/capacity\" \"$b/status\" && break; done", out => {
            const lines = out.split("\n")
            const level = parseInt(lines[0])
            qs.battery = isNaN(level) ? -1 : level
            qs.charging = lines.length > 1 && (lines[1] === "Charging" || lines[1] === "Full")
        })
    }
    function readNetwork() {
        Host.sh("nmcli -t -f TYPE,STATE,CONNECTION device", out => {
            let name = ""
            out.split("\n").forEach(line => {
                const f = line.split(":")
                if (f[1] === "connected" && name === "" && (f[0] === "wifi" || f[0] === "ethernet")) {
                    name = f.slice(2).join(":")
                }
            })
            qs.network = name
        })
    }

    function refresh() {
        readVolume()
        readBattery()
        readNetwork()
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
        nmHandler.enableWireless(!wifiOn)
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

    // Pages slide in a little from the side they come from.
    ParallelAnimation {
        id: pageIn
        NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageShift; property: "x"; from: qs.page === "" ? -16 : 16; to: 0; duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    Item {
        id: pages
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        transform: Translate { id: pageShift }

        ColumnLayout {
            id: content
            visible: qs.page === ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 14

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
                    hasMore: true
                    onToggled: qs.toggleWifi()
                    onMore: qs.page = "wifi"
                }
                QuickToggle {
                    visible: qs.hasBluetooth
                    iconName: qs.btOn ? "network-bluetooth" : "network-bluetooth-inactive"
                    label: "Bluetooth"
                    checked: qs.btOn
                    hasMore: true
                    onToggled: qs.toggleBluetooth()
                    onMore: qs.page = "bluetooth"
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

            // Brightness, one slider per screen that allows it.
            Repeater {
                model: screenBrightness.isBrightnessAvailable ? screenBrightness.displays : null
                SliderRow {
                    required property string displayName
                    required property string label
                    required property int brightness
                    required property int maxBrightness
                    Layout.fillWidth: true
                    iconName: "brightness-high"
                    iconLabel: "Brightness" + (label !== "" ? ", " + label : "")
                    value: maxBrightness > 0 ? brightness * 100 / maxBrightness : 0
                    minimum: 1
                    onMoved: v => screenBrightness.setBrightness(displayName, Math.max(1, Math.round(v * maxBrightness / 100)))
                }
            }

            SliderRow {
                Layout.fillWidth: true
                iconName: qs.muted || qs.volume === 0 ? "audio-volume-muted"
                        : qs.volume < 34 ? "audio-volume-low"
                        : qs.volume < 67 ? "audio-volume-medium" : "audio-volume-high"
                iconLabel: qs.muted ? "Unmute" : "Mute"
                value: qs.volume
                hasMore: true
                moreLabel: "Choose a sound output"
                onMoved: v => qs.setVolume(v)
                onIconClicked: qs.toggleMute()
                onMore: qs.page = "sound"
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
                    IconButton { iconName: "media-skip-backward"; onClicked: qs.player.Previous(); Accessible.name: "Previous" }
                    IconButton {
                        readonly property bool playing: qs.player && qs.player.playbackStatus === Mpris.PlaybackStatus.Playing
                        iconName: playing ? "media-playback-pause" : "media-playback-start"
                        onClicked: qs.player.PlayPause()
                        Accessible.name: playing ? "Pause" : "Play"
                    }
                    IconButton { iconName: "media-skip-forward"; onClicked: qs.player.Next(); Accessible.name: "Next" }
                }
            }
        }

        DetailPage {
            anchors.fill: parent
            visible: qs.page === "wifi"
            title: "Wi-Fi"
            hasSwitch: true
            switchOn: qs.wifiOn
            placeholder: qs.wifiOn ? "" : "Wi-Fi is turned off"
            links: [{ text: "More Wi-Fi settings", program: "kcmshell6", args: ["kcm_networkmanagement"] }]
            onBack: qs.page = ""
            onSwitched: qs.toggleWifi()
            onLinkActivated: qs.close()
            WifiList {
                anchors.fill: parent
                handler: nmHandler
            }
        }

        DetailPage {
            anchors.fill: parent
            visible: qs.page === "bluetooth"
            title: "Bluetooth"
            hasSwitch: true
            switchOn: qs.btOn
            placeholder: !qs.btOn ? "Bluetooth is turned off"
                       : btList.pairedCount === 0 ? "No devices yet. Add one to see it here." : ""
            links: [
                { text: "Add a device", program: "bluedevil-wizard", args: [] },
                { text: "More Bluetooth settings", program: "kcmshell6", args: ["kcm_bluetooth"] }
            ]
            onBack: qs.page = ""
            onSwitched: qs.toggleBluetooth()
            onLinkActivated: qs.close()
            BluetoothList {
                id: btList
                anchors.fill: parent
            }
        }

        DetailPage {
            anchors.fill: parent
            visible: qs.page === "sound"
            title: "Sound output"
            placeholder: soundList.count === 0 ? "No sound outputs found" : ""
            links: [{ text: "More sound settings", program: "verta-settings", args: ["--page", "sound"] }]
            onBack: qs.page = ""
            onLinkActivated: qs.close()
            SoundList {
                id: soundList
                anchors.fill: parent
                onChosen: Qt.callLater(qs.readVolume)
            }
        }
    }

    // Footer strip: battery (or the network), and Settings.
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
                source: qs.battery >= 0 ? qs.batteryIcon : qs.network !== "" ? "network-connect" : "network-disconnect"
                isMask: true
                color: Theme.textDim
            }
            Text {
                Layout.fillWidth: true
                text: qs.battery >= 0 ? qs.battery + "%" + (qs.charging ? " · charging" : "")
                    : qs.network !== "" ? qs.network : "Not connected"
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textDim
            }
            IconButton {
                iconName: "configure"
                Accessible.name: "Settings"
                onClicked: {
                    Host.run("verta-settings", [])
                    qs.close()
                }
            }
        }
    }

    // A Windows 11 quick action: a rounded button that fills with the
    // accent colour when on, its name underneath. With hasMore, the right
    // part of the button is a › that opens a list instead.
    component QuickToggle: ColumnLayout {
        id: toggle
        property string iconName
        property string label
        property bool checked: false
        property bool hasMore: false
        signal toggled()
        signal more()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            Rectangle {
                anchors.fill: parent
                radius: Theme.controlRadius
                color: toggle.checked ? Theme.accent : Theme.card
                border.width: toggle.checked ? 0 : 1
                border.color: Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
            MouseArea {
                id: toggleButton
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: toggle.hasMore ? parent.width - moreButton.width : parent.width
                hoverEnabled: true
                onClicked: toggle.toggled()
                Accessible.name: toggle.label
                Accessible.role: Accessible.CheckBox
                Accessible.checked: toggle.checked
                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: Theme.controlRadius
                    bottomLeftRadius: Theme.controlRadius
                    topRightRadius: toggle.hasMore ? 0 : Theme.controlRadius
                    bottomRightRadius: toggle.hasMore ? 0 : Theme.controlRadius
                    color: toggleButton.containsMouse ? (toggle.checked ? Qt.rgba(1, 1, 1, 0.12) : Theme.hover) : "transparent"
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
            MouseArea {
                id: moreButton
                visible: toggle.hasMore
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 30
                hoverEnabled: true
                onClicked: toggle.more()
                Accessible.name: toggle.label + " list"
                Accessible.role: Accessible.Button
                Rectangle {
                    anchors.fill: parent
                    topRightRadius: Theme.controlRadius
                    bottomRightRadius: Theme.controlRadius
                    color: moreButton.containsMouse ? (toggle.checked ? Qt.rgba(1, 1, 1, 0.12) : Theme.hover) : "transparent"
                }
                Rectangle {   // divider between the two halves
                    width: 1
                    height: parent.height
                    color: toggle.checked ? Qt.rgba(0, 0, 0, 0.18) : Theme.stroke
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    source: "go-next"
                    isMask: true
                    color: toggle.checked ? Theme.accentText : Theme.text
                }
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
}
