#!/usr/bin/env bash
# Rebrand an ISO made by bootc-image-builder as Verta:
#   - installer (Anaconda) look: Verta sidebar/top bar/logo instead of Fedora's,
#     and "VERTA INSTALLATION" / "WELCOME TO VERTA." without a version number
#   - boot menu entries "Install Verta" and volume label "Verta"
#   - puts Universal Blue's Secure Boot key on the ISO for the kickstart to enrol
#
#   - Verta's font (Inter) in the installer, if a folder of Inter .ttf files is given
#
#   scripts/brand-iso.sh <input.iso> <output.iso> <secureboot-key.der> [inter-fonts-dir]
#
# Called by build-iso.sh. Needs root (loop mount) and xorriso, squashfs-tools, mtools.
set -euo pipefail

IN="$1"; OUT="$2"; KEY="$3"; FONTS="${4:-}"
NEW_LABEL="Verta"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for tool in xorriso unsquashfs mksquashfs mcopy; do
    command -v "$tool" >/dev/null || apt-get install -y -qq xorriso squashfs-tools mtools >/dev/null
done

W="$(mktemp -d /var/tmp/verta-brand.XXXXXX)"
MNT="$W/iso"
mkdir -p "$MNT"
mount -o loop,ro "$IN" "$MNT"
trap 'umount "$MNT" 2>/dev/null || true; rm -rf "$W"' EXIT

OLD_LABEL="$(blkid -o value -s LABEL "$IN")"
echo ">>> Rebranding ISO (label '$OLD_LABEL' -> '$NEW_LABEL')"

### 1. Installer image (stage2) ##############################################
echo ">>> Unpacking installer image"
unsquashfs -q -no-progress -d "$W/stage2" "$MNT/images/install.img"
S2="$W/stage2"
PIXDIR="$S2/usr/share/anaconda/pixmaps"
PY="$(find "$S2/usr" -type d -name pyanaconda -path '*site-packages*' | head -1)"

# Look: Verta images + stylesheet in place of Fedora's (Anaconda's Fedora
# profile loads fedora.css, so it is replaced rather than re-pointed).
mkdir -p "$PIXDIR/verta"
cp "$ROOT"/installer/pixmaps/{sidebar-bg,sidebar-logo,topbar-bg}.png "$PIXDIR/verta/"
cp "$ROOT/installer/pixmaps/anaconda_header.png" "$PIXDIR/anaconda_header.png"
for css in "$PIXDIR/fedora.css" "$PIXDIR"/*/fedora-*.css; do
    [ -f "$css" ] && cp "$ROOT/installer/anaconda.css" "$css"
done

# Font: Inter, like the installed system (same fontconfig rule).
if [ -n "$FONTS" ] && ls "$FONTS"/Inter-*.ttf >/dev/null 2>&1; then
    mkdir -p "$S2/usr/share/fonts/verta-inter" "$S2/etc/fonts/conf.d"
    cp "$FONTS"/Inter-*.ttf "$S2/usr/share/fonts/verta-inter/"
    cp "$ROOT/system_files/usr/share/fontconfig/conf.avail/45-verta-fonts.conf" "$S2/etc/fonts/conf.d/"
fi

# Text: product name without the Fedora version number.
patch_py() {  # file, sed expression
    grep -q "$3" "$1" || { echo "WARNING: pattern not found in $1: $3" >&2; return 0; }
    sed -i "$2" "$1"
    rm -f "$(dirname "$1")/__pycache__/$(basename "$1" .py)".*.pyc
}
patch_py "$PY/ui/helpers.py" \
    's/"%(productName)s %(productVersion)s INSTALLATION"/"%(productName)s INSTALLATION"/' \
    '%(productName)s %(productVersion)s INSTALLATION'
patch_py "$PY/ui/gui/spokes/welcome.py" \
    's/"WELCOME TO %(name)s %(version)s\."/"WELCOME TO %(name)s."/' \
    'WELCOME TO %(name)s %(version)s'
patch_py "$PY/ui/gui/spokes/custom_storage.py" \
    's/your %(name)s %(version)s /your %(name)s /' \
    'your %(name)s %(version)s '
sed -i 's/^product = .*/product = Verta/' "$S2/.buildstamp"

echo ">>> Repacking installer image"
mksquashfs "$S2" "$W/install.img" -comp zstd -b 131072 -noappend -no-progress -quiet

### 2. Boot menus (ISO + the EFI partition copy) #############################
fix_cfg() {
    sed -e "s/${OLD_LABEL}/${NEW_LABEL}/g" \
        -e "s/Verta [0-9][0-9]*/Verta/g" \
        -e "s/--class fedora/--class verta --class fedora/g" "$1"
}
xorriso -osirrox on -indev "$IN" \
    -extract /EFI/BOOT/grub.cfg "$W/efi-grub.cfg" \
    -extract /boot/grub2/grub.cfg "$W/bios-grub.cfg" 2>/dev/null
chmod u+w "$W"/*.cfg
fix_cfg "$W/efi-grub.cfg"  > "$W/efi-grub.new.cfg"
fix_cfg "$W/bios-grub.cfg" > "$W/bios-grub.new.cfg"

cp "$MNT/images/efiboot.img" "$W/efiboot.img"
chmod u+w "$W/efiboot.img"
mcopy -o -i "$W/efiboot.img" "$W/efi-grub.new.cfg" ::/EFI/BOOT/grub.cfg

### 3. Write the new ISO #####################################################
# Replays the original boot setup (BIOS + UEFI, hybrid USB layout); only the
# EFI partition, changed files and label differ.
echo ">>> Writing $OUT"
rm -f "$OUT"
xorriso -indev "$IN" -outdev "$OUT" \
    -volid "$NEW_LABEL" \
    -boot_image any replay \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$W/efiboot.img" \
    -map "$W/efiboot.img"       /images/efiboot.img \
    -map "$W/install.img"       /images/install.img \
    -map "$W/efi-grub.new.cfg"  /EFI/BOOT/grub.cfg \
    -map "$W/bios-grub.new.cfg" /boot/grub2/grub.cfg \
    -map "$KEY"                 /verta-secureboot.der \
    2>&1 | grep -vE "^xorriso : UPDATE|^$" || true

# Sanity checks.
[ "$(blkid -o value -s LABEL "$OUT")" = "$NEW_LABEL" ]
xorriso -osirrox on -indev "$OUT" -extract /EFI/BOOT/grub.cfg "$W/check.cfg" 2>/dev/null
grep -q "LABEL=${NEW_LABEL}" "$W/check.cfg"
grep -q "Install Verta'" "$W/check.cfg"
# The boot image UEFI firmware actually loads (DVD and USB) must carry the new menu.
mkdir -p "$W/bootimgs"
xorriso -osirrox on -indev "$OUT" -extract_boot_images "$W/bootimgs/" 2>/dev/null
UEFI_IMG="$(ls "$W"/bootimgs/*uefi* | head -1)"
mtype -i "$UEFI_IMG" ::/EFI/BOOT/grub.cfg | grep -q "LABEL=${NEW_LABEL}" \
    || { echo "UEFI boot image still has the old boot menu" >&2; exit 1; }
[ -f "$KEY" ] && xorriso -indev "$OUT" -find /verta-secureboot.der 2>/dev/null | grep -q verta-secureboot
echo ">>> Rebranded ISO ready"
