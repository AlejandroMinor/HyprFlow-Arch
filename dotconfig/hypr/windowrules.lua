-- windowrules.lua
-- Migrated from windowrules.conf + layer rules from hyprland.conf
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- =======================================================
--  SMART GAPS (no borders/gaps when only one window)
-- =======================================================

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })

hl.window_rule({ name = "smart-borders-tiled",      match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
hl.window_rule({ name = "smart-borders-fullscreen", match = { float = false, workspace = "f[1]"   }, border_size = 0, rounding = 0 })


-- =======================================================
--  GLOBAL RULES
-- =======================================================

-- Ignore maximize requests from all apps
hl.window_rule({
    name          = "global-suppress-maximize",
    match         = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging issues with XWayland tooltips
hl.window_rule({
    name       = "no-focus-xwayland-tooltips",
    match      = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus   = true,
})


-- =======================================================
--  APP-SPECIFIC RULES
-- =======================================================

hl.window_rule({
    name       = "center-vscode-dialogs",
    match      = { class = "^(Code|code-url-handler)$", fullscreen = false },
    center     = true,
})

hl.window_rule({
    name       = "center-rofi",
    match      = { class = "^(Rofi|rofi)$", fullscreen = false },
    center     = true,
})

hl.window_rule({
    name             = "background-terminal",
    match            = { class = "kitty-bg" },
    monitor          = "DVI-I-1",
    float            = true,
    pin              = true,
    no_focus         = true,
    no_initial_focus = true,
    border_size      = 0,
    opacity          = "1.0 override 1.0 override",
})

hl.window_rule({
    name    = "waypaper-minimal",
    match   = { class = "^(waypaper)$" },
    float   = true,
    size    = {800, 540},
    center  = true,
    opacity = "0.92 override 0.92 override",
})

hl.window_rule({
    name   = "spotify-mini",
    match  = { class = "^(Spotify)$" },
    float  = true,
    size   = {900, 600},
    center = true,
})

hl.window_rule({
    name   = "xdg-file-picker",
    match  = { class = "^(xdg-desktop-portal-gtk)$" },
    float  = true,
    size   = {1000, 600},
    center = true,
})

hl.window_rule({
    name      = "audio-sink-switcher",
    match     = { class = "^(kitty-sinkswitch)$" },
    float     = true,
    size      = {450, 150},
    center    = true,
    pin       = true,
    animation = "slide",
})

hl.window_rule({
    name      = "cal-popup",
    match     = { class = "^(cal-popup)$" },
    float     = true,
    size      = {200, 200},
    center    = true,
    pin       = true,
    animation = "slide",
})

hl.window_rule({
    name      = "theme-picker",
    match     = { class = "^(kitty-theme-picker)$" },
    float     = true,
    size      = {420, 260},
    center    = true,
    pin       = true,
    animation = "popin",
    opacity   = "0.7 override 0.7 override",
})

hl.window_rule({
    name    = "kitty-transparent",
    match   = { class = "^(kitty)$" },
    opacity = "0.7 override 0.7 override",
})

hl.window_rule({
    name    = "btop-float",
    match   = { class = "^(btop-float)$" },
    float   = true,
    size    = {900, 600},
    center  = true,
    pin     = true,
    opacity = "0.85 override 0.85 override",
})

hl.window_rule({
    name    = "updates-float",
    match   = { class = "^(updates-float)$" },
    float   = true,
    size    = {900, 600},
    center  = true,
    pin     = true,
    opacity = "0.85 override 0.85 override",
})

hl.window_rule({
    name   = "satty-float",
    match  = { class = "^(com\\.gabm\\.satty)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name    = "yazi-float",
    match   = { class = "^(yazi-kitty)$" },
    opacity = "0.85 override 0.85 override",
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = {20, "monitor_h-120"},
    float = true,
})


-- =======================================================
--  DYNAMIC TAG RULES
-- =======================================================

-- Used by Super+O keybind to toggle opacity on any window
hl.window_rule({ match = { tag = "opaque" }, opaque = true })


-- =======================================================
--  LAYER RULES
-- =======================================================

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/#layer-rules

hl.layer_rule({ name = "rofi-blur",    match = { namespace = "^(rofi)$" }, blur = true, ignore_alpha = 0.01 })
hl.layer_rule({ name = "waybar-blur",  match = { namespace = "waybar" },   blur = true, ignore_alpha = 0.01 })
-- wlogout's GTK layer-shell surface reports namespace "logout_dialog", not "wlogout"
-- (check with `hyprctl layers` if porting this rule to another GTK app)
hl.layer_rule({ name = "wlogout-blur", match = { namespace = "logout_dialog" }, blur = true, ignore_alpha = 0.01 })
