import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Apps"
    subtitle: "Run apps made for Windows, Android and other Linux systems."

    property bool waydroidReady: win.backend.waydroidReady()
    property bool waydroidBusy: false
    property string waydroidError: ""

    // A Flatpak helper app: opens it, or says it is still being installed
    // (Verta installs these in the background on first start).
    component AppRow: SettingRow {
        id: appRow
        property string appId
        readonly property bool installed: win.backend.hasFlatpak(appId)
        icon: appId
        clickable: installed
        external: true
        onClicked: win.backend.launch(["flatpak", "run", appId])
        QQC2.Label {
            visible: !appRow.installed
            text: "Installing…"
            opacity: 0.55
        }
    }

    Section {
        title: "Get apps"
        SettingRow {
            title: "App Store"
            subtitle: "Thousands of apps and games, ready to install."
            icon: "org.kde.discover"
            clickable: true
            external: true
            onClicked: win.backend.launch(["plasma-discover"])
        }
    }

    Section {
        title: "Run apps from anywhere"

        AppRow {
            appId: "com.usebottles.bottles"
            title: "Windows apps"
            subtitle: "Run .exe and .msi programs; just double-click them (Bottles)."
        }
        AppRow {
            appId: "it.mijorus.gearlever"
            title: "AppImages"
            subtitle: "Open a downloaded AppImage and Gear Lever adds it to your apps."
        }
        AppRow {
            appId: "io.github.dvlv.boxbuddyrs"
            title: "Apps from other Linux systems"
            subtitle: "Install packages from Ubuntu, Arch, Debian and more in containers (BoxBuddy + Distrobox)."
        }
        SettingRow {
            title: "Android apps"
            subtitle: page.waydroidError !== "" ? page.waydroidError
                    : page.waydroidReady ? "Waydroid is set up."
                    : "Set up Waydroid: downloads about 1 GB. Works with AMD and Intel graphics."
            icon: "waydroid"
            QQC2.BusyIndicator {
                visible: page.waydroidBusy
                running: visible
                implicitWidth: 28
                implicitHeight: 28
            }
            QQC2.Button {
                text: page.waydroidReady ? "Open" : page.waydroidBusy ? "Setting up…" : "Set up"
                enabled: !page.waydroidBusy
                onClicked: {
                    if (page.waydroidReady) {
                        win.backend.launch(["waydroid", "show-full-ui"])
                    } else {
                        page.waydroidBusy = true
                        page.waydroidError = ""
                        win.backend.setupWaydroid()
                    }
                }
            }
        }
    }

    Section {
        title: "Privacy"
        AppRow {
            appId: "com.github.tchx84.Flatseal"
            title: "App permissions"
            subtitle: "Choose what each app can access: files, devices, network (Flatseal)."
        }
    }

    Connections {
        target: win.backend
        function onFinished(tag, ok, output) {
            if (tag !== "waydroid") return
            page.waydroidBusy = false
            page.waydroidReady = win.backend.waydroidReady()
            if (!ok && !page.waydroidReady) {
                const lines = output.trim().split("\n")
                page.waydroidError = "Setup didn't finish: " + (lines[lines.length - 1] || "cancelled")
            }
        }
    }
}
