// Verta default desktop: one floating glass taskbar at the bottom, Windows 11
// style. The Verta start button and pinned/open apps sit in the centre; the
// tray, clock and "show desktop" corner sit on the right. Used for every new
// user (and copied into the Verta Light theme at build time).

var bar = new Panel;
bar.location = "bottom";
bar.height = 2 * Math.ceil(gridUnit * 2.7 / 2);
bar.floating = true;
bar.hiding = "none";
bar.lengthMode = "fill";

// Two expanding spacers either side of the start button + apps centre them.
bar.addWidget("org.kde.plasma.panelspacer");

var start = bar.addWidget("org.kde.plasma.kickoff");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "verta-logo");
start.writeConfig("favoritesDisplay", "0");      // pinned apps as a grid
start.writeConfig("applicationsDisplay", "1");   // all apps as a list
start.writeConfig("compactMode", "false");

var tasks = bar.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.mozilla.firefox.desktop",
    "applications:steam.desktop",
    "applications:com.heroicgameslauncher.hgl.desktop",
    "applications:org.kde.discover.desktop",
    "applications:org.verta.Settings.desktop"
].join(","));
tasks.writeConfig("iconSpacing", "2");
tasks.writeConfig("indicateAudioStreams", "true");
tasks.writeConfig("groupingStrategy", "1");      // group windows of one app
tasks.writeConfig("middleClickAction", "NewInstance");

bar.addWidget("org.kde.plasma.panelspacer");

bar.addWidget("org.kde.plasma.systemtray");

var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BelowTime"); // time over date, like Windows
clock.writeConfig("dateFormat", "shortDate");

bar.addWidget("org.kde.plasma.showdesktop");          // "peek" corner, like Windows

// Desktop wallpaper.
desktopsForActivity(currentActivity()).forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Verta/");
});
