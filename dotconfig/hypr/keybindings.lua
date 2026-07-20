-- keybindings.lua
-- Migrated from keybindings.conf
-- NOTE: terminal, fileManager, menu are redefined here because 'local' variables
-- in hyprland.lua are not visible across require() calls.
-- If you make them global there (remove 'local'), delete these.

local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "kitty --class yazi-kitty -e yazi"
local menu        = "rofi -show drun -modes 'drun,window,run' -theme ~/.config/rofi/hyprflow/launcher-centered.rasi"


-- =======================================================
--  SYSTEM & HELP
-- =======================================================

hl.bind(mainMod .. " + X",         hl.plugin.hymission.toggle,                                   { description = "Mission Control (Hymission)" })
hl.bind(mainMod .. " + I",         hl.dsp.exec_cmd("~/.local/bin/help-binds.sh"),                { description = "View Keybind Guide" })
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal),                                    { description = "Open Terminal (Kitty)" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("[float; size 900 600; center] kitty"),       { description = "Open Floating Kitty" })
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"'),  { description = "Open App Launcher" })
hl.bind(mainMod .. " + SPACE",         hl.dsp.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"'),  { description = "Open App Launcher" })
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager),                                 { description = "Open File Manager" })
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("[float; size 1000 700; center] " .. fileManager), { description = "Open Floating File Manager" })
hl.bind(mainMod .. " + Q",         hl.dsp.window.close(),                                        { description = "Close Active Window" })
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("~/.local/bin/hyprlock-flow.sh"),             { description = "Lock Screen" })


-- =======================================================
--  WINDOW MANAGEMENT
-- =======================================================

hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }),                   { description = "Toggle Float/Tile" })
hl.bind(mainMod .. " + P",         hl.dsp.window.pin(),                                          { description = "Pin Window (all workspaces)" })
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }),             { description = "Fullscreen" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }),            { description = "Fullscreen (Absolute)" })
hl.bind(mainMod .. " + C",         hl.dsp.window.center(),                                       { description = "Center Floating Window" })
hl.bind(mainMod .. " + O",         hl.dsp.window.tag({ tag = "opaque" }),                                                                                                    { description = "Toggle Opacity" })
hl.bind(mainMod .. " + SHIFT + C", function()
    hl.dispatch(hl.dsp.window.float({ action = "enable" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1200, y = 800 }))
    hl.dispatch(hl.dsp.window.center())
end, { description = "Mini Window (1200x800)" })


-- =======================================================
--  GROUPS (Browser Mode)
-- =======================================================

hl.bind(mainMod .. " + G",         hl.dsp.group.toggle(),                                    { description = "Toggle Group" })
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("~/.local/bin/hyprland-group-all.sh"),      { description = "Group All Windows in Workspace" })

hl.bind("ALT + Tab",         hl.dsp.group.next(), { description = "Next Tab" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.group.prev(), { description = "Previous Tab" })

hl.bind(mainMod .. " + ALT + H",    hl.dsp.window.move({ into_group = "l" }))
hl.bind(mainMod .. " + ALT + L",    hl.dsp.window.move({ into_group = "r" }))
hl.bind(mainMod .. " + ALT + K",    hl.dsp.window.move({ into_group = "u" }))
hl.bind(mainMod .. " + ALT + J",    hl.dsp.window.move({ into_group = "d" }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ out_of_group = true }))


-- =======================================================
--  SCRATCHPAD
-- =======================================================

hl.bind(mainMod .. " + Z",         hl.dsp.workspace.toggle_special("magic"), { description = "Toggle Scratchpad" })
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Send to Scratchpad" })


-- =======================================================
--  SCREENSHOT SUBMAP
-- =======================================================

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.submap("screenshot"), { description = "Screenshot" })

hl.define_submap("screenshot", function()
    local out = "$HOME/Pictures/Screenshots/$(date '+%Y-%m-%d_%H-%M-%S').png"
    local satty_flags = "--copy-command wl-copy --early-exit --action-on-enter save-to-file --right-click-copy --filename - --output-filename "

    hl.bind("r", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m region --freeze --raw | satty " .. satty_flags .. out))
    end, { description = "Region Screenshot (Satty)" })

    hl.bind("w", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m window --freeze --raw | satty " .. satty_flags .. out))
    end, { description = "Window Screenshot (Satty)" })

    hl.bind("s", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m output --freeze --raw | satty " .. satty_flags .. out))
    end, { description = "Screen Screenshot (Satty)" })

    hl.bind("SHIFT + r", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m region --freeze --clipboard-only"))
    end, { description = "Region Screenshot → Clipboard" })

    hl.bind("SHIFT + w", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m window --clipboard-only"))
    end, { description = "Window Screenshot → Clipboard" })

    hl.bind("SHIFT + s", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))
    end, { description = "Screen Screenshot → Clipboard" })

    hl.bind("escape", hl.dsp.submap("reset"))
end)


-- =======================================================
--  EXTRAS
-- =======================================================

hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("swaync-client -t"),          { description = "Notifications" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -C"),          { description = "Clear Notifications" })
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("killall -SIGUSR1 waybar"),   { description = "Restart Waybar" })
hl.bind(mainMod .. " + A",         hl.dsp.window.bring_to_top(),                 { description = "Bring to Front" })


