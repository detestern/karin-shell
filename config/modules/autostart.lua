-- Автозапуск. Brain Shell стартует первым, потом софт.
local P = require("modules.paths")
local D = require("modules.desktops")

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

    -- Система
    hl.exec_cmd("python3 " .. P.scripts .. "/theme_store.py apply")   -- GTK/Qt/курсор/иконки по теме
    hl.exec_cmd("systemctl --user start hyprpolkitagent")   -- окна ввода пароля для GUI-программ
    hl.exec_cmd(P.hypridle)                                   -- автоблокировка / сон

    -- Оболочка
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(P.scripts .. "/first_wallpaper.sh")              -- обои при самом первом запуске
    hl.exec_cmd("quickshell -c " .. P.shell)

    -- Буфер обмена (Brain Shell сам подрезает историю до 100)
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 150 store")
    hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 150 store")

    -- Программы по столам (настройка: Brain Shell → Config → Desktops)
    for id, apps in pairs(D.desktops) do
        for _, app in ipairs(apps) do
            hl.exec_cmd(app.exec, { workspace = id .. " silent" })
        end
    end

    -- Через 5 секунд перейти на стартовый стол (пока всё прогрузилось)
    hl.timer(function()
        hl.dispatch(hl.dsp.focus({ workspace = D.focus }))
    end, { timeout = 5000, type = "oneshot" })
end)
