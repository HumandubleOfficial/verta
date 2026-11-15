import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Apple-style segmented control: a raised thumb slides to the chosen option.
Rectangle {
    id: seg

    property var options: []
    property int currentIndex: 0
    property int segmentWidth: 104
    signal activated(int index)

    implicitWidth: options.length * segmentWidth + 4
    implicitHeight: 32
    radius: 9
    color: Qt.rgba(win.fg.r, win.fg.g, win.fg.b, win.dark ? 0.08 : 0.07)

    Rectangle {
        id: thumb
        visible: seg.currentIndex >= 0
        y: 2
        x: 2 + Math.max(0, seg.currentIndex) * seg.segmentWidth
        width: seg.segmentWidth
        height: seg.height - 4
        radius: 7
        color: win.dark ? Qt.rgba(1, 1, 1, 0.16) : "#ffffff"
        border.width: 1
        border.color: win.hairline
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    Row {
        x: 2
        y: 2
        Repeater {
            model: seg.options
            delegate: Item {
                required property string modelData
                required property int index
                width: seg.segmentWidth
                height: seg.height - 4
                QQC2.Label {
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.weight: parent.index === seg.currentIndex ? Font.DemiBold : Font.Normal
                    opacity: parent.index === seg.currentIndex ? 1 : 0.75
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (seg.currentIndex !== parent.index) {
                            seg.currentIndex = parent.index
                            seg.activated(parent.index)
                        }
                    }
                }
            }
        }
    }
}
