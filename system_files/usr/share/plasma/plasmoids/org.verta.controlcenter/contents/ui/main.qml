/*
    Control Center: Verta's quick controls, opened from the switches icon in
    the menu bar.

      +--------------------------+  +-------------------+
      | (o) Wi-Fi        Home    |  | (o) Dark Mode     |
      | (o) Bluetooth    On      |  +-------------------+
      | (o) Game Mode    Ready   |  | (o) Do Not Disturb|
      +--------------------------+  +-------------------+
      | Sound   [####=========================]        |
      +-------------------------------------------------+
      | [art] Song - Artist                  |<  >  >|  |   (only while something plays)
      +-------------------------------------------------+
      | Night Light | Screenshot | Lock | Settings      |
      +-------------------------------------------------+

    Wi-Fi uses NetworkManager (nmcli), sound PipeWire (wpctl), Game Mode the
    power profile (performance), Do Not Disturb Plasma's notification
    settings, and Now Playing any media player (MPRIS).

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.bluezqt as BluezQt
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: cc

    Plasmoid.icon: "verta-controlcenter-symbolic"
    toolTipMainText: "Control Center"
    toolTipSubText: ""
    preferredRepresentation: compactRepresentation

    // --- state, read from the system each time the panel opens -----------
    property bool hasWifi: false
    property bool wifiOn: false
    property string network: ""            // name of the active connection
    property string networkType: ""        // "wifi", "ethernet", ...
    property int volume: 50
    property bool muted: false
    property string profile: ""            // power profile
    property bool darkMode: true
    property bool nightLight: false

    readonly property bool btAvailable: BluezQt.Manager.adapters.length > 0
    readonly property bool btOn: btAvailable && !BluezQt.Manager.bluetoothBlocked
    readonly property bool btConnected: {
        const devices = BluezQt.Manager.devices
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].connected) return true
        }
        return false
    }

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
    readonly property bool playing: player ? player.playbackStatus === Mpris.PlaybackStatus.Playing : false
    readonly property bool hasMedia: player ? (player.playbackStatus > Mpris.PlaybackStatus.Stopped && (player.track || "") !== "") : false

    // --- running commands ------------------------------------------------
    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        property var callbacks: ({})
        onNewData: (source, data) => {
            const cb = callbacks[source]
            delete callbacks[source]
            disconnectSource(source)
            if (cb) {
                cb((data["stdout"] || "").trim(), data["exit code"])
            }
        }
    }
    function run(command, callback) {
        // The same command twice in a row would share one source; add a marker.
        const source = command + " #" + Math.random().toString(36).slice(2, 8)
        if (callback) {
            shell.callbacks[source] = callback
        }
        shell.connectSource(source)
    }

    function refresh() {
        run("nmcli -t -f TYPE,STATE,CONNECTION device", out => {
            let wifi = false, name = "", type = ""
            out.split("\n").forEach(line => {
                const f = line.split(":")
                if (f[0] === "wifi") wifi = true
                if (f[1] === "connected" && name === "" && (f[0] === "wifi" || f[0] === "ethernet")) {
                    name = f.slice(2).join(":"); type = f[0]
                }
            })
            cc.hasWifi = wifi; cc.network = name; cc.networkType = type
        })
        run("nmcli radio wifi", out => { cc.wifiOn = out === "enabled" })
        run("wpctl get-volume @DEFAULT_AUDIO_SINK@", out => {
            const m = out.match(/Volume:\s*([\d.]+)/)
            if (m) cc.volume = Math.round(parseFloat(m[1]) * 100)
            cc.muted = out.indexOf("[MUTED]") >= 0
        })
        run("busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile", out => {
            const m = out.match(/"([^"]+)"/)
            cc.profile = m ? m[1] : ""
        })
        run("kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage --default org.verta.desktop", out => {
            cc.darkMode = out !== "org.verta.light"
        })
        run("kreadconfig6 --file kwinrc --group NightColor --key Active --default false", out => {
            cc.nightLight = out === "true"
        })
    }

    function toggleWifi() {
        cc.wifiOn = !cc.wifiOn
        run("nmcli radio wifi " + (cc.wifiOn ? "on" : "off"), () => refreshSoon.restart())
    }
    function toggleBluetooth() {
        BluezQt.Manager.bluetoothBlocked = cc.btOn
        if (!BluezQt.Manager.bluetoothBlocked && BluezQt.Manager.usableAdapter) {
            BluezQt.Manager.usableAdapter.powered = true
        }
    }
    function toggleGameMode() {
        const next = cc.profile === "performance" ? "balanced" : "performance"
        cc.profile = next
        run("busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s " + next,
            () => refreshSoon.restart())
    }
    function toggleDarkMode() {
        cc.darkMode = !cc.darkMode
        run("plasma-apply-lookandfeel --apply " + (cc.darkMode ? "org.verta.desktop" : "org.verta.light"))
    }
    function toggleDnd() {
        if (cc.dnd) {
            notificationSettings.notificationsInhibitedUntil = undefined
            notificationSettings.revokeApplicationInhibitions()
        } else {
            const until = new Date()
            until.setFullYear(until.getFullYear() + 1)
            notificationSettings.notificationsInhibitedUntil = until
        }
        notificationSettings.save()
    }
    function toggleNightLight() {
        cc.nightLight = !cc.nightLight
        run("kwriteconfig6 --file kwinrc --group NightColor --key Active " + (cc.nightLight ? "true" : "false")
            + " && kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant"
            + " && dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure")
    }
    function setVolume(percent) {
        cc.volume = percent
        run("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + percent + "%")
        if (cc.muted && percent > 0) {
            cc.muted = false
            run("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0")
        }
    }
    function toggleMute() {
        cc.muted = !cc.muted
        run("wpctl set-mute @DEFAULT_AUDIO_SINK@ " + (cc.muted ? "1" : "0"))
    }
    function open(command) {
        cc.expanded = false
        run(command)
    }

    Timer {
        id: refreshSoon
        interval: 1200
        onTriggered: cc.refresh()
    }
    onExpandedChanged: if (cc.expanded) cc.refresh()
    Component.onCompleted: refresh()

    compactRepresentation: MouseArea {
        id: button
        hoverEnabled: true
        Layout.minimumWidth: Math.round(height * 1.3)
        Layout.maximumWidth: Layout.minimumWidth
        property bool wasExpanded: false
        onPressed: wasExpanded = cc.expanded
        onClicked: cc.expanded = !wasExpanded
        Accessible.name: "Control Center"
        Accessible.role: Accessible.ButtonMenu

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: Math.round(parent.height * 0.12)
            anchors.bottomMargin: anchors.topMargin
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: cc.expanded ? 0.16 : (button.containsMouse ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: "verta-controlcenter-symbolic"
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }

    fullRepresentation: Item {
        id: panel
        readonly property real u: Kirigami.Units.gridUnit
        readonly property real gap: Math.round(u * 0.6)

        Layout.preferredWidth: Math.round(u * 21)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.preferredHeight: column.implicitHeight + gap * 2
        Layout.minimumHeight: Layout.preferredHeight
        Layout.maximumHeight: Layout.preferredHeight

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: panel.gap
            spacing: panel.gap

            // ---- connections + modes ----------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: panel.gap

                Card {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 11
                    Layout.fillHeight: true
                    implicitHeight: connections.implicitHeight + Math.round(panel.u * 1.1)
                    ColumnLayout {
                        id: connections
                        anchors.fill: parent
                        anchors.margins: Math.round(panel.u * 0.55)
                        spacing: Math.round(panel.u * 0.35)
                        Toggle {
                            title: cc.hasWifi ? "Wi‑Fi" : "Network"
                            subtitle: cc.hasWifi ? (!cc.wifiOn ? "Off" : (cc.networkType === "wifi" ? cc.network : "Not connected"))
                                                 : (cc.network !== "" ? "Wired" : "Not connected")
                            icon: cc.hasWifi ? (cc.wifiOn ? "network-wireless-symbolic" : "network-wireless-disconnected-symbolic")
                                             : "network-wired-symbolic"
                            on: cc.hasWifi ? cc.wifiOn : cc.network !== ""
                            onToggled: cc.hasWifi ? cc.toggleWifi() : cc.open("systemsettings kcm_networkmanagement")
                        }
                        Toggle {
                            title: "Bluetooth"
                            subtitle: !cc.btAvailable ? "Not available" : (!cc.btOn ? "Off" : (cc.btConnected ? "Connected" : "On"))
                            icon: cc.btOn ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
                            on: cc.btOn
                            enabled: cc.btAvailable
                            onToggled: cc.toggleBluetooth()
                        }
                        Toggle {
                            title: "Game Mode"
                            subtitle: cc.profile === "performance" ? "Full power" : (cc.profile === "" ? "Not available" : "Off")
                            icon: "input-gaming-symbolic"
                            fallback: "input-gamepad"
                            on: cc.profile === "performance"
                            enabled: cc.profile !== ""
                            onToggled: cc.toggleGameMode()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 9
                    Layout.fillHeight: true
                    spacing: panel.gap
                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Math.round(panel.u * 3.3)
                        Toggle {
                            anchors.fill: parent
                            anchors.margins: Math.round(panel.u * 0.55)
                            title: "Dark Mode"
                            subtitle: cc.darkMode ? "On" : "Off"
                            icon: "weather-clear-night-symbolic"
                            on: cc.darkMode
                            onToggled: cc.toggleDarkMode()
                        }
                    }
                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Math.round(panel.u * 3.3)
                        Toggle {
                            anchors.fill: parent
                            anchors.margins: Math.round(panel.u * 0.55)
                            title: "Do Not Disturb"
                            subtitle: cc.dnd ? "On" : "Off"
                            icon: cc.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
                            on: cc.dnd
                            accent: "#8b5cf6"
                            onToggled: cc.toggleDnd()
                        }
                    }
                }
            }

            // ---- sound ----------------------------------------------------------
            Card {
                Layout.fillWidth: true
                implicitHeight: soundColumn.implicitHeight + Math.round(panel.u * 1.1)
                ColumnLayout {
                    id: soundColumn
                    anchors.fill: parent
                    anchors.margins: Math.round(panel.u * 0.55)
                    spacing: Math.round(panel.u * 0.35)
                    PlasmaComponents3.Label {
                        text: "Sound"
                        font.weight: Font.DemiBold
                    }
                    BigSlider {
                        Layout.fillWidth: true
                        value: cc.muted ? 0 : cc.volume
                        icon: cc.muted || cc.volume === 0 ? "audio-volume-muted-symbolic"
                            : cc.volume < 34 ? "audio-volume-low-symbolic"
                            : cc.volume < 67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
                        onMoved: percent => cc.setVolume(percent)
                        onIconClicked: cc.toggleMute()
                    }
                }
            }

            // ---- now playing (only while a player has something) --------------
            Card {
                Layout.fillWidth: true
                visible: cc.hasMedia
                implicitHeight: Math.round(panel.u * 3.6)
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(panel.u * 0.55)
                    spacing: Math.round(panel.u * 0.6)

                    Rectangle {
                        Layout.preferredWidth: Math.round(panel.u * 2.5)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: Kirigami.Units.cornerRadius * 1.4
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: cc.player ? (cc.player.artUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: "media-album-cover"
                            visible: !cc.player || !cc.player.artUrl
                            opacity: 0.6
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: cc.player ? (cc.player.track || "") : ""
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: cc.player ? (cc.player.artist || cc.player.identity || "") : ""
                            opacity: 0.7
                            elide: Text.ElideRight
                        }
                    }
                    RoundIcon {
                        icon: "media-skip-backward-symbolic"
                        enabled: cc.player ? cc.player.canGoPrevious : false
                        onClicked: cc.player.Previous()
                    }
                    RoundIcon {
                        icon: cc.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                        big: true
                        onClicked: cc.playing ? cc.player.Pause() : cc.player.Play()
                    }
                    RoundIcon {
                        icon: "media-skip-forward-symbolic"
                        enabled: cc.player ? cc.player.canGoNext : false
                        onClicked: cc.player.Next()
                    }
                }
            }

            // ---- shortcuts ------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: panel.gap
                QuickTile {
                    title: "Night Light"
                    icon: "redshift-status-on"
                    fallback: "weather-clear-night"
                    on: cc.nightLight
                    accent: "#f59e0b"
                    onClicked: cc.toggleNightLight()
                }
                QuickTile {
                    title: "Screenshot"
                    icon: "camera-photo-symbolic"
                    onClicked: cc.open("spectacle --region")
                }
                QuickTile {
                    title: "Lock"
                    icon: "system-lock-screen-symbolic"
                    onClicked: cc.open("loginctl lock-session")
                }
                QuickTile {
                    title: "Settings"
                    icon: "configure-symbolic"
                    onClicked: cc.open("verta-settings")
                }
            }
        }
    }

    // ================= building blocks =================

    // A liquid-glass platter: a lighter pane of glass on the glass panel, a
    // soft sheen over its top half and a rim that catches the light.
    component Card: Rectangle {
        id: card
        property bool hovered: false
        property color tint: "transparent"      // filled with a colour (a tile that is on)
        readonly property bool darkTheme: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
        radius: Math.round(Kirigami.Units.gridUnit * 0.9)
        color: tint.a > 0 ? tint
             : darkTheme ? Qt.rgba(1, 1, 1, hovered ? 0.12 : 0.075)
                         : Qt.rgba(1, 1, 1, hovered ? 0.62 : 0.45)
        Behavior on color { ColorAnimation { duration: 160 } }
        implicitHeight: Kirigami.Units.gridUnit * 3
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, card.darkTheme ? 0.08 : 0.30) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
        GlassRim { radius: card.radius }
    }

    // Liquid-glass rim: a hairline that shines where the light hits (top left),
    // fades along the sides and glints again, softer, at the bottom right.
    component GlassRim: Item {
        id: rimItem
        property real radius: 0
        property real strength: 1
        anchors.fill: parent
        Rectangle {
            id: ring
            anchors.fill: parent
            radius: rimItem.radius
            color: "transparent"
            border.width: 1
            border.color: "white"
            visible: false
        }
        GE.LinearGradient {
            anchors.fill: parent
            source: ring
            start: Qt.point(0, 0)
            end: Qt.point(width, height)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.42 * rimItem.strength) }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.10 * rimItem.strength) }
                GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.05 * rimItem.strength) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.24 * rimItem.strength) }
            }
        }
    }

    // A round switch button with a title and a status line beside it.
    component Toggle: MouseArea {
        id: toggle
        property string title
        property string subtitle
        property string icon
        property string fallback: "unknown"
        property bool on: false
        property color accent: Kirigami.Theme.highlightColor
        signal toggled()
        implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.1)
        Layout.fillWidth: true
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggled()
        opacity: enabled ? 1 : 0.45
        Accessible.name: title
        Accessible.description: subtitle
        Accessible.role: Accessible.CheckBox
        Accessible.checked: on

        RowLayout {
            anchors.fill: parent
            spacing: Math.round(Kirigami.Units.gridUnit * 0.5)

            Rectangle {
                id: disc
                Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * 1.75)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: toggle.on ? toggle.accent : Qt.alpha(Kirigami.Theme.textColor, toggle.containsMouse ? 0.18 : 0.12)
                Behavior on color { ColorAnimation { duration: 160 } }
                scale: toggle.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                GlassRim { radius: disc.radius; strength: toggle.on ? 0.9 : 0.6 }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    source: toggle.icon
                    fallback: toggle.fallback
                    isMask: true
                    color: toggle.on ? "white" : Kirigami.Theme.textColor
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: toggle.title
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: toggle.subtitle
                    visible: text !== ""
                    opacity: 0.65
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                }
            }
        }
    }

    // A wide, rounded slider: the filled part grows from the left, the icon
    // sits inside the track (click it to mute), drag or scroll to change.
    component BigSlider: Item {
        id: slider
        property int value: 50
        property string icon
        signal moved(int percent)
        signal iconClicked()
        implicitHeight: Math.round(Kirigami.Units.gridUnit * 1.6)
        Accessible.role: Accessible.Slider
        Accessible.name: "Volume"

        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            clip: true
            Rectangle {
                id: fill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(track.height, track.width * slider.value / 100)
                radius: track.radius
                color: Kirigami.Theme.textColor
                opacity: 0.88
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            GlassRim { radius: track.radius; strength: 0.6 }
        }
        // knob: white, lifted by a soft shadow
        Kirigami.ShadowedRectangle {
            x: fill.width - width
            width: track.height
            height: track.height
            radius: width / 2
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.08)
            shadow.size: 8
            shadow.yOffset: 1
            shadow.color: Qt.rgba(0, 0, 0, 0.35)
            scale: drag.pressed ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        Kirigami.Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round((track.height - width) / 2)
            width: Kirigami.Units.iconSizes.small
            height: width
            source: slider.icon
            isMask: true
            color: Kirigami.Theme.backgroundColor
            z: 2
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            preventStealing: true
            property bool onIcon: false
            function percentAt(x) {
                return Math.round(Math.max(0, Math.min(1, (x - track.height / 2) / (width - track.height))) * 100)
            }
            onPressed: mouse => {
                onIcon = mouse.x < track.height
                if (!onIcon) slider.moved(percentAt(mouse.x))
            }
            onPositionChanged: mouse => {
                if (pressed && !onIcon) slider.moved(percentAt(mouse.x))
            }
            onClicked: if (onIcon) slider.iconClicked()
            onWheel: wheel => slider.moved(Math.max(0, Math.min(100, slider.value + (wheel.angleDelta.y > 0 ? 5 : -5))))
        }
    }

    // Square shortcut tile with an icon and a caption under it.
    component QuickTile: MouseArea {
        id: sc
        property string title
        property string icon
        property string fallback: ""
        property bool on: false
        property color accent: Kirigami.Theme.highlightColor
        Layout.fillWidth: true
        implicitHeight: Math.round(Kirigami.Units.gridUnit * 3.6)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.name: title
        Accessible.role: Accessible.Button

        Card {
            anchors.fill: parent
            hovered: sc.containsMouse
            tint: sc.on ? Qt.alpha(sc.accent, 0.85) : "transparent"
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Math.round(Kirigami.Units.gridUnit * 0.3)
            scale: sc.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Layout.preferredWidth
                source: sc.icon
                fallback: sc.fallback
                isMask: true
                color: sc.on ? "white" : Kirigami.Theme.textColor
            }
            PlasmaComponents3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: sc.title
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: sc.on ? "white" : Kirigami.Theme.textColor
            }
        }
    }

    // Small round icon button (media controls).
    component RoundIcon: MouseArea {
        id: ri
        property string icon
        property bool big: false
        Layout.preferredWidth: Math.round(Kirigami.Units.gridUnit * (big ? 2 : 1.6))
        Layout.preferredHeight: Layout.preferredWidth
        hoverEnabled: true
        opacity: enabled ? 1 : 0.4
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Kirigami.Theme.textColor
            opacity: ri.pressed ? 0.18 : (ri.containsMouse ? 0.1 : 0)
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: ri.big ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.small
            height: width
            source: ri.icon
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }
}
