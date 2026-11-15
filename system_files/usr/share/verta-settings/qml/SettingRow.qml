import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One row in a Section: optional app icon or coloured tile, title, subtitle,
// and controls on the right (children). Clickable rows show a chevron.
Item {
    id: row

    property string title
    property string subtitle
    property string icon                 // full-colour app icon
    property string tileIcon             // or a symbolic icon on a coloured tile
    property string tileFallback: "application-x-executable"
    property color tileTop: "#60a5fa"
    property color tileBottom: "#2563eb"
    property bool clickable: false
    property bool external: false        // opens another app: arrow instead of chevron
    signal clicked()
    default property alias trailing: trail.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, layout.implicitHeight + 24)

    // First visible row in its card: no separator line above it.
    readonly property bool first: {
        if (!parent) return true
        for (let i = 0; i < parent.children.length; i++) {
            const c = parent.children[i]
            if (c.visible && c.implicitHeight > 0) return c === row
        }
        return true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: 10
        color: mouse.pressed ? Qt.rgba(win.fg.r, win.fg.g, win.fg.b, 0.15) : win.hairline
        opacity: row.clickable && mouse.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: !row.first
        height: 1
        color: win.hairline
        anchors {
            top: parent.top
            right: parent.right
            left: parent.left
            leftMargin: layout.anchors.leftMargin + (leading.visible ? leading.width + layout.spacing : 0)
        }
    }

    RowLayout {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 14
        }
        spacing: 13

        Item {
            id: leading
            visible: row.icon !== "" || row.tileIcon !== ""
            implicitWidth: 32
            implicitHeight: 32
            Kirigami.Icon {
                anchors.fill: parent
                visible: row.icon !== ""
                source: row.icon
                fallback: "application-x-executable"
            }
            Tile {
                anchors.centerIn: parent
                visible: row.icon === "" && row.tileIcon !== ""
                size: 30
                icon: row.tileIcon
                fallback: row.tileFallback
                topColor: row.tileTop
                bottomColor: row.tileBottom
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            QQC2.Label {
                Layout.fillWidth: true
                text: row.title
                elide: Text.ElideRight
            }
            QQC2.Label {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                wrapMode: Text.WordWrap
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.92
                opacity: 0.6
            }
        }

        RowLayout {
            id: trail
            spacing: 10
        }

        Kirigami.Icon {
            visible: row.clickable
            source: row.external ? "external-link-symbolic" : "go-next-symbolic"
            fallback: row.external ? "document-open" : "go-next"
            implicitWidth: 16
            implicitHeight: 16
            opacity: mouse.containsMouse ? 0.75 : 0.4
            // The chevron nudges forward on hover.
            transform: Translate {
                x: mouse.containsMouse ? 3 : 0
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: row.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
