-- ═══════════════════════════════════════════════════════════════════════
--  karin-shell — единый конфиг Hyprland (Lua, Hyprland 0.55+)
--  Запуск из TTY: karin-shell
--  Модули — в ./modules, все пути — в modules/paths.lua,
--  личные правки под своё железо — в local.lua (его не трогают обновления).
-- ═══════════════════════════════════════════════════════════════════════

local P = require("modules.paths")

require("modules.look")       -- тема: рамки, скругления, блюр, курсор
require("modules.input")      -- клавиатура, тачпад
require("modules.monitors")   -- мониторы + попап при подключении нового
require("modules.rules")      -- правила окон и рабочих столов
require("modules.autostart")  -- что запускается при старте
require("modules.binds")      -- хоткеи

-- Хоткеи Brain Shell. Файл генерирует сам шелл (Dashboard → Config → Keybinds).
local ok, err = pcall(dofile, P.brain_keybinds)
if not ok then print("karin-shell: Brain Shell keybinds not loaded: " .. tostring(err)) end

-- Личные правки (масштаб экрана, раскладки, свои хоткеи и правила)
local lf = io.open(P.local_config, "r")
if lf then
    lf:close()
    local lok, lerr = pcall(dofile, P.local_config)
    if not lok then print("karin-shell: local.lua error: " .. tostring(lerr)) end
end