-- =======================================================
--  FOCUS
-- =======================================================

hl.bind(mainMod .. " + Tab",         hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
hl.bind(mainMod .. " + Escape",      hl.dsp.focus({ last = true }))

-- Arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))
-- Vim (HJKL)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))


-- =======================================================
--  MOVE WINDOWS (Swap)
-- =======================================================

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + K",     hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.window.move({ direction = "d" }))


-- =======================================================
--  FINE MOVEMENT (Floating windows)
-- =======================================================

hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + H",     hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L",     hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K",     hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J",     hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true })


-- =======================================================
--  WINCTL SUBMAP
-- =======================================================

hl.bind(mainMod .. " + R", hl.dsp.submap("winctl"), { description = "Window Control Mode" })

hl.define_submap("winctl", function()
    -- Resize (relative delta)
    hl.bind("right", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
    hl.bind("h",     hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("l",     hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("k",     hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("j",     hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })

    -- Move (floating)
    hl.bind("SHIFT + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true })
    hl.bind("SHIFT + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true })
    hl.bind("SHIFT + h",     hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + l",     hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true })
    hl.bind("SHIFT + k",     hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true })
    hl.bind("SHIFT + j",     hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true })

    -- Float size presets (absolute)
    hl.bind("1", hl.dsp.window.resize({ x = 720,  y = 460  }))
    hl.bind("2", hl.dsp.window.resize({ x = 1100, y = 700  }))
    hl.bind("3", hl.dsp.window.resize({ x = 1560, y = 950  }))
    hl.bind("4", hl.dsp.window.resize({ x = 2000, y = 1180 }))

    -- Master mfact presets
    local function mfact(val)
        return function()
            hl.dispatch(hl.dsp.layout("mfact -2"))
            hl.dispatch(hl.dsp.layout("mfact " .. val))
        end
    end
    hl.bind("SHIFT + 1", mfact("0.50"))
    hl.bind("SHIFT + 2", mfact("0.65"))
    hl.bind("SHIFT + 3", mfact("0.75"))
    hl.bind("SHIFT + 4", mfact("0.85"))

    hl.bind("f",         hl.dsp.window.fullscreen({ mode = "maximized" }))
    hl.bind("SHIFT + f", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
    hl.bind("c",         hl.dsp.window.center())
    hl.bind("escape",    hl.dsp.submap("reset"))
end)


-- =======================================================
--  WORKSPACES
-- =======================================================

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })


-- =======================================================
--  MEDIA & HARDWARE
-- =======================================================

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, description = "Volume Up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { repeating = true, description = "Volume Down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { repeating = true, description = "Mute Audio" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { repeating = true, description = "Mute Microphone" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s 10%+"), { repeating = true, description = "Brightness Up" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl s 10%-"), { repeating = true, description = "Brightness Down" })

-- Playback
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next Track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous Track" })

-- Media control (MX Keys alternative)
hl.bind(mainMod .. " + period",         hl.dsp.exec_cmd("playerctl next"),           { locked = true, description = "Next Track (Keyboard)" })
hl.bind(mainMod .. " + comma",          hl.dsp.exec_cmd("playerctl previous"),       { locked = true, description = "Previous Track (Keyboard)" })
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.exec_cmd("playerctl position 10+"),  { locked = true, description = "Seek Forward 10s" })
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.exec_cmd("playerctl position 10-"),  { locked = true, description = "Seek Back 10s" })


-- =======================================================
--  ZOOM
-- =======================================================

local _zoom = 1.0
local function set_zoom(delta)
    return function()
        _zoom = math.max(1.0, _zoom + delta)
        hl.config({ cursor = { zoom_factor = _zoom } })
    end
end

hl.bind(mainMod .. " + SHIFT + I",          set_zoom( 0.5), { repeating = true })
hl.bind(mainMod .. " + SHIFT + mouse_down", set_zoom( 0.1), { repeating = true })
hl.bind(mainMod .. " + SHIFT + O",          set_zoom(-0.5), { repeating = true })
hl.bind(mainMod .. " + SHIFT + mouse_up",   set_zoom(-0.1), { repeating = true })


-- =======================================================
--  MASTER LAYOUT
-- =======================================================

hl.bind(mainMod .. " + Return",    hl.dsp.layout("swapwithmaster master"), { description = "Swap with Master" })
hl.bind("mouse:277",               hl.dsp.layout("swapwithmaster master"))
hl.bind(mainMod .. " + S",         hl.dsp.layout("focusmaster auto"),      { description = "Focus Master" })
hl.bind(mainMod .. " + U",         hl.dsp.layout("orientationnext"),       { description = "Rotate Master" })
hl.bind(mainMod .. " + Y",         hl.dsp.layout("addmaster"),             { description = "Add to Master" })
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.layout("removemaster"),          { description = "Remove from Master" })


-- =======================================================
--  SESSION & LAYOUT MANAGEMENT
-- =======================================================

hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("~/.local/bin/session-manager/save.sh logout"), { description = "Save & Exit" })
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.local/bin/session-manager/save.sh custom"), { description = "Save Layout Template" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/session-manager/load.sh"),        { description = "Load Layout" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit(),                                                  { description = "Force Exit" })
