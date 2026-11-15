import QtQuick
import org.kde.kirigami as Kirigami

// A small rounded, gradient-filled icon tile (like the icons in the sidebar).
Rectangle {
    id: tile

    property int size: 28
    property string icon
    property string fallback: "application-x-executable"
    property color topColor: "#60a5fa"
    property color bottomColor: "#2563eb"

    implicitWidth: size
    implicitHeight: size
    radius: Math.round(size * 0.27)
    gradient: Gradient {
        GradientStop { position: 0; color: tile.topColor }
        GradientStop { position: 1; color: tile.bottomColor }
    }

    // Soft glossy top edge.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        implicitWidth: Math.round(tile.size * 0.6)
        implicitHeight: implicitWidth
        source: tile.icon
        fallback: tile.fallback
        isMask: true
        color: "white"
    }
}
