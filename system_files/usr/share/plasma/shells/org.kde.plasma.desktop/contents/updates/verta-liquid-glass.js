// Once per user: the Liquid Glass look for people who already have the Dock
// layout. The dock stays glass even over maximised windows, and the clock in
// the menu bar is menu-bar sized instead of filling the bar's height. The
// margins separator before the Trash goes: on the glass dock it drew a line
// straight through the middle.
panels().forEach(function (p) {
    if (p.widgets("org.verta.menu").length > 0) {
        p.widgets("org.kde.plasma.digitalclock").forEach(function (clock) {
            clock.currentConfigGroup = ["Appearance"];
            clock.writeConfig("autoFontAndSize", "false");
            clock.writeConfig("fontSize", "10");
        });
    }
    if (p.floating && p.widgets("org.verta.start").length > 0 && p.location == "bottom") {
        p.opacity = "translucent";
        p.widgets("org.kde.plasma.marginsseparator").forEach(function (w) { w.remove(); });
    }
});
