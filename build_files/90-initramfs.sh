#!/usr/bin/bash
# Build the initramfs for the one installed kernel (includes the Verta boot
# splash and, on the NVIDIA flavor, the NVIDIA modules), then clean up.
set -xeuo pipefail

KREL=$(ls /usr/lib/modules)
depmod -a "$KREL"

export DRACUT_NO_XATTR=1
dracut --no-hostonly --kver "$KREL" --reproducible --zstd --add ostree \
    -f "/usr/lib/modules/$KREL/initramfs.img"
chmod 0600 "/usr/lib/modules/$KREL/initramfs.img"

# bootc images keep /boot empty (the kernel lives in /usr/lib/modules).
find /boot -mindepth 1 -delete

dnf5 clean all
rm -rf /var/lib/dnf /var/log/dnf5* /var/tmp/* /run/dnf /run/selinux-policy 2>/dev/null || true
