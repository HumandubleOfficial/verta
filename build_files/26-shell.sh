#!/usr/bin/bash
# Verta Shell: compile its launcher (build_files/shell/main.cpp, /usr/bin/verta-shell).
# The shell itself is QML in system_files/usr/share/verta-shell. The compiler
# and headers are removed again afterwards, as in 25-glass.sh.
set -xeuo pipefail

# plasma-workspace-devel: the headers of libnotificationmanager (the notification server).
BUILD_DEPS=(gcc-c++ pkgconf-pkg-config qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel plasma-workspace-devel)

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/shell-before.txt
dnf5 -y install --setopt=install_weak_deps=False "${BUILD_DEPS[@]}"

SRC="$(mktemp -d)"
cp "$CTX/shell/main.cpp" "$SRC/"
/usr/lib64/qt6/libexec/moc "$SRC/main.cpp" -o "$SRC/main.moc"
# shellcheck disable=SC2046
g++ -std=c++17 -O2 -fPIC -I"$SRC" "$SRC/main.cpp" -o /usr/bin/verta-shell \
    $(pkg-config --cflags --libs Qt6Gui Qt6Qml Qt6Quick Qt6DBus) \
    -I/usr/include/KF6/KWindowSystem -lKF6WindowSystem -lnotificationmanager
rm -rf "$SRC"

rpm -qa --qf '%{NAME}\n' | sort -u > /tmp/shell-after.txt
mapfile -t ADDED < <(comm -13 /tmp/shell-before.txt /tmp/shell-after.txt)
if [ "${#ADDED[@]}" -gt 0 ]; then
    rpm -e "${ADDED[@]}"
fi
rm -f /tmp/shell-before.txt /tmp/shell-after.txt

test -x /usr/bin/verta-shell
if ldd /usr/bin/verta-shell | grep -q 'not found'; then
    ldd /usr/bin/verta-shell | grep 'not found' >&2
    exit 1
fi
test -f /usr/share/verta-shell/qml/Shell.qml
