#!/usr/bin/python3
"""Generate Verta's desktop wallpaper: "Flow".

  make-wallpaper.py <out dir> [width height]

Writes flow-dark.jpg and flow-light.jpg (default 3840x2160): a few wide
ribbons of light that sweep across the screen like folded silk, each one
shaded as a curved sheet with a soft sheen running along it and a soft shadow
on whatever lies behind. Everything is computed (numpy), so the same seed
gives the same picture at any size.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


THEMES = {
    "dark": {
        "bg": ("#03050d", "#0a1230", "#040612"),     # top-left, middle, bottom-right
        "glow": ("#1d4ed8", 0.34),
        "sheen": 0.75,
        "sheen_lift": 0.45,
        "shadow": 0.55,
        # ribbon: (edge colour, core colour), centre line, amplitude, thickness
        "ribbons": [
            (("#0b1a4a", "#1e40af"), 0.20, 0.10, 0.20),
            (("#1e1b4b", "#6d28d9"), 0.42, 0.12, 0.17),
            (("#0c2a5c", "#2563eb"), 0.62, 0.11, 0.19),
            (("#082f49", "#0891b2"), 0.80, 0.09, 0.13),
            (("#172554", "#3b82f6"), 1.00, 0.10, 0.16),
        ],
    },
    "light": {
        "bg": ("#f4f7ff", "#e4ecfb", "#f7f8fd"),
        "glow": ("#ffffff", 0.55),
        "sheen": 0.8,
        "sheen_lift": 0.7,
        "shadow": 0.16,
        "ribbons": [
            (("#bfd4fb", "#7aa7f5"), 0.20, 0.10, 0.20),
            (("#d9cdfb", "#a78bfa"), 0.42, 0.12, 0.17),
            (("#b9d3fa", "#5b8def"), 0.62, 0.11, 0.19),
            (("#bdeaf5", "#4cc3dd"), 0.80, 0.09, 0.13),
            (("#c8d8fb", "#6f9cf2"), 1.00, 0.10, 0.16),
        ],
    },
}


def render(theme, w, h, seed=7):
    rng = np.random.default_rng(seed)
    t = THEMES[theme]
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    # Work in a unit square scaled by height so the shapes keep their
    # proportions on any aspect ratio.
    x = xs / h
    y = ys / h
    aspect = w / h

    # Background: three-stop diagonal gradient plus a soft glow.
    d = np.clip((x / aspect + y) / 2, 0, 1)[..., None]
    c0, c1, c2 = (hexrgb(c) for c in t["bg"])
    img = np.where(d < 0.5, c0 + (c1 - c0) * (d / 0.5), c1 + (c2 - c1) * ((d - 0.5) / 0.5))
    gx, gy = 0.62 * aspect, 0.42
    glow = np.exp(-(((x - gx) / (0.9 * aspect)) ** 2 + ((y - gy) / 0.7) ** 2) * 2.2)[..., None]
    gc, ga = hexrgb(t["glow"][0]), t["glow"][1]
    img = img + (gc - img) * glow * ga

    # Ribbons sweep from lower left to upper right: rotate the frame.
    ang = np.deg2rad(-16)
    u = x * np.cos(ang) - y * np.sin(ang)          # along the ribbons
    v0 = x * np.sin(ang) + y * np.cos(ang)         # across them
    px = 1.0 / h                                   # one pixel in these units

    for i, ((edge, core), base, amp, thick) in enumerate(t["ribbons"]):
        p = rng.uniform(0, 2 * np.pi, 4)
        k = rng.uniform(1.6, 2.4)
        centre = (base
                  + amp * np.sin(k * u + p[0])
                  + amp * 0.45 * np.sin(2.3 * k * u + p[1]))
        width = thick * (1 + 0.38 * np.sin(1.3 * k * u + p[2]))
        s = (v0 - centre) / width                  # -1 .. 1 across the ribbon

        # Shadow on what lies behind, falling below the ribbon's lower edge.
        below = np.clip(s - 1, 0, None) * width
        shadow = np.where(s > 1, np.exp(-below / 0.05), 0) * t["shadow"]
        img = img * (1 - shadow[..., None] * 0.9)

        # The sheet curls: brightness follows a cosine across it, and a
        # sheen band wanders from edge to edge along its length.
        inside = smoothstep(1.0 + 1.5 * px / thick, 1.0 - 1.5 * px / thick, np.abs(s))
        across = np.clip((s + 1) / 2, 0, 1)
        curl = 0.5 + 0.5 * np.cos(np.pi * (across - 0.5) * 1.6)
        ec, cc = hexrgb(edge), hexrgb(core)
        col = ec + (cc - ec) * curl[..., None]
        # darker toward the lower edge: the fold turns away from the light
        col = col * (0.72 + 0.28 * (1 - across) ** 0.6)[..., None]
        sheen_pos = 0.5 + 0.38 * np.sin(0.9 * k * u + p[3])
        sheen = np.exp(-((across - sheen_pos) / 0.10) ** 2) * t["sheen"]
        # the sheen is the ribbon's own colour, lit up (not grey-white)
        hi = cc + (1 - cc) * t["sheen_lift"]
        col = col + (hi - col) * sheen[..., None]
        # Thin bright rim along the upper edge catches the light.
        rim = np.exp(-((s + 0.97) / 0.03) ** 2) * 0.35
        col = col + (1 - col) * rim[..., None]
        img = img * (1 - inside[..., None]) + col * inside[..., None]

    # Gentle vignette, then dither so gradients don't band.
    vig = 1 - 0.28 * smoothstep(0.55, 1.25, np.hypot((x / aspect - 0.5) * 1.6, (y - 0.5) * 1.6))
    if theme == "dark":
        img = img * vig[..., None]
    else:
        img = img * (0.94 + 0.06 * vig[..., None])
    img = img + rng.uniform(-1.2, 1.2, img.shape).astype(np.float32) / 255
    return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB")


def main():
    out = Path(sys.argv[1])
    w, h = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (3840, 2160)
    out.mkdir(parents=True, exist_ok=True)
    for theme in THEMES:
        im = render(theme, w, h)
        path = out / f"flow-{theme}.jpg"
        im.save(path, quality=93, subsampling=0, optimize=True)
        print(f"wallpaper: wrote {path}")


if __name__ == "__main__":
    main()
