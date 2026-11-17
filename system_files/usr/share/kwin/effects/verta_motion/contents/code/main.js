/*
    Verta Motion: how windows, menus and tooltips appear and disappear.

    Windows rise into place while growing and fading in (fast out, gentle
    landing), and sink back slightly as they close. Menus and popups drop in
    with a small scale; tooltips just fade. Fullscreen windows (games) are never
    animated, so launching or quitting a game is instant.

    Based on KWin's Scale effect.
    SPDX-FileCopyrightText: 2018, 2021 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/

"use strict";

const skipped = {
    // The logout screen and login splash have their own effects.
    "ksmserver ksmserver": [],
    "ksmserver-logout-greeter ksmserver-logout-greeter": [],
    "ksplashqml ksplashqml": [],
    // Spectacle's region selector must appear instantly.
    "spectacle org.kde.spectacle": ["region-editor"],
};

class VertaMotion {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.cleanupForcedRoles.bind(this));
        effects.windowAdded.connect(this.slotWindowAdded.bind(this));
        effects.windowClosed.connect(this.slotWindowClosed.bind(this));
        effects.windowDataChanged.connect(this.slotWindowDataChanged.bind(this));
        this.loadConfig();
    }

    loadConfig() {
        // animationTime() applies the global animation speed (Settings ->
        // Appearance -> Animation speed).
        this.windowIn = animationTime(effect.readConfig("WindowInDuration", 280));
        this.windowOut = animationTime(effect.readConfig("WindowOutDuration", 200));
        this.popupIn = animationTime(effect.readConfig("PopupInDuration", 150));
        this.popupOut = animationTime(effect.readConfig("PopupOutDuration", 110));
    }

    // "window", "panel", "popup", "tooltip" or null (leave alone).
    static kind(window) {
        if (window.windowClass == "plasmashell plasmashell"
                || window.windowClass == "plasmashell org.kde.plasmashell") {
            // The Start menu opens in the middle of the screen: it rises and
            // grows into place. Plasma's other popups (tray, calendar) slide
            // out of the bar with the Sliding Popups effect; only its dialogs
            // animate here.
            if (window.caption == "Verta Start") {
                return "panel";
            }
            return window.hasDecoration ? "window" : null;
        }
        const tags = skipped[window.windowClass];
        if (tags && (tags.length === 0 || tags.includes(window.tag))) {
            return null;
        }
        if (window.lockScreen || window.outline || window.desktopWindow
                || window.dock || window.splash || window.fullScreen) {
            return null;
        }
        if (window.tooltip) {
            return "tooltip";
        }
        if (window.popupMenu || window.dropdownMenu || window.comboBox
                || window.notification || window.criticalNotification
                || window.onScreenDisplay) {
            return "popup";
        }
        if (window.hasDecoration) {
            return "window";
        }
        if (window.popupWindow || !window.managed) {
            return null;
        }
        return (window.normalWindow || window.dialog) ? "window" : null;
    }

    setupForcedRoles(window) {
        // Keep translucent windows frosted while they animate.
        window.setData(Effect.WindowForceBackgroundContrastRole, true);
        window.setData(Effect.WindowForceBlurRole, true);
    }

    cleanupForcedRoles(window) {
        window.setData(Effect.WindowForceBackgroundContrastRole, null);
        window.setData(Effect.WindowForceBlurRole, null);
    }

    slotWindowAdded(window) {
        if (effects.hasActiveFullScreenEffect || !window.visible) {
            return;
        }
        const kind = VertaMotion.kind(window);
        if (!kind || effect.isGrabbed(window, Effect.WindowAddedGrabRole)) {
            return;
        }
        this.setupForcedRoles(window);
        let animations;
        let duration;
        let curve;
        if (kind === "window") {
            duration = this.windowIn;
            curve = QEasingCurve.OutQuint;
            animations = [
                { type: Effect.Scale, from: 0.9 },
                { type: Effect.Translation, from: { value1: 0, value2: 22 } },
                { type: Effect.Opacity, from: 0 },
            ];
        } else if (kind === "panel") {
            duration = this.windowIn;
            curve = QEasingCurve.OutQuint;
            animations = [
                { type: Effect.Scale, from: 0.94 },
                { type: Effect.Translation, from: { value1: 0, value2: 28 } },
                { type: Effect.Opacity, from: 0 },
            ];
        } else if (kind === "popup") {
            duration = this.popupIn;
            curve = QEasingCurve.OutCubic;
            animations = [
                { type: Effect.Scale, from: 0.96 },
                { type: Effect.Translation, from: { value1: 0, value2: -6 } },
                { type: Effect.Opacity, from: 0 },
            ];
        } else {
            duration = this.popupIn;
            curve = QEasingCurve.OutCubic;
            animations = [{ type: Effect.Opacity, from: 0 }];
        }
        window.vertaInAnimation = animate({ window, duration, curve, animations });
    }

    slotWindowClosed(window) {
        if (effects.hasActiveFullScreenEffect || !window.visible || window.skipsCloseAnimation) {
            return;
        }
        const kind = VertaMotion.kind(window);
        if (!kind || effect.isGrabbed(window, Effect.WindowClosedGrabRole)) {
            return;
        }
        if (window.vertaInAnimation) {
            cancel(window.vertaInAnimation);
            delete window.vertaInAnimation;
        }
        this.setupForcedRoles(window);
        let animations;
        let duration;
        if (kind === "window") {
            // Closing: shrinks back and fades, starting at once (no slow
            // wind-up), so the window feels like it gets put away.
            duration = this.windowOut;
            animations = [
                { type: Effect.Scale, to: 0.86, curve: QEasingCurve.OutQuart },
                { type: Effect.Translation, to: { value1: 0, value2: 10 }, curve: QEasingCurve.OutQuart },
                { type: Effect.Opacity, to: 0, curve: QEasingCurve.OutCubic },
            ];
        } else if (kind === "popup" || kind === "panel") {
            duration = this.popupOut;
            animations = [
                { type: Effect.Scale, to: 0.97 },
                { type: Effect.Opacity, to: 0 },
            ];
        } else {
            duration = this.popupOut;
            animations = [{ type: Effect.Opacity, to: 0 }];
        }
        window.vertaOutAnimation = animate({ window, duration, curve: QEasingCurve.InQuad, animations });
    }

    slotWindowDataChanged(window, role) {
        if (role == Effect.WindowAddedGrabRole) {
            if (window.vertaInAnimation && effect.isGrabbed(window, role)) {
                cancel(window.vertaInAnimation);
                delete window.vertaInAnimation;
                this.cleanupForcedRoles(window);
            }
        } else if (role == Effect.WindowClosedGrabRole) {
            if (window.vertaOutAnimation && effect.isGrabbed(window, role)) {
                cancel(window.vertaOutAnimation);
                delete window.vertaOutAnimation;
                this.cleanupForcedRoles(window);
            }
        }
    }
}

new VertaMotion();
