import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A grouped, rounded card of rows with an optional heading and footnote.
ColumnLayout {
    id: section

    property string title
    property string footer
    default property alias content: box.data

    Layout.fillWidth: true
    spacing: 8

    QQC2.Label {
        visible: section.title !== ""
        text: section.title
        leftPadding: 6
        font.weight: Font.DemiBold
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
        opacity: 0.6
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: box.implicitHeight
        radius: 14
        color: win.cardColor
        border.width: 1
        border.color: win.hairline

        ColumnLayout {
            id: box
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 0
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        visible: section.footer !== ""
        text: section.footer
        leftPadding: 6
        rightPadding: 6
        wrapMode: Text.WordWrap
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.92
        opacity: 0.55
    }
}
