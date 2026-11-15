// Plasma runs each script in this folder once per user, the first time Plasma
// starts after the script appears. Sets the Verta wallpaper on every desktop.
desktops().forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Verta/");
});
