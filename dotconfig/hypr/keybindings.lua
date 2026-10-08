-- keybindings.lua
-- Migrated from keybindings.conf
-- terminal, fileManager and menu are globals set in hyprland.lua, which
-- require()s this file after defining them.

local mainMod = "SUPER"


-- =======================================================
--  SYSTEM & HELP
-- =======================================================

hl.bind(mainMod .. " + X",         function() if hl.plugin.hymission then hl.plugin.hymission.toggle() end end, { description = "Mission Control (Hymission)" })
hl.bind(mainMod .. " + I",         hl.dsp.exec_cmd("~/.local/lib/hyprflow/help-binds.sh"),                { description = "View Keybind Guide" })
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd(terminal),                                    { description = "Open Terminal (Kitty)" })
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("[float; size 900 600; center] kitty"),       { description = "Open Floating Kitty" })
hl.bind(mainMod .. " + SPACE",         hl.dsp.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"'),  { description = "Open App Launcher" })
hl.bind(mainMod .. " + D",         hl.dsp.exec_cmd("~/.local/lib/hyprflow/hyprland-show-desktop.sh"),    { description = "Show Desktop" })
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager),                                 { description = "Open File Manager" })
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("[float; size 1000 700; center] " .. fileManager), { description = "Open Floating File Manager" })
hl.bind(mainMod .. " + Q",         hl.dsp.window.close(),                                        { description = "Close Active Window" })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("~/.local/lib/hyprflow/close-workspace.sh"),                        { description = "Close All Windows in Workspace" })
hl.bind(mainMod .. " + ALT + L",   hl.dsp.exec_cmd("~/.local/bin/hyprlock-flow.sh"),             { description = "Lock Screen" })


-- =======================================================
--  WINDOW MANAGEMENT
-- =======================================================

hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }),                   { description = "Toggle Float/Tile" })
hl.bind(mainMod .. " + P",         hl.dsp.window.pin(),                                          { description = "Pin Window (all workspaces)" })
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }),             { description = "Fullscreen" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }),            { description = "Fullscreen (Absolute)" })
hl.bind(mainMod .. " + CTRL + F",  require("macos-fullscreen").toggle,                          { description = "Fullscreen on Its Own Workspace (macOS)" })
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

hl.bind(mainMod .. " + G",         function() toggle_submap("groupmode") end, { description = "Toggle Group Mode" })
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.group.toggle(), { description = "Toggle Group" })
hl.bind("ALT + G",                 hl.dsp.exec_cmd("~/.local/lib/hyprflow/hyprland-group-all.sh"), { description = "Group All Windows in Workspace" })

