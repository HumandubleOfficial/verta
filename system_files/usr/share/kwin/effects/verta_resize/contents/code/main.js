/*
    Verta Resize: maximising and restoring a window (title-bar button,
    double-click, dragging to the top edge, Meta+Up) morphs it smoothly from
    its old size and place to the new one, cross-fading old and new content,
    with a quick start and a soft landing. Fullscreen games are never touched.

    Based on KWin's Maximize effect.
    SPDX-FileCopyrightText: 2012 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/

"use strict";

class VertaResize {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(window => window.setData(Effect.WindowForceBlurRole, null));
        effects.windowAdded.connect(this.manage.bind(this));
        for (const window of effects.stackingOrder) {
            this.manage(window);
        }
        this.loadConfig();
    }

    loadConfig() {
        this.duration = animationTime(effect.readConfig("Duration", 300));
    }

    manage(window) {
        window.windowFrameGeometryChanged.connect(this.onGeometryChanged.bind(this));
        window.windowMaximizedStateChanged.connect(this.onMaximized.bind(this));
        window.windowMaximizedStateAboutToChange.connect(this.onAboutToMaximize.bind(this));
    }

    static skip(window) {
        return !window.visible || window.fullScreen || effects.hasActiveFullScreenEffect;
    }

    onAboutToMaximize(window) {
        if (VertaResize.skip(window)) {
            return;
        }
        window.vertaOldGeometry = Object.assign({}, window.geometry);
        if (window.vertaMorph) {
            cancel(window.vertaMorph);
            delete window.vertaMorph;
        }
        // Old picture fades out while the new one takes over.
        if (!window.vertaFade || !retarget(window.vertaFade, 1.0, this.duration)) {
            window.vertaFade = animate({
                window,
                duration: this.duration,
                animations: [{ type: Effect.CrossFadePrevious, from: 0.0, to: 1.0, curve: QEasingCurve.OutCubic }],
            });
        }
    }

    onMaximized(window) {
        if (VertaResize.skip(window) || !window.vertaOldGeometry) {
            return;
        }
        window.setData(Effect.WindowForceBlurRole, true);
        const from = window.vertaOldGeometry;
        const to = window.geometry;
        window.vertaMorph = animate({
            window,
            duration: this.duration,
            animations: [{
                type: Effect.Size,
                from: { value1: from.width, value2: from.height },
                to: { value1: to.width, value2: to.height },
                curve: QEasingCurve.OutQuint,
            }, {
                type: Effect.Translation,
                from: {
                    value1: from.x - to.x - (to.width / 2 - from.width / 2),
                    value2: from.y - to.y - (to.height / 2 - from.height / 2),
                },
                to: { value1: 0, value2: 0 },
                curve: QEasingCurve.OutQuint,
            }],
        });
        // End both animations on the same frame.
        retarget(window.vertaFade, 1.0, this.duration);
    }

    onGeometryChanged(window, oldGeometry) {
        if (!window.vertaMorph
                || (window.geometry.width == oldGeometry.width && window.geometry.height == oldGeometry.height)
                || (window.vertaOldGeometry.width == oldGeometry.width
                    && window.vertaOldGeometry.height == oldGeometry.height)) {
            return;
        }
        // Resized again half-way through: stop morphing, show the real thing.
        cancel(window.vertaMorph);
        delete window.vertaMorph;
        if (window.vertaFade) {
            cancel(window.vertaFade);
            delete window.vertaFade;
        }
    }
}

new VertaResize();
