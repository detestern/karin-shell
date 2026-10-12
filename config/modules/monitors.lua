-- Мониторы.
--  * Встроенный экран ноутбука (eDP-*) — всегда слева/в 0x0.
--  * Мониторы, для которых в попапе нажали «Запомнить», лежат в monitors.saved.lua
--    (пишет scripts/monitor_store.py).
--  * Новый незнакомый монитор, подключённый во время работы → попап Brain Shell.
--  * Масштаб встроенного экрана и прочее под своё железо — в local.lua.

local P = require("modules.paths")

hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto" })
hl.monitor({ output = "eDP-2", mode = "preferred", position = "0x0", scale = "auto" })

local saved = {}
local ok, data = pcall(dofile, P.monitors_saved)
if ok and type(data) == "table" then saved = data end

for desc, rule in pairs(saved) do
    local r = { output = "desc:" .. desc }
    for k, v in pairs(rule) do r[k] = v end
    hl.monitor(r)
end

-- Всё остальное по умолчанию — справа, пока не выбрали в попапе
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = "auto" })

-- Мониторы, которые уже подключены при входе, попапом не дёргаем — только «горячее» подключение
local started_at = nil
hl.on("hyprland.start", function() started_at = os.time() end)

hl.on("monitor.added", function(mon)
    if not started_at or os.time() - started_at < 5 then return end
    if mon.name:match("^eDP") then return end
    if mon.description ~= "" and saved[mon.description] then return end
    hl.exec_cmd(P.scripts .. "/monitor_setup.sh '" .. mon.name .. "'")
end)
