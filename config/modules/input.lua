hl.config({
    input = {
        kb_layout    = "us,ru",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = false,
        },
    },
})

-- Свайп тремя пальцами — переключение рабочих столов
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
