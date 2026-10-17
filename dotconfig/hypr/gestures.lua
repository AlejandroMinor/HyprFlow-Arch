-- gestures.lua
--
-- Mapped to macOS trackpad defaults, since that's the muscle memory this
-- setup borrows from. Nothing destructive lives on a gesture: they fire by
-- accident, and there's no undo. Close, fullscreen and swap-with-master are
-- on Super+Q, Super+F and Super+Return instead.
--
-- menu is a global set in hyprland.lua, which require()s this file.

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

-- Swipe LEFT/RIGHT -> Switch workspaces on this monitor (macOS spaces).
-- Same dispatcher as Super+H/L, so it plays the keybind animation; the
-- tracked "workspace" action can't use slidefade. Both finger counts too:
-- the T14's Synaptics pad often reads a 3 finger swipe as 4.
-- Past the last workspace of the monitor it opens an empty one, unless
-- this one is empty already, like the tracked swipe did.
local function next_workspace()
    local monitor = hl.get_active_monitor()
    local current = monitor.active_workspace.id
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.monitor.name == monitor.name and ws.id > current then
            hl.dispatch(hl.dsp.focus({ workspace = "m+1" }))
            return
        end
    end
    if monitor.active_workspace.windows > 0 then
        hl.dispatch(hl.dsp.focus({ workspace = "emptynm" }))
    end
end
local function prev_workspace() hl.dispatch(hl.dsp.focus({ workspace = "m-1" })) end

hl.gesture({ fingers = 3, direction = "left",  action = next_workspace, description = "Next Workspace on Monitor" })
hl.gesture({ fingers = 3, direction = "right", action = prev_workspace, description = "Previous Workspace on Monitor" })
hl.gesture({ fingers = 4, direction = "left",  action = next_workspace, description = "Next Workspace on Monitor" })
hl.gesture({ fingers = 4, direction = "right", action = prev_workspace, description = "Previous Workspace on Monitor" })

-- Pinch IN -> app launcher, where macOS has Launchpad.
hl.gesture({ fingers = 4, direction = "pinchin",  action = function() hl.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"') end, description = "App Launcher" })

-- Pinch OUT -> show desktop, same as macOS.
hl.gesture({ fingers = 4, direction = "pinchout", action = function() hl.exec_cmd("~/.local/lib/hyprflow/hyprland-show-desktop.sh") end, description = "Show Desktop" })

-- Pinch zoom (macOS style, continuous)
hl.gesture({ fingers = 2, direction = "pinch", action = "cursorZoom", zoom_level = 1, mode = "live", description = "Zoom" })
