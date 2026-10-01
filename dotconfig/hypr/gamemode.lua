-- Game mode (bin/game-mode.sh). While it is on, its state file exists, and
-- every load of this config (a reload, monitors.sh, a hotplug) keeps the game
-- settings instead of quietly undoing them. game-mode.sh off removes the file
-- and reloads.
do
    local state_home = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
    local f = io.open(state_home .. "/hyprflow/game-mode", "r")
    if f then
        local state = f:read("*a")
        f:close()
        hl.config({
            animations = { enabled = false },
            decoration = { blur = { enabled = false }, shadow = { enabled = false } },
            -- 2 = fullscreen only; always on flickers on the desktop
            misc       = { vrr = tonumber(state:match("vrr=(%d)")) or 0 },
        })
        -- A game opens fullscreen on top of Big Picture, not tiled beside it.
        hl.window_rule({
            name       = "game-mode-games-fullscreen",
            match      = { class = "^(steam_app_.*)$" },
            fullscreen = true,
        })
    end

    -- Closing Big Picture from the controller ends game mode. game-mode.sh
    -- checks it is still on and that Steam did not just reopen the window.
    hl.on("window.close", function (w)
        if w and w.title == "Steam Big Picture Mode" then
            hl.exec_cmd("game-mode.sh bigpicture-closed")
        end
    end)
end
