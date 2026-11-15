#!/usr/bin/python3
"""Verta Settings: the everyday settings, in one clean window.

Python (PySide6) does the system work; the interface is QML in ./qml, drawn
with Kirigami so it follows the current Verta Light / Verta Dark colours.
Anything not covered here opens the matching page of KDE System Settings.

    verta-settings [--page NAME] [--screenshot OUT.png]
"""
import argparse
import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QProcess, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

HERE = Path(__file__).resolve().parent
UPDATE_REGISTRY = "ghcr.io/humandubleofficial"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))


def sh(argv, timeout=8):
    """Run a quick command; return (exit code, stdout). Never raises."""
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return 127, ""


def kread(file, group, key, default=""):
    code, out = sh(["kreadconfig6", "--file", file, "--group", group, "--key", key, "--default", default])
    return out if code == 0 else default


def kwrite(file, group, key, value):
    # --notify tells running Plasma apps to re-read the setting straight away.
    args = ["kwriteconfig6", "--notify", "--file", file, "--group", group, "--key", key]
    args += ["--type", "bool", "true" if value else "false"] if isinstance(value, bool) else [str(value)]
    sh(args)


def kwin_reconfigure():
    sh(["dbus-send", "--session", "--type=method_call", "--dest=org.kde.KWin", "/KWin",
        "org.kde.KWin.reconfigure"])


def os_release():
    data = {}
    for line in Path("/usr/lib/os-release").read_text(errors="replace").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            data[k] = v.strip().strip('"')
    return data


