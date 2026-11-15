// Verta default desktop: a slim frosted-glass top bar (launcher, clock, tray)
// and a floating, centred glass dock with pinned games apps. Used for every
// new user. Panels are translucent with blur by default (Breeze Plasma style +
// KWin blur, tuned in build_files/30-desktop.sh).

// --- Top bar ---------------------------------------------------------------
var bar = new Panel;
bar.location = "top";
bar.height = 2 * Math.ceil(gridUnit * 1.6 / 2);
bar.floating = false;
bar.hiding = "none";

var launcher = bar.addWidget("org.kde.plasma.kickoff");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("icon", "verta-logo");

bar.addWidget("org.kde.plasma.panelspacer");

var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");

bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");

// --- Dock ------------------------------------------------------------------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.8);
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";
dock.floating = true;

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:steam.desktop",
    "applications:com.heroicgameslauncher.hgl.desktop",
    "applications:net.lutris.Lutris.desktop",
    "applications:org.mozilla.firefox.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.discover.desktop",
    "applications:systemsettings.desktop"
].join(","));
tasks.writeConfig("iconSpacing", "2");
tasks.writeConfig("indicateAudioStreams", "true");

// --- Desktop wallpaper -----------------------------------------------------
desktopsForActivity(currentActivity()).forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Verta/");
});
