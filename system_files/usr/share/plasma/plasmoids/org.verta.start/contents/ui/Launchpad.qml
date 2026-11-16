/*
    Launchpad: every app in a full-screen grid over the blurred, dimmed
    desktop, opened from the Apps icon in the dock (or the Meta key).

                      [  Search                     ]

          [app]   [app]   [app]   [app]   [app]   [app]   [app]
          [app]   [app]   [app]   [app]   [app]   [app]   [app]
           ...
                                • ○ ○

    Apps are A to Z in pages; swipe, scroll or use the arrow keys to move
    between pages. Typing searches apps, files, settings and the calculator.
    Enter opens the highlighted result, Esc clears the search or closes, and
    clicking anywhere empty closes. Right-click an app for its actions; drag
    one onto the dock to keep it there.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

Kicker.DashboardWindow {
    id: pad

    readonly property bool searching: search.text.length > 0
    readonly property var apps: start.allAppsModel
    readonly property var results: start.runnerModel.count > 0 ? start.runnerModel.modelForRow(0) : null

    // Grid geometry: 7 x 5 like a phone home screen on a big display, fewer
    // on small screens; icons scale with the screen (64 - 96 px).
    readonly property int columns: width >= 1500 ? 7 : (width >= 1100 ? 6 : 5)
    readonly property int rows: height >= 1000 ? 5 : 4
    readonly property int perPage: columns * rows
    readonly property int pageCount: apps ? Math.max(1, Math.ceil(apps.count / perPage)) : 1
    property int current: -1                  // keyboard selection (index into apps)

    visualParent: start.fullRepresentationItem
    backgroundColor: "transparent"
    keyEventProxy: search

    onKeyEscapePressed: {
        if (searching) {
            search.text = ""
        } else {
            dismiss()
        }
    }
    // Clicking another window or the panel closes Launchpad.
    onActiveChanged: {
        if (!active && visible && !dragHelper.isDragging) {
            toggle()
        }
    }
    onVisibleChanged: {
        if (visible) {
            search.text = ""
            current = -1
            pages.currentIndex = 0
            pages.positionViewAtBeginning()
            search.forceActiveFocus()
            enter.restart()
        } else {
            content.opacity = 0
        }
    }

    // Plays the closing animation, then hides.
    function dismiss() {
        if (!leave.running) {
            leave.restart()
        }
    }
    function open(model, index) {
        model.trigger(index, "", null)
        dismiss()
    }

    // Keyboard selection across pages.
    function move(step) {
        if (!apps || apps.count === 0) {
            return
        }
        current = current < 0 ? 0 : Math.max(0, Math.min(apps.count - 1, current + step))
        pages.currentIndex = Math.floor(current / perPage)
    }

    mainItem: MouseArea {
        id: backdrop
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: pad.dismiss()

        // Page by page with the mouse wheel / touchpad.
        property real wheelDelta: 0
        onWheel: wheel => {
            if (pad.searching) {
                return
            }
            wheelDelta += Math.abs(wheel.angleDelta.y) > Math.abs(wheel.angleDelta.x) ? wheel.angleDelta.y : wheel.angleDelta.x
            if (Math.abs(wheelDelta) >= 120 && !pageTurn.running) {
                pages.currentIndex = Math.max(0, Math.min(pad.pageCount - 1, pages.currentIndex + (wheelDelta < 0 ? 1 : -1)))
                wheelDelta = 0
                pageTurn.start()
            }
        }
        Timer { id: pageTurn; interval: 350 }

        // Dim the (blurred) desktop so the icons and names stand out.
        Rectangle {
            anchors.fill: parent
            color: "#05070d"
            opacity: content.opacity * 0.5
        }

        Item {
            id: content
            anchors.fill: parent
            opacity: 0
            scale: 1.06

            ParallelAnimation {
                id: enter
                NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: content; property: "scale"; from: 1.06; to: 1; duration: 320; easing.type: Easing.OutQuint }
            }
            SequentialAnimation {
                id: leave
                ParallelAnimation {
                    NumberAnimation { target: content; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
                    NumberAnimation { target: content; property: "scale"; to: 1.04; duration: 150; easing.type: Easing.InCubic }
                }
                ScriptAction { script: pad.toggle() }
            }

            // ---- search --------------------------------------------------
            PlasmaComponents3.TextField {
                id: search
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.06)
                width: Math.min(Kirigami.Units.gridUnit * 20, parent.width - Kirigami.Units.gridUnit * 4)
                implicitHeight: Math.round(Kirigami.Units.gridUnit * 2.1)
                leftPadding: Math.round(Kirigami.Units.gridUnit * 2.1)
                horizontalAlignment: activeFocus || text.length > 0 ? Text.AlignLeft : Text.AlignHCenter
                placeholderText: "Search"
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.6)
                color: "white"
                onTextChanged: {
                    start.searchText = text
                    resultsView.currentIndex = 0
                }

                background: Rectangle {
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, search.activeFocus ? 0.16 : 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                    Kirigami.Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(Kirigami.Units.gridUnit * 0.7)
                        width: Kirigami.Units.iconSizes.small
                        height: width
                        source: "search"
                        isMask: true
                        color: "white"
                        opacity: 0.7
                    }
                }

                Keys.onPressed: event => {
                    const view = pad.searching ? resultsView : null
                    switch (event.key) {
                    case Qt.Key_Left:
                        if (view) view.moveCurrentIndexLeft(); else pad.move(-1)
                        break
                    case Qt.Key_Right:
                        if (view) view.moveCurrentIndexRight(); else pad.move(1)
                        break
                    case Qt.Key_Up:
                        if (view) view.moveCurrentIndexUp(); else pad.move(-pad.columns)
                        break
                    case Qt.Key_Down:
                        if (view) view.moveCurrentIndexDown(); else pad.move(pad.columns)
                        break
                    case Qt.Key_PageDown:
                        pages.currentIndex = Math.min(pad.pageCount - 1, pages.currentIndex + 1)
                        break
                    case Qt.Key_PageUp:
                        pages.currentIndex = Math.max(0, pages.currentIndex - 1)
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (view && view.count > 0) {
                            pad.open(view.model, Math.max(0, view.currentIndex))
                        } else if (!view && pad.current >= 0) {
                            pad.open(pad.apps, pad.current)
                        }
                        break
                    default:
                        return
                    }
                    event.accepted = true
                }
            }

            // ---- the grid area ---------------------------------------------
            Item {
                id: area
                anchors.top: search.bottom
                anchors.topMargin: Math.round(parent.height * 0.05)
                anchors.horizontalCenter: parent.horizontalCenter
                // room for the page dots and the dock below
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Kirigami.Units.gridUnit * 7
                width: Math.min(parent.width - Kirigami.Units.gridUnit * 4, cellWidth * pad.columns)

                readonly property real cellWidth: Math.min(Kirigami.Units.gridUnit * 9,
                    (pad.width - Kirigami.Units.gridUnit * 4) / pad.columns)
                readonly property real cellHeight: height / pad.rows
                readonly property int iconSize: Math.max(48, Math.min(96,
                    Math.round(Math.min(cellWidth, cellHeight) * 0.56)))

                // Pages of apps, side by side; swipe or scroll between them.
                ListView {
                    id: pages
                    anchors.fill: parent
                    visible: !pad.searching
                    orientation: ListView.Horizontal
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 380
                    boundsBehavior: Flickable.StopAtBounds
                    clip: false
                    model: pad.pageCount
                    delegate: Item {
                        id: page
                        required property int index
                        width: pages.width
                        height: pages.height

                        // Each page shows its slice of the one A-Z list.
                        GridView {
                            anchors.fill: parent
                            interactive: false
                            model: pad.apps
                            cellWidth: area.cellWidth
                            cellHeight: area.cellHeight
                            contentY: page.index * pad.rows * area.cellHeight
                            cacheBuffer: 0
                            delegate: Tile {
                                appModel: pad.apps
                                selected: pad.current === index
                                visible: index >= page.index * pad.perPage && index < (page.index + 1) * pad.perPage
                            }
                        }
                    }
                }

                // Search results, in the same kind of grid.
                GridView {
                    id: resultsView
                    anchors.fill: parent
                    visible: pad.searching
                    model: pad.results
                    cellWidth: area.cellWidth
                    cellHeight: area.cellHeight
                    currentIndex: 0
                    keyNavigationWraps: false
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    delegate: Tile {
                        appModel: pad.results
                        selected: GridView.isCurrentItem
                    }
                }
                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    visible: pad.searching && resultsView.count === 0 && !start.runnerModel.querying
                    text: "No results for “" + search.text + "”"
                    color: "white"
                    opacity: 0.75
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                }
            }

            // ---- page dots -----------------------------------------------------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: area.bottom
                anchors.topMargin: Kirigami.Units.gridUnit
                spacing: Kirigami.Units.smallSpacing * 2
                visible: !pad.searching && pad.pageCount > 1
                Repeater {
                    model: pad.pageCount
                    delegate: MouseArea {
                        required property int index
                        width: 18
                        height: 18
                        hoverEnabled: true
                        onClicked: pages.currentIndex = index
                        Accessible.name: "Page " + (index + 1)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: "white"
                            opacity: pages.currentIndex === parent.index ? 0.95 : (parent.containsMouse ? 0.55 : 0.35)
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                    }
                }
            }
        }
    }

    // One app: a big icon with its name underneath.
    component Tile: Item {
        id: tile
        required property int index
        required property var model
        property var appModel
        property bool selected: false

        width: area.cellWidth
        height: area.cellHeight

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, area.iconSize * 1.9)
            height: Math.min(parent.height, area.iconSize * 1.75)
            radius: Kirigami.Units.cornerRadius * 2.5
            color: "white"
            opacity: tile.selected ? 0.16 : (mouse.containsMouse ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing * 1.5

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: area.iconSize
                Layout.preferredHeight: area.iconSize
                source: tile.model.decoration
                animated: false
                scale: mouse.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: tile.model.display || ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.0
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point pressPos
            onPressed: mouseEvent => pressPos = Qt.point(mouseEvent.x, mouseEvent.y)
            onPositionChanged: mouseEvent => {
                // Dragging an app out (e.g. onto the dock to keep it there).
                if (pressed && tile.model.url && !dragHelper.isDragging
                        && dragHelper.isDrag(pressPos.x, pressPos.y, mouseEvent.x, mouseEvent.y)) {
                    dragHelper.startDrag(start, tile.model.url, tile.model.decoration)
                    pad.toggle()
                }
            }
            onClicked: mouseEvent => {
                if (mouseEvent.button === Qt.RightButton) {
                    tile.showActions()
                } else {
                    pad.open(tile.appModel, tile.index)
                }
            }
        }

        Accessible.name: tile.model.display || ""
        Accessible.role: Accessible.Button

        // Right-click: the app's own actions (new window, pin, uninstall ...).
        function showActions() {
            const actions = tile.model.actionList
            if (!actions || actions.length === 0) {
                return
            }
            const menu = menuComponent.createObject(tile)
            actions.forEach(a => {
                if (!a.subActions) {
                    itemComponent.createObject(menu, { actionItem: a })
                }
            })
            menu.statusChanged.connect(() => {
                if (menu.status === PlasmaExtras.Menu.Closed) {
                    menu.destroy()
                }
            })
            menu.openRelative()
        }
        Component {
            id: menuComponent
            PlasmaExtras.Menu {
                visualParent: tile
                placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            }
        }
        Component {
            id: itemComponent
            PlasmaExtras.MenuItem {
                required property var actionItem
                text: actionItem.text ?? ""
                icon: actionItem.icon ?? null
                enabled: actionItem.type !== "title" && (actionItem.enabled ?? true)
                separator: actionItem.type === "separator"
                section: actionItem.type === "title"
                onClicked: {
                    if (tile.appModel.trigger(tile.index, actionItem.actionId, actionItem.actionArgument)) {
                        pad.dismiss()
                    }
                }
            }
        }
    }
}
