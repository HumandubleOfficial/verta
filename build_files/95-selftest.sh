#!/usr/bin/bash
# Last step: make sure Verta's own apps actually start in the finished image.
# A missing library or a QML mistake fails the build here instead of reaching
# people's PCs as an app that silently won't open.
set -xeuo pipefail

python3 -I -c 'import PySide6.QtCore, PySide6.QtGui, PySide6.QtQml, PySide6.QtWidgets'

# Open Verta Settings off-screen on every page; it saves a picture of each and
# quits. No picture means the window never came up.
T="$(mktemp -d)"
export HOME="$T" XDG_RUNTIME_DIR="$T" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
for page in appearance display sound gaming apps updates about; do
    timeout 60 /usr/bin/verta-settings --page "$page" --screenshot "$T/$page.png" 2>&1 | tail -20
    if [ ! -s "$T/$page.png" ]; then
        echo "selftest: Verta Settings did not open ($page page)" >&2
        exit 1
    fi
done
rm -rf "$T"
echo "selftest: Verta Settings opens on every page"

# Desktop defaults must be readable by everyone: a file only root can read is
# silently ignored by Plasma and the apps (the look would quietly fall back).
UNREADABLE="$(find /usr/share/kde-settings /etc/xdg /usr/share/plasma /usr/share/kwin \
    /usr/share/verta /usr/share/color-schemes /usr/share/aurorae /usr/share/icons/Verta \
    -type f ! -perm -o=r 2>/dev/null || true)"
if [ -n "$UNREADABLE" ]; then
    echo "selftest: these desktop files are readable by root only:" >&2
    echo "$UNREADABLE" >&2
    exit 1
fi
echo "selftest: desktop defaults are readable by everyone"
