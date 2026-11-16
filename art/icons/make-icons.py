#!/usr/bin/env python3
"""Generate the Verta icon theme (Apple-style app tiles and folders).

Every icon is drawn on a 512x512 canvas from a few shared building blocks so
the whole set stays simple and consistent: a rounded-square tile with a gentle
gradient, one soft shadow and a hairline rim, and a flat white symbol (no
gloss, no glyph shadows); folders share one Mac-style folder body with a flat
symbol. Every app gets its own shape and colour, so no two icons look alike.

Only SVG features Qt's renderer handles well are used (no filters, masks or
clip paths), so icons look the same in Plasma as in a browser.

Output: <out>/Verta/scalable/{apps,places}/*.svg, index.theme for "Verta"
(dark) and "Verta-Light", plus <out>/preview.svg (a contact sheet).

    python3 -I make-icons.py <output-dir>
"""
import math
import os
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"

WHITE = "#ffffff"


# --- shared building blocks -------------------------------------------------

def tile(uid, top, bottom):
    """Rounded-square app tile: one soft shadow, a gentle gradient, a hairline rim."""
    x, y, s, r = 48, 40, 416, 100
    shadow = "".join(
        f'<rect x="{x - g}" y="{y + 8 + g}" width="{s + 2 * g}" height="{s}" rx="{r + g}" '
        f'fill="#000" opacity="{o}"/>'
        for g, o in ((0, 0.10), (8, 0.05))
    )
    return (
        f'<defs>'
        f'<linearGradient id="{uid}-bg" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
        f'</defs>'
        f'{shadow}'
        f'<rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{r}" fill="url(#{uid}-bg)"/>'
        f'<rect x="{x + 1}" y="{y + 1}" width="{s - 2}" height="{s - 2}" rx="{r - 1}" '
        f'fill="none" stroke="#fff" stroke-opacity="0.10" stroke-width="2"/>'
    )


def lifted(body):
    """Glyphs are drawn flat (kept as a hook so every app draws the same way)."""
    return body


def gear_points(cx, cy, r_out, r_in, teeth, tooth_frac=0.5, rot=0.0):
    pts = []
    step = 2 * math.pi / teeth
    half = step * tooth_frac / 2
    for i in range(teeth):
        a = rot + i * step
        for ang, rr in ((a - half * 1.25, r_in), (a - half * 0.7, r_out), (a + half * 0.7, r_out), (a + half * 1.25, r_in)):
            pts.append(f"{cx + rr * math.cos(ang):.1f},{cy + rr * math.sin(ang):.1f}")
    return " ".join(pts)


def gear(cx, cy, r_out, r_in, hole, color=WHITE, teeth=8):
    return (f'<polygon points="{gear_points(cx, cy, r_out, r_in, teeth, rot=-math.pi / 2)}" fill="{color}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r_in - 2}" fill="{color}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{hole}" fill="BG_HOLE"/>')


def svg(content):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">'
            f'{content}</svg>\n')


# --- app icons ---------------------------------------------------------------

def app_files(u):
    folder = ('<path d="M150 190 Q150 172 168 172 H222 Q232 172 240 180 L252 192 H344 Q362 192 362 210 V318 '
              'Q362 336 344 336 H168 Q150 336 150 318 Z" fill="#fff"/>'
              '<rect x="150" y="214" width="212" height="122" rx="18" fill="#dbeafe"/>')
    return tile(u, "#5ea8ff", "#1f5fe0") + lifted(folder)


def app_terminal(u):
    g = ('<path d="M168 196 L232 248 L168 300" fill="none" stroke="#e6ebf5" stroke-width="30" '
         'stroke-linecap="round" stroke-linejoin="round"/>'
         '<rect x="252" y="290" width="96" height="28" rx="14" fill="#60a5fa"/>')
    return tile(u, "#334155", "#0b1220") + g


def app_settings(u):
    """KDE's full System Settings: three sliders on grey."""
    g = ''.join(
        f'<rect x="150" y="{y - 9}" width="212" height="18" rx="9" fill="#fff" opacity="0.55"/>'
        f'<rect x="150" y="{y - 9}" width="{k - 150}" height="18" rx="9" fill="#fff"/>'
        f'<circle cx="{k}" cy="{y}" r="30" fill="#fff"/>'
        for y, k in ((176, 300), (256, 196), (336, 268)))
    return tile(u, "#9aa4b4", "#5b6577") + g


