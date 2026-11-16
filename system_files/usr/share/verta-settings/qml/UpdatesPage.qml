import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// Software update, the Apple way: the page checks by itself when it opens,
// says plainly where things stand, offers one obvious next step, shows real
// progress while downloading, and the PC keeps working the whole time.
// Updates also download by themselves every day; a notification says when
// one is ready (verta-update-notify), so nobody has to come here at all.
SettingsPage {
    id: page
    title: "Updates"
    subtitle: "Verta updates itself in the background. Restart when it's ready."

    property var info: win.backend.updateInfo()
    // idle | checking | uptodate | available | installing | background | ready | connecting | error
    property string phase: info.staged ? "ready" : "idle"
    property string message: ""
    property string newVersion: ""
    property real progress: -1          // 0..1, or -1 while the size isn't known yet
    property string progressText: ""
    property real lastChecked: win.backend.lastChecked()
    property bool autoUpdates: win.backend.autoUpdates()

    readonly property bool working: phase === "checking" || phase === "installing"
                                     || phase === "background" || phase === "connecting"

    function lastLine(text) {
        const lines = text.trim().split("\n").filter(l => l.trim() !== "")
        return lines.length ? lines[lines.length - 1] : ""
    }

    // "Today at 09:41", "Yesterday at 04:02", "12 November at 18:30", "Never"
    function when(epoch) {
        if (!epoch) return "Never"
        const d = new Date(epoch * 1000)
        const today = new Date(); today.setHours(0, 0, 0, 0)
        const day = new Date(d); day.setHours(0, 0, 0, 0)
        const days = Math.round((today - day) / 86400000)
        const time = d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        if (days === 0) return "Today at " + time
        if (days === 1) return "Yesterday at " + time
        return d.toLocaleDateString(Qt.locale(), "d MMMM") + " at " + time
    }

    function check() {
        page.phase = "checking"
        win.backend.checkUpdates()
    }
    function install() {
        page.progress = -1
        page.progressText = ""
        page.phase = "installing"
        win.backend.installUpdates()
    }

    readonly property string headline: {
        if (!info.ok) return "Updates aren't available here"
        switch (phase) {
        case "ready": return "Restart to finish updating"
        case "checking": return "Checking for updates…"
        case "installing": return newVersion ? "Downloading Verta " + newVersion : "Downloading the update"
        case "background": return "Downloading the update"
        case "connecting": return "Connecting to Verta updates…"
        }
        if (!info.connected) return "Connect to Verta updates"
        switch (phase) {
        case "available": return newVersion ? "Verta " + newVersion + " is available" : "An update is available"
        case "uptodate": return "Verta is up to date"
        case "error": return "Couldn't update"
        }
        return "Verta " + info.version
    }

    readonly property string detail: {
        if (!info.ok) return "This doesn't look like an installed Verta system."
        switch (phase) {
        case "ready": return (info.stagedVersion ? "Verta " + info.stagedVersion : "The new version")
                             + " is downloaded and starts the next time you restart."
        case "installing": return page.progressText || "You can keep using your PC while it downloads."
        case "background": return "Verta is already downloading it in the background. This page updates when it's done."
        case "connecting": return "Downloading Verta from GitHub. This can take a while."
        case "checking": return "Version " + info.version
        }
        if (!info.connected) return "This PC was installed from a locally built image, so it can't get updates yet."
        switch (phase) {
        case "available": return "Your apps, games and files stay just as they are."
        case "uptodate": return "Version " + info.version + " · Checked " + page.when(page.lastChecked).toLowerCase()
        case "error": return page.message
        }
        return page.autoUpdates ? "New versions download by themselves. You'll get a notification when one is ready."
                                : "Automatic updates are off."
    }

    // --- the status card ---------------------------------------------------
    Section {
        Item {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + 48

            RowLayout {
                id: hero
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 24 }
                spacing: 20

                // Verta logo with a small status badge (shape + colour, never colour alone).
                Item {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 72
                    implicitHeight: 72
                    Kirigami.Icon {
                        anchors.fill: parent
                        source: "verta-logo"
                        fallback: "system-software-update"
                    }
                    Rectangle {
                        id: badge
                        readonly property string kind: page.phase === "uptodate" ? "ok"
                            : (page.phase === "available" || page.phase === "ready") ? "new"
                            : page.phase === "error" ? "warn" : ""
                        visible: kind !== ""
                        anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
                        width: 26; height: 26; radius: 13
                        color: kind === "ok" ? "#22c55e" : kind === "warn" ? "#f59e0b" : win.accent
                        border.width: 2
                        border.color: Kirigami.Theme.backgroundColor
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 14; height: 14
                            isMask: true
                            color: "white"
                            source: badge.kind === "ok" ? "checkmark"
                                  : badge.kind === "warn" ? "emblem-important-symbolic"
                                  : page.phase === "ready" ? "system-reboot-symbolic" : "download"
                        }
                        scale: visible ? 1 : 0.4
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        spacing: 10
                        QQC2.BusyIndicator {
                            visible: page.phase === "checking" || page.phase === "connecting"
                            running: visible
                            implicitWidth: 22
                            implicitHeight: 22
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: page.headline
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                    }

                    // Download progress: real numbers when known.
                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        visible: page.phase === "installing" || page.phase === "background"
                        indeterminate: page.phase === "background" || page.progress < 0
                        value: Math.max(0, page.progress)
                        Behavior on value { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: page.detail
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                    }

                    QQC2.Label {
                        visible: page.phase === "available" || page.phase === "ready"
                        text: "<a href=\"https://github.com/HumandubleOfficial/verta/commits/main\">What's new</a>"
                        textFormat: Text.StyledText
                        onLinkActivated: link => Qt.openUrlExternally(link)
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }

                // One clear next step. Update / restart / connect are the
                // page's primary action: a filled accent button.
                QQC2.Button {
                    id: action
                    readonly property bool primary: page.phase === "available" || page.phase === "ready" || !page.info.connected
                    Layout.alignment: Qt.AlignTop
                    visible: page.info.ok && !page.working
                    leftPadding: 18
                    rightPadding: 18
                    topPadding: 8
                    bottomPadding: 8
                    contentItem: QQC2.Label {
                        text: action.text
                        horizontalAlignment: Text.AlignHCenter
                        font.weight: action.primary ? Font.DemiBold : Font.Normal
                        color: action.primary ? "white" : Kirigami.Theme.textColor
                    }
                    background: Rectangle {
                        radius: height / 2
                        color: action.primary
                            ? (action.down ? Qt.darker(win.accent, 1.15) : action.hovered ? Qt.lighter(win.accent, 1.1) : win.accent)
                            : Qt.rgba(win.fg.r, win.fg.g, win.fg.b, action.down ? 0.16 : action.hovered ? 0.11 : 0.07)
                        border.width: action.visualFocus ? 2 : 0
                        border.color: Qt.lighter(win.accent, 1.3)
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    scale: down ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Accessible.name: text
                    text:page.phase === "ready" ? "Restart now"
                        : !page.info.connected ? "Connect"
                        : page.phase === "available" ? "Update now"
                        : page.phase === "error" ? "Try again"
                        : "Check now"
                    onClicked: {
                        if (page.phase === "ready") {
                            win.backend.restart()
                        } else if (!page.info.connected) {
                            page.phase = "connecting"
                            win.backend.connectUpdates()
                        } else if (page.phase === "available") {
                            page.install()
                        } else {
                            page.check()
                        }
                    }
                }
            }
        }
    }

    // --- options -----------------------------------------------------------
    Section {
        title: "Options"

        SettingRow {
            title: "Automatic updates"
            subtitle: "Download new versions overnight (or the next time you start up) and get a notification when one is ready. Skipped on metered connections."
            QQC2.Switch {
                id: autoSwitch
                checked: page.autoUpdates
                enabled: page.info.ok
                onToggled: win.backend.setAutoUpdates(checked)
            }
        }
        SettingRow {
            title: "Go back to the previous version"
            subtitle: page.info.rollbackVersion
                ? "If something stopped working after an update, restart into Verta " + page.info.rollbackVersion + "."
                : "If something stopped working after an update, restart into the version you had before."
            QQC2.Button {
                text: "Go back…"
                enabled: page.info.rollback && !page.working
                onClicked: rollbackDialog.open()
            }
        }
        SettingRow {
            title: "App updates"
            subtitle: "Apps from the App Store update by themselves, separately from Verta."
            icon: "org.kde.discover"
            clickable: true
            external: true
            onClicked: win.backend.launch(["plasma-discover", "--mode", "update"])
        }
    }

    // --- details -------------------------------------------------------------
    Section {
        title: "Details"
        visible: page.info.ok
        SettingRow {
            title: "Installed version"
            QQC2.Label { text: page.info.version || "—"; opacity: 0.6 }
        }
        SettingRow {
            title: "Last checked"
            QQC2.Label { text: page.when(page.lastChecked); opacity: 0.6 }
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

    // Going back is a big step: confirm it, and say exactly what happens.
    Kirigami.PromptDialog {
        id: rollbackDialog
        title: page.info.rollbackVersion ? "Go back to Verta " + page.info.rollbackVersion + "?" : "Go back to the previous version?"
        subtitle: "Your PC starts the previous version the next time you restart. Your apps, games and files stay just as they are, and you can update again at any time."
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                text: "Go back"
                icon.name: "edit-undo"
                onTriggered: {
                    rollbackDialog.close()
                    page.progress = -1
                    page.progressText = "Switching to the previous version…"
                    page.phase = "installing"
                    win.backend.rollback()
                }
            }
        ]
    }

    // While Verta downloads in the background, look again every few seconds.
    Timer {
        interval: 8000
        repeat: true
        running: page.phase === "background"
        onTriggered: {
            page.info = win.backend.updateInfo()
            if (page.info.staged) page.phase = "ready"
            else if (!win.backend.transactionRunning()) page.check()
        }
    }

    // Like macOS: opening the page looks for updates straight away.
    Component.onCompleted: {
        if (info.ok && info.connected && !info.staged && !win.backend.busy("check")) {
            check()
        }
    }

    Connections {
        target: win.backend
        function onProgress(tag, fraction, text) {
            if (tag !== "install") return
            page.progress = fraction
            page.progressText = text
        }
        function onFinished(tag, ok, output) {
            if (tag === "check") {
                page.lastChecked = win.backend.lastChecked()
                // "available|<version>", "ready" (already downloaded) or "uptodate"
                if (!ok) { page.phase = "error"; page.message = output }
                else if (output.startsWith("available")) {
                    page.newVersion = output.split("|")[1] || ""
                    page.phase = "available"
                }
                else if (output === "ready") { page.info = win.backend.updateInfo(); page.phase = "ready" }
                else page.phase = "uptodate"
            } else if (tag === "install" || tag === "rollback" || tag === "connect") {
                page.info = win.backend.updateInfo()
                if (ok && (page.info.staged || tag !== "install")) page.phase = "ready"
                else if (ok) page.phase = "uptodate"            // nothing new after all
                else if (/[Tt]ransaction in progress/.test(output)) page.phase = "background"
                else if (/dismissed|Not authorized|126/.test(output) || output.trim() === "") page.phase = "idle"
                else { page.phase = "error"; page.message = page.lastLine(output) }
            } else if (tag === "autoupdates") {
                page.autoUpdates = win.backend.autoUpdates()
                autoSwitch.checked = page.autoUpdates      // back to the truth if it was cancelled
            }
        }
    }
}
