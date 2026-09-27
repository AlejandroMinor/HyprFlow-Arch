-- Environment variables for the session: cursor, toolkits (Qt through qt6ct,
-- GTK dark), Wayland hints and the GPU driver for video decoding.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE",                      "24")
hl.env("HYPRCURSOR_SIZE",                   "24")
hl.env("XCURSOR_THEME",                     "Bibata-Modern-Classic")
hl.env("XDG_CURRENT_DESKTOP",               "Hyprland")
hl.env("XDG_SESSION_TYPE",                  "wayland")
hl.env("XDG_SESSION_DESKTOP",               "Hyprland")
hl.env("MOZ_ENABLE_WAYLAND",                "1")

hl.env("QT_QPA_PLATFORM",                   "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",       "0")
hl.env("QT_QPA_PLATFORMTHEME",              "qt6ct")
hl.env("QT_QPA_PLATFORMTHEME_Qt5",          "qt5ct")
hl.env("GTK_THEME",                         "Adwaita-dark")
hl.env("GTK_ICON_THEME",                    "Adwaita")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")


local function has_nvidia()
    local f = io.open("/proc/driver/nvidia/version", "r")
    if f then f:close(); return true end
    f = io.open("/sys/module/nvidia/initstate", "r")
    if f then f:close(); return true end
    return false
end

if has_nvidia() then
    hl.env("LIBVA_DRIVER_NAME",             "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME",     "nvidia")
else
    hl.env("LIBVA_DRIVER_NAME",             "radeonsi")
end
hl.env("ELECTRON_OZONE_PLATFORM_HINT",      "auto")
