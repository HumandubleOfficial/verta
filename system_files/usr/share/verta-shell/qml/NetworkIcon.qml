/*
    The network icon on the taskbar (Wi-Fi strength, cable, or offline),
    from Plasma's network back end. Loaded with a Loader, so the taskbar
    still works if that back end is missing.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM

Kirigami.Icon {
    source: connectionIcon.connectionIcon || "network-wired"
    isMask: true
    color: Theme.text

    PlasmaNM.NetworkStatus {
        id: networkStatus
    }
    PlasmaNM.ConnectionIcon {
        id: connectionIcon
        connectivity: networkStatus.connectivity
    }
}
