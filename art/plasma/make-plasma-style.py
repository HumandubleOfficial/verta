#!/usr/bin/env python3
"""Generate the "Verta" Plasma Style (taskbar, popups, tooltips, highlights).

Plasma draws panels and popups from "frame" SVGs: nine named pieces (four
corners, four edges, centre) per state, stretched to size. This script draws
those pieces from a few parameters so the whole style stays consistent:

  * glass taskbar and popups: translucent, rounded, a hairline rim, soft shadow
    and a blur mask that follows the rounded corners
  * task buttons like Windows 11: a short dash under running apps, a longer
    accent-coloured dash under the active one, a soft rounded pill on hover
  * rounded hover/selection pills in menus and lists (Start menu, tray, ...)

Colours use Plasma's ColorScheme-* classes, so the style follows Verta Dark,
Verta Light and the accent colour automatically. Anything not drawn here
falls back to Plasma's stock style.

    python3 -I make-plasma-style.py <output-dir>     (writes <output-dir>/verta)
"""
import json
import os
import sys

OUT = os.path.join(sys.argv[1] if len(sys.argv) > 1 else "out", "verta")

STYLE = ('<style type="text/css" id="current-color-scheme">'
         '.ColorScheme-Background{color:#0d1220;}'
         '.ColorScheme-Text{color:#e6ebf5;}'
         '.ColorScheme-Highlight{color:#3b82f6;}'
         '.ColorScheme-NeutralText{color:#f59e0b;}'
         '</style>')

E = 12  # length of the stretchable edge/centre pieces


def paint(cls, alpha):
    """Fill attributes for a theme colour at some opacity."""
    if cls is None:
        return 'fill="#000" fill-opacity="0"'
    if cls == "black":
        return f'fill="#000" fill-opacity="{alpha}"'
    return f'class="ColorScheme-{cls}" style="fill:currentColor;fill-opacity:{alpha}"'


