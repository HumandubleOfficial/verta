#!/usr/bin/python3
"""Generate Verta's window decorations (KWin Aurorae SVG themes).

  make-aurorae.py <output dir>     e.g. system_files/usr/share/aurorae/themes

Writes two themes, "Verta" (dark) and "Verta-Light". Each has a title bar in
the colour scheme's header colour (so it blends into the app like a unified
macOS toolbar) and Verta's own round buttons on the right:

  - at rest: a soft glass circle with a thin, round-capped glyph
    (close X, minimise line, maximise square, restore two squares)
  - on hover the circle fills with colour (close red, minimise amber,
    maximise green) and the glyph turns solid; Aurorae cross-fades the states
  - pressed: a deeper shade; inactive windows: everything quieter

Rounded window corners and shadows come from the Round-Corners KWin effect,
so the decoration itself is square and shadowless.
"""
import json
import sys
from pathlib import Path

S = 24  # button canvas (px)
C = S / 2

GLYPHS = {
    "close": '<path d="M8.6 8.6 15.4 15.4M15.4 8.6 8.6 15.4"/>',
    "minimize": '<path d="M8 12h8"/>',
    "maximize": '<rect x="8.3" y="8.3" width="7.4" height="7.4" rx="2"/>',
    "restore": ('<rect x="7.4" y="9.8" width="6.6" height="6.6" rx="1.7"/>'
                '<path d="M10 9.8V9.1a1.7 1.7 0 0 1 1.7-1.7h3.2a1.7 1.7 0 0 1 1.7 1.7'
                'v3.2a1.7 1.7 0 0 1-1.7 1.7H14"/>'),
}

# Hover / pressed fills (top, bottom of a gentle vertical gradient) and the
# glyph colour drawn on them.
FILLS = {
    "close": (("#fb7185", "#ef4444"), "#dc2626", "#ffffff"),
    "minimize": (("#fcd34d", "#f59e0b"), "#d97706", "#422006"),
    "maximize": (("#4ade80", "#22c55e"), "#16a34a", "#052e16"),
}
FILLS["restore"] = FILLS["maximize"]

THEMES = {
    "Verta": {
        "comment": "Verta's dark window title bar with round buttons",
        "header": "#0a0e1a", "header_inactive": "#0c111e",
        "text": "230,235,245", "text_inactive": "138,148,168",
        "glyph": "#e6ebf5", "rest": ("#ffffff", 0.08), "rest_inactive": ("#ffffff", 0.045),
        "glyph_alpha": 0.82, "glyph_inactive": ("#8a94a8", 0.7),
    },
    "Verta-Light": {
        "comment": "Verta's light window title bar with round buttons",
        "header": "#f6f7fa", "header_inactive": "#f1f3f7",
        "text": "17,24,39", "text_inactive": "107,114,128",
        "glyph": "#111827", "rest": ("#0f172a", 0.065), "rest_inactive": ("#0f172a", 0.04),
        "glyph_alpha": 0.74, "glyph_inactive": ("#6b7280", 0.62),
    },
}


def glyph(kind, color, alpha):
    return (f'<g fill="none" stroke="{color}" stroke-opacity="{alpha}" stroke-width="1.5" '
            f'stroke-linecap="round" stroke-linejoin="round">{GLYPHS[kind]}</g>')


def state(prefix, x, body):
    """One button state, drawn in its own 24x24 cell at column x."""
    # The id sits on an untransformed group (KSvg reads element bounds from it);
    # the shift into its cell happens one level down.
    return (f'<g id="{prefix}-center"><g transform="translate({x} 0)">'
            f'<rect width="{S}" height="{S}" fill="#000000" fill-opacity="0"/>{body}</g></g>')


