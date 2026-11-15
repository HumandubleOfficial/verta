#!/usr/bin/bash
# os-release branding, plus repo files bootc-image-builder needs.
set -xeuo pipefail

# Keep ID=fedora so Fedora tooling (and bootc-image-builder) still recognises the
# system; only the user-facing names change.
OS_RELEASE=/usr/lib/os-release
sed -i \
    -e "s|^NAME=.*|NAME=\"Verta\"|" \
    -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Verta\"|" \
    -e "s|^VARIANT=.*|VARIANT=\"Gaming Desktop\"|" \
    -e "s|^VARIANT_ID=.*|VARIANT_ID=${VERTA_FLAVOR}|" \
    -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"verta\"|" \
    -e "s|^LOGO=.*|LOGO=verta-logo|" \
    "$OS_RELEASE"
for kv in 'VARIANT="Gaming Desktop"' "VARIANT_ID=${VERTA_FLAVOR}" 'DEFAULT_HOSTNAME="verta"' 'LOGO=verta-logo'; do
    grep -q "^${kv%%=*}=" "$OS_RELEASE" || echo "$kv" >> "$OS_RELEASE"
done
sed -i '/^IMAGE_ID=/d; /^IMAGE_VERSION=/d' "$OS_RELEASE"
echo "IMAGE_ID=${VERTA_FLAVOR}"       >> "$OS_RELEASE"
echo "IMAGE_VERSION=${VERTA_VERSION}" >> "$OS_RELEASE"

gtk-update-icon-cache -f /usr/share/icons/hicolor || true

# Fedora 45 keeps its .repo files in /usr/share/dnf5/repos.d, but
# bootc-image-builder only reads /etc/yum.repos.d from the image when building
# the installer ISO (it fails with "missing packages: glibc, systemd, ...").
# A same-named file in /etc overrides the /usr/share one, so this is safe for dnf.
for repo in /usr/share/dnf5/repos.d/*.repo; do
    [ -e "$repo" ] || continue
    [ -e "/etc/yum.repos.d/$(basename "$repo")" ] || cp "$repo" /etc/yum.repos.d/
done
