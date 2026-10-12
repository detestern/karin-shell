-- Тема: цвета рамок, скругления, отступы, курсор.
-- Данные — theme.lua в корне karin-shell (генерирует scripts/theme_store.py из theme.json;
-- править удобно в Brain Shell: Dashboard → Config → Theme). Здесь — чтение + запасные значения.

local P = require("modules.paths")

local T = {
    border_active   = "rgb(f38ba8)",
    border_inactive = "rgb(313244)",
    border_size     = 3,
    rounding        = 10,
    gaps_in         = 7,
    gaps_out        = 10,
    cursor_theme    = "Adwaita",
    cursor_size     = 24,
}

local ok, data = false, "no path"
if P.theme_saved then ok, data = pcall(dofile, P.theme_saved) end
if ok and type(data) == "table" then
    for k, v in pairs(data) do T[k] = v end
end

return T
