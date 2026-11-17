#!/usr/bin/python3
"""Generate Verta's window decorations (KWin Aurorae SVG themes).

  make-aurorae.py <output dir>     e.g. system_files/usr/share/aurorae/themes

Writes two themes, "Verta" (dark) and "Verta-Light", in the style of
Windows 11: a title bar in the window's own colour (so it blends into the
app), the app icon and title on the left, and minimise, maximise and close
on the right as wide, flat buttons with thin symbols:

  - under the pointer a soft grey square lights up behind the symbol; close
    turns red with a white cross
  - pressed: a little dimmer
  - windows in the background: the symbols fade

Rounded window corners and shadows come from the Round-Corners KWin effect,
so the decoration itself is square and shadowless.
"""
import json
import sys
from pathlib import Path

W, H = 46, 32   # button size (px), as on Windows 11

# Thin 1 px symbols, 10 px across, centred in the button.
X0, Y0 = W / 2 - 5, H / 2 - 5
GLYPHS = {
    "minimize": f'<path d="M{X0} {H / 2 + 0.5}h10"/>',
    "maximize": f'<rect x="{X0 + 0.5}" y="{Y0 + 0.5}" width="9" height="9" rx="1.5"/>',
    "restore": (f'<rect x="{X0 + 0.5}" y="{Y0 + 2.5}" width="7" height="7" rx="1.2"/>'
                f'<path d="M{X0 + 2.5} {Y0 + 2.5}V{Y0 + 1.7}a1.2 1.2 0 0 1 1.2-1.2H{X0 + 8.3}'
                f'a1.2 1.2 0 0 1 1.2 1.2V{Y0 + 6.3}a1.2 1.2 0 0 1-1.2 1.2H{X0 + 7.5}"/>'),
    "close": f'<path d="M{X0} {Y0}l10 10M{X0 + 10} {Y0}l-10 10"/>',
}
CLOSE_RED = "#c42b1c"

THEMES = {
    "Verta": {
        "comment": "Verta's dark title bar, Windows 11 style",
        "header": "#161616", "header_inactive": "#161616",
        "text": "238,238,238", "text_inactive": "153,153,153",
        "glyph": "#ffffff", "hover": ("#ffffff", 0.08), "press": ("#ffffff", 0.05),
    },
    "Verta-Light": {
        "comment": "Verta's light title bar, Windows 11 style",
        "header": "#f8f8f8", "header_inactive": "#f8f8f8",
        "text": "28,28,28", "text_inactive": "118,118,118",
        "glyph": "#000000", "hover": ("#000000", 0.06), "press": ("#000000", 0.04),
    },
}


def symbol(kind, color, alpha):
    return (f'<g fill="none" stroke="{color}" stroke-opacity="{alpha}" stroke-width="1" '
            f'stroke-linecap="square" stroke-linejoin="miter">{GLYPHS[kind]}</g>')


def plate(color, alpha):
    return f'<rect width="{W}" height="{H}" fill="{color}" fill-opacity="{alpha}"/>'


def state(prefix, x, body):
    """One button state, drawn in its own cell at column x."""
    # The id sits on an untransformed group (KSvg reads element bounds from it);
    # the shift into its cell happens one level down.
    return (f'<g id="{prefix}-center"><g transform="translate({x} 0)">'
            f'<rect width="{W}" height="{H}" fill="#000000" fill-opacity="0"/>{body}</g></g>')


def button_svg(kind, t):
    g = t["glyph"]
    if kind == "close":
        hover = plate(CLOSE_RED, 1) + symbol(kind, "#ffffff", 1)
        press = plate(CLOSE_RED, 0.85) + symbol(kind, "#ffffff", 0.8)
    else:
        hover = plate(*t["hover"]) + symbol(kind, g, 1)
        press = plate(*t["press"]) + symbol(kind, g, 0.75)
    states = [
        ("active", symbol(kind, g, 0.95)),
        ("hover", hover),
        ("pressed", press),
        ("deactivated", symbol(kind, g, 0.3)),         # e.g. can't maximise
        ("inactive", symbol(kind, g, 0.45)),          # window in the background
        ("hover-inactive", hover),
        ("pressed-inactive", press),
        ("deactivated-inactive", symbol(kind, g, 0.2)),
    ]
    cells = "".join(state(p, i * (W + 4), body) for i, (p, body) in enumerate(states))
    width = len(states) * (W + 4)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{H}" '
            f'viewBox="0 0 {width} {H}">{cells}</svg>\n')


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
    # 46x32 buttons flush with the top-right corner, title on the left after
    # the app icon.
    return f"""[General]
ActiveTextColor={t["text"]}
InactiveTextColor={t["text_inactive"]}
TitleAlignment=Left
TitleVerticalAlignment=Center
Animation=100
Shadow=false
UseTextShadow=false
HaloActive=false
HaloInactive=false
DecorationPosition=0

[Layout]
BorderLeft=1
BorderRight=1
BorderBottom=1
TitleEdgeTop=0
TitleEdgeBottom=0
TitleEdgeLeft=8
TitleEdgeRight=0
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=8
TitleEdgeRightMaximized=0
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight=32
ButtonWidth=46
ButtonHeight=32
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
X-KDE-PluginInfo-Version=2.0
""")
        (d / "metadata.json").write_text(json.dumps({
            "KPlugin": {
                "Authors": [{"Name": "Verta"}],
                "Description": t["comment"],
                "Id": name,
                "License": "GPL-2.0-or-later",
                "Name": name.replace("-", " "),
                "Version": "2.0",
            },
        }, indent=4) + "\n")
        print(f"aurorae: wrote {d}")


if __name__ == "__main__":
    main()
