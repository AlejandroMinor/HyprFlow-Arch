-- monitors.lua
-- Layout: AOC (vertical) -> NZXT -> ASUS (vertical) -> THINKPAD
-- IDs detectados por monitors.sh y guardados en monitors_ids.lua

local ok = pcall(require, "monitors_ids")
if not ok then
    AOC      = ""
    ASUS     = ""
    NZXT     = ""
    THINKPAD = ""
end

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({ output = AOC,      mode = "1920x1080@60",  position = "0x0",    scale = 1.0, transform = 1 })
hl.monitor({ output = NZXT,     mode = "2560x1440@120", position = "1080x0", scale = 1.0 })
hl.monitor({ output = ASUS,     mode = "1920x1080@60",  position = "3640x0", scale = 1.0, transform = 3 })
hl.monitor({ output = THINKPAD, mode = "1920x1080@60",  position = "4720x0", scale = 1.0 })

-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
hl.workspace_rule({ workspace = "1", monitor = NZXT })
hl.workspace_rule({ workspace = "2", monitor = NZXT })

hl.workspace_rule({ workspace = "3", monitor = AOC,  layout_opts = { orientation = "top" } })
hl.workspace_rule({ workspace = "6", monitor = AOC,  layout_opts = { orientation = "top" } })

hl.workspace_rule({ workspace = "4", monitor = ASUS, layout_opts = { orientation = "top" } })
hl.workspace_rule({ workspace = "8", monitor = ASUS, layout_opts = { orientation = "top" } })

hl.workspace_rule({ workspace = "5", monitor = THINKPAD })
hl.workspace_rule({ workspace = "7", monitor = THINKPAD })
