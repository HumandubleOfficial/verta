#!/usr/bin/python3
"""Restyle Plasma's lock screen for Verta (run at image build time).

Only the look changes; every line that handles unlocking stays Plasma's own.
Each change replaces an exact piece of Plasma's QML. If Plasma changes those
files in an update, a piece won't match and the build stops with an error,
instead of shipping a lock screen that might not unlock.

  - big, bold clock in Inter Display with the date above it (Apple style)
  - your picture and the password field low on the screen, under the clock
  - soft dark gradients so the clock and buttons read on any wallpaper
  - glass, pill-shaped password field that brightens when focused
  - round accent-coloured unlock button that grows slightly on hover
  - the clock glides down into place when the lock screen appears
"""
import sys
from pathlib import Path

LOCK = Path("/usr/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen")


def patch(path, edits):
    text = path.read_text()
    for old, new in edits:
        count = text.count(old)
        if count != 1:
            sys.exit(f"verta-lockscreen: expected 1 match in {path.name}, found {count}:\n{old}")
        text = text.replace(old, new)
    path.write_text(text)
    print(f"verta-lockscreen: patched {path}")


patch(LOCK / "LockScreenUi.qml", [
    # Gradients behind the clock (top) and the buttons (bottom).
    ("""        DropShadow {
            id: clockShadow""",
     """        // Verta: soft gradients so the clock and footer read on any wallpaper.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.42) }
                GradientStop { position: 0.38; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
            }
        }

        DropShadow {
            id: clockShadow"""),

    # Verta clock: date over a big light time, high on the screen.
    ("""        Clock {
            id: clock
            property Item shadow: clockShadow
            visible: y > 0 && config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter
            y: (mainBlock.userList.y + mainStack.y)/2 - height/2
            Layout.alignment: Qt.AlignBaseline
        }""",
     """        Item {
            id: clock
            property Item shadow: clockShadow
            property date now: new Date()
            visible: config.alwaysShowClock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.08)
            width: vertaClock.implicitWidth
            height: vertaClock.implicitHeight
            transform: Translate { id: clockSlide; y: -28 }

            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clock.now = new Date()
            }

            ColumnLayout {
                id: vertaClock
                spacing: 0
                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: clock.now.toLocaleDateString(Qt.locale(), "dddd d MMMM")
                    font.family: "Inter"
                    font.pointSize: Math.max(14, lockScreenRoot.height / 50)
                    font.weight: Font.DemiBold
                    color: "white"
                    opacity: 0.88
                }
                PlasmaComponents3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    // Inter's display cut, drawn for big sizes: the time reads
                    // like one solid shape rather than a row of digits.
                    text: clock.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                    font.family: "Inter Display"
                    font.pointSize: Math.max(64, lockScreenRoot.height / 8)
                    font.weight: Font.DemiBold
                    font.letterSpacing: -3
                    font.features: { "tnum": 1 }
                    color: "white"
                    opacity: 0.94
                }
            }

            NumberAnimation {
                running: true
                target: clockSlide
                property: "y"
                to: 0
                duration: Kirigami.Units.veryLongDuration * 2
                easing.type: Easing.OutCubic
            }
        }"""),

    # Your picture and the password field sit low on the screen, under the
    # clock, instead of in the middle of the wallpaper. They move back up
    # while the on-screen keyboard is open so it can't cover them.
    ("""            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3
""",
     """            height: lockScreenRoot.height + Kirigami.Units.gridUnit * 3
            transform: Translate {
                y: Keyboards.KWinVirtualKeyboard.visible ? 0 : Math.round(lockScreenRoot.height * 0.2)
                Behavior on y { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic } }
            }
"""),
])

patch(LOCK / "MainBlock.qml", [
    # Glass pill password field.
    ("""            cursorVisible: visible
""",
     """            cursorVisible: visible

            // Verta: glass pill that brightens while focused.
            implicitHeight: Kirigami.Units.gridUnit * 2.4
            leftPadding: Kirigami.Units.gridUnit
            background: Rectangle {
                radius: height / 2
                color: Qt.rgba(1, 1, 1, passwordBox.activeFocus ? 0.20 : 0.12)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, passwordBox.activeFocus ? 0.50 : 0.24)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }
"""),
    # Round accent unlock button.
    ("""            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"
""",
     """            icon.name: LayoutMirroring.enabled ? "go-previous" : "go-next"

            // Verta: round accent button that grows a little on hover.
            icon.color: "white"
            scale: pressed ? 0.94 : (hovered ? 1.06 : 1)
            Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic } }
            background: Rectangle {
                radius: width / 2
                color: loginButton.pressed ? Qt.darker(Kirigami.Theme.highlightColor, 1.2)
                     : loginButton.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.12)
                     : Kirigami.Theme.highlightColor
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }
"""),
])