class Sheet:
    """One SVG file; frames are laid out left to right so they don't overlap."""

    def __init__(self):
        self.parts = []
        self.defs = []
        self.x = 0

    def add(self, s):
        self.parts.append(s)

    def frame(self, prefix, r, fill, rim=None, cw=None, ch=None, dash=None, hints=None, stretch=False):
        """A rounded frame.

        r      corner radius;  cw/ch  corner piece size (>= r), i.e. border sizes
        fill   (class, alpha) of the body;  rim  (class, alpha) 1px inner outline
        dash   (class, alpha) indicator line along the bottom, inset by cw on
               both sides (so its length = width - 2*cw), with rounded ends
        hints  (top, right, bottom, left) content margins
        """
        cw = cw or r
        ch = ch or r
        p = f"{prefix}-" if prefix else ""
        ox, oy = self.x, 0
        W, H = 2 * cw + E, 2 * ch + E
        self.x += W + 20
        f = paint(*fill)

        def cell(name, x, y, w, h, body):
            self.add(f'<g id="{p}{name}" transform="translate({ox + x} {oy + y})">{body}</g>')

        def corner_path(w, h, rr, which):
            # A w*h cell with one rounded corner of radius rr (the outer one).
            if which == "topleft":
                return f"M0 {h} V{rr} A{rr} {rr} 0 0 1 {rr} 0 H{w} V{h} Z"
            if which == "topright":
                return f"M0 0 H{w - rr} A{rr} {rr} 0 0 1 {w} {rr} V{h} H0 Z"
            if which == "bottomright":
                return f"M0 0 H{w} V{h - rr} A{rr} {rr} 0 0 1 {w - rr} {h} H0 Z"
            return f"M0 0 H{w} V{h} H{rr} A{rr} {rr} 0 0 1 0 {h - rr} Z"

        def rim_corner(w, h, rr, which):
            if not rim:
                return ""
            s = 'fill="none" stroke-width="1" ' + paint(*rim).replace("fill", "stroke")
            q = rr - 0.5
            if which == "topleft":
                d = f"M0.5 {h} V{rr} A{q} {q} 0 0 1 {rr} 0.5 H{w}"
            elif which == "topright":
                d = f"M0 0.5 H{w - rr} A{q} {q} 0 0 1 {w - 0.5} {rr} V{h}"
            elif which == "bottomright":
                d = f"M{w - 0.5} 0 V{h - rr} A{q} {q} 0 0 1 {w - rr} {h - 0.5} H0"
            else:
                d = f"M{w} {h - 0.5} H{rr} A{q} {q} 0 0 1 0.5 {h - rr} V0"
            return f'<path d="{d}" {s}/>'

        def rim_rect(x, y, w, h):
            return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {paint(*rim)}/>' if rim else ""

        def dash_body(kind):
            if not dash:
                return ""
            dy, dh = ch - 5, 3
            d = paint(*dash)
            if kind == "bottom":
                return f'<rect x="0" y="{dy}" width="{E}" height="{dh}" {d}/>'
            if kind == "bottomleft":    # rounded left end of the dash
                return f'<path d="M{cw} {dy} A1.5 1.5 0 0 0 {cw} {dy + dh} Z" {d}/>'
            if kind == "bottomright":   # rounded right end
                return f'<path d="M0 {dy} A1.5 1.5 0 0 1 0 {dy + dh} Z" {d}/>'
            return ""

        for which, x, y in (("topleft", 0, 0), ("topright", cw + E, 0),
                            ("bottomright", cw + E, ch + E), ("bottomleft", 0, ch + E)):
            cell(which, x, y, cw, ch,
                 f'<path d="{corner_path(cw, ch, r, which)}" {f}/>' + rim_corner(cw, ch, r, which) + dash_body(which))
        cell("top", cw, 0, E, ch, f'<rect width="{E}" height="{ch}" {f}/>' + rim_rect(0, 0, E, 1))
        cell("bottom", cw, ch + E, E, ch,
             f'<rect width="{E}" height="{ch}" {f}/>' + rim_rect(0, ch - 1, E, 1) + dash_body("bottom"))
        cell("left", 0, ch, cw, E, f'<rect width="{cw}" height="{E}" {f}/>' + rim_rect(0, 0, 1, E))
        cell("right", cw + E, ch, cw, E, f'<rect width="{cw}" height="{E}" {f}/>' + rim_rect(cw - 1, 0, 1, E))
        cell("center", cw, ch, E, E, f'<rect width="{E}" height="{E}" {f}/>')

        if hints:
            t, rt, b, lf = hints
            hy = oy + H + 4
            for name, w, h in (("hint-top-margin", 4, t), ("hint-right-margin", rt, 4),
                               ("hint-bottom-margin", 4, b), ("hint-left-margin", lf, 4)):
                self.add(f'<rect id="{p}{name}" x="{ox}" y="{hy}" width="{max(w, 0.01)}" '
                         f'height="{max(h, 0.01)}" fill="none"/>')
                hy += 8
        if stretch:
            self.add(f'<rect id="{p}hint-stretch-borders" x="{ox}" y="{oy + H + 40}" width="1" height="1" fill="none"/>')

    def shadow(self, size, alpha, prefix="shadow"):
        """Soft drop shadow pieces around a frame (slightly heavier below)."""
        s = size
        ox = self.x
        self.x += 2 * s + E + 20
        uid = prefix.replace("-", "")

        def grad(gid, x1, y1, x2, y2):
            self.defs.append(
                f'<linearGradient id="{uid}{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
                f'<stop offset="0" stop-color="#000" stop-opacity="{alpha}"/>'
                f'<stop offset="0.5" stop-color="#000" stop-opacity="{alpha * 0.35}"/>'
                f'<stop offset="1" stop-color="#000" stop-opacity="0"/></linearGradient>')

        def rad(gid, cx, cy):
            self.defs.append(
                f'<radialGradient id="{uid}{gid}" cx="{cx}" cy="{cy}" r="{s}" gradientUnits="userSpaceOnUse">'
                f'<stop offset="0" stop-color="#000" stop-opacity="{alpha}"/>'
                f'<stop offset="0.5" stop-color="#000" stop-opacity="{alpha * 0.35}"/>'
                f'<stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>')

        grad("t", 0, 1, 0, 0)
        grad("b", 0, 0, 0, 1)
        grad("l", 1, 0, 0, 0)
        grad("r", 0, 0, 1, 0)
        rad("tl", s, s)
        rad("tr", 0, s)
        rad("bl", s, 0)
        rad("br", 0, 0)
        pieces = (("topleft", 0, 0, s, s, "tl"), ("top", s, 0, E, s, "t"), ("topright", s + E, 0, s, s, "tr"),
                  ("left", 0, s, s, E, "l"), ("right", s + E, s, s, E, "r"),
                  ("bottomleft", 0, s + E, s, s, "bl"), ("bottom", s, s + E, E, s, "b"),
                  ("bottomright", s + E, s + E, s, s, "br"))
        for name, x, y, w, h, g in pieces:
            self.add(f'<g id="{prefix}-{name}" transform="translate({ox + x} {y})">'
                     f'<rect width="{w}" height="{h}" fill="url(#{uid}{g})"/></g>')

    def write(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        w, h = max(self.x, 1), 200
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
                     f'<defs>{STYLE}{"".join(self.defs)}</defs>{"".join(self.parts)}</svg>\n')


