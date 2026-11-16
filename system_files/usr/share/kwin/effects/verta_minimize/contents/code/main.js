/*
    Verta Minimise: windows glide into their taskbar icon when minimised and
    spring back out of it when restored.

    The window shrinks toward the icon while it fades, picking up speed like it
    is being pulled in; restoring plays it the other way with a soft landing.
    Clicking the taskbar icon again mid-animation simply reverses it.
    Fullscreen windows (games) are never animated.

    Based on KWin's Squash effect.
    SPDX-FileCopyrightText: 2018 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/

"use strict";

class VertaMinimize {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(window => window.setData(Effect.WindowForceBlurRole, null));
        effects.windowAdded.connect(this.watch.bind(this));
        for (const window of effects.stackingOrder) {
            this.watch(window);
        }
        this.loadConfig();
    }

    loadConfig() {
        this.outDuration = animationTime(effect.readConfig("MinimizeDuration", 300));
        this.inDuration = animationTime(effect.readConfig("RestoreDuration", 320));
    }

    watch(window) {
        window.minimizedChanged.connect(() => {
            if (window.minimized) {
                this.minimize(window);
            } else {
                this.restore(window);
            }
        });
    }

    // Where the window goes: its taskbar icon, or (no icon) just below the
    // window, towards the taskbar.
    static target(window) {
        const w = window.geometry;
        let icon = window.iconGeometry;
        if (icon.width == 0 || icon.height == 0) {
            icon = {
                x: w.x + w.width * 0.35,
                y: w.y + w.height * 0.9,
                width: w.width * 0.3,
                height: w.height * 0.3,
            };
        }
        return {
            size: { value1: Math.max(icon.width, 1), value2: Math.max(icon.height, 1) },
            offset: {
                value1: icon.x - w.x - (w.width - icon.width) / 2,
                value2: icon.y - w.y - (w.height - icon.height) / 2,
            },
            full: { value1: w.width, value2: w.height },
        };
    }

    // Turn a running animation around instead of starting over: "other" is
    // the opposite animation, "same" a previous run of this one.
    static reverse(window, other, same) {
        if (window[other]) {
            if (redirect(window[other], Effect.Backward)) {
                return true;
            }
            cancel(window[other]);
            delete window[other];
        }
        if (window[same]) {
            if (redirect(window[same], Effect.Forward)) {
                return true;
            }
            cancel(window[same]);
            delete window[same];
        }
        return false;
    }

    minimize(window) {
        if (effects.hasActiveFullScreenEffect || window.fullScreen) {
            return;
        }
        if (VertaMinimize.reverse(window, "vertaRestore", "vertaMinimize")) {
            return;
        }
        const t = VertaMinimize.target(window);
        window.setData(Effect.WindowForceBlurRole, true);
        window.vertaMinimize = animate({
            window,
            duration: this.outDuration,
            curve: QEasingCurve.InOutCubic,
            keepAlive: false,
            animations: [
                { type: Effect.Size, from: t.full, to: t.size },
                { type: Effect.Translation, from: { value1: 0, value2: 0 }, to: t.offset },
                // Stay solid at first, then fade as it reaches the icon.
                { type: Effect.Opacity, from: 1, to: 0, curve: QEasingCurve.InQuad },
            ],
        });
    }

    restore(window) {
        if (effects.hasActiveFullScreenEffect || window.fullScreen) {
            return;
        }
        if (VertaMinimize.reverse(window, "vertaMinimize", "vertaRestore")) {
            return;
        }
        const t = VertaMinimize.target(window);
        window.setData(Effect.WindowForceBlurRole, true);
        window.vertaRestore = animate({
            window,
            duration: this.inDuration,
            curve: QEasingCurve.OutQuint,
            keepAlive: false,
            animations: [
                { type: Effect.Size, from: t.size, to: t.full },
                { type: Effect.Translation, from: t.offset, to: { value1: 0, value2: 0 } },
                { type: Effect.Opacity, from: 0, to: 1, curve: QEasingCurve.OutCubic },
            ],
        });
    }
}

new VertaMinimize();
