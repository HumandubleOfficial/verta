#!/usr/bin/bash
# Verta branding: Fedora is the engine underneath, but nothing a user sees
# should say Fedora. Names, logos, links, themes, wallpapers, Firefox, Flatpak
# sources and the firmware boot entry all become Verta.
set -xeuo pipefail

VERTA_URL=https://github.com/HumandubleOfficial/verta
LOGO=/usr/share/verta/logo          # rendered by scripts/render-art.sh

### os-release ###############################################################
# ID=fedora and VERSION_ID stay: they are how package tools, Distrobox and
# bootc-image-builder recognise the base. Everything shown to people changes.
OS_RELEASE=/usr/lib/os-release
sed -i -E '/^(NAME|PRETTY_NAME|VERSION|VERSION_CODENAME|VARIANT|VARIANT_ID|DEFAULT_HOSTNAME|LOGO|ANSI_COLOR|CPE_NAME|HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL|SUPPORT_END|REDHAT_[A-Z_]+|IMAGE_ID|IMAGE_VERSION)=/d' "$OS_RELEASE"
cat >> "$OS_RELEASE" <<EOF
NAME="Verta"
PRETTY_NAME="Verta"
VERSION="${VERTA_VERSION}"
VARIANT="Gaming Desktop"
VARIANT_ID=${VERTA_FLAVOR}
DEFAULT_HOSTNAME="verta"
LOGO=verta-logo
ANSI_COLOR="1;38;2;59;130;246"
HOME_URL="${VERTA_URL}"
DOCUMENTATION_URL="${VERTA_URL}#readme"
SUPPORT_URL="${VERTA_URL}/issues"
BUG_REPORT_URL="${VERTA_URL}/issues"
IMAGE_ID=${VERTA_FLAVOR}
IMAGE_VERSION=${VERTA_VERSION}
EOF
grep -q '^ID=fedora' "$OS_RELEASE"
if grep -qiE 'fedoraproject|kinoite' "$OS_RELEASE"; then echo 'Fedora left in os-release' >&2; exit 1; fi

# /etc/system-release is what some apps print as the OS name. fedora-release
# and redhat-release stay for tools that check for a Fedora base.
rm -f /etc/system-release
echo "Verta release ${VERTA_VERSION}" > /usr/lib/system-release
ln -s ../usr/lib/system-release /etc/system-release

### About This System ########################################################
cat > /etc/xdg/kcm-about-distrorc <<EOF
[General]
LogoPath=${LOGO}/verta-logo.svg
Website=${VERTA_URL}
EOF

### Logos: every Fedora logo file becomes the Verta logo ######################
# (the files stay so nothing that points at them breaks)
size_of() {   # .../48x48/apps/x.png -> 48
    local d; d="$(basename "$(dirname "$(dirname "$1")")")"
    [[ $d =~ ^([0-9]+)x[0-9]+$ ]] && echo "${BASH_REMATCH[1]}" || echo 256
}
png_for() {
    local s; s="$(size_of "$1")"
    [ -f "$LOGO/verta-logo-$s.png" ] && echo "$LOGO/verta-logo-$s.png" || echo "$LOGO/verta-logo-256.png"
}
while IFS= read -r -d '' f; do
    cp "$(png_for "$f")" "$f"
done < <(find /usr/share/icons/hicolor /usr/share/icons/Bluecurve -type f \
           \( -name 'fedora-logo*.png' -o -name 'start-here.png' -o -name 'kmenu.png' \
              -o -name 'icon-panel-menu.png' -o -name 'gnome-main-menu.png' \) -print0)
find /usr/share/icons/hicolor -type f -name 'fedora-logo*.svg' -exec cp "$LOGO/verta-logo.svg" {} \;
for f in /usr/share/pixmaps/fedora*.png /usr/share/pixmaps/system-logo*.png; do
    if [ -f "$f" ]; then cp "$LOGO/verta-logo-256.png" "$f"; fi
