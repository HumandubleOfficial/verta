#!/usr/bin/python3
"""Generate the Verta cursor theme.

  make-cursors.py <output dir>      e.g. system_files/usr/share/icons

Writes <output>/verta-cursors/ with
  - cursors_scalable/<name>/   SVG cursors (Plasma draws these sharp at any size)
  - cursors/<name>             classic X cursors (24, 32, 48, 64 px) for X11 apps
                               and games, built with xcursorgen
  - aliases.txt                other standard cursor names and the cursor each
                               one uses; the image build turns them into links
  - index.theme

The look: clean, Mac-like pointers drawn from scratch for Verta: solid
near-black shapes with a crisp white outline and a soft shadow, rounded joins,
coloured badges for help / copy / link / no-drop, and Verta's ring as the busy
spinner. Everything is drawn on a 24x24 canvas (the cursor's nominal size).

Needs rsvg-convert and xcursorgen (Ubuntu: librsvg2-bin, x11-apps).
"""
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
INK = "#15171c"
SIZES = (24, 32, 48, 64)


# --- drawing helpers ----------------------------------------------------------

def rot(body, angle, cx=12, cy=12):
    return f'<g transform="rotate({angle} {cx} {cy})">{body}</g>' if angle else body


def solid(shapes, outline=1.5):
    """Shapes as one solid black piece with a white outline and soft shadow.

    The outline is the same shapes stroked wide underneath the fill, so
    overlapping parts merge into one silhouette with no inner lines.
    """
    return (f'<g filter="url(#shadow)" transform="translate(0 0.9)" opacity="0.4">'
            f'<g fill="#000" stroke="#000" stroke-width="{outline * 2}" stroke-linejoin="round" '
            f'stroke-linecap="round">{shapes}</g></g>'
            f'<g fill="#fff" stroke="#fff" stroke-width="{outline * 2}" stroke-linejoin="round" '
            f'stroke-linecap="round">{shapes}</g>'
            f'<g fill="{INK}">{shapes}</g>')


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
            '<defs><filter id="shadow" x="-50%" y="-50%" width="200%" height="200%">'
            '<feGaussianBlur stdDeviation="0.85"/></filter></defs>'
            f'{body}</svg>\n')


def badge(color, glyph, cx=17.6, cy=18.4, r=4.4):
    return (f'<circle cx="{cx}" cy="{cy + 0.6}" r="{r + 0.6}" fill="#000" opacity="0.25" filter="url(#shadow)"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r + 1.1}" fill="#fff"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>'
            f'<g fill="none" stroke="#fff" stroke-width="1.3" stroke-linecap="round" '
            f'stroke-linejoin="round">{glyph}</g>')


# --- shapes ---------------------------------------------------------------------

ARROW = '<path d="M4.6 3 L4.6 19.4 L8.5 15.8 L11.3 21.9 L14 20.6 L11.3 14.7 L16.6 14.7 Z"/>'
SMALL_ARROW = '<path d="M3.6 2.4 L3.6 15.6 L6.7 12.7 L8.9 17.6 L11.1 16.6 L8.9 11.8 L13.2 11.8 Z"/>'


def arrow(mirror=False):
    body = solid(ARROW)
    return f'<g transform="translate(24 0) scale(-1 1)">{body}</g>' if mirror else body


def arrow_with(color, glyph):
    return solid(SMALL_ARROW) + badge(color, glyph)


def hand_point():
    shapes = ('<rect x="8.1" y="2.8" width="3" height="11.5" rx="1.5"/>'      # index
              '<rect x="11.1" y="8.6" width="3" height="6.5" rx="1.5"/>'      # middle
              '<rect x="14.1" y="9.4" width="2.9" height="6" rx="1.45"/>'     # ring
              '<rect x="17" y="10.4" width="2.7" height="5.4" rx="1.35"/>'    # little
              '<rect x="8.1" y="11.8" width="11.6" height="8.6" rx="3.6"/>'   # palm
              '<rect x="3.9" y="11.7" width="6.6" height="3" rx="1.5" transform="rotate(38 7.2 13.2)"/>'
              '<rect x="9.4" y="18.6" width="9" height="3.4" rx="1.2"/>')     # wrist
    gaps = ''.join(f'<path d="M{x} {y} V14.6" stroke="#fff" stroke-opacity="0.55" stroke-width="0.6" '
                   f'stroke-linecap="round"/>' for x, y in ((11.1, 9.8), (14.1, 10.6), (17, 11.5)))
    return solid(shapes, 1.3) + gaps


