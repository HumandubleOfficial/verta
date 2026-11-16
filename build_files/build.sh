#!/usr/bin/bash
# Runs inside the image build (see Containerfile). Each numbered step script in
# this folder runs in order; they share the variables exported here.
set -xeuo pipefail

export FEDORA_VERSION="${FEDORA_VERSION:-$(rpm -E %fedora)}"
export VERTA_FLAVOR="${VERTA_FLAVOR:-verta}"
export VERTA_VERSION="${VERTA_VERSION:-dev}"
export KERNEL_FLAVOR="${KERNEL_FLAVOR:-ogc}"
export CTX=/ctx                     # this folder + system_files
export AKMODS=/akmods               # ghcr.io/ublue-os/akmods:<kernel flavor>
export AKMODS_NVIDIA=/akmods-nvidia # ghcr.io/ublue-os/akmods-nvidia-open:<kernel flavor>

# System files first, with fresh permissions (644 files / 755 dirs): files
# checked out on a Windows drive arrive as 0777, which must not end up in /usr.
cp -rT --no-preserve=mode,ownership "$CTX/system_files" /
chmod 0755 /usr/libexec/verta-flatpak-setup /usr/libexec/verta-boot-entry /usr/libexec/verta-update-notify /usr/bin/verta-settings

for step in "$CTX"/[0-9][0-9]-*.sh; do
    echo "==== $(basename "$step")"
    bash "$step"
done
