/*
    Notification pop-ups, bottom right above the taskbar, newest nearest the
    taskbar. Each slides in from the right, stays a few seconds (longer while
    the pointer is on it; urgent ones stay until dismissed) and then moves to
    the list in the clock's flyout. Click it to open what it's about.

    With Do not disturb on, only urgent ones pop up; the rest go straight
    to the list. Fullscreen games cover them.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.layershell as LayerShell
import org.kde.notificationmanager as NotificationManager

Window {
    id: popups

    required property QtObject shell
    property bool dnd: false
    readonly property int cardWidth: 364
    readonly property int gap: 12
    readonly property int defaultTimeout: 6000

    // The urgency a notification reports (NotificationManager's values), and
    // "invoke, then close it".
    readonly property int urgencyCritical: 4
    readonly property int invokeAndClose: 1

    width: cardWidth + gap
    height: Math.max(1, list.implicitHeight + gap)
    // Out of the way while the Start menu or a flyout is open.
    property bool suppressed: false
    visible: cards.count > 0 && !suppressed
    color: "transparent"

    LayerShell.Window.scope: "verta-notifications"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    onDndChanged: {
        // Tells the server, so notifications that came in meanwhile don't all
        // pop up at once when Do not disturb ends.
        try { NotificationManager.Server.inhibited = dnd } catch (e) {}
    }

    NotificationManager.Settings {
        id: settings
    }
    NotificationManager.Notifications {
        id: popupModel
        limit: 4
        showExpired: false
        showDismissed: false
        showJobs: false
        showAddedDuringInhibition: false
        // (Enum names: the property refuses plain numbers.)
        urgencies: popups.dnd ? NotificationManager.Notifications.CriticalUrgency
                              : NotificationManager.Notifications.LowUrgency
                                | NotificationManager.Notifications.NormalUrgency
                                | NotificationManager.Notifications.CriticalUrgency
        blacklistedDesktopEntries: settings.popupBlacklistedApplications
        blacklistedNotifyRcNames: settings.popupBlacklistedServices
        // Oldest first, so the newest sits at the bottom, nearest the taskbar.
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.AscendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
    }

    function updateBlur() {
        const rects = []
        for (let i = 0; i < list.children.length; i++) {
            const c = list.children[i]
            if (c.isCard && c.visible) {
                const p = c.mapToItem(list.parent, 0, 0)
                rects.push({ x: p.x, y: p.y, width: c.width, height: c.height })
            }
        }
        Host.setBlurRects(popups, rects, Theme.radius)
    }
    onHeightChanged: Qt.callLater(updateBlur)
    onVisibleChanged: if (visible) Qt.callLater(updateBlur)

    // A Column, not a ListView: a ListView only makes the cards it has room
    // for, and its room came from the cards.
    Column {
        id: list
        x: 0
        width: popups.cardWidth
        anchors.bottom: parent.bottom
        anchors.bottomMargin: popups.gap
        spacing: 8

        add: Transition {
            NumberAnimation { property: "x"; from: popups.cardWidth / 2; to: 0; duration: Theme.normal + 80; easing.type: Easing.OutQuint }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal }
        }
        move: Transition {
            NumberAnimation { properties: "y"; duration: Theme.normal; easing.type: Easing.OutCubic }
        }
        onImplicitHeightChanged: Qt.callLater(popups.updateBlur)

        Repeater {
            id: cards
            model: popupModel
            delegate: NotificationCard {
                id: card
                required property var model
                required property int index
                readonly property bool isCard: true
                readonly property int timeoutMs: {
                    if (model.urgency === popups.urgencyCritical) return 0
                    const t = model.timeout
                    return t > 0 ? Math.max(3000, t) : popups.defaultTimeout
                }

                width: popups.cardWidth
                appName: model.applicationName || ""
                appIcon: model.applicationIconName || ""
                image: model.image || model.iconName || ""
                summary: model.summary || ""
                body: model.body || ""
                actionNames: model.actionNames || []
                actionLabels: model.actionLabels || []
                closable: model.closable !== false
                critical: model.urgency === popups.urgencyCritical

                function modelIndex() { return popupModel.index(index, 0) }

                Component.onCompleted: {
                    popupModel.playSoundHint(modelIndex())
                    Qt.callLater(popups.updateBlur)
                }
                onHeightChanged: Qt.callLater(popups.updateBlur)

                Timer {
                    interval: card.timeoutMs
                    running: card.timeoutMs > 0 && !card.hovered
                    onTriggered: popupModel.expire(card.modelIndex())
                }
                onActivated: {
                    if (model.hasDefaultAction) {
                        popupModel.invokeDefaultAction(modelIndex(), popups.invokeAndClose)
                    } else {
                        popupModel.expire(modelIndex())
                    }
                }
                onCloseClicked: popupModel.expire(modelIndex())
                onActionInvoked: name => popupModel.invokeAction(modelIndex(), name, popups.invokeAndClose)
            }
        }
    }
}