class Backend(QObject):
    # tag, success, output
    finished = Signal(str, bool, str)

    def __init__(self):
        super().__init__()
        self._procs = {}
        self._flatpaks = None

    # --- running things -----------------------------------------------------

    @Slot(str, list)
    def run(self, tag, argv):
        """Run a slow command in the background; emits finished(tag, ...)."""
        if tag in self._procs:
            return
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.MergedChannels)
        self._procs[tag] = p

        def done(code, _status):
            out = bytes(p.readAll()).decode(errors="replace").strip()
            self._procs.pop(tag, None)
            p.deleteLater()
            self.finished.emit(tag, code == 0, out)
        p.finished.connect(done)
        p.errorOccurred.connect(lambda _e: p.state() == QProcess.NotRunning and done(127, None))
        p.start(argv[0], argv[1:])

    @Slot(str, result=bool)
    def busy(self, tag):
        return tag in self._procs

    @Slot(list)
    def launch(self, argv):
        QProcess.startDetached(argv[0], argv[1:])

    @Slot(str)
    def openKcm(self, name):
        QProcess.startDetached("systemsettings", [name] if name else [])

    # --- appearance ---------------------------------------------------------

    @Slot(result=str)
    def appearanceMode(self):
        if kread("kdeglobals", "KDE", "AutomaticLookAndFeel", "false") == "true":
            return "auto"
        laf = kread("kdeglobals", "KDE", "LookAndFeelPackage", "org.verta.desktop")
        return "light" if laf == "org.verta.light" else "dark"

    @Slot(str)
    def setAppearanceMode(self, mode):
        kwrite("kdeglobals", "KDE", "AutomaticLookAndFeel", mode == "auto")
        if mode in ("light", "dark"):
            pkg = "org.verta.light" if mode == "light" else "org.verta.desktop"
            self.run("laf", ["plasma-apply-lookandfeel", "--apply", pkg])
        # "auto": Plasma's look-and-feel auto-switcher (kded) then flips between
        # the DefaultLight/DefaultDarkLookAndFeel packages (Verta Light/Dark).

    @Slot(result=str)
    def accent(self):
        rgb = kread("kdeglobals", "General", "AccentColor", "")
        m = re.match(r"\s*(\d+),\s*(\d+),\s*(\d+)", rgb)
        return "#%02x%02x%02x" % tuple(int(x) for x in m.groups()) if m else ""

    @Slot(str)
    def setAccent(self, color):
        scheme = "VertaLight" if self.appearanceMode() == "light" else "VertaDark"
        self.run("accent", ["plasma-apply-colorscheme", "--accent-color", color, scheme])

    @Slot(result=list)
    def wallpapers(self):
        found = []
        roots = [Path("/usr/share/wallpapers"), Path.home() / ".local/share/wallpapers"]
        for root in roots:
            if not root.is_dir():
                continue
            for d in sorted(root.iterdir()):
                # Skip aliases (Fedora -> Default -> Verta) so nothing shows twice.
                if d.is_symlink() or not (d / "contents").is_dir():
                    continue
                thumb = d / "contents/screenshot.png"
                if not thumb.exists():
                    imgs = sorted((d / "contents/images").glob("*"), key=lambda p: p.stat().st_size)
                    if not imgs:
                        continue
                    thumb = imgs[0]
                name = d.name
                try:
                    name = json.loads((d / "metadata.json").read_text())["KPlugin"]["Name"]
                except (OSError, ValueError, KeyError):
                    pass
                found.append({"name": name, "path": str(d), "thumb": QUrl.fromLocalFile(str(thumb)).toString()})
        found.sort(key=lambda w: (w["name"] != "Verta", w["name"].lower()))
        return found[:12]

    @Slot(result=str)
    def currentWallpaper(self):
        f = CONFIG / "plasma-org.kde.plasma.desktop-appletsrc"
        try:
            m = re.search(r"^Image=(?:file://)?(.+)$", f.read_text(errors="replace"), re.M)
        except OSError:
            m = None
        return m.group(1).rstrip("/") if m else "/usr/share/wallpapers/Verta"

    @Slot(str)
    def setWallpaper(self, path):
        self.run("wallpaper", ["plasma-apply-wallpaperimage", path])

    @Slot(result=float)
    def animationSpeed(self):
        try:
            return float(kread("kdeglobals", "KDE", "AnimationDurationFactor", "0.75"))
        except ValueError:
            return 0.75

    @Slot(float)
    def setAnimationSpeed(self, factor):
        kwrite("kdeglobals", "KDE", "AnimationDurationFactor", factor)
        kwin_reconfigure()

    # --- sound --------------------------------------------------------------

    @Slot(result=int)
    def volume(self):
        _, out = sh(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
        m = re.search(r"Volume:\s*([\d.]+)", out)
        return round(float(m.group(1)) * 100) if m else 50

    @Slot(int)
    def setVolume(self, percent):
        sh(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", f"{percent}%"])

    @Slot(result=bool)
    def muted(self):
        return "[MUTED]" in sh(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])[1]

    @Slot(bool)
    def setMuted(self, muted):
        sh(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if muted else "0"])

    @Slot(result=str)
    def outputDevice(self):
        _, out = sh(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"])
        m = re.search(r'node\.description = "([^"]+)"', out)
        return m.group(1) if m else ""

    # --- gaming & performance -----------------------------------------------

    @Slot(result=str)
    def cpuMode(self):
        _, out = sh(["scxctl", "get"])
        m = re.search(r"\bin (\w+) mode", out, re.I)
        return m.group(1).lower() if m else ("off" if "not running" in out.lower() else "")

    @Slot(str)
    def setCpuMode(self, mode):
        # Admins can talk to scx_loader directly (Verta's D-Bus policy); fall
        # back to an admin password prompt for everyone else.
        script = (f"scxctl switch --mode {mode} || scxctl start --sched lavd --mode {mode}")
        code, _ = sh(["sh", "-c", script], timeout=15)
        if code == 0:
            self.finished.emit("cpu", True, "")
        else:
            self.run("cpu", ["pkexec", "sh", "-c", script])

    @Slot(result=str)
    def powerProfile(self):
        code, out = sh(["busctl", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles",
                        "net.hadess.PowerProfiles", "ActiveProfile"])
        m = re.search(r'"([^"]+)"', out)
        return m.group(1) if code == 0 and m else ""

    @Slot(str)
    def setPowerProfile(self, profile):
        self.run("power", ["busctl", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles",
                           "net.hadess.PowerProfiles", "ActiveProfile", "s", profile])

    @Slot(result=bool)
    def mangohud(self):
        f = CONFIG / "environment.d/90-verta-mangohud.conf"
        return f.exists() and "MANGOHUD=1" in f.read_text(errors="replace")

    @Slot(bool)
    def setMangohud(self, on):
        f = CONFIG / "environment.d/90-verta-mangohud.conf"
        if on:
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_text("# Set by Verta Settings: performance overlay in every game\nMANGOHUD=1\n")
        else:
            f.unlink(missing_ok=True)

    @Slot(result=bool)
    def tearing(self):
        return kread("kwinrc", "Compositing", "AllowTearing", "true") == "true"

    @Slot(bool)
    def setTearing(self, on):
        kwrite("kwinrc", "Compositing", "AllowTearing", on)
        kwin_reconfigure()

    # --- apps ---------------------------------------------------------------

    @Slot(str, result=bool)
    def hasFlatpak(self, app_id):
        if self._flatpaks is None:
            _, out = sh(["flatpak", "list", "--app", "--columns=application"], timeout=15)
            self._flatpaks = set(out.split())
        return app_id in self._flatpaks

    @Slot()
    def refreshApps(self):
        self._flatpaks = None

    @Slot(result=bool)
    def waydroidReady(self):
        return Path("/var/lib/waydroid/waydroid.cfg").exists()

    @Slot()
    def setupWaydroid(self):
        self.run("waydroid", ["pkexec", "sh", "-c",
                              "waydroid init && systemctl enable --now waydroid-container.service"])

    # --- updates ------------------------------------------------------------

    @Slot(result="QVariantMap")
    def updateInfo(self):
        code, out = sh(["rpm-ostree", "status", "--json"], timeout=20)
        info = {"ok": False, "version": "", "staged": False, "stagedVersion": "",
                "rollback": False, "source": "", "connected": False, "image": self._image_name()}
        if code != 0:
            return info
        try:
            deps = json.loads(out).get("deployments", [])
        except ValueError:
            return info
        booted = next((d for d in deps if d.get("booted")), {})
        staged = next((d for d in deps if d.get("staged")), None)
        ref = booted.get("container-image-reference", "")
        info.update(
            ok=True,
            version=booted.get("version", ""),
            staged=staged is not None,
            stagedVersion=(staged or {}).get("version", ""),
            rollback=any(not d.get("booted") and not d.get("staged") for d in deps),
            source=ref.split(":", 1)[-1].removeprefix("docker://"),
            connected=UPDATE_REGISTRY in ref,
        )
        return info

    def _image_name(self):
        return os_release().get("IMAGE_ID") or "verta"

    @Slot()
    def checkUpdates(self):
        # Exit 0: an update is available; 77: already up to date.
        self.run("check", ["sh", "-c", "rpm-ostree upgrade --check; echo \"exit=$?\""])

    @Slot()
    def installUpdates(self):
        self.run("install", ["rpm-ostree", "upgrade"])

    @Slot()
    def rollback(self):
        self.run("rollback", ["rpm-ostree", "rollback"])

    @Slot()
    def connectUpdates(self):
        image = f"{UPDATE_REGISTRY}/{self._image_name()}:latest"
        self.run("connect", ["pkexec", "bootc", "switch", image])

    @Slot()
    def restart(self):
        QProcess.startDetached("systemctl", ["reboot"])

    # --- about --------------------------------------------------------------

    @Slot(result="QVariantMap")
    def about(self):
        rel = os_release()
        cpu = ""
        try:
            m = re.search(r"^model name\s*:\s*(.+)$", Path("/proc/cpuinfo").read_text(), re.M)
            cpu = re.sub(r"\s+", " ", m.group(1)).replace("(R)", "").replace("(TM)", "") if m else ""
        except OSError:
            pass
        threads = os.cpu_count() or 0
        mem = ""
        try:
            kb = int(re.search(r"MemTotal:\s+(\d+)", Path("/proc/meminfo").read_text()).group(1))
            mem = f"{kb / 1024 / 1024:.0f} GB"
        except (OSError, AttributeError):
            pass
        gpus = []
        _, out = sh(["lspci"])
        for line in out.splitlines():
            if re.search(r"VGA compatible|3D controller|Display controller", line):
                name = line.split(": ", 1)[-1]
                name = re.sub(r"\s*\(rev \w+\)$", "", name)
                br = re.search(r"\[([^\]]*(?:GeForce|Radeon|RTX|GTX|Arc|Iris|UHD)[^\]]*)\]", name)
                gpus.append(br.group(1) if br else name)
        _, sb = sh(["mokutil", "--sb-state"])
        disk = ""
        try:
            st = os.statvfs("/var")
            disk = f"{st.f_bavail * st.f_frsize / 1e9:.0f} GB free of {st.f_blocks * st.f_frsize / 1e9:.0f} GB"
        except OSError:
            pass
        return {
            "name": rel.get("NAME", "Verta"),
            "version": rel.get("IMAGE_VERSION") or rel.get("VERSION_ID", ""),
            "edition": "NVIDIA" if "nvidia" in rel.get("IMAGE_ID", "") else "AMD / Intel",
            "base": f"Fedora {rel.get('VERSION_ID', '')}".strip(),
            "hostname": socket.gethostname(),
            "cpu": f"{cpu} ({threads} threads)" if cpu else "",
            "gpu": " + ".join(gpus),
            "memory": mem,
            "disk": disk,
            "kernel": os.uname().release,
            "secureBoot": "On" if "enabled" in sb.lower() else ("Off" if sb else "Unknown"),
        }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--page", default="")
    ap.add_argument("--screenshot", default="")
    args = ap.parse_args()

    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    app = QApplication(sys.argv)
    app.setApplicationName("verta-settings")
    app.setApplicationDisplayName("Settings")
    app.setOrganizationName("Verta")
    app.setDesktopFileName("org.verta.Settings")
    app.setWindowIcon(QIcon.fromTheme("org.verta.Settings"))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.setInitialProperties({"backend": backend, "startPage": args.page,
                                 "screenshotPath": os.path.abspath(args.screenshot) if args.screenshot else ""})
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        return 1

    if args.screenshot:
        # Main.qml saves the picture and quits; this is only a safety net.
        QTimer.singleShot(15000, app.quit)

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