done
for f in /usr/share/pixmaps/fedora*.svg /usr/share/fedora-logos/*.svg; do
    if [ -f "$f" ]; then cp "$LOGO/verta-logo.svg" "$f"; fi
done
if [ -f /etc/favicon.png ]; then cp "$LOGO/verta-logo-32.png" /etc/favicon.png; fi
gtk-update-icon-cache -f /usr/share/icons/hicolor || true

### Themes and wallpapers ####################################################
# Fedora's global themes (Fedora / Fedora Dark / Fedora Light) and wallpapers
# can't be uninstalled (Plasma requires the packages), so drop their files and
# point anything that used them at Verta.
rm -rf /usr/share/plasma/look-and-feel/org.fedoraproject.*
rm -rf /usr/share/wallpapers/F[0-9][0-9] /usr/share/wallpapers/Fedora
ln -sfn Verta /usr/share/wallpapers/Default
grep -rlIZ -E 'wallpapers/(Fedora|F[0-9]{2})|org\.fedoraproject\.fedora(dark|light)?\.desktop' \
    /etc /usr/lib/plasmalogin /usr/share/kde-settings /usr/share/plasma 2>/dev/null \
  | xargs -0 -r sed -i -E \
      -e 's#wallpapers/(Fedora|F[0-9]{2})/?#wallpapers/Verta/#g' \
      -e 's#org\.fedoraproject\.fedoralight\.desktop#org.verta.light#g' \
      -e 's#org\.fedoraproject\.fedora(dark)?\.desktop#org.verta.desktop#g' \
  || true
if grep -rlI -E 'wallpapers/(Fedora|F[0-9]{2})|org\.fedoraproject\.fedora' \
        /etc /usr/lib/plasmalogin /usr/share/kde-settings /usr/share/plasma 2>/dev/null; then
    echo 'Fedora theme/wallpaper references left (above)' >&2
    exit 1
fi
# GNOME-style Fedora backgrounds (some apps' wallpaper pickers list these too).
rm -rf /usr/share/backgrounds/f[0-9][0-9] /usr/share/backgrounds/fedora-workstation
# NeoChat's preset "Fedora" chat room.
rm -f /usr/share/kde-settings/kde-profile/default/xdg/neochatrc

### The OS entry the App Store (Discover) shows: Verta, not "Fedora Linux" ####
# The id stays (it ties the entry to this system); name, text and links are
# Verta's, and Fedora's release list (its upgrade prompts) is gone.
OS_META=/usr/share/metainfo/org.fedoraproject.fedora.metainfo.xml
if [ -f "$OS_META" ]; then
    cat > "$OS_META" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="operating-system">
  <id>org.fedoraproject.fedora</id>
  <name>Verta</name>
  <summary>The gaming desktop that updates itself</summary>
  <description>
    <p>Verta is a gaming desktop built on Fedora Atomic: Steam and gaming tools ready to go, a clean Windows-like desktop, and whole-system updates that can always be undone.</p>
  </description>
  <url type="homepage">https://github.com/HumandubleOfficial/verta</url>
  <metadata_license>MIT</metadata_license>
  <developer_name>Verta</developer_name>
  <releases>
    <release version="${VERTA_VERSION:-1}" type="stable"/>
  </releases>
</component>
EOF
fi

### Firefox ##################################################################
FF_PREFS=/usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js
if [ -f "$FF_PREFS" ]; then
    sed -i -E \
        -e 's|^pref\("browser\.startup\.homepage",.*|pref("browser.startup.homepage", "about:home");|' \
        -e 's|^pref\("browser\.newtabpage\.pinned",.*|pref("browser.newtabpage.pinned", "[]");|' \
        "$FF_PREFS"
    if grep -qi 'fedoraproject' "$FF_PREFS"; then echo 'Fedora left in Firefox prefs' >&2; exit 1; fi
fi
FF_DIST=/usr/lib64/firefox/distribution/distribution.ini
if [ -f "$FF_DIST" ]; then sed -i 's/Fedora/Verta/g; s/=fedora$/=verta/' "$FF_DIST"; fi

### Flatpak: Flathub only (no "Fedora Flatpaks" source in the App Store) ######
systemctl disable flatpak-add-fedora-repos.service || true
rm -f /etc/flatpak/remotes.d/fedora*.flatpakrepo /usr/share/flatpak/remotes.d/fedora*.flatpakrepo

### Firewall: a "Verta" zone (same rules as Fedora Workstation's) ############
test -f /usr/lib/firewalld/zones/Verta.xml
sed -i -E 's/^DefaultZone=.*/DefaultZone=Verta/' /etc/firewalld/firewalld.conf
grep -q '^DefaultZone=Verta$' /etc/firewalld/firewalld.conf
rm -f /usr/lib/firewalld/zones/Fedora*.xml

### Other places that said Fedora ###########################################
# "Fedora Packages" web search keyword (Settings -> Web Search Keywords).
rm -f /usr/share/kf6/searchproviders/fedora.desktop
# Fedora's one-time Plasma script that swapped launcher icons for its logo.
rm -f /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/00-start-here*.js
# Online check: Verta's (KDE's server) instead of Fedora's.
test -f /usr/lib/NetworkManager/conf.d/20-verta-connectivity.conf
rm -f /usr/lib/NetworkManager/conf.d/20-connectivity-fedora.conf

