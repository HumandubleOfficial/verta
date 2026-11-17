/*
    Verta Shell's look: Windows 11-style acrylic surfaces (blurred, tinted,
    one fine border), 8 px rounded flyouts, 4 px rounded buttons, Inter.
    Dark or light follows the system colour scheme; the accent follows the
    accent colour chosen in Settings.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma Singleton
import QtQuick

QtObject {
    readonly property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }
    readonly property bool dark: palette.window.hslLightness < 0.5

    // Surfaces (drawn over KWin's blur, so these are the acrylic tints).
    readonly property color taskbar: dark ? Qt.rgba(0.11, 0.11, 0.12, 0.84) : Qt.rgba(0.95, 0.95, 0.96, 0.86)
    readonly property color flyout: dark ? Qt.rgba(0.14, 0.14, 0.15, 0.90) : Qt.rgba(0.97, 0.97, 0.98, 0.92)
    readonly property color footer: dark ? Qt.rgba(0, 0, 0, 0.14) : Qt.rgba(0, 0, 0, 0.03)
    readonly property color card: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.70)
    readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.80)
    readonly property color stroke: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color divider: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)

    // Controls.
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.03)
    readonly property color selected: dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color accent: dark ? Qt.lighter(palette.highlight, 1.45) : palette.highlight
    readonly property color accentText: dark ? "#000000" : "#ffffff"

    // Text.
    readonly property color text: dark ? "#ffffff" : "#1b1b1b"
    readonly property color textDim: dark ? Qt.rgba(1, 1, 1, 0.74) : Qt.rgba(0, 0, 0, 0.62)
    readonly property color textFaint: dark ? Qt.rgba(1, 1, 1, 0.50) : Qt.rgba(0, 0, 0, 0.44)

    readonly property string font: "Inter"
    readonly property int radius: 8          // flyouts and the Start menu
    readonly property int controlRadius: 4   // buttons on the taskbar and in menus
    readonly property int taskbarHeight: 48

    // Motion: Windows 11 flyouts decelerate into place.
    readonly property int fast: 120
    readonly property int normal: 220
}