def button_svg(kind, t):
    top_bottom, pressed, on_glyph = FILLS[kind]
    grad = f"g{kind}"
    rest = lambda fill: f'<circle cx="{C}" cy="{C}" r="9" fill="{fill[0]}" fill-opacity="{fill[1]}"/>'
    filled = (f'<circle cx="{C}" cy="{C}" r="9" fill="url(#{grad})"/>'
              # thin light rim on the top half: a touch of gloss
              f'<path d="M4.2 11.2a7.9 7.9 0 0 1 15.6 0" fill="none" stroke="#ffffff" '
              f'stroke-opacity="0.28" stroke-width="0.8" stroke-linecap="round"/>')
    deep = f'<circle cx="{C}" cy="{C}" r="9" fill="{pressed}"/>'
    states = [
        ("active", rest(t["rest"]) + glyph(kind, t["glyph"], t["glyph_alpha"])),
        ("hover", filled + glyph(kind, on_glyph, 0.9)),
        ("pressed", deep + glyph(kind, on_glyph, 0.85)),
        ("deactivated", rest(t["rest_inactive"]) + glyph(kind, t["glyph"], 0.22)),
        ("inactive", rest(t["rest_inactive"]) + glyph(kind, *t["glyph_inactive"])),
        ("hover-inactive", filled + glyph(kind, on_glyph, 0.9)),
        ("pressed-inactive", deep + glyph(kind, on_glyph, 0.85)),
        ("deactivated-inactive", rest(t["rest_inactive"]) + glyph(kind, t["glyph"], 0.16)),
    ]
    cells = "".join(state(p, i * (S + 4), body) for i, (p, body) in enumerate(states))
    width = len(states) * (S + 4)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{S}" '
            f'viewBox="0 0 {width} {S}"><defs><linearGradient id="{grad}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top_bottom[0]}"/><stop offset="1" stop-color="{top_bottom[1]}"/>'
            f'</linearGradient></defs>{cells}</svg>\n')


def frame(prefix, x0, color):
    """A 3x3 frame (2 px corners/edges) in one solid colour."""
    parts = []
    names = [["topleft", "top", "topright"], ["left", "center", "right"],
             ["bottomleft", "bottom", "bottomright"]]
    for r, row in enumerate(names):
        for c, name in enumerate(row):
            parts.append(f'<rect id="{prefix}-{name}" x="{x0 + c * 2}" y="{r * 2}" '
                         f'width="2" height="2" fill="{color}"/>')
    return "".join(parts)


def decoration_svg(t):
    body = frame("decoration", 0, t["header"]) + frame("decoration-inactive", 8, t["header_inactive"])
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="6" viewBox="0 0 14 6" '
            f'shape-rendering="crispEdges">{body}</svg>\n')


def themerc(t):
    return f"""[General]
ActiveTextColor={t["text"]}
InactiveTextColor={t["text_inactive"]}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=150
Shadow=false
UseTextShadow=false
HaloActive=false
HaloInactive=false
DecorationPosition=0

[Layout]
BorderLeft=1
BorderRight=1
BorderBottom=1
TitleEdgeTop=6
TitleEdgeBottom=6
TitleEdgeLeft=10
TitleEdgeRight=8
TitleEdgeTopMaximized=4
TitleEdgeBottomMaximized=4
TitleEdgeLeftMaximized=10
TitleEdgeRightMaximized=8
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight=24
ButtonWidth=24
ButtonHeight=24
ButtonSpacing=4
ButtonMarginTop=0
ButtonMarginTopMaximized=0
ExplicitButtonSpacer=8
PaddingTop=0
PaddingBottom=0
PaddingLeft=0
PaddingRight=0
"""


def main():
    out = Path(sys.argv[1])
    for name, t in THEMES.items():
        d = out / name
        d.mkdir(parents=True, exist_ok=True)
        (d / "decoration.svg").write_text(decoration_svg(t))
        for kind in GLYPHS:
            (d / f"{kind}.svg").write_text(button_svg(kind, t))
        (d / f"{name}rc").write_text(themerc(t))
        (d / "metadata.desktop").write_text(f"""[Desktop Entry]
Name={name.replace("-", " ")}
Comment={t["comment"]}
X-KDE-PluginInfo-Name={name}
X-KDE-PluginInfo-Author=Verta
X-KDE-PluginInfo-License=GPL-2.0-or-later
X-KDE-PluginInfo-Version=1.0
""")
        (d / "metadata.json").write_text(json.dumps({
            "KPlugin": {
                "Authors": [{"Name": "Verta"}],
                "Description": t["comment"],
                "Id": name,
                "License": "GPL-2.0-or-later",
                "Name": name.replace("-", " "),
                "Version": "1.0",
            },
        }, indent=4) + "\n")
        print(f"aurorae: wrote {d}")


if __name__ == "__main__":
    main()
