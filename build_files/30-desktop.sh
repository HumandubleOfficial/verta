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

### Plasma style: Verta glass taskbar, popups and highlights ##################
kset plasmarc Theme name verta
test -f /usr/share/plasma/desktoptheme/verta/widgets/tasks.svg

### Hover animations: smooth fades on buttons, menus and title-bar buttons ####
kset breezerc Style AnimationsEnabled true
kset breezerc Style AnimationsDuration 160
kset breezerc Windeco AnimationsEnabled true
kset breezerc Windeco AnimationsDuration 140
# Hovering an app in the taskbar spotlights its windows (others fade back).
kset kwinrc Plugins highlightwindowEnabled true

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
# Verta Motion (our own effect, /usr/share/kwin/effects/verta_motion) animates
# windows, menus and tooltips; KDE's stock open/close effects are switched off.
test -f /usr/share/kwin/effects/verta_motion/contents/code/main.js
kset kwinrc Plugins verta_motionEnabled true
kset kwinrc Plugins glideEnabled false
kset kwinrc Plugins scaleEnabled false
kset kwinrc Plugins fadeEnabled false
kset kwinrc Plugins fadingpopupsEnabled false
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

### Lock screen: Verta clock, glass password field, round unlock button ######
python3 "$CTX/verta-lockscreen.py"

### Boot splash ##############################################################
# Verta's own animated script theme (verta.script + images from system_files);
# only the small padlock icon is borrowed from the stock theme.
THEME=/usr/share/plymouth/themes/verta
cp /usr/share/plymouth/themes/spinner/lock.png "$THEME/"
ls "$THEME"/verta.script "$THEME"/logo-v.png "$THEME"/ring-71.png "$THEME"/glow.png >/dev/null
test -f /usr/lib64/plymouth/script.so
plymouth-set-default-theme verta
