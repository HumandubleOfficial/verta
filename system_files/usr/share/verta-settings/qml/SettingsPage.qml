import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A scrolling page: big title, then sections, centred at a readable width.
QQC2.ScrollView {
    id: page

    property string title
    property string subtitle
    default property alias content: column.data

    // Show the window colour behind the cards, not the darker "view" colour
    // scroll views paint by default.
    background: Item {}

    implicitWidth: 600      // fixed, so the size doesn't depend on itself
    implicitHeight: 400
    contentWidth: availableWidth
    contentHeight: body.implicitHeight
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    Item {
        id: body
        width: page.availableWidth
        implicitHeight: column.implicitHeight + 76

        ColumnLayout {
            id: column
            width: Math.min(parent.width - 72, 760)
            x: Math.round((parent.width - width) / 2)
            y: 38
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 4
                QQC2.Label {
                    text: page.title
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.1
                    font.weight: Font.Bold
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    visible: page.subtitle !== ""
                    text: page.subtitle
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                }
            }
        }
    }
}
