import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Sound"
    subtitle: "Volume, speakers, headphones and microphones."

    property int volume: win.backend.volume()
    property bool muted: win.backend.muted()

    Section {
        title: "Output"

        SettingRow {
            title: win.backend.outputDevice() || "Speakers"
            subtitle: "Playing sound through this device"
            tileIcon: "audio-speakers-symbolic"; tileFallback: "audio-speakers"
            tileTop: "#fb7185"; tileBottom: "#e11d48"
        }

        SettingRow {
            title: "Volume"
            Kirigami.Icon {
                source: "audio-volume-low-symbolic"; fallback: "audio-volume-low"
                implicitWidth: 16; implicitHeight: 16; opacity: 0.6
            }
            QQC2.Slider {
                Layout.preferredWidth: 300
                from: 0
                to: 100
                stepSize: 1
                value: page.volume
                enabled: !page.muted
                onMoved: {
                    page.volume = Math.round(value)
                    win.backend.setVolume(page.volume)
                }
            }
            Kirigami.Icon {
                source: "audio-volume-high-symbolic"; fallback: "audio-volume-high"
                implicitWidth: 16; implicitHeight: 16; opacity: 0.6
            }
            QQC2.Label {
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                text: page.volume + "%"
                opacity: 0.7
            }
        }

        SettingRow {
            title: "Mute"
            QQC2.Switch {
                checked: page.muted
                onToggled: {
                    page.muted = checked
                    win.backend.setMuted(checked)
                }
            }
        }
    }

    Section {
        footer: "Verta runs PipeWire with a small audio buffer for low latency in games."
        SettingRow {
            title: "Devices, microphones & app volumes"
            subtitle: "Choose outputs and inputs, set volume per app."
            tileIcon: "audio-card-symbolic"; tileFallback: "audio-card"
            tileTop: "#f472b6"; tileBottom: "#be185d"
            clickable: true
            onClicked: win.backend.openKcm("kcm_pulseaudio")
        }
    }
}