def hand_open():
    shapes = ('<rect x="6.6" y="5" width="2.8" height="9" rx="1.4"/>'
              '<rect x="9.6" y="3.4" width="2.8" height="10" rx="1.4"/>'
              '<rect x="12.6" y="3.8" width="2.8" height="10" rx="1.4"/>'
              '<rect x="15.6" y="5.6" width="2.6" height="8.6" rx="1.3"/>'
              '<rect x="6.6" y="10.6" width="11.6" height="9.4" rx="3.8"/>'
              '<rect x="2.8" y="12" width="6.4" height="2.8" rx="1.4" transform="rotate(40 6 13.4)"/>')
    gaps = ''.join(f'<path d="M{x} {y} V12.4" stroke="#fff" stroke-opacity="0.55" stroke-width="0.6" '
                   f'stroke-linecap="round"/>' for x, y in ((9.5, 6.2), (12.5, 5), (15.5, 6.8)))
    return solid(shapes, 1.3) + gaps


def hand_closed():
    shapes = ('<rect x="6.8" y="8.4" width="2.8" height="5" rx="1.4"/>'
              '<rect x="9.6" y="7.6" width="2.8" height="5.6" rx="1.4"/>'
              '<rect x="12.4" y="7.6" width="2.8" height="5.6" rx="1.4"/>'
              '<rect x="15.2" y="8.4" width="2.6" height="5" rx="1.3"/>'
              '<rect x="6.8" y="10.4" width="11" height="9.2" rx="3.8"/>'
              '<rect x="4.2" y="11.6" width="5.4" height="2.8" rx="1.4" transform="rotate(30 6.9 13)"/>')
    gaps = ''.join(f'<path d="M{x} 9 V11.6" stroke="#fff" stroke-opacity="0.55" stroke-width="0.6" '
                   f'stroke-linecap="round"/>' for x in (9.6, 12.4, 15.2))
    return solid(shapes, 1.3) + gaps


def ibeam(angle=0):
    d = ("M8.8 4.2 H10.6 Q12 4.2 12 5.6 V18.4 Q12 19.8 10.6 19.8 H8.8 "
         "M15.2 4.2 H13.4 Q12 4.2 12 5.6 M15.2 19.8 H13.4 Q12 19.8 12 18.4")
    body = (f'<path d="{d}" fill="none" stroke="#000" stroke-opacity="0.4" stroke-width="4.2" '
            f'stroke-linecap="round" filter="url(#shadow)" transform="translate(0 0.9)"/>'
            f'<path d="{d}" fill="none" stroke="#fff" stroke-width="4.2" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>')
    return rot(body, angle)


def crosshair(thick=False):
    if thick:
        shapes = '<rect x="9.7" y="4" width="4.6" height="16" rx="1"/><rect x="4" y="9.7" width="16" height="4.6" rx="1"/>'
        return solid(shapes, 1.2)
    shapes = ('<rect x="11.3" y="3" width="1.4" height="6.5" rx="0.7"/><rect x="11.3" y="14.5" width="1.4" height="6.5" rx="0.7"/>'
              '<rect x="3" y="11.3" width="6.5" height="1.4" rx="0.7"/><rect x="14.5" y="11.3" width="6.5" height="1.4" rx="0.7"/>'
              '<circle cx="12" cy="12" r="1"/>')
    return solid(shapes, 1.2)


def not_allowed():
    shapes = ('<circle cx="12" cy="12" r="7" fill="none" stroke-width="2.4"/>'
              '<path d="M7.2 16.8 L16.8 7.2" stroke-width="2.4"/>')
    return (f'<g fill="none" stroke="#fff" stroke-width="4.8" stroke-linecap="round">'
            f'<circle cx="12" cy="12" r="7"/><path d="M7.2 16.8 L16.8 7.2"/></g>'
            f'<g fill="none" stroke="{INK}" stroke-linecap="round">{shapes}</g>')