hl.bind("ALT + Tab",         hl.dsp.group.next(), { description = "Next Tab" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.group.prev(), { description = "Previous Tab" })

hl.bind(mainMod .. " + ALT + O", hl.dsp.window.move({ out_of_group = true }), { description = "Move Out Of Group" })

hl.define_submap("groupmode", function()
    hl.bind("g", hl.dsp.group.toggle(), { description = "Toggle Group" })
    hl.bind("a", hl.dsp.exec_cmd("~/.local/lib/hyprflow/hyprland-group-all.sh"), { description = "Group All Windows in Workspace" })
    hl.bind("o", hl.dsp.window.move({ out_of_group = true }), { description = "Move Out Of Group" })

    hl.bind("left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus Left" })
    hl.bind("right", hl.dsp.focus({ direction = "right" }), { description = "Focus Right" })
    hl.bind("up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus Up" })
    hl.bind("down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus Down" })

    hl.bind("h", hl.dsp.focus({ direction = "left" }),  { description = "Focus Left" })
    hl.bind("l", hl.dsp.focus({ direction = "right" }), { description = "Focus Right" })
    hl.bind("k", hl.dsp.focus({ direction = "up" }),    { description = "Focus Up" })
    hl.bind("j", hl.dsp.focus({ direction = "down" }),  { description = "Focus Down" })

    hl.bind("SHIFT + left",  hl.dsp.window.move({ into_group = "l" }), { description = "Move Into Group (Left)" })
    hl.bind("SHIFT + right", hl.dsp.window.move({ into_group = "r" }), { description = "Move Into Group (Right)" })
    hl.bind("SHIFT + up",    hl.dsp.window.move({ into_group = "u" }), { description = "Move Into Group (Up)" })
    hl.bind("SHIFT + down",  hl.dsp.window.move({ into_group = "d" }), { description = "Move Into Group (Down)" })
    hl.bind("SHIFT + H",     hl.dsp.window.move({ into_group = "l" }), { description = "Move Into Group (Left)" })
    hl.bind("SHIFT + L",     hl.dsp.window.move({ into_group = "r" }), { description = "Move Into Group (Right)" })
    hl.bind("SHIFT + K",     hl.dsp.window.move({ into_group = "u" }), { description = "Move Into Group (Up)" })
    hl.bind("SHIFT + J",     hl.dsp.window.move({ into_group = "d" }), { description = "Move Into Group (Down)" })

    hl.bind("comma",  hl.dsp.group.move_window({ back = true }), { description = "Move Tab Back" })
    hl.bind("period", hl.dsp.group.move_window({}),              { description = "Move Tab Forward" })

    hl.bind("n", hl.dsp.group.next(), { description = "Next Tab" })
    hl.bind("p", hl.dsp.group.prev(), { description = "Previous Tab" })

    for i = 1, 9 do
        hl.bind("" .. i, hl.dsp.group.active({ index = i }), { description = "Jump to Tab" })
    end

    hl.bind(mainMod .. " + G", hl.dsp.submap("reset"), { description = "Exit Group Mode" })
    hl.bind("escape", hl.dsp.submap("reset"), { description = "Exit Mode" })
end)


-- =======================================================
--  SCRATCHPAD
-- =======================================================

hl.bind(mainMod .. " + Z",         hl.dsp.workspace.toggle_special("magic"), { description = "Toggle Scratchpad" })
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Send to Scratchpad" })


-- =======================================================
--  SCREENSHOT SUBMAP
-- =======================================================

hl.bind(mainMod .. " + SHIFT + S", function() toggle_submap("screenshot") end, { description = "Toggle Screenshot Mode" })

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

    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.submap("reset"), { description = "Exit Screenshot Mode" })
    hl.bind("escape", hl.dsp.submap("reset"), { description = "Exit Mode" })
end)


-- =======================================================
--  EXTRAS
-- =======================================================

hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("swaync-client -t"),          { description = "Notifications" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -C"),          { description = "Clear Notifications" })
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd("killall -SIGUSR1 waybar"),   { description = "Show / Hide Bar" })
hl.bind(mainMod .. " + A",         hl.dsp.window.bring_to_top(),                 { description = "Bring to Front" })
hl.bind(mainMod .. " + K",         hl.dsp.exec_cmd("~/.local/lib/hyprflow/quick-actions.py"), { description = "Quick Actions (screens, game mode, lights, theme)" })


-- =======================================================
--  FOCUS
-- =======================================================

hl.bind(mainMod .. " + Tab",         hl.dsp.window.cycle_next(),                             { description = "Focus Next Window" })
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }),           { description = "Focus Previous Window" })
hl.bind(mainMod .. " + Escape",      hl.dsp.focus({ last = true }),                         { description = "Focus Last Window" })

-- Arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus Left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus Right" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus Up" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus Down" })


-- =======================================================
--  MOVE WINDOWS (Swap)
-- =======================================================

hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }), { description = "Move Window Left" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }), { description = "Move Window Right" })
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }), { description = "Move Window Up" })
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }), { description = "Move Window Down" })
hl.bind(mainMod .. " + SHIFT + H",     hl.dsp.window.move({ direction = "l" }), { description = "Move Window Left" })
hl.bind(mainMod .. " + SHIFT + L",     hl.dsp.window.move({ direction = "r" }), { description = "Move Window Right" })
hl.bind(mainMod .. " + SHIFT + K",     hl.dsp.window.move({ direction = "u" }), { description = "Move Window Up" })
hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.window.move({ direction = "d" }), { description = "Move Window Down" })


