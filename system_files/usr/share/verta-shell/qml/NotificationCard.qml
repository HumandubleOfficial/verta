/*
    One notification, Windows 11 style: the app's icon and name on top with a
    close button, then the picture or icon, the title in bold and the text,
    and the app's buttons (Reply, Open, ...) underneath. Used for the
    pop-ups and for the list in the clock's flyout.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property string appName
    property var appIcon
    property var image             // a picture the app sent (QImage) or an icon name
    property string summary
    property string body
    property date created
    property bool showTime: false
    property var actionNames: []
    property var actionLabels: []
    property bool closable: true
    property bool critical: false
    readonly property bool hovered: hover.hovered
    signal activated()
    signal closeClicked()
    signal actionInvoked(string name)

    implicitHeight: column.implicitHeight + 24
    radius: Theme.radius
    color: hover.hovered ? Qt.lighter(Theme.flyout, Theme.dark ? 1.12 : 1.0) : Theme.flyout
    border.width: 1
    border.color: critical ? "#e81123" : Theme.stroke
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: card.activated()
    }

    function ago(date) {
        const s = Math.max(0, (Date.now() - date.getTime()) / 1000)
        if (s < 60) return "Now"
        if (s < 3600) return Math.floor(s / 60) + " min ago"
        if (s < 86400) return date.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Kirigami.Icon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                source: card.appIcon || "preferences-desktop-notification"
            }
            Text {
                Layout.fillWidth: true
                text: card.appName
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textDim
            }
            Text {
                visible: card.showTime && !closeButton.visible
                text: card.ago(card.created)
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.textFaint
            }
            IconButton {
                id: closeButton
                visible: card.closable && (card.hovered || !card.showTime)
                implicitWidth: 24
                implicitHeight: 24
                iconName: "window-close"
                iconSize: 12
                onClicked: card.closeClicked()
                Accessible.name: "Dismiss"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Kirigami.Icon {
                visible: !!card.image
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                source: card.image || ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.summary
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.textDim
                    linkColor: Theme.accent
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.actionNames.length > 0
            spacing: 8
            Repeater {
                model: Math.min(3, card.actionNames.length)
                PillButton {
                    required property int index
                    Layout.fillWidth: true
                    implicitWidth: 60
                    text: card.actionLabels[index] || card.actionNames[index]
                    onClicked: card.actionInvoked(card.actionNames[index])
                }
            }
        }
    }
}