def app_verta_settings(u):
    g = gear(256, 248, 124, 100, 46).replace("BG_HOLE", "#1e40af")
    return tile(u, "#4f8dff", "#1e3a8a") + g


def app_store(u):
    bag = ('<path d="M206 196 V180 Q206 132 256 132 Q306 132 306 180 V196" fill="none" stroke="#fff" '
           'stroke-width="22" stroke-linecap="round"/>'
           '<path d="M150 196 H362 L348 356 Q346 380 322 380 H190 Q166 380 164 356 Z" fill="#fff"/>'
           '<path d="M226 270 L256 300 L286 270" fill="none" stroke="#2563eb" stroke-width="18" '
           'stroke-linecap="round" stroke-linejoin="round"/>')
    return tile(u, "#38bdf8", "#2563eb") + lifted(bag)


def app_launchpad(u):
    """Apps (Verta Start in the dock): a 3x3 grid of rounded squares, each a
    different colour, on a light tile (it stands out on dark and light docks)."""
    colors = ["#f87171", "#fbbf24", "#34d399",
              "#38bdf8", "#818cf8", "#f472b6",
              "#a3e635", "#fb923c", "#60a5fa"]
    cells = "".join(
        f'<rect x="{150 + c * 76}" y="{142 + r * 76}' + f'" width="60" height="60" rx="16" fill="{colors[r * 3 + c]}"/>'
        for r in range(3) for c in range(3))
    return tile(u, "#f8fafc", "#cbd5e1") + cells


def app_editor(u):
    paper = ''.join(f'<rect x="148" y="{y}" width="{w}" height="16" rx="8" fill="#b6bfcd"/>'
                    for y, w in ((222, 216), (262, 216), (302, 216), (342, 150)))
    top_band = '<path d="M48 136 V136 Q48 40 144 40 H368 Q464 40 464 136 V168 H48 Z" fill="#fbbf24"/>'
    return tile(u, "#ffffff", "#e5e9f0") + top_band + paper


def app_archive(u):
    box = ('<rect x="146" y="150" width="220" height="220" rx="26" fill="#fff"/>'
           + ''.join(f'<rect x="{x}" y="{y}" width="24" height="16" rx="4" fill="#b45309"/>'
                     for x, y in ((244, 160), (244, 192), (244, 224), (244, 256)))
           + '<rect x="234" y="282" width="44" height="54" rx="10" fill="#b45309"/>')
    return tile(u, "#fbbf24", "#c2610c") + lifted(box)


def app_screenshot(u):
    c = '#fff'
    corners = ''.join(
        f'<path d="{d}" fill="none" stroke="{c}" stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>'
        for d in ("M150 206 V172 Q150 150 172 150 H206", "M306 150 H340 Q362 150 362 172 V206",
                  "M362 306 V340 Q362 362 340 362 H306", "M206 362 H172 Q150 362 150 340 V306"))
    lens = f'<circle cx="256" cy="256" r="46" fill="{c}"/>'
    return tile(u, "#b69cff", "#6d28d9") + lifted(corners + lens)


def app_monitor(u):
    grid = ''.join(f'<rect x="120" y="{y}" width="272" height="4" rx="2" fill="#16a34a" opacity="0.12"/>'
                   for y in (176, 236, 296, 356))
    pulse = ('<path d="M112 272 H186 L214 200 L254 330 L286 236 L306 272 H400" fill="none" stroke="#16a34a" '
             'stroke-width="24" stroke-linecap="round" stroke-linejoin="round"/>')
    return tile(u, "#ffffff", "#e3e8f0") + grid + pulse


def app_info(u):
    g = ('<circle cx="256" cy="256" r="124" fill="none" stroke="#fff" stroke-width="26"/>'
         '<circle cx="256" cy="188" r="20" fill="#fff"/>'
         '<rect x="238" y="226" width="36" height="110" rx="18" fill="#fff"/>')
    return tile(u, "#67e8f9", "#0e7490") + lifted(g)