def glass(path, r, alpha, hints, shadow=None, rim_alpha=0.10):
    """Translucent rounded background + matching blur mask (+ shadow)."""
    sh = Sheet()
    sh.frame("", r, ("Background", alpha), rim=("Text", rim_alpha), hints=hints)
    sh.frame("mask", r, ("black", 1))
    if shadow:
        sh.shadow(*shadow)
    sh.write(os.path.join(OUT, path))


def tasks(path):
    """Taskbar buttons (normal = running, focus = active, launcher = pinned)."""
    sh = Sheet()
    hints = (3, 3, 4, 3)
    hover = ("Text", 0.10)
    hover_rim = ("Text", 0.07)
    idle_dash = ("Text", 0.45)
    accent = ("Highlight", 1)
    warn = ("NeutralText", 1)
    # Corner width sets the dash length: wider corners -> shorter dash.
    short, long_ = 17, 12
    states = {
        # prefix:            (fill,                rim,       dash,      corner width)
        "launcher-hover":    (hover,               hover_rim, None,      long_),
        "hover":             (hover,               hover_rim, None,      long_),
        "normal":            ((None, 0),           None,      idle_dash, short),
        "normal-hover":      (hover,               hover_rim, ("Text", 0.6), short),
        "minimized":         ((None, 0),           None,      ("Text", 0.3), short),
        "minimized-hover":   (hover,               hover_rim, ("Text", 0.45), short),
        "focus":             (("Text", 0.07),      ("Text", 0.06), accent, long_),
        "focus-hover":       (("Text", 0.12),      hover_rim, accent,    long_),
        "attention":         (("NeutralText", 0.14), None,    warn,      long_),
        "attention-hover":   (("NeutralText", 0.22), None,    warn,      long_),
        "progress":          (("Highlight", 0.22), None,      None,      long_),
    }
    for prefix, (fill, rim, dash, cw) in states.items():
        sh.frame(prefix, 7, fill, rim=rim, cw=cw, ch=8, dash=dash, hints=hints, stretch=True)
    sh.write(os.path.join(OUT, path))


def viewitem(path):
    """Hover / selection pills in the Start menu, tray and other lists."""
    sh = Sheet()
    for prefix, a, ra in (("hover", 0.16, 0.22), ("selected", 0.28, 0.40), ("selected+hover", 0.34, 0.48)):
        sh.frame(prefix, 7, ("Highlight", a), rim=("Highlight", ra), hints=(4, 6, 4, 6))
    sh.write(os.path.join(OUT, path))


def main():
    # Taskbar: normal / glass (blur available) / solid (a window is maximised).
    panel_shadow = (18, 0.30)
    glass("widgets/panel-background.svg", 16, 0.92, (4, 8, 4, 8), panel_shadow)
    glass("translucent/widgets/panel-background.svg", 16, 0.62, (4, 8, 4, 8), panel_shadow)
    glass("solid/widgets/panel-background.svg", 16, 0.98, (4, 8, 4, 8), panel_shadow)
    # Popups (Start menu, tray, calendar) and tooltips.
    glass("dialogs/background.svg", 14, 0.95, (8, 8, 8, 8), (22, 0.35))
    glass("translucent/dialogs/background.svg", 14, 0.80, (8, 8, 8, 8), (22, 0.35))
    glass("widgets/tooltip.svg", 10, 0.95, (6, 8, 6, 8), (14, 0.28))
    glass("translucent/widgets/tooltip.svg", 10, 0.84, (6, 8, 6, 8), (14, 0.28))
    tasks("widgets/tasks.svg")
    viewitem("widgets/viewitem.svg")

    meta = {
        "KPlugin": {
            "Authors": [{"Name": "Verta"}],
            "Description": "Verta glass: frosted taskbar and popups, Windows 11-style app indicators",
            "Id": "verta",
            "Name": "Verta",
            "Version": "1.0",
            "Website": "https://github.com/HumandubleOfficial/verta",
        },
        "X-Plasma-API": "5.0",
    }
    with open(os.path.join(OUT, "metadata.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, indent=4)
        fh.write("\n")
    with open(os.path.join(OUT, "plasmarc"), "w", encoding="utf-8") as fh:
        fh.write("[AdaptiveTransparency]\nenabled=true\n\n"
                 "[BlurBehindEffect]\nenabled=true\n\n"
                 "[ContrastEffect]\nenabled=true\ncontrast=0.3\nintensity=1.0\nsaturation=1.8\n")
    print(f"Wrote Plasma style to {OUT}")


main()
