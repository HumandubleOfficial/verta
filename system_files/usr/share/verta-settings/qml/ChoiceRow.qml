import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A row with a title/subtitle and a full-width segmented choice under it.
Item {
    id: row

    property string title
    property string subtitle
    property var options: []       // labels
    property var keys: []          // values, same order
    property string current
    signal picked(string key)

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 30

    readonly property bool first: {
        if (!parent) return true
        for (let i = 0; i < parent.children.length; i++) {
            const c = parent.children[i]
            if (c.visible && c.implicitHeight > 0) return c === row
        }
        return true
    }

    Rectangle {
        visible: !row.first
        height: 1
        color: win.hairline
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 16 }
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            QQC2.Label { Layout.fillWidth: true; text: row.title }
            QQC2.Label {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.92
                opacity: 0.6
            }
        }

        Segmented {
            Layout.fillWidth: true
            segmentWidth: Math.floor((width - 4) / Math.max(1, row.options.length))
            options: row.options
            currentIndex: row.keys.indexOf(row.current)
            onActivated: index => row.picked(row.keys[index])
        }
    }
}
