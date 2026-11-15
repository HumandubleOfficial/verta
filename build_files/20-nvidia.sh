#!/usr/bin/bash
# NVIDIA flavor only: proprietary userspace + open kernel modules built for the
# exact kernel installed by 00-kernel.sh (from ghcr.io/ublue-os/akmods-nvidia-open).
set -xeuo pipefail

[ "$VERTA_FLAVOR" = "verta-nvidia" ] || { echo "not the NVIDIA flavor; skipping"; exit 0; }

KREL=$(ls /usr/lib/modules)

# Repo files, modprobe config and kernel args from Universal Blue first...
dnf5 -y install "$AKMODS_NVIDIA"/rpms/ublue-os/ublue-os-nvidia-addons-*.rpm

# ...then the driver itself (64- and 32-bit libraries for Steam) and the kmod.
KMOD=$(find "$AKMODS_NVIDIA/rpms/kmods" -name "kmod-nvidia-${KREL}-*.rpm" | head -1)
[ -n "$KMOD" ] || { echo "No kmod-nvidia built for kernel $KREL" >&2; exit 1; }
dnf5 -y install "$AKMODS_NVIDIA"/rpms/nvidia/*.rpm "$KMOD" libva-nvidia-driver

# Keep nouveau out of the way and enable kernel modesetting, unless the addons
# package already ships those kernel arguments.
if ! grep -rqs nouveau /usr/lib/bootc/kargs.d/; then
    cat > /usr/lib/bootc/kargs.d/00-verta-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1", "nvidia-drm.fbdev=1"]
EOF
fi