-- =======================================================
--  FINE MOVEMENT (Floating windows)
-- =======================================================

hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true, description = "Nudge Window Left" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true, description = "Nudge Window Right" })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true, description = "Nudge Window Up" })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true, description = "Nudge Window Down" })
hl.bind(mainMod .. " + CTRL + H",     hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true, description = "Nudge Window Left" })
hl.bind(mainMod .. " + CTRL + L",     hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true, description = "Nudge Window Right" })
hl.bind(mainMod .. " + CTRL + K",     hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true, description = "Nudge Window Up" })
hl.bind(mainMod .. " + CTRL + J",     hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true, description = "Nudge Window Down" })


-- =======================================================
--  WINCTL SUBMAP
-- =======================================================

hl.bind(mainMod .. " + R", function() toggle_submap("winctl") end, { description = "Toggle Window Control Mode" })

hl.define_submap("winctl", function()
    -- Resize (relative delta)
    hl.bind("right", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true, description = "Grow Width" })
    hl.bind("left",  hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true, description = "Shrink Width" })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true, description = "Shrink Height" })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true, description = "Grow Height" })
    hl.bind("h",     hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true, description = "Shrink Width" })
    hl.bind("l",     hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true, description = "Grow Width" })
    hl.bind("k",     hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true, description = "Shrink Height" })
    hl.bind("j",     hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true, description = "Grow Height" })

    -- Move (floating)
    hl.bind("SHIFT + right", hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true, description = "Move Window Right" })
    hl.bind("SHIFT + left",  hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true, description = "Move Window Left" })
    hl.bind("SHIFT + up",    hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true, description = "Move Window Up" })
    hl.bind("SHIFT + down",  hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true, description = "Move Window Down" })
    hl.bind("SHIFT + h",     hl.dsp.window.move({ x = -50, y = 0,   relative = true }), { repeating = true, description = "Move Window Left" })
    hl.bind("SHIFT + l",     hl.dsp.window.move({ x = 50,  y = 0,   relative = true }), { repeating = true, description = "Move Window Right" })
    hl.bind("SHIFT + k",     hl.dsp.window.move({ x = 0,   y = -50, relative = true }), { repeating = true, description = "Move Window Up" })
    hl.bind("SHIFT + j",     hl.dsp.window.move({ x = 0,   y = 50,  relative = true }), { repeating = true, description = "Move Window Down" })

    -- Float size presets (absolute)
    hl.bind("1", hl.dsp.window.resize({ x = 720,  y = 460  }), { description = "Size 720x460" })
    hl.bind("2", hl.dsp.window.resize({ x = 1100, y = 700  }), { description = "Size 1100x700" })
    hl.bind("3", hl.dsp.window.resize({ x = 1560, y = 950  }), { description = "Size 1560x950" })
    hl.bind("4", hl.dsp.window.resize({ x = 2000, y = 1180 }), { description = "Size 2000x1180" })

    -- Master mfact presets
    local function mfact(val)
        return function()
            hl.dispatch(hl.dsp.layout("mfact -2"))
            hl.dispatch(hl.dsp.layout("mfact " .. val))
        end
    end
    hl.bind("SHIFT + 1", mfact("0.50"), { description = "Master Width 50%" })
    hl.bind("SHIFT + 2", mfact("0.65"), { description = "Master Width 65%" })
    hl.bind("SHIFT + 3", mfact("0.75"), { description = "Master Width 75%" })
    hl.bind("SHIFT + 4", mfact("0.85"), { description = "Master Width 85%" })

    hl.bind("f",         hl.dsp.window.fullscreen({ mode = "maximized" }),  { description = "Fullscreen" })
    hl.bind("SHIFT + f", hl.dsp.window.fullscreen({ mode = "fullscreen" }), { description = "Fullscreen (Absolute)" })
    hl.bind("c",         hl.dsp.window.center(),                            { description = "Center Floating Window" })
    hl.bind(mainMod .. " + R", hl.dsp.submap("reset"), { description = "Exit Window Control Mode" })
    hl.bind("escape", hl.dsp.submap("reset"), { description = "Exit Mode" })
