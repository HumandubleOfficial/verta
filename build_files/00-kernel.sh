#!/usr/bin/bash
# Replace Fedora's kernel with the one from ghcr.io/ublue-os/akmods:<KERNEL_FLAVOR>.
# "ogc" is Universal Blue's gaming kernel (the one Bazzite uses); "main" is
# Fedora's stock kernel. Both are prebuilt together with matching kmods
# (NVIDIA, Xbox controllers) and signed with Universal Blue's key.
set -xeuo pipefail

# The NVIDIA flavor takes the kernel from the NVIDIA akmods image so it always
# matches kmod-nvidia exactly.
if [ "$VERTA_FLAVOR" = "verta-nvidia" ]; then
    KSRC="$AKMODS_NVIDIA/kernel-rpms"
else
    KSRC="$AKMODS/kernel-rpms"
fi

KREL=$(rpm -qp --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "$KSRC"/kernel-core-*.rpm)
echo "Installing kernel $KREL ($KERNEL_FLAVOR)"

# Kernel packages run kernel-install hooks (rpm-ostree, dracut, grub). In an
# image build we generate the initramfs ourselves (90-initramfs.sh), so
# replace the hooks with no-ops for the duration of the swap.
HOOKS=/usr/lib/kernel/install.d
mkdir -p /tmp/kernel-install-hooks
for hook in "$HOOKS"/*.install; do
    mv "$hook" /tmp/kernel-install-hooks/
    printf '#!/bin/sh\nexit 0\n' > "$hook"
    chmod 0755 "$hook"
done

# Remove the base image's kernel. --nodeps: nothing else may disappear with it.
mapfile -t OLD < <(rpm -qa --qf '%{NAME}\n' kernel kernel-core 'kernel-modules*' kernel-uki-virt | sort -u)
if [ "${#OLD[@]}" -gt 0 ]; then
    rpm -e --nodeps "${OLD[@]}"
fi
rm -rf /usr/lib/modules/*

# Install everything except devel packages.
mapfile -t NEW < <(find "$KSRC" -name 'kernel-*.rpm' ! -name '*-devel-*' | sort)
dnf5 -y install "${NEW[@]}"

# Extra drivers: Xbox wireless dongle (xone), Xbox Bluetooth controllers
# (xpadneo) and v4l2loopback (OBS virtual camera). Only if built for this kernel.
EXTRA=()
for name in xone xpadneo v4l2loopback; do
    kmod=$(find "$AKMODS/rpms/kmods" -name "kmod-${name}-${KREL}-*.rpm" 2>/dev/null | head -1)
    if [ -n "$kmod" ]; then
        EXTRA+=("$kmod")
        common=$(find "$AKMODS/rpms/common" -name "${name}-*.rpm" -o -name "${name}-kmod-common-*.rpm" 2>/dev/null | head -1)
        [ -n "$common" ] && EXTRA+=("$common")
    else
        echo "WARNING: no kmod-$name for $KREL in akmods image; skipping"
    fi
done
[ "${#EXTRA[@]}" -gt 0 ] && dnf5 -y install "${EXTRA[@]}"

# Put the real hooks back.
for hook in /tmp/kernel-install-hooks/*.install; do
    mv -f "$hook" "$HOOKS/"
done

# Exactly one kernel must remain.
[ "$(ls /usr/lib/modules | wc -l)" -eq 1 ] || { ls -la /usr/lib/modules; exit 1; }
[ -f "/usr/lib/modules/$KREL/vmlinuz" ]
