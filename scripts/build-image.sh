#!/usr/bin/env bash
# Build a Verta OS image into root's podman storage (bootc-image-builder reads it from there).
#   scripts/build-image.sh [verta|verta-nvidia]
# Environment overrides: FEDORA_VERSION (45), KERNEL_FLAVOR (ogc | main), VERTA_VERSION (date)
set -euo pipefail

FLAVOR="${1:-verta}"
FEDORA_VERSION="${FEDORA_VERSION:-45}"
KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
VERTA_VERSION="${VERTA_VERSION:-$(date +%Y.%m.%d)}"
BASE_IMAGE=ghcr.io/ublue-os/kinoite-main

case "$FLAVOR" in
    verta|verta-nvidia) ;;
    *) echo "usage: $0 [verta|verta-nvidia]" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo

echo ">>> Building localhost/${FLAVOR}:latest (Fedora ${FEDORA_VERSION}, ${KERNEL_FLAVOR} kernel, Verta ${VERTA_VERSION})"

$SUDO podman build \
    --pull=newer \
    --build-arg BASE_IMAGE="$BASE_IMAGE" \
    --build-arg FEDORA_VERSION="$FEDORA_VERSION" \
    --build-arg KERNEL_FLAVOR="$KERNEL_FLAVOR" \
    --build-arg VERTA_FLAVOR="$FLAVOR" \
    --build-arg VERTA_VERSION="$VERTA_VERSION" \
    ${IMAGE_SOURCE:+--build-arg IMAGE_SOURCE="$IMAGE_SOURCE"} \
    --tag "localhost/${FLAVOR}:latest" \
    --tag "localhost/${FLAVOR}:${VERTA_VERSION}" \
    --file "$ROOT/Containerfile" \
    "$ROOT"

echo ">>> Done. Quick check:"
$SUDO podman run --rm "localhost/${FLAVOR}:latest" bash -c '
    grep -E "^(NAME|PRETTY_NAME|VARIANT)=" /usr/lib/os-release
    echo "kernel: $(ls /usr/lib/modules)"
    rpm -q steam gamescope mangohud gamemode scx-scheds ananicy-cpp papirus-icon-theme rsms-inter-fonts kwin-effect-roundcorners
    grep -E "^(kwin4_effect_shapecornersEnabled|glideEnabled|AllowTearing|AnimationDurationFactor)=" \
        /usr/share/kde-settings/kde-profile/default/xdg/kwinrc /usr/share/kde-settings/kde-profile/default/xdg/kdeglobals
    rpm -qa "kmod-*" | grep -v kmod-libs | sort
    systemctl is-enabled scx_loader.service ananicy-cpp.service verta-flatpak-setup.service 2>/dev/null || true
    echo "plymouth: $(plymouth-set-default-theme)"'
