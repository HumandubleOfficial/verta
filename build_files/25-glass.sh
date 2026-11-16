#!/usr/bin/bash
# Liquid glass: build the "Glass" KWin effect (https://github.com/4v3ngR/kwin-effects-glass,
# GPL-3.0) from source, against the exact KWin in this image. It replaces Plasma's
# blur with real glass: the picture behind a panel, the dock, a menu or a popup bends
# at its rounded edges like light through a lens, its rim catches the light, and the
# tint adapts to what is behind it. 30-desktop.sh switches it on and tunes it.
#
# KWin effects only load into the KWin they were compiled for, so this is built
# here, in the same image, every time; never taken from a package for another KWin.
set -xeuo pipefail

GLASS_COMMIT=5e2845fffbe893177c091fe18d603b9095cc2729   # main, 2026-11-09 (Plasma 6.8 support)

BUILD_DEPS=(
    cmake extra-cmake-modules gcc-c++ kwin-devel kdecoration-devel libplasma-devel
    kf6-kconfigwidgets-devel kf6-kcmutils-devel kf6-kwindowsystem-devel kf6-kglobalaccel-devel
    kf6-ki18n-devel kf6-kcoreaddons-devel kf6-kconfig-devel kf6-kguiaddons-devel
    kf6-kcrash-devel kf6-knotifications-devel kf6-kservice-devel kf6-kpackage-devel
    kf6-kwidgetsaddons-devel qt6-qtbase-devel qt6-qtbase-private-devel qt6-qttools-devel
    qt6-qtdeclarative-devel libepoxy-devel wayland-devel wayland-protocols-devel
    plasma-wayland-protocols-devel libdrm-devel libxcb-devel
)

# Remember what is installed now, so exactly the build tools come out again.
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/glass-before.txt
dnf5 -y install --setopt=install_weak_deps=False "${BUILD_DEPS[@]}"

SRC="$(mktemp -d)"
curl -fsSL "https://github.com/4v3ngR/kwin-effects-glass/archive/${GLASS_COMMIT}.tar.gz" \
    | tar -xz -C "$SRC" --strip-components=1
cmake -S "$SRC" -B "$SRC/build" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build "$SRC/build" -j"$(nproc)"
cmake --install "$SRC/build"
install -Dm644 "$SRC/LICENSE" /usr/share/licenses/kwin-effects-glass/LICENSE
rm -rf "$SRC"

# Take the build tools out again (only what this script added).
rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/glass-after.txt
mapfile -t ADDED < <(comm -13 /tmp/glass-before.txt /tmp/glass-after.txt)
if [ "${#ADDED[@]}" -gt 0 ]; then
    rpm -e "${ADDED[@]}"
fi
rm -f /tmp/glass-before.txt /tmp/glass-after.txt

# The effect must load: every library it needs is still there after the clean-up.
PLUGINS=/usr/lib64/qt6/plugins/kwin/effects
test -f "$PLUGINS/plugins/glass.so"
test -f "$PLUGINS/configs/kwin_glass_config.so"
if ldd "$PLUGINS/plugins/glass.so" "$PLUGINS/configs/kwin_glass_config.so" | grep -q 'not found'; then
    ldd "$PLUGINS/plugins/glass.so" "$PLUGINS/configs/kwin_glass_config.so" | grep 'not found' >&2
    exit 1
fi
