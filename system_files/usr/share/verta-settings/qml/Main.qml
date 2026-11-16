import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ApplicationWindow {
    id: win

    required property var backend
    property string startPage: ""
    property string screenshotPath: ""   // --screenshot: save the window and quit
    property int currentPage: 0

    title: "Settings"
    width: 1080
    height: 720
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    color: Kirigami.Theme.backgroundColor

    // Shared look, used by every page and component.
    readonly property bool dark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    // The installed Verta version, e.g. "2026.11.16.8" (shown under the title).
    readonly property string osVersion: backend.version()
    readonly property color fg: Kirigami.Theme.textColor
    readonly property color accent: Kirigami.Theme.highlightColor
    readonly property color cardColor: dark ? Qt.rgba(1, 1, 1, 0.045) : "#ffffff"
    readonly property color hairline: Qt.rgba(fg.r, fg.g, fg.b, dark ? 0.09 : 0.08)
    readonly property color sidebarColor: dark ? Qt.darker(Kirigami.Theme.backgroundColor, 1.18)
                                               : Qt.tint(Kirigami.Theme.backgroundColor, Qt.rgba(0, 0, 0, 0.035))

    readonly property var pages: [
        { key: "appearance", title: "Appearance", file: "AppearancePage.qml",
          icon: "preferences-desktop-appearance-symbolic", fallback: "draw-brush",
          top: "#818cf8", bottom: "#4f46e5", keywords: "theme dark light accent colour color wallpaper background animation" },
        { key: "display", title: "Display", file: "DisplayPage.qml",
          icon: "video-display-symbolic", fallback: "monitor",
          top: "#38bdf8", bottom: "#0284c7", keywords: "screen monitor resolution refresh rate hz scale hdr night light" },
        { key: "sound", title: "Sound", file: "SoundPage.qml",
          icon: "audio-volume-high-symbolic", fallback: "audio-volume-high",
          top: "#fb7185", bottom: "#e11d48", keywords: "volume audio speakers headphones microphone mute" },
        { key: "gaming", title: "Gaming & Performance", file: "GamingPage.qml",
          icon: "input-gaming-symbolic", fallback: "input-gaming",
          top: "#4ade80", bottom: "#16a34a", keywords: "games fps overlay mangohud cpu scheduler power proton tearing gpu" },
        { key: "apps", title: "Apps", file: "AppsPage.qml",
          icon: "view-app-grid-symbolic", fallback: "view-list-icons",
          top: "#60a5fa", bottom: "#2563eb", keywords: "store discover windows exe bottles android waydroid appimage distrobox install" },
        { key: "updates", title: "Updates", file: "UpdatesPage.qml",
          icon: "software-update-available-symbolic", fallback: "update-none",
          top: "#fbbf24", bottom: "#d97706", keywords: "update upgrade version rollback restart" },
        { key: "about", title: "About", file: "AboutPage.qml",
          icon: "help-about-symbolic", fallback: "help-about",
          top: "#94a3b8", bottom: "#475569", keywords: "system info hardware cpu gpu memory version kernel secure boot" }
    ]

    function matches(p) {
        const q = search.text.trim().toLowerCase()
        return q === "" || p.title.toLowerCase().includes(q) || p.keywords.includes(q)
    }

    Component.onCompleted: {
        for (let i = 0; i < pages.length; i++)
            if (pages[i].key === startPage) currentPage = i
        pageLoader.source = pages[currentPage].file
        intro.start()
    }

    onCurrentPageChanged: {
        if (!pageLoader.source.toString()) return
        pageLoader.opacity = 0
        slide.y = 14
        pageLoader.source = pages[currentPage].file
        pageIn.restart()
    }

    RowLayout {
        id: everything
        anchors.fill: parent
        spacing: 0

        // ---- Sidebar ------------------------------------------------------
        Rectangle {
            // (also paints the window colour under the page, for --screenshot)
            Rectangle {
                x: parent.width
                width: everything.width - parent.width
                height: parent.height
                color: win.color
            }

            Layout.fillHeight: true
            Layout.preferredWidth: 256
            color: win.sidebarColor

            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1
                color: win.hairline
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 20
                spacing: 6

                RowLayout {
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 10
                    spacing: 12
                    Kirigami.Icon {
                        source: "verta-logo"
                        implicitWidth: 38
                        implicitHeight: 38
                    }
                    ColumnLayout {
                        spacing: 0
                        QQC2.Label {
                            text: "Verta"
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
                            font.weight: Font.Bold
                        }
                        QQC2.Label {
                            text: win.osVersion ? "Settings · " + win.osVersion : "Settings"
                            opacity: 0.55
                        }
                    }
                }

                Kirigami.SearchField {
                    id: search
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    onAccepted: {
                        for (let i = 0; i < win.pages.length; i++)
                            if (win.matches(win.pages[i])) { win.currentPage = i; return }
                    }
                }

                ListView {
                    id: nav
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: win.pages
                    currentIndex: win.currentPage
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 220
                    highlightResizeDuration: 0
                    highlight: Rectangle {
                        radius: 9
                        color: win.accent
                    }

                    delegate: Item {
                        id: navItem
                        required property var modelData
                        required property int index
                        readonly property bool shown: win.matches(modelData)
                        readonly property bool selected: index === win.currentPage

                        width: ListView.view.width
                        height: shown ? 40 : 0
                        visible: shown

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: win.hairline
                            opacity: navMouse.containsMouse && !navItem.selected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 11
                            Tile {
                                size: 26
                                scale: navMouse.pressed ? 0.92 : navMouse.containsMouse ? 1.1 : 1
                                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                icon: navItem.modelData.icon
                                fallback: navItem.modelData.fallback
                                topColor: navItem.modelData.top
                                bottomColor: navItem.modelData.bottom
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                text: navItem.modelData.title
                                elide: Text.ElideRight
                                color: navItem.selected ? Kirigami.Theme.highlightedTextColor : win.fg
                                font.weight: navItem.selected ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.currentPage = navItem.index
                        }
                    }
                }

                // Everything else lives in KDE System Settings.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: win.hairline
                        opacity: moreMouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 11
                        Tile {
                            size: 26
                            icon: "preferences-system-symbolic"
                            fallback: "configure"
                            topColor: "#9ca3af"
                            bottomColor: "#4b5563"
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: "All settings"
                        }
                        Kirigami.Icon {
                            source: "external-link-symbolic"
                            fallback: "document-open"
                            implicitWidth: 14
                            implicitHeight: 14
                            opacity: 0.45
                        }
                    }
                    MouseArea {
                        id: moreMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.backend.openKcm("")
                    }
                }
            }
        }

        // ---- Page ---------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: pageLoader
                anchors.fill: parent
                transform: Translate { id: slide }
            }

            ParallelAnimation {
                id: pageIn
                NumberAnimation { target: pageLoader; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: slide; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
            }
        }
    }

    Timer {
        interval: 1800
        running: win.screenshotPath !== ""
        onTriggered: everything.grabToImage(result => {
            result.saveToFile(win.screenshotPath)
            Qt.quit()
        })
    }

    // Window fades in gently on open.
    NumberAnimation {
        id: intro
        target: win.contentItem
        property: "opacity"
        from: 0
        to: 1
        duration: 260
        easing.type: Easing.OutCubic
    }
}
