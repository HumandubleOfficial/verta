// Verta default desktop: just the wallpaper. Plasma draws no panels; the
// taskbar and Start menu are Verta Shell (/usr/bin/verta-shell). Used for
// every new user (and copied into the Verta Light theme).

desktopsForActivity(currentActivity()).forEach(function (desktop) {
    desktop.wallpaperPlugin = "org.kde.image";
    desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desktop.writeConfig("Image", "file:///usr/share/wallpapers/Verta/");
});
