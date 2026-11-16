// Verta "Taskbar" desktop: one floating glass taskbar at the bottom, Windows 11
// style. The Verta Start menu and pinned/open apps sit in the centre; the
// tray and clock sit on the right.
//
// Verta Settings -> Appearance -> Desktop layout runs this to switch from the
// Dock layout (dock.js, the default).

var bar = new Panel;
bar.location = "bottom";
bar.height = 2 * Math.ceil(gridUnit * 2.8 / 2);   // ~52 px: room for the app indicator dash
bar.floating = true;
bar.hiding = "none";
bar.lengthMode = "fill";

// Two expanding spacers either side of the start button + apps centre them.
bar.addWidget("org.kde.plasma.panelspacer");

// Verta Start (/usr/share/plasma/plasmoids/org.verta.start): pinned apps,
// recent files, all apps and search. Opens with the Windows/Meta key too.
var start = bar.addWidget("org.verta.start");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "verta-logo");
start.writeConfig("launchpad", "false");

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
tasks.writeConfig("iconSpacing", "1");           // tight, evenly spaced like Windows 11
tasks.writeConfig("taskHoverEffect", "true");     // rounded hover pill (Verta Plasma style)
tasks.writeConfig("highlightWindows", "true");    // hover an app: its windows are spotlighted
tasks.writeConfig("showToolTips", "true");        // live window previews on hover
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