### App names: what they are, like on any other computer #####################
# "Files", not "Dolphin"; "Terminal", not "Konsole". Only the name shown in the
# Start menu, the taskbar and window titles changes (in every language); the
# old name stays a search keyword, so typing "dolphin" still finds Files.
python3 - <<'PY'
import re
from pathlib import Path

NAMES = {
    "org.kde.dolphin.desktop": "Files",
    "org.kde.konsole.desktop": "Terminal",
    "org.kde.discover.desktop": "App Store",
    "org.kde.spectacle.desktop": "Screenshot",
    "org.kde.kate.desktop": "Text Editor",
    "org.kde.kwrite.desktop": "Simple Text Editor",
    "org.kde.ark.desktop": "Archive Utility",
    "org.kde.filelight.desktop": "Disk Usage",
    "org.kde.partitionmanager.desktop": "Disk Utility",
    "org.kde.plasma-systemmonitor.desktop": "Activity Monitor",
    "org.kde.plasma.emojier.desktop": "Emoji & Symbols",
    "org.kde.gwenview.desktop": "Image Viewer",
    "org.kde.okular.desktop": "Document Viewer",
    "org.kde.kcalc.desktop": "Calculator",
    "org.kde.kwalletmanager.desktop": "Passwords",
    "org.kde.kwalletmanager5.desktop": "Passwords",
    "org.kde.haruna.desktop": "Videos",
    "org.kde.elisa.desktop": "Music",
    "org.kde.kfind.desktop": "Find Files",
    "org.kde.khelpcenter.desktop": "Help",
    "org.kde.kcharselect.desktop": "Characters",
    "org.kde.skanpage.desktop": "Scanner",
    "org.kde.kinfocenter.desktop": "System Information",
    "org.kde.ksystemlog.desktop": "Console",
    "Waydroid.desktop": "Android Apps",
}

for file, new in NAMES.items():
    path = Path("/usr/share/applications") / file
    if not path.exists():
        print(f"app names: {file} not installed, skipping")
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    group, old, out, has_keywords = None, None, [], False
    for line in lines:
        if group == "[Desktop Entry]" and line.startswith("Name="):
            old = line[len("Name="):]
        if line.startswith("["):
            group = line.strip()
    group = None
    for line in lines:
        if line.startswith("["):
            if group == "[Desktop Entry]" and not has_keywords:
                out.append(f"Keywords={old};")
            group = line.strip()
        elif group == "[Desktop Entry]":
            m = re.match(r"(Name|X-GNOME-FullName)(\[[^]]*\])?=", line)
            if m:
                if m.group(1) == "Name" and not m.group(2):
                    out.append(f"Name={new}")
                continue                    # localised names would undo it
            m = re.match(r"Keywords(\[[^]]*\])?=(.*)", line)
            if m:
                line = f"Keywords{m.group(1) or ''}={old};{m.group(2)}"
                has_keywords = has_keywords or not m.group(1)
        out.append(line)
    if group == "[Desktop Entry]" and not has_keywords:
        out.append(f"Keywords={old};")
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"app names: {old} -> {new}")
PY
grep -q '^Name=Files$' /usr/share/applications/org.kde.dolphin.desktop
grep -q '^Name=Terminal$' /usr/share/applications/org.kde.konsole.desktop

# Nothing a person can see may say Fedora: names and comments of every app,
# menu entry, Plasma script, search keyword and firewall zone.
if grep -liE '^(Name|GenericName|Comment|Keywords)(\[[^]]*\])?=.*fedora' /usr/share/applications/*.desktop /usr/share/kf6/searchproviders/*.desktop 2>/dev/null    || grep -rliI fedora /usr/share/plasma /usr/lib/firewalld/zones /etc/xdg 2>/dev/null; then
    echo 'Visible Fedora references left (above)' >&2
    exit 1
fi

### Firmware boot menu: "Verta" instead of "Fedora" ##########################
systemctl enable verta-boot-entry.service

# Fedora 45 keeps its .repo files in /usr/share/dnf5/repos.d, but
# bootc-image-builder only reads /etc/yum.repos.d from the image when building
# the installer ISO (it fails with "missing packages: glibc, systemd, ...").
# A same-named file in /etc overrides the /usr/share one, so this is safe for dnf.
for repo in /usr/share/dnf5/repos.d/*.repo; do
    [ -e "$repo" ] || continue
    [ -e "/etc/yum.repos.d/$(basename "$repo")" ] || cp "$repo" /etc/yum.repos.d/
done
