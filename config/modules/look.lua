-- Внешний вид. Цвета/размеры — из темы (Brain Shell → Config → Theme, modules/theme.lua).
local T = require("modules.theme")

-- Курсор и Qt-тема для всех программ (GTK/Qt-настройки пишет scripts/theme_store.py)
hl.env("XCURSOR_THEME",        T.cursor_theme)
hl.env("XCURSOR_SIZE",         tostring(T.cursor_size))
hl.env("HYPRCURSOR_THEME",     T.cursor_theme)
hl.env("HYPRCURSOR_SIZE",      tostring(T.cursor_size))
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

hl.config({
    general = {
        gaps_in     = T.gaps_in,
        gaps_out    = T.gaps_out,
        border_size = T.border_size,
        col = {
            active_border   = T.border_active,
            inactive_border = T.border_inactive,
        },
        layout                  = "dwindle",
        resize_on_border        = true,  -- тянуть окно за край
        extend_border_grab_area = 15,    -- зона захвата вокруг рамки
    },

    decoration = {
        rounding = T.rounding,
        shadow = {
            enabled = true,
            range   = 15,
            color   = "rgba(00000070)",
        },
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
        focus_on_activate       = false,
    },
})