end)


-- =======================================================
--  WORKSPACES
-- =======================================================

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }),   { description = "Focus Workspace" })
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), { description = "Send Window to Workspace" })
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next Workspace" })
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Previous Workspace" })
-- This monitor only, like Ctrl+arrows on macOS: fullscreen apps (90-99) come last.
hl.bind(mainMod .. " + ALT + right", hl.dsp.focus({ workspace = "m+1" }), { description = "Next Workspace on Monitor" })
hl.bind(mainMod .. " + ALT + left",  hl.dsp.focus({ workspace = "m-1" }), { description = "Previous Workspace on Monitor" })
hl.bind(mainMod .. " + L",           hl.dsp.focus({ workspace = "m+1" }), { description = "Next Workspace on Monitor" })
hl.bind(mainMod .. " + H",           hl.dsp.focus({ workspace = "m-1" }), { description = "Previous Workspace on Monitor" })
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true, description = "Drag Window (hold + move mouse)" })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true, description = "Resize Window (hold + move mouse)" })


-- =======================================================
--  MEDIA & HARDWARE
-- =======================================================

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.local/lib/hyprflow/volume.sh up"),       { repeating = true, description = "Volume Up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.local/lib/hyprflow/volume.sh down"),     { repeating = true, description = "Volume Down" })
-- Toggles do not repeat: holding the key would flip mute on and off at random.
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("~/.local/lib/hyprflow/volume.sh mute"),     { description = "Mute Audio" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("~/.local/lib/hyprflow/volume.sh mic-mute"), { description = "Mute Microphone" })
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

hl.bind(mainMod .. " + SHIFT + I",          set_zoom( 0.5), { repeating = true, description = "Zoom In" })
hl.bind(mainMod .. " + SHIFT + mouse_down", set_zoom( 0.1), { repeating = true, description = "Zoom In (fine)" })
hl.bind(mainMod .. " + SHIFT + O",          set_zoom(-0.5), { repeating = true, description = "Zoom Out" })
hl.bind(mainMod .. " + SHIFT + mouse_up",   set_zoom(-0.1), { repeating = true, description = "Zoom Out (fine)" })


-- =======================================================
--  MASTER LAYOUT
-- =======================================================

hl.bind(mainMod .. " + Return",    hl.dsp.layout("swapwithmaster master"), { description = "Swap with Master" })
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("~/.local/lib/hyprflow/master-pick.py --notify"), { description = "Pick Window to Send to Master" })
-- "masculine" is º, the key left of 1 on the es layout.
hl.bind(mainMod .. " + masculine",      hl.dsp.exec_cmd("~/.local/lib/hyprflow/master-pick.py --notify"), { description = "Pick Window to Send to Master (alt)" })
hl.bind("mouse:277",               hl.dsp.layout("swapwithmaster master"), { description = "Swap With Master" })
hl.bind(mainMod .. " + S",         hl.dsp.layout("focusmaster auto"),      { description = "Focus Master" })
hl.bind(mainMod .. " + U",         hl.dsp.layout("orientationnext"),       { description = "Rotate Master" })
hl.bind(mainMod .. " + Y",         hl.dsp.layout("addmaster"),             { description = "Add to Master" })
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.layout("removemaster"),          { description = "Remove from Master" })


-- =======================================================
--  SESSION & LAYOUT MANAGEMENT
-- =======================================================

hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("~/.local/lib/hyprflow/session-manager.py logout"), { description = "Save & Exit" })
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("~/.local/lib/hyprflow/session-manager.py save"), { description = "Save Layout" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/lib/hyprflow/session-manager.py load"),        { description = "Open Saved Layout" })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit(),                                                  { description = "Force Exit" })