def app_disk_usage(u):
    r, cx, cy = 116, 256, 256

    def arc(a0, a1, color):
        x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
        x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
        large = 1 if a1 - a0 > math.pi else 0
        return (f'<path d="M{x0:.1f} {y0:.1f} A{r} {r} 0 {large} 1 {x1:.1f} {y1:.1f}" fill="none" '
                f'stroke="{color}" stroke-width="56"/>')
    a = -math.pi / 2
    segs = arc(a, a + 3.6, "#fff") + arc(a + 3.7, a + 5.1, "#99f6e4") + arc(a + 5.2, a + 6.15, "#5eead4")
    return tile(u, "#2dd4bf", "#0f766e") + segs


def app_drives(u):
    d = ('<rect x="130" y="172" width="252" height="168" rx="30" fill="#fff"/>'
         '<rect x="130" y="270" width="252" height="70" rx="30" fill="#e2e8f0"/>'
         '<circle cx="330" cy="305" r="13" fill="#22c55e"/>'
         '<rect x="166" y="298" width="96" height="14" rx="7" fill="#94a3b8"/>')
    return tile(u, "#cbd5e1", "#5b6778") + lifted(d)


def app_gpu(u):
    pins = ''.join(f'<rect x="{x}" y="128" width="16" height="40" rx="6" fill="#fff"/>'
                   f'<rect x="{x}" y="344" width="16" height="40" rx="6" fill="#fff"/>'
                   for x in (196, 248, 300))
    pins += ''.join(f'<rect x="128" y="{y}" width="40" height="16" rx="6" fill="#fff"/>'
                    f'<rect x="344" y="{y}" width="40" height="16" rx="6" fill="#fff"/>'
                    for y in (196, 248, 300))
    chip = ('<rect x="160" y="160" width="192" height="192" rx="30" fill="#fff"/>'
            '<rect x="208" y="208" width="96" height="96" rx="16" fill="#dc2626"/>')
    return tile(u, "#fb7185", "#b91c1c") + lifted(pins + chip)


def app_update(u):
    g = ('<path d="M352 222 A104 104 0 1 0 352 290" fill="none" stroke="#fff" stroke-width="30" '
         'stroke-linecap="round"/>'
         '<path d="M318 168 L366 222 L304 240 Z" fill="#fff" stroke="#fff" stroke-width="14" '
         'stroke-linejoin="round"/>')
    return tile(u, "#a5b4fc", "#4338ca") + lifted(g)


def app_android(u):
    g = ('<path d="M156 280 Q156 176 256 176 Q356 176 356 280 Z" fill="#fff"/>'
         '<circle cx="216" cy="236" r="14" fill="#15803d"/><circle cx="296" cy="236" r="14" fill="#15803d"/>'
         '<path d="M196 182 L170 140 M316 182 L342 140" stroke="#fff" stroke-width="16" stroke-linecap="round"/>'
         '<rect x="156" y="296" width="200" height="60" rx="20" fill="#fff"/>')
    return tile(u, "#86efac", "#16a34a") + lifted(g)


# --- folders -----------------------------------------------------------------

def folder(u, emblem=""):
    back = ('<path d="M60 150 Q60 112 98 112 H196 Q214 112 228 124 L254 146 H414 Q452 146 452 184 V380 '
            'Q452 418 414 418 H98 Q60 418 60 380 Z" fill="url(#' + u + '-back)"/>')
    shadow = ''.join(f'<rect x="{56 - g}" y="{196 + 4 + g}" width="{400 + 2 * g}" height="242" rx="{34 + g}" '
                     f'fill="#000" opacity="{o}"/>' for g, o in ((1, 0.10), (7, 0.04)))
    front = (f'<rect x="56" y="190" width="400" height="242" rx="34" fill="url(#{u}-front)"/>'
             f'<rect x="57" y="191" width="398" height="240" rx="33" fill="none" stroke="#fff" '
             f'stroke-opacity="0.30" stroke-width="2"/>')
    defs = (f'<defs>'
            f'<linearGradient id="{u}-back" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#4b8df8"/><stop offset="1" stop-color="#1e4fc7"/></linearGradient>'
            f'<linearGradient id="{u}-front" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#8cc2ff"/><stop offset="1" stop-color="#3b82f6"/></linearGradient>'
            f'</defs>')
    # Symbol: one flat tone of the folder's own blue.
    emb = ''
    if emblem:
        emb = f'<g opacity="0.75" fill="#1d4ed8" stroke="#1d4ed8">{emblem}</g>'
    return defs + back + shadow + front + emb


