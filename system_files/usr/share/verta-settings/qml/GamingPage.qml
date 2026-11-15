import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Gaming & Performance"
    subtitle: "Tune Verta for the games you play."

    property string cpu: win.backend.cpuMode()
    property string power: win.backend.powerProfile()

    Section {
        title: "Performance"
        footer: "The CPU scheduler (sched-ext LAVD) decides which program runs when. Gaming favours the game in the foreground; Auto adapts on its own."

        ChoiceRow {
            title: "CPU scheduler"
            subtitle: page.cpu === "" ? "Not available right now" : page.cpu === "off" ? "Off: using the kernel's default scheduler" : ""
            options: ["Auto", "Gaming", "Low latency", "Power save"]
            keys: ["auto", "gaming", "lowlatency", "powersave"]
            current: page.cpu
            onPicked: key => {
                page.cpu = key
                win.backend.setCpuMode(key)
            }
        }

        ChoiceRow {
            visible: page.power !== ""
            title: "Power mode"
            options: ["Power saver", "Balanced", "Performance"]
            keys: ["power-saver", "balanced", "performance"]
            current: page.power
            onPicked: key => {
                page.power = key
                win.backend.setPowerProfile(key)
            }
        }
    }

    Section {
        title: "In games"

        SettingRow {
            title: "Performance overlay in every game"
            subtitle: "FPS, frame time and CPU/GPU load (MangoHud). Starts after you sign out and back in; Right Shift + F12 hides it."
            QQC2.Switch {
                checked: win.backend.mangohud()
                onToggled: win.backend.setMangohud(checked)
            }
        }
        SettingRow {
            title: "Allow tearing in fullscreen games"
            subtitle: "Lowest input latency. Games that use V-Sync are not affected."
            QQC2.Switch {
                checked: win.backend.tearing()
                onToggled: win.backend.setTearing(checked)
            }
        }
    }

    Section {
        title: "Tools"
        footer: "Tip: in Steam, put  gamemoderun %command%  in a game's launch options for extra CPU priority, or  gamescope -f -- %command%  for upscaling."

        SettingRow {
            title: "Proton & Wine versions"
            subtitle: "Install Proton-GE for better game compatibility (ProtonUp-Qt)."
            icon: "net.davidotek.pupgui2"
            clickable: true
            external: true
            onClicked: win.backend.launch(["flatpak", "run", "net.davidotek.pupgui2"])
        }
        SettingRow {
            title: "Overlay & sharpening"
            subtitle: "Customise the overlay and vkBasalt post-processing (GOverlay)."
            icon: "io.github.benjamimgois.goverlay"
            clickable: true
            external: true
            onClicked: win.backend.launch(["goverlay"])
        }
        SettingRow {
            title: "Graphics card control"
            subtitle: "Fan curves, clocks and power limits (CoreCtrl, mainly AMD)."
            icon: "corectrl"
            clickable: true
            external: true
            onClicked: win.backend.launch(["corectrl"])
        }
    }

    Connections {
        target: win.backend
        function onFinished(tag, ok, output) {
            if (tag === "cpu") page.cpu = win.backend.cpuMode()
            else if (tag === "power") page.power = win.backend.powerProfile()
        }
    }
}
