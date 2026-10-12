-- Мои хоткеи. Хоткеи Brain Shell — в Brain_ShellKeybinds.lua (подключается в hyprland.lua).
--
-- Занято Brain Shell (не трогаем здесь):
--   Super+S/T/D/C/W/V/M/B/Esc, Super+Alt+W/B/G/H/S/I, Ctrl+Shift+Esc, Alt+F9

local P   = require("modules.paths")
local D   = require("modules.desktops")
local mod = "SUPER"
local function key(k) return mod .. " + " .. k end
local function sh(cmd) return hl.dsp.exec_cmd(cmd) end

------------------------------------------------------------------ окна
hl.bind(key("Return"),      sh(P.terminal))
hl.bind(key("Q"),           hl.dsp.window.close())
hl.bind(key("F"),           hl.dsp.window.fullscreen())
hl.bind(key("H"),           hl.dsp.window.move({ monitor = "+1" }))   -- окно на другой монитор
hl.bind(key("A"),           sh(P.scripts .. "/move_to_ws.sh"))        -- «телепорт» окна (rofi с картинками)

-- Super+↑ — сделать окно плавающим по центру (52%×60% свободной области монитора,
-- как новое окно kitty), Super+↓ — вернуть в плитку. Считается для того монитора,
-- где окно, с учётом панели Brain Shell — одинаково на ноутбуке и внешнем экране.
local FLOAT_W, FLOAT_H = 0.52, 0.60

hl.bind(key("Up"), function()
    local w = hl.get_active_window()
    if not w then return end
    local sel = "address:" .. w.address
    local m = w.monitor or hl.get_active_monitor()
    if not m then return end
    local r  = m.reserved or { top = 0, right = 0, bottom = 0, left = 0 }
    local sc = (m.scale and m.scale > 0) and m.scale or 1
    local aw = m.width  / sc - r.left - r.right
    local ah = m.height / sc - r.top  - r.bottom
    local W, H = math.floor(aw * FLOAT_W), math.floor(ah * FLOAT_H)
    local X = math.floor(m.x + r.left + (aw - W) / 2)
    local Y = math.floor(m.y + r.top  + (ah - H) / 2)

    if w.fullscreen ~= 0 then hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", window = sel })) end
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel })) end
    hl.dispatch(hl.dsp.window.resize({ x = W, y = H, window = sel }))
    hl.dispatch(hl.dsp.window.move({ x = X, y = Y, window = sel }))
end)

hl.bind(key("Down"), function()
    local w = hl.get_active_window()
    if not w then return end
    local sel = "address:" .. w.address
    if w.fullscreen ~= 0 then hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", window = sel })) end
    if w.floating then hl.dispatch(hl.dsp.window.float({ action = "disable", window = sel })) end
end)

-- Мышь: Super+ЛКМ — двигать, Super+ПКМ — менять размер
hl.bind(key("mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

------------------------------------------------------------- рабочие столы
for i = 1, 9 do
    hl.bind(key(tostring(i)),             hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. i),         hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("Tab"),           hl.dsp.focus({ workspace = "m+1" }))
hl.bind(key("SHIFT + Tab"),   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(key("Right"),         hl.dsp.focus({ workspace = "m+1" }))
hl.bind(key("Left"),          hl.dsp.focus({ workspace = "m-1" }))
hl.bind(key("SHIFT + Right"), hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(key("SHIFT + Left"),  hl.dsp.window.move({ workspace = "m-1" }))

-- Super+N — новый стол (после постоянных)
hl.bind(key("N"), function()
    local max = D.count
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.id > max then max = ws.id end
    end
    hl.dispatch(hl.dsp.focus({ workspace = max + 1 }))
end)

-- Super+Shift+N — закрыть текущий доп. стол со всеми окнами (постоянные защищены)
-- (раньше было Super+M, но его занимает микшер Brain Shell)
hl.bind(key("SHIFT + N"), function()
    local cur = hl.get_active_workspace()
    if not cur then return end
    if cur.id <= D.count then
        hl.exec_cmd("notify-send -i dialog-warning 'Hyprland' 'Основной стол " .. cur.id .. " защищён от удаления'")
        return
    end
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.id == cur.id then
            hl.dispatch(hl.dsp.window.close({ window = "address:" .. w.address }))
        end
    end
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)

---------------------------------------------------------------- система
hl.bind(key("L"),          sh(P.hyprlock))
hl.bind(key("SHIFT + C"),  sh("hyprctl reload"))
hl.bind(key("SHIFT + E"),  hl.dsp.exit())                            -- выход сразу, без окна hyprshutdown
hl.bind(key("SHIFT + P"),  sh(P.scripts .. "/monitor_setup.sh"))      -- настроить внешний монитор вручную

-- Закрыл крышку — экран блокируется (hyprlock через hypridle/loginctl)
hl.bind("switch:on:Lid Switch", sh("loginctl lock-session"), { locked = true })

------------------------------------------------------------- скриншоты
hl.bind("Print",         sh("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind("SHIFT + Print", sh("f=" .. P.pictures .. "/$(date +%Y-%m-%d-%H%M%S)_screenshot.png; grim \"$f\" && notify-send 'Скриншот сохранён' \"$f\""))

---------------------------------------------------- звук, яркость, медиа
local rep = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  sh("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), rep)
hl.bind("XF86AudioLowerVolume",  sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        rep)
hl.bind("XF86AudioMute",         sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   sh("brightnessctl -e4 -n2 set 5%+"),                     rep)
hl.bind("XF86MonBrightnessDown", sh("brightnessctl -e4 -n2 set 5%-"),                     rep)
hl.bind("XF86AudioPlay",  sh("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", sh("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  sh("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  sh("playerctl previous"),   { locked = true })
