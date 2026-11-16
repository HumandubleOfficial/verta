import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Appearance"
    subtitle: "Light or dark, your desktop layout, accent colour and wallpaper."

    property string mode: win.backend.appearanceMode()
    property string accent: win.backend.accent()
    property string wallpaper: win.backend.currentWallpaper()
    property string layoutName: win.backend.desktopLayout()

    // Mini desktop used by the Light / Dark / Automatic choices.
    component Preview: Rectangle {
        property bool darkLook: false
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0; color: darkLook ? "#1b2c52" : "#dbe7fb" }
            GradientStop { position: 1; color: darkLook ? "#060b18" : "#9dbcf2" }
        }
        Rectangle {   // window
            x: parent.width * 0.14; y: parent.height * 0.16
            width: parent.width * 0.62; height: parent.height * 0.52
            radius: 7
            color: darkLook ? "#1e293b" : "#ffffff"
            border.width: 1
            border.color: darkLook ? "#3b82f6" : Qt.rgba(0, 0, 0, 0.08)
            Row {
                x: 7; y: 7; spacing: 4
                Repeater {
                    model: ["#f6574e", "#f8b62a", "#2fc75c"]
                    Rectangle { required property string modelData; width: 6; height: 6; radius: 3; color: modelData }
                }
            }
            Rectangle {
                x: 8; y: 22; width: parent.width * 0.3; height: parent.height - 30; radius: 4
                color: darkLook ? "#0f172a" : "#f1f5f9"
            }
            Rectangle {
                x: parent.width * 0.3 + 16; y: 24; width: parent.width * 0.45; height: 6; radius: 3
                color: win.accent
            }
            Rectangle {
                x: parent.width * 0.3 + 16; y: 36; width: parent.width * 0.35; height: 5; radius: 2.5
                color: darkLook ? "#334155" : "#e2e8f0"
            }
        }
        Rectangle {   // dock or taskbar
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 7
            width: parent.width * (page.layoutName === "dock" ? 0.4 : 0.86); height: 10; radius: 5
            color: darkLook ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.7)
        }
    }

    // Mini desktop for the Dock / Taskbar choices.
    component LayoutPreview: Rectangle {
        property bool dock: true
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0; color: "#1e3a8a" }
            GradientStop { position: 0.55; color: "#4c1d95" }
            GradientStop { position: 1; color: "#0b1230" }
        }
        // menu bar: logo, app name, menus ... clock
        Rectangle {
            visible: parent.dock
            width: parent.width; height: Math.round(parent.height * 0.09)
            topLeftRadius: parent.radius; topRightRadius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.16)
            Row {
                x: 9; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                Rectangle { width: 6; height: 6; radius: 3; color: "white"; opacity: 0.9 }
                Repeater {
                    model: [16, 10, 10, 12]
                    Rectangle { required property int modelData; width: modelData; height: 4; radius: 2; color: "white"; opacity: 0.6; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 4; radius: 2; color: "white"; opacity: 0.6 }
        }
        // window with buttons on the left (Dock) or right (Taskbar)
        Rectangle {
            x: parent.width * 0.16; y: parent.height * (parent.dock ? 0.2 : 0.12)
            width: parent.width * 0.6; height: parent.height * 0.48
            radius: 6
            color: "#1e293b"
            Row {
                y: 6; spacing: 3
                x: parent.parent.dock ? 6 : parent.width - width - 6
                Repeater {
                    model: ["#f6574e", "#f8b62a", "#2fc75c"]
                    Rectangle { required property string modelData; width: 5; height: 5; radius: 2.5; color: modelData }
                }
            }
        }
        // the dock (narrow, centred) or the taskbar (full width)
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 6
            width: parent.dock ? parent.width * 0.46 : parent.width - 12
            height: Math.round(parent.height * (parent.dock ? 0.13 : 0.11))
            radius: parent.dock ? 6 : height / 2
            color: Qt.rgba(1, 1, 1, 0.18)
            Row {
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: ["#f87171", "#60a5fa", "#34d399", "#fbbf24", "#a78bfa"]
                    Rectangle { required property string modelData; width: 8; height: 8; radius: 2.5; color: modelData }
                }
            }
        }
    }

    Section {
        title: "Theme"

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 20

            Repeater {
                model: [
                    { key: "light", label: "Light" },
                    { key: "dark", label: "Dark" },
                    { key: "auto", label: "Automatic" }
                ]
                delegate: ColumnLayout {
                    id: choice
                    required property var modelData
                    readonly property bool selected: page.mode === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * 0.62)
                        scale: themeMouse.pressed ? 0.97 : themeMouse.containsMouse ? 1.025 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: 16
                            color: "transparent"
                            border.width: 3
                            border.color: win.accent
                            opacity: choice.selected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                        Preview {
                            anchors.fill: parent
                            visible: choice.modelData.key !== "dark"
                            darkLook: false
                        }
                        // Automatic: light on the left, dark on the right.
                        Item {
                            visible: choice.modelData.key !== "light"
                            x: choice.modelData.key === "auto" ? Math.round(parent.width / 2) : 0
                            width: parent.width - x
                            height: parent.height
                            clip: true
                            Preview {
                                x: -parent.x
                                width: parent.parent.width
                                height: parent.height
                                darkLook: true
                            }
                        }
                        MouseArea {
                            id: themeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.mode = choice.modelData.key
                                win.backend.setAppearanceMode(choice.modelData.key)
                            }
                        }
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: choice.modelData.label
                        font.weight: choice.selected ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    Section {
        title: "Desktop layout"
        footer: page.layoutName === "dock"
            ? "A menu bar along the top with the Verta menu and the app's menus, and a dock for your apps. Window buttons sit on the left."
            : "One taskbar along the bottom with Start, your apps, the tray and the clock. Window buttons sit on the right."

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 20

            Repeater {
                model: [
                    { key: "dock", label: "Dock" },
                    { key: "taskbar", label: "Taskbar" }
                ]
                delegate: ColumnLayout {
                    id: layoutChoice
                    required property var modelData
                    readonly property bool selected: page.layoutName === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * 0.56)
                        scale: layoutMouse.pressed ? 0.97 : layoutMouse.containsMouse ? 1.02 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: 16
                            color: "transparent"
                            border.width: 3
                            border.color: win.accent
                            opacity: layoutChoice.selected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                        LayoutPreview {
                            anchors.fill: parent
                            dock: layoutChoice.modelData.key === "dock"
                        }
                        MouseArea {
                            id: layoutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.name: layoutChoice.modelData.label
                            Accessible.role: Accessible.RadioButton
                            onClicked: {
                                if (!layoutChoice.selected) {
                                    page.layoutName = layoutChoice.modelData.key
                                    win.backend.setDesktopLayout(layoutChoice.modelData.key)
                                }
                            }
                        }
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: layoutChoice.modelData.label
                        font.weight: layoutChoice.selected ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    Section {
        title: "Accent colour"
        footer: "Used for highlights, selections, switches and the Control Center."

        Flow {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 14

            Repeater {
                model: [
                    { c: "#3b82f6", n: "Verta Blue" }, { c: "#8b5cf6", n: "Purple" },
                    { c: "#ec4899", n: "Pink" }, { c: "#ef4444", n: "Red" },
                    { c: "#f97316", n: "Orange" }, { c: "#eab308", n: "Yellow" },
                    { c: "#22c55e", n: "Green" }, { c: "#14b8a6", n: "Teal" },
                    { c: "#64748b", n: "Graphite" }
                ]
                delegate: Item {
                    id: swatch
                    required property var modelData
                    required property int index
                    readonly property bool selected: page.accent === "" ? index === 0 : page.accent.toLowerCase() === modelData.c
                    width: 36
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: swatch.modelData.c
                        opacity: swatch.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: swatch.selected ? 24 : (swatchMouse.containsMouse ? 30 : 28)
                        height: width
                        radius: width / 2
                        color: swatch.modelData.c
                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.3) }
                                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
                            }
                        }
                    }
                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.accent = swatch.modelData.c
                            win.backend.setAccent(swatch.modelData.c)
                        }
                    }
                    QQC2.ToolTip.text: modelData.n
                    QQC2.ToolTip.visible: swatchMouse.containsMouse
                    QQC2.ToolTip.delay: 400
                }
            }
        }
    }

    Section {
        title: "Wallpaper"

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            columns: 4
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: win.backend.wallpapers()
                delegate: Item {
                    id: wp
                    required property var modelData
                    readonly property bool selected: page.wallpaper.indexOf(modelData.path) === 0
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.round(width * 9 / 16)
                    scale: wpMouse.containsMouse ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 13
                        color: "transparent"
                        border.width: 3
                        border.color: win.accent
                        opacity: wp.selected ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }
                    Image {
                        id: thumb
                        anchors.fill: parent
                        source: wp.modelData.thumb
                        sourceSize.width: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }
                    Kirigami.ShadowedTexture {
                        anchors.fill: parent
                        source: thumb
                        radius: 9
                    }
                    MouseArea {
                        id: wpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.wallpaper = wp.modelData.path
                            win.backend.setWallpaper(wp.modelData.path)
                        }
                    }
                    QQC2.ToolTip.text: modelData.name
                    QQC2.ToolTip.visible: wpMouse.containsMouse
                    QQC2.ToolTip.delay: 500
                }
            }
        }

        SettingRow {
            title: "Use your own picture"
            tileIcon: "folder-pictures-symbolic"
            tileFallback: "folder-pictures"
            tileTop: "#38bdf8"
            tileBottom: "#0284c7"
            clickable: true
            onClicked: picker.open()
        }
    }

    FileDialog {
        id: picker
        title: "Choose a wallpaper"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.avif *.jxl)"]
        onAccepted: {
            const path = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            page.wallpaper = path
            win.backend.setWallpaper(path)
        }
    }

    Section {
        title: "Motion"
        ChoiceRow {
            title: "Animation speed"
            subtitle: "How quickly windows, menus and the taskbar animate."
            options: ["Off", "Fast", "Balanced", "Relaxed"]
            keys: ["0", "0.5", "0.75", "1"]
            current: {
                const f = win.backend.animationSpeed()
                return f <= 0.01 ? "0" : f <= 0.6 ? "0.5" : f <= 0.85 ? "0.75" : "1"
            }
            onPicked: key => win.backend.setAnimationSpeed(parseFloat(key))
        }
    }
}
