#!/usr/bin/bash
# Performance services and boot-time trims.
set -xeuo pipefail

### CPU scheduler: sched-ext "LAVD" (built for gaming: favours the
### latency-critical threads that drive frame times). The kernel falls back to
### its normal scheduler automatically if scx ever stops.
if [ -f /usr/lib/systemd/system/scx_loader.service ]; then
    mkdir -p /etc/scx_loader
    for cfg in /etc/scx_loader/config.toml /etc/scx_loader.toml; do
        cat > "$cfg" <<'EOF'
default_sched = "scx_lavd"
default_mode = "Auto"
EOF
    done
    systemctl enable scx_loader.service
elif [ -f /usr/lib/systemd/system/scx.service ]; then
    sed -i 's/^SCX_SCHEDULER=.*/SCX_SCHEDULER=scx_lavd/' /etc/default/scx
    systemctl enable scx.service
else
    echo "ERROR: no scx service found" >&2
    exit 1
fi

### Process priorities: ananicy-cpp with CachyOS' rules (games and audio up,
### compilers, indexers and updaters down).
systemctl enable ananicy-cpp.service

### Faster login: KDE Connect can't be removed (other packages need its
### library), so at least don't start its daemon at every login. Users can
### still launch it from the menu.
rm -f /etc/xdg/autostart/org.kde.kdeconnect.daemon.desktop
# File indexer (indexing is switched off in 30-desktop.sh) and Discover's
# update notifier (Verta updates as a whole image; Flatpaks update on a timer).
rm -f /etc/xdg/autostart/baloo_file.desktop
rm -f /etc/xdg/autostart/org.kde.discover.notifier.desktop

### Faster boot.
# Don't hold up boot waiting for the network (Verta's first-boot app install
# waits for it on its own).
systemctl disable NetworkManager-wait-online.service
# Mobile-broadband modems are rare on gaming PCs.
systemctl disable ModemManager.service
# dnf metadata refresh is useless on an image-based system.
systemctl disable dnf-makecache.timer
# Fedora's anonymous user-count ping and the man-page index rebuild at boot.
for unit in rpm-ostree-countme.timer fedora-atomic-desktop-mandb-update.service; do
    if [ -e "/usr/lib/systemd/system/$unit" ]; then
        systemctl disable "$unit"
    fi
done

### Privacy: nothing is sent anywhere unless you ask.
# Fedora's count ping is off (above). KDE's crash reporter still shows what
# crashed, but never uploads in the background.
systemctl --global mask drkonqi-sentry-postman.path drkonqi-sentry-postman.timer drkonqi-sentry-postman.service
# No "donate to KDE" or "get the browser extension" pop-ups.
kwriteconfig6 --file /etc/xdg/kded6rc --group Module-donationmessage --key autoload false
kwriteconfig6 --file /etc/xdg/kded6rc --group Module-browserintegrationreminder --key autoload false
# Firefox: no telemetry, studies, sponsored tiles or "recommended" pop-ups;
# it uses the system's file dialog (system_files/usr/lib64/firefox).
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' /usr/lib64/firefox/distribution/policies.json

systemctl enable verta-flatpak-setup.service

### Updates: Verta downloads new versions by itself every day (rpm-ostree
### automatic updates, policy "stage"); this tells people when one is ready.
grep -q "^AutomaticUpdatePolicy=stage" /etc/rpm-ostreed.conf
systemctl --global enable verta-update-notify.path
