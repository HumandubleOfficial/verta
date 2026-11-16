#!/usr/bin/python3
"""Generate Verta's window decorations (KWin Aurorae SVG themes).

  make-aurorae.py <output dir>     e.g. system_files/usr/share/aurorae/themes

Writes two themes, "Verta" (dark) and "Verta-Light". Each has a title bar in
the colour scheme's header colour (so it blends into the app like a unified
toolbar), a centred title, and three coloured dots for the window buttons:

  - close red, minimise amber, maximise green, each a small flat dot with a
    thin darker rim; the symbol (x, -, two arrows) appears on hover
  - pressed: a deeper shade
  - windows in the background: all three dots turn a quiet grey, and light up
    again under the pointer

Each dot sits in a 24 px square so it stays easy to hit. The dots go on the
left (Dock layout) or right (Taskbar layout); kwinrc decides which.

Rounded window corners and shadows come from the Round-Corners KWin effect,
so the decoration itself is square and shadowless.
"""
import json
import sys
from pathlib import Path

S = 24          # button canvas (px): the click target
C = S / 2
R = 7           # dot radius: a 14 px dot

# Symbols, drawn small inside the dot.
GLYPHS = {
    "close": ('stroke', '<path d="M9.6 9.6 14.4 14.4M14.4 9.6 9.6 14.4"/>'),
    "minimize": ('stroke', '<path d="M9.2 12h5.6"/>'),
    # two small triangles pointing out (make bigger) ...
    "maximize": ('fill', '<path d="M9.3 13.4V9.3h4.1z"/><path d="M14.7 10.6v4.1h-4.1z"/>'),
    # ... and pointing in (make smaller again)
    "restore": ('fill', '<path d="M11.4 11.4H8.4l3-3z"/><path d="M12.6 12.6h3l-3 3z"/>'),
}

# Dot colours: (top, bottom) of a gentle gradient, pressed, rim.
FILLS = {
    "close": (("#ff7a70", "#f0473f"), "#c9352e", "#b8322b"),
    "minimize": (("#ffd25a", "#f4ab1f"), "#cf8a10", "#b9800f"),
    "maximize": (("#4fdc78", "#25b84c"), "#1c913b", "#1a8a37"),
}
FILLS["restore"] = FILLS["maximize"]
GLYPH_ON_DOT = ("#000000", 0.55)

THEMES = {
    "Verta": {
        "comment": "Verta's dark window title bar with coloured button dots",
        "header": "#0a0e1a", "header_inactive": "#0c111e",
        "text": "230,235,245", "text_inactive": "138,148,168",
        "idle": ("#3a4152", "#2c3241"),       # background windows: grey dots
        "idle_rim": "#4a5266",
    },
    "Verta-Light": {
        "comment": "Verta's light window title bar with coloured button dots",
        "header": "#f6f7fa", "header_inactive": "#f1f3f7",
        "text": "17,24,39", "text_inactive": "107,114,128",
        "idle": ("#d9dce3", "#ccd0d8"),
        "idle_rim": "#bfc4ce",
    },
}


def glyph(kind, color, alpha):
    mode, body = GLYPHS[kind]
    if mode == "stroke":
        return (f'<g fill="none" stroke="{color}" stroke-opacity="{alpha}" stroke-width="1.35" '
                f'stroke-linecap="round" stroke-linejoin="round">{body}</g>')
    return f'<g fill="{color}" fill-opacity="{alpha}" stroke="none">{body}</g>'


def dot(fill, rim, gloss=False):
    """A dot: fill (a colour or url(#id)), a 0.6 px rim just inside its edge,
    and (optionally) a faint highlight on the top half."""
    out = (f'<circle cx="{C}" cy="{C}" r="{R}" fill="{fill}"/>'
           f'<circle cx="{C}" cy="{C}" r="{R - 0.3}" fill="none" stroke="{rim}" '
           f'stroke-opacity="0.55" stroke-width="0.6"/>')
    if gloss:
        out += (f'<ellipse cx="{C}" cy="{C - 3.2}" rx="4.4" ry="2.4" fill="#ffffff" '
                f'fill-opacity="0.22"/>')
    return out


def state(prefix, x, body):
    """One button state, drawn in its own 24x24 cell at column x."""
    # The id sits on an untransformed group (KSvg reads element bounds from it);
    # the shift into its cell happens one level down.
    return (f'<g id="{prefix}-center"><g transform="translate({x} 0)">'
            f'<rect width="{S}" height="{S}" fill="#000000" fill-opacity="0"/>{body}</g></g>')


def button_svg(kind, t):
    top_bottom, pressed, rim = FILLS[kind]
    grad, idle = f"g{kind}", f"i{kind}"
    lit = dot(f"url(#{grad})", rim)
    deep = dot(pressed, rim)
    grey = dot(f"url(#{idle})", t["idle_rim"])
    sym = glyph(kind, *GLYPH_ON_DOT)
    states = [
        ("active", lit),                              # colour, no symbol
        ("hover", lit + sym),                         # symbol appears
        ("pressed", deep + sym),
        ("deactivated", f'<g opacity="0.35">{grey}</g>'),   # e.g. can't maximise
        ("inactive", grey),                           # window in the background
        ("hover-inactive", lit + sym),
        ("pressed-inactive", deep + sym),
        ("deactivated-inactive", f'<g opacity="0.3">{grey}</g>'),
    ]
    cells = "".join(state(p, i * (S + 4), body) for i, (p, body) in enumerate(states))
    width = len(states) * (S + 4)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{S}" '
            f'viewBox="0 0 {width} {S}"><defs>'
            f'<linearGradient id="{grad}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top_bottom[0]}"/><stop offset="1" stop-color="{top_bottom[1]}"/>'
            f'</linearGradient>'
            f'<linearGradient id="{idle}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{t["idle"][0]}"/><stop offset="1" stop-color="{t["idle"][1]}"/>'
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
    # 24 px buttons with no spacing: 14 px dots 10 px apart, starting 11 px
    # from the window edge.
    return f"""[General]
ActiveTextColor={t["text"]}
InactiveTextColor={t["text_inactive"]}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=120
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
TitleEdgeLeft=6
TitleEdgeRight=6
TitleEdgeTopMaximized=4
TitleEdgeBottomMaximized=4
TitleEdgeLeftMaximized=6
TitleEdgeRightMaximized=6
TitleBorderLeft=10
TitleBorderRight=10
TitleHeight=24
ButtonWidth=24
ButtonHeight=24
ButtonSpacing=0
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
X-KDE-PluginInfo-Version=1.1
""")
        (d / "metadata.json").write_text(json.dumps({
            "KPlugin": {
                "Authors": [{"Name": "Verta"}],
                "Description": t["comment"],
                "Id": name,
                "License": "GPL-2.0-or-later",
                "Name": name.replace("-", " "),
                "Version": "1.1",
            },
        }, indent=4) + "\n")
        print(f"aurorae: wrote {d}")


if __name__ == "__main__":
    main()
