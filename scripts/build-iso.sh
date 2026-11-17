#!/usr/bin/env bash
# Turn a built Verta image into an installable ISO with bootc-image-builder.
#   scripts/build-iso.sh [verta|verta-nvidia]
# Output: output/<flavor>-<YYYYMMDD-HHMM>.iso in the project folder.
set -euo pipefail

FLAVOR="${1:-verta}"
LOCAL_IMAGE="localhost/${FLAVOR}:latest"
# Where installed systems get their updates from (published by
# .github/workflows/build.yml). The ISO installs the locally built image but
# tells the installed system to update from this registry image.
REGISTRY="${REGISTRY:-ghcr.io/humandubleofficial}"
IMAGE="${REGISTRY}/${FLAVOR}:latest"
BIB_IMAGE="${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo

if ! $SUDO podman image exists "$LOCAL_IMAGE"; then
    echo "$LOCAL_IMAGE not found; run scripts/build-image.sh $FLAVOR first." >&2
    exit 1
fi
$SUDO podman tag "$LOCAL_IMAGE" "$IMAGE"

# Build on the Linux filesystem (fast, supports the file ops osbuild needs),
# then copy the finished ISO to the project folder.
WORK="/var/tmp/verta-iso/${FLAVOR}"
$SUDO rm -rf "$WORK"
$SUDO mkdir -p "$WORK"
$SUDO cp "$ROOT/disk_config/iso.toml" "$WORK/config.toml"

echo ">>> Building ISO from $IMAGE"
$SUDO podman run --rm --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$WORK/config.toml:/config.toml:ro" \
    -v "$WORK:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$BIB_IMAGE" \
    --type anaconda-iso \
    --rootfs btrfs \
    "$IMAGE"

ISO_SRC="$(find "$WORK" -name '*.iso' ! -name 'verta-branded.iso' | head -1)"
[ -n "$ISO_SRC" ] || { echo "No ISO produced." >&2; exit 1; }

# Universal Blue's Secure Boot key, from the image itself, for the installer to enrol.
KEY="$WORK/verta-secureboot.der"
$SUDO podman run --rm "$IMAGE" cat /etc/pki/akmods/certs/akmods-ublue.der > "$KEY"

# Verta's UI font (Inter), from the image itself, for the installer.
FONTS="$WORK/fonts"
mkdir -p "$FONTS"
$SUDO podman run --rm "$IMAGE" tar -C /usr/share/fonts/rsms-inter-fonts -c \
    Inter-Regular.ttf Inter-Italic.ttf Inter-Medium.ttf Inter-SemiBold.ttf Inter-Bold.ttf \
    | tar -C "$FONTS" -x

# Verta branding for the installer, boot menu and volume label.
$SUDO bash "$ROOT/scripts/brand-iso.sh" "$ISO_SRC" "$WORK/verta-branded.iso" "$KEY" "$FONTS"

mkdir -p "$ROOT/output"
# Timestamped, so a new build never collides with an ISO a VM still has attached.
ISO_DST="$ROOT/output/${FLAVOR}-$(date +%Y%m%d-%H%M).iso"
cp "$WORK/verta-branded.iso" "$ISO_DST"
echo ">>> ISO ready: $ISO_DST ($(du -h "$ISO_DST" | cut -f1))"
