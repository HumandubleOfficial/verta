/*
    What opens from the clock, Windows 11 style: your notifications on top
    (click one to open it, × to remove it, or clear them all), then today's
    date and the month with arrows to page through it. Today is a filled
    accent circle; days from the months either side are dimmed.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.notificationmanager as NotificationManager

Flyout {
    id: cal

    panelWidth: 360
    panelHeight: content.implicitHeight + 1

    property date today: new Date()
    property int shownYear: today.getFullYear()
    property int shownMonth: today.getMonth()
    readonly property int firstDay: Qt.locale().firstDayOfWeek   // 0 = Sunday

    // Everything that came in: the pop-ups end up here.
    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        sortMode: NotificationManager.Notifications.SortByDate
        groupMode: NotificationManager.Notifications.GroupDisabled
    }
    // The count on the clock: what came in since the list was last opened.
    readonly property int unread: history.unreadNotificationsCount
    readonly property int invokeAndClose: 1

    function clearAll() {
        history.clear(1)                     // ClearExpired
        for (let i = history.count - 1; i >= 0; i--) {
            history.close(history.index(i, 0))
        }
    }

    // Without a "last read" time nothing counts as new.
    Component.onCompleted: history.lastRead = new Date()
    onShownChanged: if (!shown) history.lastRead = new Date()
    onOpened: {
        history.lastRead = new Date()
        today = new Date()
        shownYear = today.getFullYear()
        shownMonth = today.getMonth()
    }

    function page(step) {
        let m = shownMonth + step
        shownYear += Math.floor(m / 12)
        shownMonth = ((m % 12) + 12) % 12
    }

    // 42 days (six weeks) starting on the locale's first weekday.
    readonly property var days: {
        const first = new Date(shownYear, shownMonth, 1)
        const lead = (first.getDay() - firstDay + 7) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(shownYear, shownMonth, 1 - lead + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === shownMonth,
                isToday: d.toDateString() === today.toDateString()
            })
        }
        return out
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        // Notifications.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 10
            Layout.topMargin: 10
            Layout.bottomMargin: 6
            Text {
                Layout.fillWidth: true
                text: "Notifications"
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            PillButton {
                visible: history.count > 0
                implicitWidth: 72
                implicitHeight: 26
                text: "Clear all"
                onClicked: cal.clearAll()
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.bottomMargin: 14
            visible: history.count === 0
            text: "No new notifications"
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.textDim
        }
        ListView {
            id: notificationList
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 10
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: history.count > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: history
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast }
            }
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
            }
            delegate: NotificationCard {
                required property var model
                required property int index
                width: notificationList.width
                color: hovered ? Theme.hover : Theme.card
                showTime: true
                created: model.created || new Date()
                appName: model.applicationName || ""
                appIcon: model.applicationIconName || ""
                image: model.image || model.iconName || ""
                summary: model.summary || ""
                body: model.body || ""
                actionNames: model.expired ? [] : (model.actionNames || [])
                actionLabels: model.actionLabels || []
                closable: true
                function modelIndex() { return history.index(index, 0) }
                onActivated: {
                    if (model.hasDefaultAction && !model.expired) {
                        history.invokeDefaultAction(modelIndex(), cal.invokeAndClose)
                        cal.close()
                    }
                }
                onCloseClicked: history.close(modelIndex())
                onActionInvoked: name => {
                    history.invokeAction(modelIndex(), name, cal.invokeAndClose)
                    cal.close()
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
        }

        // Today, e.g. "Tuesday, 17 November".
        Text {
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.bottomMargin: 12
            text: cal.today.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
            elide: Text.ElideRight
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
        }

        // Month and arrows.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 10
            Layout.topMargin: 10
            Text {
                Layout.fillWidth: true
                text: new Date(cal.shownYear, cal.shownMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            PageButton { iconName: "arrow-up"; onClicked: cal.page(-1); Accessible.name: "Previous month" }
            PageButton { iconName: "arrow-down"; onClicked: cal.page(1); Accessible.name: "Next month" }
        }

        // Weekday names.
        Grid {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            columns: 7
            Repeater {
                model: 7
                Text {
                    required property int index
                    width: 42
                    height: 32
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Qt.locale().dayName((cal.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.text
                }
            }
        }

        // The days; the wheel pages through months.
        Grid {
            id: grid
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 12
            columns: 7
            Repeater {
                model: cal.days
                Item {
                    required property var modelData
                    width: 42
                    height: 40
                    Rectangle {
                        anchors.centerIn: parent
                        width: 36; height: 36
                        radius: 18
                        color: modelData.isToday ? Theme.accent : dayMouse.containsMouse ? Theme.hover : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: modelData.isToday ? Font.DemiBold : Font.Normal
                        color: modelData.isToday ? Theme.accentText : modelData.inMonth ? Theme.text : Theme.textFaint
                    }
                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
            WheelHandler {
                onWheel: event => cal.page(event.angleDelta.y > 0 ? -1 : 1)
            }
        }
    }

    component PageButton: MouseArea {
        id: pageButton
        property string iconName
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        hoverEnabled: true
        Rectangle {
            anchors.fill: parent
            radius: Theme.controlRadius
            color: pageButton.pressed ? Theme.pressed : pageButton.containsMouse ? Theme.hover : "transparent"
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 14; height: 14
            source: pageButton.iconName
            isMask: true
            color: Theme.text
        }
    }
}
