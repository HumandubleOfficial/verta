import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Updates"
    subtitle: "Verta updates the whole system at once and can always go back."

    property var info: win.backend.updateInfo()
    // idle | checking | uptodate | available | installing | ready | connecting | error
    property string phase: info.staged ? "ready" : "idle"
    property string message: ""

    function lastLine(text) {
        const lines = text.trim().split("\n").filter(l => l.trim() !== "")
        return lines.length ? lines[lines.length - 1] : ""
    }

    readonly property bool working: phase === "checking" || phase === "installing" || phase === "connecting"

    readonly property string headline: {
        if (!info.ok) return "Updates aren't available here"
        if (phase === "ready") return "Restart to finish updating"
        if (phase === "checking") return "Checking for updates…"
        if (phase === "installing") return "Downloading and installing…"
        if (phase === "connecting") return "Connecting to Verta updates…"
        if (!info.connected) return "Connect to Verta updates"
        if (phase === "available") return "An update is available"
        if (phase === "uptodate") return "Verta is up to date"
        if (phase === "error") return "Something went wrong"
        return "Verta " + info.version
    }

    readonly property string detail: {
        if (!info.ok) return "This doesn't look like an installed Verta system."
        if (phase === "ready") return (info.stagedVersion ? "Verta " + info.stagedVersion : "The new version") + " is installed and starts the next time you restart."
        if (phase === "installing") return "Keep using your PC; your apps, games and files are not touched."
        if (phase === "connecting") return "Downloading Verta from GitHub. This can take a while."
        if (!info.connected) return "This PC was installed from a locally built image, so it can't receive updates yet. Connect it to Verta's update server: " + "ghcr.io/humandubleofficial/" + info.image + "."
        if (phase === "available") return "Download it now, or let Verta do it in the background."
        if (phase === "uptodate") return "Version " + info.version + ". Checked just now."
        if (phase === "error") return message
        return "Updates download by themselves in the background and are applied when you restart."
    }

    Section {
        Item {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + 48

            RowLayout {
                id: hero
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 24 }
                spacing: 20

                Item {
                    implicitWidth: 72
                    implicitHeight: 72
                    Kirigami.Icon {
                        anchors.fill: parent
                        source: "system-software-update"
                        RotationAnimator on rotation {
                            running: page.working
                            from: 0; to: 360
                            duration: 1600
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) parent.rotation = 0
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: page.headline
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: page.detail
                        wrapMode: Text.WordWrap
                        opacity: 0.65
                    }
                }

                QQC2.Button {
                    visible: page.info.ok && !page.working
                    highlighted: true
                    text: page.phase === "ready" ? "Restart now"
                        : !page.info.connected ? "Connect"
                        : page.phase === "available" ? "Download & install"
                        : "Check for updates"
                    onClicked: {
                        if (page.phase === "ready") {
                            win.backend.restart()
                        } else if (!page.info.connected) {
                            page.phase = "connecting"
                            win.backend.connectUpdates()
                        } else if (page.phase === "available") {
                            page.phase = "installing"
                            win.backend.installUpdates()
                        } else {
                            page.phase = "checking"
                            win.backend.checkUpdates()
                        }
                    }
                }
            }
        }
    }

    Section {
        title: "Options"

        SettingRow {
            title: "Automatic updates"
            subtitle: "Verta downloads updates in the background and applies them the next time you restart."
            QQC2.Label { text: "On"; opacity: 0.6 }
        }
        SettingRow {
            title: "Go back to the previous version"
            subtitle: "If something stopped working after an update, restart into the version you had before."
            QQC2.Button {
                text: "Roll back"
                enabled: page.info.rollback && !page.working
                onClicked: {
                    page.phase = "installing"
                    win.backend.rollback()
                }
            }
        }
        SettingRow {
            title: "App updates"
            subtitle: "Apps from the App Store update separately, in Discover."
            icon: "org.kde.discover"
            clickable: true
            external: true
            onClicked: win.backend.launch(["plasma-discover", "--mode", "update"])
        }
    }

    Section {
        title: "Details"
        visible: page.info.ok
        SettingRow {
            title: "Installed version"
            QQC2.Label { text: page.info.version || "—"; opacity: 0.6 }
        }
        SettingRow {
            title: "Update source"
            QQC2.Label {
                Layout.maximumWidth: 420
                text: page.info.source || "—"
                elide: Text.ElideMiddle
                opacity: 0.6
            }
        }
    }

    Connections {
        target: win.backend
        function onFinished(tag, ok, output) {
            if (tag === "check") {
                const m = output.match(/exit=(\d+)/)
                const code = m ? parseInt(m[1]) : 1
                if (code === 0 && /AvailableUpdate/.test(output)) page.phase = "available"
                else if (code === 0 || code === 77) page.phase = "uptodate"
                else { page.phase = "error"; page.message = page.lastLine(output.replace(/exit=\d+/, "")) }
            } else if (tag === "install" || tag === "rollback" || tag === "connect") {
                page.info = win.backend.updateInfo()
                if (ok) page.phase = "ready"
                else if (/dismissed|Not authorized|126/.test(output) || output.trim() === "") page.phase = "idle"
                else { page.phase = "error"; page.message = page.lastLine(output) }
            }
        }
    }
}
