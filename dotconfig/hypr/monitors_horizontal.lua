-- monitors_horizontal.lua
-- Layout: AOC -> NZXT -> ASUS -> THINKPAD (all horizontal)
-- To activate: change require("monitors_vertical") to require("monitors_horizontal") in hyprland.lua

local ok = pcall(require, "monitors_ids")
if not ok then
    AOC      = ""
    ASUS     = ""
    NZXT     = ""
    THINKPAD = ""
end

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({ output = AOC,      mode = "1920x1080@60",  position = "0x0",    scale = 1.0 })
hl.monitor({ output = NZXT,     mode = "2560x1440@120", position = "1920x0", scale = 1.0 })
hl.monitor({ output = ASUS,     mode = "1920x1080@60",  position = "4480x0", scale = 1.0 })
hl.monitor({ output = THINKPAD, mode = "1920x1080@60",  position = "6400x0", scale = 1.0 })

-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
hl.workspace_rule({ workspace = "1", monitor = NZXT })
hl.workspace_rule({ workspace = "2", monitor = NZXT })

hl.workspace_rule({ workspace = "3", monitor = AOC })
hl.workspace_rule({ workspace = "6", monitor = AOC })

hl.workspace_rule({ workspace = "4", monitor = ASUS })
hl.workspace_rule({ workspace = "8", monitor = ASUS })

hl.workspace_rule({ workspace = "5", monitor = THINKPAD })
hl.workspace_rule({ workspace = "7", monitor = THINKPAD })
