// Verta "Dock" desktop (the default): a slim glass menu bar along the top and
// a floating dock at the bottom.
//
//   menu bar:  [Verta menu | App name] [app's menus] .... [tray] [Control Center] [date + time]
//   dock:      [Apps] [pinned and open apps] [Trash]
//
// Plasma runs this for new users (it is the Verta global theme's layout); Verta
// Settings -> Appearance -> Desktop layout runs it to switch from the taskbar.

var menubar = new Panel;
menubar.location = "top";
menubar.height = 2 * Math.ceil(gridUnit * 1.5 / 2);     // ~28 px
menubar.floating = false;
menubar.hiding = "none";
menubar.lengthMode = "fill";
menubar.opacity = "translucent";                        // always glass, even over maximised windows

// Verta menu: the logo opens About, Settings, App Store, Force Quit, Sleep,
// Restart, Shut Down... Next to it, the name of the app in front.
menubar.addWidget("org.verta.menu");

// The front app's menus (File, Edit, View...) live here, not in its window.
var appmenu = menubar.addWidget("org.kde.plasma.appmenu");
appmenu.currentConfigGroup = ["General"];
appmenu.writeConfig("compactView", "false");

menubar.addWidget("org.kde.plasma.panelspacer");
menubar.addWidget("org.kde.plasma.systemtray");
// Control Center: Wi-Fi, Bluetooth, Game Mode, Dark Mode, Do Not Disturb,
// sound and what's playing, in one glass panel.
menubar.addWidget("org.verta.controlcenter");

var clock = menubar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");   // "Mon 16 Nov  14:32"
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");
clock.writeConfig("use24hFormat", "2");                 // follow the region setting
clock.writeConfig("autoFontAndSize", "false");          // menu-bar sized, like the other items
clock.writeConfig("fontSize", "10");

var dock = new Panel;
dock.location = "bottom";
dock.height = 2 * Math.ceil(gridUnit * 3.4 / 2);    // ~62 px: big, clear icons
dock.floating = true;
dock.hiding = "none";
dock.lengthMode = "fit";                            // only as wide as its icons
dock.alignment = "center";
dock.opacity = "translucent";                       // liquid glass, even over maximised windows

// Verta Start in Launchpad style: every app in a full-screen grid, with search.
var start = dock.addWidget("org.verta.start");
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "verta-launchpad");
start.writeConfig("launchpad", "true");

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:org.kde.dolphin.desktop",
    "applications:org.mozilla.firefox.desktop",
    "applications:steam.desktop",
    "applications:com.heroicgameslauncher.hgl.desktop",
    "applications:org.kde.discover.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.verta.Settings.desktop"
].join(","));
tasks.writeConfig("iconSpacing", "1");
tasks.writeConfig("taskHoverEffect", "true");
tasks.writeConfig("highlightWindows", "true");    // hover an app: its windows are spotlighted
tasks.writeConfig("showToolTips", "true");        // live window previews on hover
tasks.writeConfig("indicateAudioStreams", "true");
tasks.writeConfig("groupingStrategy", "1");
tasks.writeConfig("middleClickAction", "NewInstance");
tasks.writeConfig("fill", "false");               // no stretching: the dock hugs its icons

dock.addWidget("org.kde.plasma.trash");
