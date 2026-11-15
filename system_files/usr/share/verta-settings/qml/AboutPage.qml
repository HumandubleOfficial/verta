import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

SettingsPage {
    id: page
    title: "About"

    property var a: win.backend.about()

    component InfoRow: SettingRow {
        id: info
        property string value
        visible: value !== ""
        QQC2.Label {
            Layout.maximumWidth: 440
            text: info.value
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            opacity: 0.65
        }
    }

    Section {
        Item {
        Layout.fillWidth: true
        implicitHeight: header.implicitHeight + 60
        ColumnLayout {
            id: header
            anchors.centerIn: parent
            spacing: 6

            Kirigami.Icon {
                id: logo
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
                source: "verta-logo"
                implicitWidth: 104
                implicitHeight: 104
                scale: 0.85
                opacity: 0
                Component.onCompleted: logoIn.start()
                ParallelAnimation {
                    id: logoIn
                    NumberAnimation { target: logo; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutBack }
                    NumberAnimation { target: logo; property: "opacity"; to: 1; duration: 320 }
                }
            }
            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: page.a.name
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                font.weight: Font.Bold
            }
            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Version " + page.a.version + "  ·  " + page.a.edition + " edition"
                opacity: 0.6
            }
        }
        }
    }

    Section {
        InfoRow { title: "Device name"; value: page.a.hostname }
        InfoRow { title: "Processor"; value: page.a.cpu }
        InfoRow { title: "Graphics"; value: page.a.gpu }
        InfoRow { title: "Memory"; value: page.a.memory }
        InfoRow { title: "Storage"; value: page.a.disk }
        InfoRow { title: "Kernel"; value: page.a.kernel }
        InfoRow { title: "Secure Boot"; value: page.a.secureBoot }
        InfoRow { title: "Based on"; value: page.a.base }
    }

    Section {
        SettingRow {
            title: "More system information"
            subtitle: "Detailed hardware, drivers, graphics and firmware info."
            tileIcon: "help-about-symbolic"; tileFallback: "help-about"
            tileTop: "#94a3b8"; tileBottom: "#475569"
            clickable: true
            external: true
            onClicked: win.backend.launch(["kinfocenter"])
        }
    }
}
