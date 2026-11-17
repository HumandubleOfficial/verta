/*
    A Quick Settings slider: an icon button on the left (mute for volume),
    the slider, and an optional "more" chevron on the right (pick the sound
    output). Values run from 0 to 100.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

RowLayout {
    id: row
    property string iconName
    property string iconLabel
    property real value: 0
    property real minimum: 0
    property bool hasMore: false
    property string moreLabel
    signal moved(int value)
    signal iconClicked()
    signal more()
    spacing: 6

    IconButton {
        iconName: row.iconName
        iconSize: 18
        onClicked: row.iconClicked()
        Accessible.name: row.iconLabel
    }
    QQC2.Slider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: 100
        stepSize: 1
        value: row.value
        onMoved: row.moved(Math.max(row.minimum, Math.round(value)))
        Accessible.name: row.iconLabel
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.45)
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 20; height: 20
            radius: 10
            color: Theme.dark ? "#454545" : "#ffffff"
            border.width: 1
            border.color: Theme.stroke
            Rectangle {
                anchors.centerIn: parent
                width: slider.pressed ? 10 : slider.hovered ? 14 : 12
                height: width
                radius: width / 2
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.fast } }
            }
        }
    }
    Text {
        Layout.preferredWidth: 26
        horizontalAlignment: Text.AlignRight
        text: Math.round(row.value)
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.textDim
    }
    IconButton {
        visible: row.hasMore
        iconName: "go-next"
        iconSize: 12
        onClicked: row.more()
        Accessible.name: row.moreLabel
    }
}
