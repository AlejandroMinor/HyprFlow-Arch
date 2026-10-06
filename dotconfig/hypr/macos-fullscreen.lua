-- macos-fullscreen.lua
-- Fullscreen like the green button on macOS: on the main monitor (the one
-- holding workspace 1) the window slides to a workspace of its own, 90 to 99,
-- and comes back to where it was however it leaves fullscreen (this bind, F11,
-- the app itself). A new window opens on that desktop, like launching another
-- app on macOS. On any other
-- monitor it is a plain fullscreen.
-- keybindings.lua binds toggle(); the hooks below do the way back.

local M = {}

-- 90 to 99 sort after 1 to 9 both as numbers and as text, and Waybar's
-- ext/workspaces sorts them as text (special:magic is not a number). 100
-- would land between 1 and 2, so there are ten.
local FIRST_WS, LAST_WS = 90, 99

-- window address -> { from = workspace it came from, to = the one it got }
-- Kept in a file too: a reload runs this file again and would otherwise
-- forget every window out on 90 to 99. XDG_RUNTIME_DIR ends with the
-- session, the same as the addresses in it.
local trips = {}
local STATE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hyprflow-macos-fullscreen"

local function save()
    local f = io.open(STATE, "w")
    if not f then return end
    for addr, trip in pairs(trips) do
        f:write(addr, " ", trip.from, " ", trip.to, "\n")
    end
    f:close()
end

-- A window Hyprland would tile opening over the app would knock it out of
-- fullscreen (misc.on_focus_under_fullscreen = 2), so it goes to the desktop
-- the app came from and the view follows. Dialogs float already and open on
-- top of the app. One rule per workspace, rewritten as trips start and end.
local function route_newcomers(to, from)
    hl.window_rule({
        name      = "macos-fullscreen-" .. to,
        enabled   = from ~= nil,
        match     = { workspace = tostring(to), float = false },
        workspace = tostring(from or 1),
    })
end

local function end_trip(addr)
    local trip = trips[addr]
    if not trip then return end
    trips[addr] = nil
    route_newcomers(trip.to, nil)
    save()
    return trip
end

local function load()
    local f = io.open(STATE, "r")
    if not f then return end
    for line in f:lines() do
        local addr, from, to = line:match("^(%S+) (-?%d+) (%d+)$")
        if addr and hl.get_window("address:" .. addr) then
            trips[addr] = { from = tonumber(from), to = tonumber(to) }
            route_newcomers(trips[addr].to, trips[addr].from)
        end
    end
    f:close()
end

local function on_main_monitor(win)
    local ws1 = hl.get_workspace(1)
    if not (ws1 and ws1.monitor and win.monitor) then return true end
    return win.monitor.name == ws1.monitor.name
end

local function free_workspace()
    for id = FIRST_WS, LAST_WS do
        local ws = hl.get_workspace(id)
        if not ws or ws.windows == 0 then return id end
    end
end

function M.toggle()
    local win = hl.get_active_window()
    if not win or not win.workspace then return end

    -- Leaving: the window.fullscreen hook takes it back.
    if trips[win.address] then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "unset", window = win }))
        return
    end

    local main = on_main_monitor(win)
    local to = main and free_workspace()
    if not to then
        if main then
            hl.exec_cmd('notify-send -u low -i view-fullscreen "Fullscreen" "Workspaces 90 to 99 are taken, this one stays here"')
        end
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen" }))
        return
    end

    trips[win.address] = { from = win.workspace.id, to = to }
    route_newcomers(to, win.workspace.id)
    save()
    hl.dispatch(hl.dsp.window.move({ workspace = to }))
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" }))
end

-- Home again, with any dialog still over it: nothing stays behind on 90 to 99.
hl.on("window.fullscreen", function(w)
    if not w or w.fullscreen > 0 then return end
    local trip = end_trip(w.address)
    if not trip then return end
    for _, other in ipairs(hl.get_workspace_windows(trip.to)) do
        if other.address ~= w.address then
            hl.dispatch(hl.dsp.window.move({ workspace = trip.from, window = other, follow = false }))
        end
    end
    hl.dispatch(hl.dsp.window.move({ workspace = trip.from, window = w }))
    hl.dispatch(hl.dsp.focus({ window = w }))
end)

-- Sent somewhere else by hand (Super + Shift + 2, ...): it stays there.
hl.on("window.move_to_workspace", function(w)
    local trip = w and trips[w.address]
    if trip and w.workspace and w.workspace.id ~= trip.to then
        end_trip(w.address)
    end
end)

hl.on("window.destroy", function(w)
    if w then end_trip(w.address) end
end)

load()

return M