E = {  # folder emblems, drawn around (256, 312)
    "documents": ('<path d="M222 262 H274 L300 288 V360 Q300 368 292 368 H222 Q214 368 214 360 V270 Q214 262 222 262 Z" '
                  'stroke="none"/>'),
    "download": ('<path d="M256 258 V340 M222 310 L256 344 L290 310" fill="none" stroke-width="20" '
                 'stroke-linecap="round" stroke-linejoin="round"/><rect x="214" y="356" width="84" height="16" rx="8" stroke="none"/>'),
    "music": ('<path d="M244 268 L304 256 V342" fill="none" stroke-width="16" stroke-linejoin="round"/>'
              '<rect x="236" y="262" width="16" height="84" stroke="none"/>'
              '<ellipse cx="230" cy="350" rx="24" ry="18" stroke="none"/>'
              '<ellipse cx="290" cy="342" rx="24" ry="18" stroke="none"/>'),
    "pictures": ('<path d="M208 360 L248 300 L272 332 L288 312 L320 360 Z" stroke="none"/>'
                 '<circle cx="292" cy="280" r="14" stroke="none"/>'),
    "videos": '<path d="M232 270 L300 314 L232 358 Z" stroke-linejoin="round" stroke-width="10"/>',
    "desktop": ('<rect x="200" y="266" width="112" height="72" rx="10" stroke="none"/>'
                '<rect x="236" y="342" width="40" height="22" stroke="none"/>'
                '<rect x="222" y="360" width="68" height="10" rx="5" stroke="none"/>'),
    "home": '<path d="M256 262 L314 312 H298 V366 H272 V334 H240 V366 H214 V312 H198 Z" stroke="none"/>',
    "games": ('<path d="M206 292 Q206 276 222 276 H290 Q306 276 306 292 L318 344 Q322 362 304 362 Q294 362 288 352 '
              'L280 338 H232 L224 352 Q218 362 208 362 Q190 362 194 344 Z" stroke="none"/>'),
    "templates": ('<rect x="214" y="266" width="84" height="22" rx="6" stroke="none"/>'
                  '<rect x="214" y="296" width="36" height="66" rx="6" stroke="none"/>'
                  '<rect x="258" y="296" width="40" height="66" rx="6" stroke="none"/>'),
    "publicshare": ('<circle cx="236" cy="290" r="18" stroke="none"/><circle cx="284" cy="290" r="18" stroke="none"/>'
                    '<path d="M204 358 Q204 318 236 318 Q268 318 268 358 Z M252 358 Q252 318 284 318 Q316 318 316 358 Z" stroke="none"/>'),
}


def trash(u, full=False):
    body = ('<path d="M150 170 H362 L340 410 Q338 432 316 432 H196 Q174 432 172 410 Z" fill="url(#' + u + '-can)"/>'
            '<rect x="128" y="132" width="256" height="44" rx="22" fill="url(#' + u + '-lid)"/>'
            + ''.join(f'<rect x="{x}" y="212" width="14" height="180" rx="7" fill="#fff" opacity="0.45"/>'
                      for x in (206, 249, 292)))
    paper = ('<path d="M190 136 L214 92 L262 108 L250 140 Z" fill="#e2e8f0"/>'
             '<path d="M262 132 L296 86 L330 112 L308 138 Z" fill="#cbd5e1"/>') if full else ''
    defs = (f'<defs><linearGradient id="{u}-can" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#cfd6e1"/><stop offset="1" stop-color="#7a8597"/></linearGradient>'
            f'<linearGradient id="{u}-lid" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#e5e9f0"/><stop offset="1" stop-color="#a3adbd"/></linearGradient></defs>')
    shadow = '<ellipse cx="256" cy="440" rx="120" ry="14" fill="#000" opacity="0.12"/>'
    # Drawn a size up so it matches the app tiles next to it in the dock.
    return (defs + '<g transform="translate(256 262) scale(1.26) translate(-256 -266)">'
            + shadow + paper + body + '</g>')


# --- which icon names get which drawing --------------------------------------

