#!/usr/bin/bash
# Make the Verta look the default everywhere: global theme, window effects and
# animations, fonts, terminal, lock/login screen, login splash and boot splash.
set -xeuo pipefail

# System-wide KDE defaults live in kde-settings' XDG directory (it is on
# XDG_CONFIG_DIRS); users' own settings still override anything set here.
KDE_XDG=/usr/share/kde-settings/kde-profile/default/xdg
kset() { kwriteconfig6 --file "$KDE_XDG/$1" --group "$2" --key "$3" "$4"; }

### Global themes: Verta Dark (default) and Verta Light ######################
sed -i 's/^LookAndFeelPackage=.*/LookAndFeelPackage=org.verta.desktop/' "$KDE_XDG/kdeglobals"
grep -q '^LookAndFeelPackage=org.verta.desktop' "$KDE_XDG/kdeglobals"
# Plasma's light/dark switch flips between these two (stock: Breeze Light/Dark,
# which is what dropped Verta's colours when switching).
kset kdeglobals KDE DefaultDarkLookAndFeel  org.verta.desktop
kset kdeglobals KDE DefaultLightLookAndFeel org.verta.light
kset kdeglobals Icons Theme Verta
# Verta Light shares the taskbar layout and login splash with Verta Dark.
LAF=/usr/share/plasma/look-and-feel
cp -r "$LAF/org.verta.desktop/contents/layouts" "$LAF/org.verta.light/contents/"
cp -r "$LAF/org.verta.desktop/contents/splash"  "$LAF/org.verta.light/contents/"
# Verta Light uses the same app/folder icons (they work on both backgrounds);
# only what it inherits differs (light Papirus/Breeze for everything else).
ln -sfn ../Verta/scalable /usr/share/icons/Verta-Light/scalable
gtk-update-icon-cache -f /usr/share/icons/Verta
gtk-update-icon-cache -f /usr/share/icons/Verta-Light

### Windows feel: familiar shortcuts and task switcher ########################
SC() { kwriteconfig6 --file "$KDE_XDG/kglobalshortcutsrc" --group services --group "$1" --key "$2" "$3"; }
SC org.kde.dolphin.desktop               _launch                     'Meta+E'
SC org.kde.spectacle.desktop             RectangularRegionScreenShot 'Meta+Shift+S'
SC org.kde.plasma-systemmonitor.desktop  _launch                     'Ctrl+Shift+Esc'
SC org.verta.Settings.desktop            _launch                     'Meta+I'
kset kwinrc TabBox LayoutName thumbnail_grid      # Alt+Tab shows window thumbnails

### Fonts: Inter for the UI #################################################
INTER='Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kset kdeglobals General font                 "$INTER"
kset kdeglobals General menuFont             "$INTER"
kset kdeglobals General toolBarFont          'Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kset kdeglobals General smallestReadableFont 'Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1'
kset kdeglobals WM      activeFont           'Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1'

### Animations: smooth but quick ############################################
# 0.75 = every animation 25% shorter than stock Plasma.
kset kdeglobals KDE AnimationDurationFactor 0.75
kset kwinrc Plugins glideEnabled true          # windows glide in/out on open/close
kset kwinrc Plugins scaleEnabled false         # (glide replaces the default scale)
kset kwinrc Plugins squashEnabled true         # minimise squashes into the dock
kset kwinrc Plugins magiclampEnabled false
kset kwinrc Plugins wobblywindowsEnabled false
kset kwinrc Plugins dimscreenEnabled true      # dim behind password prompts

### Glass: frosted blur behind panels, menus, popups and the terminal ########
kset kwinrc Plugins blurEnabled true
kset kwinrc Plugins contrastEnabled true
kset kwinrc Effect-blur BlurStrength 12
kset kwinrc Effect-blur NoiseStrength 4

### Windows: rounded corners, thin blue outline + soft glow on the active one,
### borderless frames. Maximised and fullscreen windows (games) are left alone.
kset kwinrc Plugins kwin4_effect_shapecornersEnabled true
RC() { kset kwinrc Round-Corners "$1" "$2"; }
RC Size 12
RC InactiveCornerRadius 12
RC DisableRoundMaximize true
RC DisableOutlineMaximize true
RC DisableRoundFullScreen true
RC DisableOutlineFullScreen true
RC OutlineThickness 1
RC ActiveOutlineUseCustom true
RC OutlineColor 59,130,246
RC ActiveOutlineAlpha 150
RC InactiveOutlineThickness 1
RC InactiveOutlineUseCustom true
RC InactiveOutlineColor 30,41,59
RC InactiveOutlineAlpha 150
RC UseNativeDecorationShadows false
RC ActiveShadowUseCustom true
RC ShadowColor 37,99,235
RC ActiveShadowAlpha 70
RC ShadowSize 28
RC InactiveShadowUseCustom true
RC InactiveShadowColor 0,0,0
RC InactiveShadowAlpha 140
RC InactiveShadowSize 20
RC AnimationDuration 150
kset kwinrc org.kde.kdecoration2 BorderSize None
kset kwinrc org.kde.kdecoration2 BorderSizeAuto false
kset breezerc Common OutlineIntensity OutlineOff
kset breezerc Windeco TitleAlignment AlignCenterFullWidth

### Games: let fullscreen games tear for the lowest input latency ###########
kset kwinrc Compositing AllowTearing true

### Terminal: translucent, blurred Verta profile ############################
kset konsolerc "Desktop Entry" DefaultProfile Verta.profile

### Speed: no file indexing (Baloo) on a gaming PC ##########################
kset baloofilerc "Basic Settings" Indexing-Enabled false

### Lock screen / login screen wallpaper ####################################
sed -i 's|/usr/share/wallpapers/Fedora/|/usr/share/wallpapers/Verta/|g' "$KDE_XDG/kscreenlockerrc"
# Anything else still asking for the Fedora/Default wallpaper gets Verta's.
ln -sfn Verta /usr/share/wallpapers/Default

### Boot splash ##############################################################
# watermark.png (V) and throbber-*.png (spinning ring) come from system_files;
# borrow only the password box and keyboard/lock icons from the stock spinner.
SPINNER=/usr/share/plymouth/themes/spinner
THEME=/usr/share/plymouth/themes/verta
for f in bullet capslock entry keyboard keymap-render lock; do
    cp "$SPINNER/$f.png" "$THEME/"
done
ls "$THEME"/throbber-0036.png "$THEME"/watermark.png
plymouth-set-default-theme verta
