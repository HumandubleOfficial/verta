/*
    Sound outputs for Quick Settings (speakers, headphones, HDMI on the
    graphics card, a USB headset), through Plasma's PulseAudio library on
    PipeWire. Click one to make it the output; apps playing now move to it.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.private.volume as PA

ListView {
    id: list
    signal chosen()

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded }

    model: PA.SinkModel {}

    delegate: ListRow {
        required property var model
        readonly property string kind: (model.Name || "") + " " + (model.Description || "")
        width: list.width
        iconName: /hdmi|displayport/i.test(kind) ? "video-display"
                : /headphone|headset/i.test(kind) ? "audio-headphones"
                : /bluez|bluetooth/i.test(kind) ? "audio-headphones"
                : /usb/i.test(kind) ? "audio-card"
                : "audio-speakers"
        title: model.Description || model.Name || ""
        subtitle: model.Default ? "In use" : ""
        current: model.Default === true
        onClicked: {
            if (model.PulseObject) {
                model.PulseObject.default = true
            }
            list.chosen()
        }
    }
}
