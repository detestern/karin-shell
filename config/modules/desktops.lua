-- Рабочие столы при запуске: сколько постоянных столов и какие программы где открывать.
-- Данные — desktops.lua в корне karin-shell (его пишет Brain Shell: Dashboard → Config → Desktops,
-- через scripts/desktops_store.py). Здесь только чтение + запасные значения.

local P = require("modules.paths")

local D = { count = 5, focus = 1, desktops = {} }

local ok, data = false, "no path"
if P.desktops_saved then ok, data = pcall(dofile, P.desktops_saved) end
if ok and type(data) == "table" then
    D.count    = tonumber(data.count) or D.count
    D.focus    = tonumber(data.focus) or D.focus
    D.desktops = type(data.desktops) == "table" and data.desktops or {}
else
    print("karin-shell: desktops.lua not loaded, using defaults: " .. tostring(data))
end

-- Экранирование class для регулярки правила окна (org.telegram.desktop → org\.telegram\.desktop)
function D.class_regex(cls)
    return "^(" .. cls:gsub("[%.%+%*%?%^%$%(%)%[%]%{%}%|\\]", "\\%0") .. ")$"
end

return D
