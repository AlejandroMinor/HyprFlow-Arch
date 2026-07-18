-- gestures.lua
local menu = "rofi -show drun -modes 'drun,window,run' -theme ~/.config/rofi/hyprflow/launcher-centered.rasi"

-- 3-finger swipe UP -> Open app launcher (Rofi)
hl.gesture({ fingers = 3, direction = "up",         action = function() hl.exec_cmd('sh -c "pkill -x rofi || ' .. menu .. '"') end })

-- 3-finger swipe HORIZONTAL -> Switch workspaces
hl.gesture({ fingers = 3, direction = "horizontal",  action = "workspace" })

-- 3-finger swipe DOWN -> Toggle scratchpad
hl.gesture({ fingers = 3, direction = "down",        action = "special", workspace_name = "magic" })

-- 4-finger swipe UP -> Mission Control (Hymission plugin)
hl.gesture({ 
    fingers = 4, 
    direction = "up",          
    action = function() hl.plugin.hymission.toggle() end 
})

-- 4-finger swipe DOWN -> Swap with master
hl.gesture({ fingers = 4, direction = "down",        action = function() hl.dispatch(hl.dsp.layout("swapwithmaster master")) end })

-- 4-finger pinch out -> Close window
hl.gesture({ fingers = 4, direction = "pinchout",     action = "close" })

-- 4-finger pinch in -> Fullscreen window
hl.gesture({ fingers = 4, direction = "pinchin",    action = function() hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" })) end })

-- Pinch zoom (macOS style, continuous)
hl.gesture({ fingers = 2, direction = "pinch",       action = "cursorZoom", zoom_level = 1, mode = "live" })
