-- gestures.lua
--
-- Mapped to macOS trackpad defaults, since that's the muscle memory this
-- setup borrows from. Nothing destructive lives on a gesture: they fire by
-- accident, and there's no undo. Close, fullscreen and swap-with-master are
-- on Super+Q, Super+F and Super+Return instead.
local menu = "rofi -show drun -modes 'drun,window,run' -theme ~/.config/rofi/hyprflow/launcher-centered.rasi"

local function mission_control()
    if hl.plugin.hymission then hl.plugin.hymission.toggle() end
end

-- Swipe UP -> Mission Control. Both finger counts, like macOS: same motion,
-- same result, so a miscount doesn't do something else entirely.
hl.gesture({ fingers = 3, direction = "up",   action = mission_control, description = "Mission Control" })
hl.gesture({ fingers = 4, direction = "up",   action = mission_control, description = "Mission Control" })

-- Swipe DOWN -> Scratchpad. macOS puts App Exposé here; this is the closest
-- thing that exists in the setup.
hl.gesture({ fingers = 3, direction = "down", action = "special", workspace_name = "magic", description = "Toggle Scratchpad" })
hl.gesture({ fingers = 4, direction = "down", action = "special", workspace_name = "magic", description = "Toggle Scratchpad" })

-- Swipe HORIZONTAL -> Switch workspaces (macOS spaces).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace", description = "Switch Workspace" })

-- Pinch IN -> app launcher, where macOS has Launchpad.
hl.gesture({ fingers = 4, direction = "pinchin",  action = function() hl.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"') end, description = "App Launcher" })

-- Pinch OUT -> show desktop, same as macOS.
hl.gesture({ fingers = 4, direction = "pinchout", action = function() hl.exec_cmd("~/.local/bin/hyprland-show-desktop.sh") end, description = "Show Desktop" })

-- Pinch zoom (macOS style, continuous)
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live", description = "Zoom" })
