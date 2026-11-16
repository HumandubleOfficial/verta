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
