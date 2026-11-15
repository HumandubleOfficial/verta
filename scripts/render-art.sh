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

### Boot splash (Plymouth two-step): V as the watermark, ring as a 36-frame
### spinner drawn at the same spot, so the ring orbits the V while booting.
PLY="$SF/usr/share/plymouth/themes/verta"
mkdir -p "$PLY"
rm -f "$PLY"/*.png
rsvg-convert -w 200 -h 200 "$ART/logo-v.svg" -o "$PLY/watermark.png"
TMP="$(mktemp -d)"
for i in $(seq 1 36); do
    angle=$(( (i - 1) * 10 ))
    sed "s/rotate(0 256 256)/rotate(${angle} 256 256)/" "$ART/logo-ring.svg" > "$TMP/ring.svg"
    rsvg-convert -w 200 -h 200 "$TMP/ring.svg" -o "$PLY/throbber-$(printf '%04d' "$i").png"
done
rm -rf "$TMP"

### Installer (Anaconda) sidebar, top bar and header; used by brand-iso.sh ###
PIX="$ROOT/installer/pixmaps"
mkdir -p "$PIX"
rsvg-convert -w 406  -h 767 "$ART/installer/sidebar-bg.svg"   -o "$PIX/sidebar-bg.png"
rsvg-convert -w 180  -h 150 "$ART/installer/sidebar-logo.svg" -o "$PIX/sidebar-logo.png"
rsvg-convert -w 1040 -h 132 "$ART/installer/topbar-bg.svg"    -o "$PIX/topbar-bg.png"
rsvg-convert -w 119  -h 36  "$ART/installer/header.svg"       -o "$PIX/anaconda_header.png"

echo "Rendered art into system_files/ and installer/pixmaps/."
