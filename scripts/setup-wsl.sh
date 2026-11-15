#!/usr/bin/env bash
# One-time setup of the WSL2 Ubuntu build environment.
#   wsl -u root -- bash scripts/setup-wsl.sh      (or run with sudo inside WSL)
set -euo pipefail

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo

$SUDO apt-get update
# podman/skopeo: images; librsvg2-bin: art; xorriso/squashfs-tools/mtools: ISO branding
$SUDO apt-get install -y podman skopeo librsvg2-bin xorriso squashfs-tools mtools

echo
podman --version

# Base image + build layers + ISO work files need roughly 40 GB.
$SUDO mkdir -p /var/lib/containers
avail_gb=$(df --output=avail -BG /var/lib/containers | tail -1 | tr -dc '0-9')
echo "Free space for container storage: ${avail_gb} GB"
if [ "$avail_gb" -lt 40 ]; then
    echo "WARNING: less than 40 GB free; image/ISO builds may run out of space." >&2
fi
