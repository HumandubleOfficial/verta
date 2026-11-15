# Verta

A gaming desktop Linux OS. Verta is a custom **Fedora Atomic** image (KDE Plasma) built with
[bootc](https://containers.github.io/bootc/) on top of Universal Blue's base images, which
already include media codecs and RPM Fusion.

## What Verta adds

**Look**

| | |
|---|---|
| **Logo** | "Orbit": a V inside an open orbit ring with a moon (`art/logo.svg`; `logo-ring.svg` + `logo-v.svg` are the animated layers) |
| **Verta theme** | Global theme `org.verta.desktop`: "glass" look on near-black navy with dark-blue accents (`Verta Dark` colour scheme), Papirus-Dark icons, Inter UI font |
| **Glass** | Frosted blur behind panels, menus, popups and the terminal; rounded window corners with a thin blue outline and soft blue glow on the active window (KDE-Rounded-Corners); borderless frames |
| **Animations** | Windows glide in/out, minimise squashes into the dock, everything 25% quicker than stock Plasma; animated login splash (V pops in, ring orbits) and boot splash (ring spins around the V) |
| **Layout** | Slim top bar (Verta launcher, clock, tray) + floating centred dock with Steam, Heroic, Lutris, Firefox, Dolphin, Konsole, Discover and Settings pinned |
| **Wallpaper** | Space scene with the Orbit mark, on desktop, lock screen and login screen |
| **Branding** | "Verta" and the Verta logo in About This System and the boot menu; Verta-branded installer |

**Games**

| | |
|---|---|
| **Steam** | RPM package plus `steam-devices` udev rules for controllers and VR |
| **gamescope** | `gamescope -- %command%` in a game's launch options for upscaling/fullscreen tricks |
| **MangoHud + GOverlay** | FPS/frametime overlay (64- and 32-bit); `mangohud %command%` |
| **GameMode** | `gamemoderun %command%` |
| **vkBasalt** | Sharpening / SMAA for Vulkan games |
| **CoreCtrl** | GPU clocks, fans and power profiles (mainly AMD) |
| **Controllers** | `xone` (Xbox wireless dongle) and `xpadneo` (Xbox controllers over Bluetooth) drivers |
| **First-boot apps** | Heroic, Lutris, ProtonUp-Qt and Flatseal from Flathub, installed in the background once the PC is online |

**Performance**

| | |
|---|---|
| **Gaming kernel** | Universal Blue's `ogc` kernel (the one Bazzite uses) instead of Fedora's |
| **CPU scheduler** | sched-ext `scx_lavd` via `scx_loader`, built to keep frame times steady |
| **Priorities** | `ananicy-cpp` with CachyOS' rules (games/audio up, background work down) |
| **Memory / I/O** | Tuned for zram, early writeback, per-disk I/O schedulers (NVMe none, SSD mq-deadline, HDD bfq) |
| **Audio** | PipeWire default latency halved (512 samples) |
| **Boot** | Quiet graphical boot; no waiting for the network; ModemManager and dnf metadata refresh off |
| **Desktop** | No file indexing (Baloo), no Discover/KDE Connect background daemons at login, fullscreen games may tear for lowest latency |
| **Less bloat** | Removes apps a gaming PC doesn't need (`build_files/remove.txt`) |

Because it's an atomic OS, the system part (`/usr`) is read-only and every update is a whole
new image; if an update breaks something, pick the previous entry in the boot menu (or run
`sudo bootc rollback`).

## Flavors

| Flavor | For |
|---|---|
| `verta` | AMD and Intel GPUs |
| `verta-nvidia` | NVIDIA GTX 16xx / RTX 20xx and newer (open kernel modules; GTX 10xx and older are not supported) |

Both are built from `ghcr.io/ublue-os/kinoite-main:45`. The kernel and its drivers come from
`ghcr.io/ublue-os/akmods:ogc-45` and, for NVIDIA, `ghcr.io/ublue-os/akmods-nvidia-open:ogc-45`,
so the NVIDIA driver always matches the kernel exactly.

## Secure Boot

Verta's kernel and drivers are signed with Universal Blue's key, not Fedora's. The installer
queues that key for enrolment, so **on the first reboot after installing** a blue
*Perform MOK management* screen appears:

1. **Enroll MOK** → **Continue** → **Yes**
2. Password: `universalblue`
3. **Reboot**

Skipped it? Run `sudo mokutil --import /etc/pki/akmods/certs/akmods-ublue.der` (same password)
from a booted system, or turn Secure Boot off in the firmware. PCs with Secure Boot off never
see this screen.

## Layout

```
Containerfile              image definition
art/                       logo + wallpaper sources (SVG)
build_files/build.sh       runs inside the build; runs the numbered steps in order:
  00-kernel.sh               swap in the gaming kernel + controller drivers
  10-packages.sh             add packages.txt, remove remove.txt
  20-nvidia.sh               NVIDIA driver (verta-nvidia only)
  30-desktop.sh              make the Verta theme / splash the default
  40-tuning.sh               scheduler, priorities, boot trims
  50-branding.sh             os-release
  90-initramfs.sh            initramfs for the new kernel
system_files/              files copied onto / (theme, colour scheme, tuning configs, services)
disk_config/iso.toml       installer settings (+ Secure Boot key enrolment)
installer/                 installer (Anaconda) stylesheet + rendered images
scripts/                   build helpers (run inside WSL) and the Hyper-V test VM script
  brand-iso.sh               rebrands the installer ISO: Verta installer look, "Install Verta"
                             boot menu, volume label "Verta", Secure Boot key on the ISO
output/                    finished ISOs (git-ignored)
```

- Add a package: a line in `build_files/packages.txt`. Remove one: a line in `build_files/remove.txt`.
- Add a Flatpak: the `APPS` list in `system_files/usr/libexec/verta-flatpak-setup`.
- Change the dock: `system_files/usr/share/plasma/look-and-feel/org.verta.desktop/contents/layouts/org.kde.plasma.desktop-layout.js`.
- Change colours: `system_files/usr/share/color-schemes/VertaDark.colors`.
- Change the logo or wallpaper: edit `art/*.svg`, then run `scripts/render-art.sh`.

## Building (Windows + WSL2 Ubuntu)

Everything runs as root in WSL, because bootc-image-builder needs rootful podman. From PowerShell
in this folder:

```powershell
# one-time: install podman + skopeo in WSL
wsl -u root -- bash scripts/setup-wsl.sh

# after editing art/*.svg
wsl -u root -- bash scripts/render-art.sh

# build the OS image
wsl -u root -- bash scripts/build-image.sh verta          # or verta-nvidia

# turn it into an installer ISO → output\verta-YYYYMMDD-HHMM.iso
wsl -u root -- bash scripts/build-iso.sh verta            # or verta-nvidia
```

Options (set before the command inside WSL, e.g. `wsl -u root -- env KERNEL_FLAVOR=main bash scripts/build-image.sh verta`):

- `KERNEL_FLAVOR=main` — use Fedora's stock kernel instead of the gaming kernel.
- `FEDORA_VERSION=46` — build on a newer Fedora once the base images publish it
  (check with `skopeo list-tags docker://ghcr.io/ublue-os/kinoite-main`).

## Testing in a Hyper-V VM (AMD/Intel flavor)

1. From an **administrator** PowerShell in this folder, create and start the VM (Gen 2, 4 CPUs,
   8 GB RAM, 64 GB disk, Secure Boot with the Microsoft UEFI CA, newest ISO attached):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\new-test-vm.ps1            # add -Replace to recreate
   ```
2. In the VM window, install (pick the disk, create your user). When it finishes, eject the ISO
   (**Media → DVD Drive → Eject**) before rebooting, or the VM boots the installer again.
3. Enrol the Secure Boot key on the blue MOK screen (see above).
4. Check:
   - the Verta boot splash, then the Verta login screen and desktop (top bar + dock)
   - *About This System* says Verta and shows the `ogc` kernel
   - `systemctl status scx_loader ananicy-cpp` are running; `scxctl get` reports `lavd`
   - Steam starts and signs in (games will be slow: a VM has no real GPU)
   - a few minutes after first boot, Heroic and Lutris appear in the dock
     (`systemctl status verta-flatpak-setup` shows progress)

A VM can't test the NVIDIA flavor; use real hardware for that.

Already have a user from an older Verta build? New users get the Verta layout automatically;
for an existing user run `plasma-apply-lookandfeel -a org.verta.desktop --resetLayout`
(this replaces that user's panels).

## Installing on a real PC

1. Write the ISO to a USB stick (8 GB+) with **Fedora Media Writer** ("Select .iso file") or
   **Rufus** in *DD image* mode. This wipes the stick.
2. Boot the PC from USB (usually F12/F8/Esc at power-on) and install.
3. Enrol the Secure Boot key on the first reboot (see above).
4. NVIDIA flavor: `nvidia-smi` should list your GPU.

## Updates

An ISO built from a local image points updates at `localhost/verta`, so `bootc upgrade` on an
installed machine has nothing to download yet. To ship updates, push the image to a registry
(for example GitHub Container Registry) and switch installed machines to it once:

```bash
sudo bootc switch ghcr.io/<you>/verta:latest
```

After that, `sudo bootc upgrade` (or the automatic update timer) pulls each new build.
