// Verta default desktop. At build time (30-desktop.sh) the Dock layout
// (/usr/share/verta/layouts/dock.js: menu bar on top, dock at the bottom) is
// put in front of this; this part sets the wallpaper. Used for every new user
// (and copied into the Verta Light theme).

desktopsForActivity(currentActivity()).forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Verta/");
});