def x_shape():
    shapes = '<rect x="10.6" y="3.5" width="2.8" height="17" rx="1.4"/>'
    return solid(rot(shapes, 45) + rot(shapes, -45), 1.2)


DOUBLE = 'M3.2 12 L8 7.2 V10.5 H16 V7.2 L20.8 12 L16 16.8 V13.5 H8 V16.8 Z'
SINGLE = 'M12 3.2 L18.2 9.6 H14 V20.8 H10 V9.6 H5.8 Z'


def double_arrow(angle, bar=False):
    shapes = f'<path d="{DOUBLE}"/>'
    if bar:
        shapes += '<rect x="11" y="4.5" width="2" height="15" rx="1"/>'
    return solid(rot(shapes, angle), 1.3)


def single_arrow(angle):
    return solid(rot(f'<path d="{SINGLE}"/>', angle), 1.3)


def four_way():
    head = 'M12 2.6 L15.6 6.6 H13.2 V10.8 H10.8 V6.6 H8.4 Z'
    shapes = ''.join(rot(f'<path d="{head}"/>', a) for a in (0, 90, 180, 270))
    shapes += '<circle cx="12" cy="12" r="2.2"/>'
    return solid(shapes, 1.3)


def pencil():
    shapes = ('<g transform="rotate(45 12 12)">'
              '<rect x="10" y="2.5" width="4" height="13" rx="1"/>'
              '<path d="M10 15.5 H14 L12 20.5 Z"/></g>')
    tip = '<path d="M4.15 19.85 L5.4 16.9 L7.1 18.6 Z" fill="#fff" opacity="0.9"/>'
    return solid(shapes, 1.2) + tip


def magnifier(plus):
    ring = ('<circle cx="10" cy="10" r="6" fill="none" stroke-width="2.4"/>'
            '<path d="M14.4 14.4 L19.8 19.8" stroke-width="3.2"/>')
    sign = '<path d="M7.4 10 H12.6"/>' + ('<path d="M10 7.4 V12.6"/>' if plus else '')
    return (f'<g fill="none" stroke="#fff" stroke-linecap="round"><circle cx="10" cy="10" r="6" stroke-width="5"/>'
            f'<path d="M14.4 14.4 L19.8 19.8" stroke-width="5.8"/></g>'
            f'<circle cx="10" cy="10" r="5" fill="#fff" fill-opacity="0.85"/>'
            f'<g fill="none" stroke="{INK}" stroke-linecap="round">{ring}</g>'
            f'<g fill="none" stroke="{INK}" stroke-width="1.6" stroke-linecap="round">{sign}</g>')


