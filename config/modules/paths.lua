-- Все пути в одном месте. Если что-то переедет — правим только здесь.
local H = os.getenv("HOME")
local DATA = (os.getenv("XDG_DATA_HOME") or (H .. "/.local/share")) .. "/karin-shell"

local P = {
    home       = H,
    kc         = H .. "/.config/karin-shell",          -- этот конфиг
    scripts    = H .. "/.config/karin-shell/scripts",
    assets     = H .. "/.config/karin-shell/assets",
    data       = DATA,                                 -- оболочка, обои
    shell      = DATA .. "/shell",                     -- Brain Shell (Quickshell)
    wallpapers = DATA .. "/wallpapers",
    pictures   = H .. "/Pictures",

    brain_keybinds = H .. "/.config/Brain_Shell/Brain_ShellKeybinds.lua",
    monitors_saved = H .. "/.config/karin-shell/monitors.saved.lua",
    desktops_saved = H .. "/.config/karin-shell/desktops.lua",
    theme_saved    = H .. "/.config/karin-shell/theme.lua",
    local_config   = H .. "/.config/karin-shell/local.lua",  -- личные правки, не в git
}

P.hyprlock = "hyprlock -c " .. P.kc .. "/hyprlock.conf"
P.hypridle = "hypridle -c " .. P.kc .. "/hypridle.conf"

-- Команда для Brain Shell по IPC: P.qs("monitor-setup", "open", "HDMI-A-1")
function P.qs(target, fn, ...)
    local cmd = "qs ipc -c " .. P.shell .. " call " .. target .. " " .. (fn or "toggle")
    for _, a in ipairs({ ... }) do cmd = cmd .. " '" .. tostring(a) .. "'" end
    return cmd
end

-- Программы по умолчанию (можно переопределить в local.lua)
P.terminal    = "kitty"
P.browser     = "firefox"
P.filemanager = "nemo"
P.editor      = "code"

return P
