#!/usr/bin/env bash
# Render art/*.svg into the files the image ships (PNG where SVG isn't supported).
# Run after editing anything in art/:   wsl -u root -- bash scripts/render-art.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ART="$ROOT/art"
SF="$ROOT/system_files"

if ! command -v rsvg-convert >/dev/null; then
    SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo
    $SUDO apt-get install -y librsvg2-bin
fi

install_to() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }

### Wallpaper (desktop, lock screen, login screen) ###########################
WP="$SF/usr/share/wallpapers/Verta/contents/images"
mkdir -p "$WP"
rm -f "$WP"/*
rsvg-convert -w 3840 -h 2160 "$ART/wallpaper.svg" -o "$WP/3840x2160.png"
rsvg-convert -w 1920 -h 1080 "$ART/wallpaper.svg" -o "$SF/usr/share/wallpapers/Verta/contents/screenshot.png"

### Logo: start button, About This System, app icon ##########################
install_to "$ART/logo.svg" "$SF/usr/share/icons/hicolor/scalable/apps/verta-logo.svg"
install_to "$ART/logo.svg" "$SF/usr/share/pixmaps/verta-logo.svg"

### Login splash (QML): V and ring as separate layers so the ring can spin ####
SPLASH="$SF/usr/share/plasma/look-and-feel/org.verta.desktop/contents/splash/images"
mkdir -p "$SPLASH"
rm -f "$SPLASH"/*
cp "$ART/logo-v.svg"    "$SPLASH/logo-v.svg"
cp "$ART/logo-ring.svg" "$SPLASH/logo-ring.svg"

### Boot animation (Plymouth script theme, verta.script): the V, the ring with
### its moon as 72 frames 5 degrees apart, glow, password pill, progress line.
### Rendered large (384 px) so they stay sharp on 4K; the script scales down.
PLY="$SF/usr/share/plymouth/themes/verta"
mkdir -p "$PLY"
rm -f "$PLY"/*.png
rsvg-convert -w 384 -h 384 "$ART/logo-v.svg" -o "$PLY/logo-v.png"
TMP="$(mktemp -d)"
for i in $(seq 0 71); do
    sed "s/rotate(0 256 256)/rotate($(( i * 5 )) 256 256)/" "$ART/logo-ring.svg" > "$TMP/ring.svg"
    rsvg-convert -w 384 -h 384 "$TMP/ring.svg" -o "$PLY/ring-$i.png"
done
rm -rf "$TMP"
rsvg-convert -w 640 -h 640 "$ART/plymouth/glow.svg"   -o "$PLY/glow.png"
rsvg-convert -w 600 -h 88  "$ART/plymouth/entry.svg"  -o "$PLY/entry.png"
rsvg-convert -w 32  -h 32  "$ART/plymouth/bullet.svg" -o "$PLY/bullet.png"
rsvg-convert -w 400 -h 8   "$ART/plymouth/track.svg"  -o "$PLY/track.png"
rsvg-convert -w 400 -h 8   "$ART/plymouth/fill.svg"   -o "$PLY/fill.png"

### Verta icon theme (app tiles + folders, generated) #########################
### Verta-Light gets only an index.theme here; it shares Verta's icons through
### a symlink made at build time (30-desktop.sh) and inherits light Papirus.
TMP="$(mktemp -d)"
python3 -I "$ART/icons/make-icons.py" "$TMP"
ICONS="$SF/usr/share/icons"
rm -rf "$ICONS/Verta" "$ICONS/Verta-Light"
cp -r "$TMP/Verta" "$TMP/Verta-Light" "$ICONS/"
rsvg-convert -w 1120 "$TMP/preview.svg" -o "$ART/icons/preview.png"
install_to "$ICONS/Verta/scalable/apps/org.verta.Settings.svg" "$ICONS/hicolor/scalable/apps/org.verta.Settings.svg"
rm -rf "$TMP"

### Verta Plasma style (taskbar, popups, tooltips, highlights) ###############
rm -rf "$SF/usr/share/plasma/desktoptheme/verta"
python3 -I "$ART/plasma/make-plasma-style.py" "$SF/usr/share/plasma/desktoptheme"

### Verta window title bars with round buttons (Aurorae themes) #############
rm -rf "$SF/usr/share/aurorae/themes/Verta" "$SF/usr/share/aurorae/themes/Verta-Light"
python3 -I "$ART/aurorae/make-aurorae.py" "$SF/usr/share/aurorae/themes"
PREV="$(mktemp -d)"
for t in Verta Verta-Light; do
    for b in minimize maximize restore close; do
        rsvg-convert -z 4 "$SF/usr/share/aurorae/themes/$t/$b.svg" -o "$PREV/$t-$b.png"
    done
done
mkdir -p "$ART/aurorae/preview" && cp "$PREV"/*.png "$ART/aurorae/preview/" && rm -rf "$PREV"

### Verta logo in place of distro logos: icon names apps and KDE ask for
### (start-here, distributor-logo, ...) and PNG sizes for the files Fedora's
### logo package ships (swapped in at build time by 50-branding.sh).
for n in start-here start-here-kde start-here-kde-plasma distributor-logo system-logo \
         fedora-logo-icon start-here-fedora distributor-logo-fedora; do
    install_to "$ART/logo.svg" "$ICONS/Verta/scalable/apps/$n.svg"
    install_to "$ART/logo.svg" "$ICONS/Verta/scalable/places/$n.svg"
done
LOGO="$SF/usr/share/verta/logo"
rm -rf "$LOGO"; mkdir -p "$LOGO"
cp "$ART/logo.svg" "$LOGO/verta-logo.svg"
for s in 16 22 24 32 36 48 64 96 128 256 512; do
    rsvg-convert -w "$s" -h "$s" "$ART/logo.svg" -o "$LOGO/verta-logo-$s.png"
done

### Installer (Anaconda) sidebar, top bar and header; used by brand-iso.sh ###
PIX="$ROOT/installer/pixmaps"
mkdir -p "$PIX"
rsvg-convert -w 406  -h 767 "$ART/installer/sidebar-bg.svg"   -o "$PIX/sidebar-bg.png"
rsvg-convert -w 180  -h 150 "$ART/installer/sidebar-logo.svg" -o "$PIX/sidebar-logo.png"
rsvg-convert -w 1040 -h 132 "$ART/installer/topbar-bg.svg"    -o "$PIX/topbar-bg.png"
rsvg-convert -w 119  -h 36  "$ART/installer/header.svg"       -o "$PIX/anaconda_header.png"

echo "Rendered art into system_files/ and installer/pixmaps/."