def ring(phase, cx=12, cy=12, r=6.4, width=2.8, outline=True):
    """Verta's ring spinner: a blue-to-violet arc chasing round a soft track."""
    a0 = phase * 2 * math.pi
    a1 = a0 + 2 * math.pi * 0.62
    x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
    x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
    gx0, gy0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
    gx1, gy1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
    out = ''
    if outline:
        out += (f'<circle cx="{cx}" cy="{cy + 0.8}" r="{r}" fill="none" stroke="#000" stroke-opacity="0.35" '
                f'stroke-width="{width + 2.4}" filter="url(#shadow)"/>'
                f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#fff" stroke-width="{width + 2.4}"/>')
    out += (f'<linearGradient id="arc" gradientUnits="userSpaceOnUse" x1="{gx0:.2f}" y1="{gy0:.2f}" '
            f'x2="{gx1:.2f}" y2="{gy1:.2f}"><stop offset="0" stop-color="#60a5fa" stop-opacity="0.15"/>'
            f'<stop offset="1" stop-color="#2563eb"/></linearGradient>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#1e293b" stroke-opacity="0.25" stroke-width="{width}"/>'
            f'<path d="M{x0:.2f} {y0:.2f} A{r} {r} 0 1 1 {x1:.2f} {y1:.2f}" fill="none" stroke="url(#arc)" '
            f'stroke-width="{width}" stroke-linecap="round"/>'
            f'<circle cx="{x1:.2f}" cy="{y1:.2f}" r="{width / 2:.2f}" fill="#2563eb"/>')
    return out


FRAMES = 18          # spinner frames (one full turn)
FRAME_MS = 45


def busy_frame(i, with_arrow):
    if with_arrow:
        return solid(SMALL_ARROW) + ring(i / FRAMES, 17.4, 17.8, 4.1, 2.2)
    return ring(i / FRAMES)


# Badge glyphs (drawn in white on the badge, centred at 17.6, 18.4).
Q_MARK = '<path d="M16.1 17.2 a1.55 1.55 0 1 1 2.2 1.4 c-.55 .25 -.7 .55 -.7 1.1"/><circle cx="17.6" cy="21" r=".35" fill="#fff"/>'
PLUS = '<path d="M17.6 16.2 V20.6 M15.4 18.4 H19.8"/>'
LINK = '<path d="M15.7 20.4 C15.7 18.3 16.6 17.3 18.6 17.3 H19.6"/><path d="M18.3 15.9 L19.8 17.3 L18.3 18.7"/>'
NO = '<circle cx="17.6" cy="18.4" r="2.3"/><path d="M16 20 L19.2 16.8"/>'
MENU = '<path d="M15.6 16.9 H19.6 M15.6 18.4 H19.6 M15.6 19.9 H19.6"/>'

# name -> (drawing, hotspot). The 48 cursors every theme ships; other standard
# names point at these (aliases.txt).
CURSORS = {
    "default":            (lambda: arrow(), (4.6, 3)),
    "pirate":             (lambda: arrow(), (4.6, 3)),
    "wayland-cursor":     (lambda: arrow(), (4.6, 3)),
    "right_ptr":          (lambda: arrow(mirror=True), (19.4, 3)),
    "center_ptr":         (lambda: single_arrow(0), (12, 3.2)),
    "pointer":            (hand_point, (9.6, 2.9)),
    "openhand":           (hand_open, (12, 12)),
    "dnd-move":           (hand_closed, (12, 12)),
    "text":               (lambda: ibeam(), (12, 12)),
    "vertical-text":      (lambda: ibeam(90), (12, 12)),
    "crosshair":          (lambda: crosshair(), (12, 12)),
    "color-picker":       (lambda: crosshair(), (12, 12)),
    "cell":               (lambda: crosshair(thick=True), (12, 12)),
    "not-allowed":        (not_allowed, (12, 12)),
    "x-cursor":           (x_shape, (12, 12)),
    "help":               (lambda: arrow_with("#3b82f6", Q_MARK), (3.6, 2.4)),
    "copy":               (lambda: arrow_with("#22c55e", PLUS), (3.6, 2.4)),
    "alias":              (lambda: arrow_with("#8b5cf6", LINK), (3.6, 2.4)),
    "no-drop":            (lambda: arrow_with("#ef4444", NO), (3.6, 2.4)),
    "dnd-no-drop":        (lambda: arrow_with("#ef4444", NO), (3.6, 2.4)),
    "context-menu":       (lambda: arrow_with("#475569", MENU), (3.6, 2.4)),
    "size_hor":           (lambda: double_arrow(0), (12, 12)),
    "size_ver":           (lambda: double_arrow(90), (12, 12)),
    "size_fdiag":         (lambda: double_arrow(45), (12, 12)),
    "size_bdiag":         (lambda: double_arrow(-45), (12, 12)),
    "left_side":          (lambda: double_arrow(0), (12, 12)),
    "right_side":         (lambda: double_arrow(0), (12, 12)),
    "top_side":           (lambda: double_arrow(90), (12, 12)),
    "bottom_side":        (lambda: double_arrow(90), (12, 12)),
    "top_left_corner":    (lambda: double_arrow(45), (12, 12)),
    "bottom_right_corner": (lambda: double_arrow(45), (12, 12)),
    "top_right_corner":   (lambda: double_arrow(-45), (12, 12)),
    "bottom_left_corner": (lambda: double_arrow(-45), (12, 12)),
    "col-resize":         (lambda: double_arrow(0, bar=True), (12, 12)),
    "row-resize":         (lambda: double_arrow(90, bar=True), (12, 12)),
    "fleur":              (four_way, (12, 12)),
    "all-scroll":         (four_way, (12, 12)),
    "up-arrow":           (lambda: single_arrow(0), (12, 3.2)),
    "right-arrow":        (lambda: single_arrow(90), (20.8, 12)),
    "down-arrow":         (lambda: single_arrow(180), (12, 20.8)),
    "left-arrow":         (lambda: single_arrow(270), (3.2, 12)),
    "pencil":             (pencil, (4.2, 19.8)),
    "draft":              (pencil, (4.2, 19.8)),
    "zoom-in":            (lambda: magnifier(True), (10, 10)),
    "zoom-out":           (lambda: magnifier(False), (10, 10)),
}
ANIMATED = {
    "wait":     (lambda i: busy_frame(i, False), (12, 12)),
    "progress": (lambda i: busy_frame(i, True), (3.6, 2.4)),
}


def run(*argv):
    subprocess.run(argv, check=True)


def main():
    out = Path(sys.argv[1]) / "verta-cursors"
    if out.exists():
        shutil.rmtree(out)
    scalable = out / "cursors_scalable"
    xcur = out / "cursors"
    xcur.mkdir(parents=True)
    work = Path(tempfile.mkdtemp())

    def emit(name, frames, hot, delay=0):
        """frames: list of SVG bodies (one unless animated)."""
        d = scalable / name
        d.mkdir(parents=True)
        meta, cfg = [], []
        for i, body in enumerate(frames):
            fname = f"{name}.svg" if len(frames) == 1 else f"{name}-{i + 1:02d}.svg"
            (d / fname).write_text(svg(body))
            entry = {"filename": fname, "hotspot_x": hot[0], "hotspot_y": hot[1], "nominal_size": 24}
            if delay:
                entry["delay"] = delay
            meta.append(entry)
            for size in SIZES:
                png = work / f"{name}-{i}-{size}.png"
                run("rsvg-convert", "-w", str(size), "-h", str(size), str(d / fname), "-o", str(png))
                hx, hy = round(hot[0] * size / 24), round(hot[1] * size / 24)
                cfg.append(f"{size} {hx} {hy} {png}" + (f" {delay}" if delay else ""))
        (d / "metadata.json").write_text(json.dumps(meta, indent=4) + "\n")
        (work / f"{name}.cfg").write_text("\n".join(cfg) + "\n")
        run("xcursorgen", str(work / f"{name}.cfg"), str(xcur / name))

    for name, (draw, hot) in CURSORS.items():
        emit(name, [draw()], hot)
    for name, (draw, hot) in ANIMATED.items():
        emit(name, [draw(i) for i in range(FRAMES)], hot, FRAME_MS)

    shutil.copy(HERE / "aliases.txt", out / "aliases.txt")
    (out / "index.theme").write_text(
        "[Icon Theme]\nName=Verta\nComment=Verta's pointers: crisp, rounded, with a soft shadow\n"
        "Inherits=breeze_cursors\n")

    # Contact sheet of every cursor, on dark and light.
    names = list(CURSORS) + list(ANIMATED)
    cells = []
    for i, name in enumerate(names):
        x, y = (i % 12) * 56 + 8, (i // 12) * 56 + 8
        first = sorted((scalable / name).glob("*.svg"))[0].relative_to(out)
        for band, bg in enumerate(("#f3f4f6", "#0b1220")):
            oy = band * 248
            cells.append(f'<image x="{x}" y="{y + oy}" width="48" height="48" href="{first}"/>')
    sheet = out / "sheet.svg"   # next to the cursors: rsvg only loads files below it
    sheet.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="680" height="496">'
                     '<rect width="680" height="248" fill="#f3f4f6"/><rect y="248" width="680" height="248" fill="#0b1220"/>'
                     + "".join(cells) + "</svg>")
    run("rsvg-convert", str(sheet), "-o", str(HERE / "preview.png"))
    sheet.unlink()
    shutil.rmtree(work)
    print(f"cursors: wrote {len(names)} cursors to {out}")


if __name__ == "__main__":
    main()
