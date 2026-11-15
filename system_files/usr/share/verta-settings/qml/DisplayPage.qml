import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: "Display"
    subtitle: "Screens, resolution, refresh rate, scaling and colour."

    Section {
        SettingRow {
            title: "Resolution, refresh rate & scale"
            subtitle: "Arrange screens, choose 144 Hz and up, turn on HDR and variable refresh rate (FreeSync / G-SYNC)."
            tileIcon: "video-display-symbolic"; tileFallback: "monitor"
            tileTop: "#38bdf8"; tileBottom: "#0284c7"
            clickable: true
            onClicked: win.backend.openKcm("kcm_kscreen")
        }
        SettingRow {
            title: "Night Light"
            subtitle: "Warmer colours in the evening, easier on the eyes."
            tileIcon: "weather-clear-night-symbolic"; tileFallback: "weather-clear-night"
            tileTop: "#fbbf24"; tileBottom: "#ea580c"
            clickable: true
            onClicked: win.backend.openKcm("kcm_nightlight")
        }
    }

    Section {
        title: "Power"
        SettingRow {
            title: "Screen off & sleep"
            subtitle: "When to dim, turn off the screen and sleep."
            tileIcon: "system-suspend-symbolic"; tileFallback: "system-suspend"
            tileTop: "#a78bfa"; tileBottom: "#6d28d9"
            clickable: true
            onClicked: win.backend.openKcm("kcm_powerdevilprofilesconfig")
        }
        SettingRow {
            title: "Lock screen"
            subtitle: "Lock automatically and when waking up."
            tileIcon: "system-lock-screen-symbolic"; tileFallback: "system-lock-screen"
            tileTop: "#94a3b8"; tileBottom: "#475569"
            clickable: true
            onClicked: win.backend.openKcm("kcm_screenlocker")
        }
    }

    Section {
        title: "Effects"
        SettingRow {
            title: "Desktop effects"
            subtitle: "Blur, window animations, rounded corners and more."
            tileIcon: "preferences-desktop-effects-symbolic"; tileFallback: "preferences-desktop-effects"
            tileTop: "#f472b6"; tileBottom: "#db2777"
            clickable: true
            onClicked: win.backend.openKcm("kcm_kwin_effects")
        }
    }
}
