import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "Appearance"
    subtitle: "Light or dark, your accent colour and your wallpaper."

    property string mode: win.backend.appearanceMode()
    property string accent: win.backend.accent()
    property string wallpaper: win.backend.currentWallpaper()

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
                    model: 3
                    Rectangle { width: 6; height: 6; radius: 3; color: darkLook ? "#475569" : "#cbd5e1" }
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
        Rectangle {   // taskbar
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 7
            width: parent.width * 0.5; height: 10; radius: 5
            color: darkLook ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.7)
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
        title: "Accent colour"
        footer: "Used for highlights, selections, switches and the active window outline."

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