APPS = {
    app_files:          ["org.kde.dolphin", "system-file-manager", "file-manager"],
    app_terminal:       ["org.kde.konsole", "utilities-terminal", "terminal"],
    app_settings:       ["systemsettings", "preferences-system", "org.kde.systemsettings"],
    app_verta_settings: ["org.verta.Settings"],
    app_store:          ["org.kde.discover", "plasmadiscover", "system-software-install"],
    app_launchpad:      ["verta-launchpad"],
    app_editor:         ["org.kde.kate", "kate", "accessories-text-editor", "org.kde.kwrite"],
    app_archive:        ["org.kde.ark", "ark", "utilities-file-archiver"],
    app_screenshot:     ["org.kde.spectacle", "spectacle", "accessories-screenshot"],
    app_monitor:        ["org.kde.plasma-systemmonitor", "utilities-system-monitor", "ksysguard"],
    app_info:           ["org.kde.kinfocenter", "hwinfo", "help-about"],
    app_disk_usage:     ["org.kde.filelight", "filelight"],
    app_drives:         ["org.kde.partitionmanager", "partitionmanager", "drive-harddisk"],
    app_gpu:            ["corectrl"],
    app_update:         ["system-software-update", "update-manager"],
    app_android:        ["waydroid", "android"],
}

FOLDERS = {
    "": ["folder", "inode-directory", "folder-blue", "folder-open"],
    "documents": ["folder-documents"],
    "download": ["folder-download", "folder-downloads"],
    "music": ["folder-music", "folder-sound"],
    "pictures": ["folder-pictures", "folder-images"],
    "videos": ["folder-videos", "folder-video"],
    "desktop": ["user-desktop", "folder-desktop"],
    "home": ["user-home", "folder-home"],
    "games": ["folder-games"],
    "templates": ["folder-templates"],
    "publicshare": ["folder-publicshare", "folder-public"],
}


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    base = os.path.join(OUT, "Verta", "scalable")
    sheet = []

    for fn, names in APPS.items():
        for name in names:
            write(os.path.join(base, "apps", name + ".svg"), svg(fn("i")))
        sheet.append((names[0], fn))

    for emblem, names in FOLDERS.items():
        draw = (lambda u, e=emblem: folder(u, E.get(e, "")))
        for name in names:
            dest = "mimetypes" if name == "inode-directory" else "places"
            write(os.path.join(base, dest, name + ".svg"), svg(draw("i")))
        sheet.append((names[0], draw))

    for name, full in (("user-trash", False), ("user-trash-full", True)):
        draw = (lambda u, f=full: trash(u, f))
        write(os.path.join(base, "places", name + ".svg"), svg(draw("i")))
        sheet.append((name, draw))

    index = """[Icon Theme]
Name={name}
Comment=Verta app and folder icons, with Papirus for everything else
Inherits={inherits}
Directories=scalable/apps,scalable/places,scalable/mimetypes
FollowsColorScheme=true

[scalable/apps]
Size=64
MinSize=8
MaxSize=512
Context=Applications
Type=Scalable

[scalable/places]
Size=64
MinSize=8
MaxSize=512
Context=Places
Type=Scalable

[scalable/mimetypes]
Size=64
MinSize=8
MaxSize=512
Context=MimeTypes
Type=Scalable
"""
    write(os.path.join(OUT, "Verta", "index.theme"),
          index.format(name="Verta", inherits="Papirus-Dark,breeze-dark,hicolor"))
    write(os.path.join(OUT, "Verta-Light", "index.theme"),
          index.format(name="Verta Light", inherits="Papirus,breeze,hicolor"))

    # Contact sheet: every distinct drawing at 128px, on dark and light rows.
    cols, cell = 8, 140
    rows = math.ceil(len(sheet) / cols)
    parts = []
    for band, bg in enumerate(("#0b1220", "#f3f4f6")):
        oy = band * rows * cell
        parts.append(f'<rect x="0" y="{oy}" width="{cols * cell}" height="{rows * cell}" fill="{bg}"/>')
        for i, (name, fn) in enumerate(sheet):
            x, y = (i % cols) * cell + 6, oy + (i // cols) * cell + 6
            parts.append(f'<svg x="{x}" y="{y}" width="128" height="128" viewBox="0 0 512 512">'
                         f'{fn(f"p{band}_{i}")}</svg>')
    write(os.path.join(OUT, "preview.svg"),
          f'<svg xmlns="http://www.w3.org/2000/svg" width="{cols * cell}" height="{2 * rows * cell}">'
          + "".join(parts) + '</svg>\n')

    count = sum(len(n) for n in APPS.values()) + sum(len(n) for n in FOLDERS.values()) + 2
    print(f"Wrote {count} icons ({len(sheet)} designs) to {OUT}")


main()
