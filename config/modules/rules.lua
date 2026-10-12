-- Правила окон и рабочих столов
local D = require("modules.desktops")

-- Постоянные столы 1..N (N и программы — в Brain Shell: Config → Desktops; дальше — Super+N)
for i = 1, D.count do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- «Закреплённые» программы: их окна всегда открываются на своём столе, как бы ни запустили
for id, apps in pairs(D.desktops) do
    for _, app in ipairs(apps) do
        if app.pin and app.class and app.class ~= "" then
            hl.window_rule({
                name      = "pin-" .. app.class .. "-ws" .. id,
                match     = { class = D.class_regex(app.class) },
                workspace = id .. " silent",
            })
        end
    end
end

-- Приветственное окно с Карин (kitty + fastfetch)
hl.window_rule({
    name    = "karin-welcome",
    match   = { class = "^(desktop_info)$" },
    float   = true,
    size    = "monitor_w*0.47 monitor_h*0.56",
    center  = true,
    suppress_event = "maximize fullscreen fullscreenoutput",
    opacity = "0.9 0.9",
})

-- Терминалы чуть прозрачные
-- Игнорировать просьбы программ «развернуть меня» (kitty, например, сам просит
-- maximize при открытии). Развернуть вручную — Super+F.
hl.window_rule({
    name           = "suppress-maximize",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

-- kitty (Super+Enter и любой запуск) — плавающее окно по центру, уменьшенное
hl.window_rule({
    name    = "kitty-float",
    match   = { class = "^(kitty)$" },
    float   = true,
    size    = "monitor_w*0.52 monitor_h*0.6",   -- в долях экрана: одинаково на ноутбуке и внешнем мониторе
    center  = true,
    opacity = "0.9 0.9",
    suppress_event = "maximize fullscreen fullscreenoutput",
})
hl.window_rule({ name = "alacritty-opacity", match = { class = "^(Alacritty)$" }, opacity = "0.9 0.9" })

-- VS Code чуть прозрачный (на какой стол — решает Config → Desktops)
hl.window_rule({ name = "code-opacity", match = { class = "^(code-oss)$" }, opacity = "0.9 0.9" })

-- Nemo — всегда плиткой
hl.window_rule({ name = "nemo-tile", match = { class = "^(nemo)$" }, tile = true })

-- Диалоги выбора файлов: плавающие, по центру, на текущем столе
for _, cls in ipairs({ "xdg-desktop-portal-gtk", "xdg-desktop-portal-gnome" }) do
    hl.window_rule({
        name      = "portal-" .. cls,
        match     = { class = "^(" .. cls .. ")$" },
        float     = true,
        center    = true,
        workspace = "current",
    })
end

-- Окно авторизации polkit — по центру поверх всего
hl.window_rule({
    name   = "polkit-agent",
    match  = { class = "^(hyprpolkitagent)$" },
    float  = true,
    center = true,
    pin    = true,
})

-- «Широкие» терминальные программы: если в плавающем kitty запустили одну из них,
-- окно само уходит в плитку на всю свободную область (циферблат sigye и т.п. не режется).
-- Совпадение — по началу заголовка окна (kitty ставит туда имя запущенной команды).
local WIDE_TUI = { "sigye", "btop", "htop", "cava" }

hl.on("window.title", function(w)
    if not w or w.class ~= "kitty" or not w.floating then return end
    local title = (w.title or ""):lower()
    for _, name in ipairs(WIDE_TUI) do
        if title:sub(1, #name) == name then
            hl.dispatch(hl.dsp.window.float({ action = "disable", window = "address:" .. w.address }))
            return
        end
    end
end)

-- Не гасить и не блокировать экран, пока что-то открыто на весь экран (видео, игры)
hl.window_rule({ name = "idle-inhibit-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Мелкие утилиты и служебные окна — плавающие, по центру
local FLOAT_CLASSES = {
    "pavucontrol", "org.pulseaudio.pavucontrol", "blueman-manager", "nm-connection-editor",
    "nwg-look", "qt6ct", "qt5ct", "kvantummanager", "org.gnome.Calculator", "gnome-calculator",
    "file-roller", "org.gnome.FileRoller", "xdg-desktop-portal-hyprland", "hyprland-share-picker",
    "com.nikitahya.karincore", "karincore", "Viewnior",
}
for _, cls in ipairs(FLOAT_CLASSES) do
    hl.window_rule({
        name   = "float-util-" .. cls,
        match  = { class = "^(" .. cls:gsub("%.", "\\.") .. ")$" },
        float  = true,
        center = true,
        size   = "monitor_w*0.45 monitor_h*0.55",
    })
end

-- Диалоги по заголовку: «Открыть/Сохранить файл», свойства и т.п.
for i, title in ipairs({ "^(Open File)(.*)$", "^(Save File)(.*)$", "^(Save As)(.*)$", "^(Открыть файл)(.*)$",
                         "^(Сохранить)(.*)$", "^(Properties)(.*)$", "^(Свойства)(.*)$" }) do
    hl.window_rule({ name = "float-dialog-" .. i, match = { title = title }, float = true, center = true })
end

-- Firefox «картинка в картинке» — маленькое окно поверх всего в правом нижнем углу
hl.window_rule({
    name  = "firefox-pip",
    match = { title = "^(Picture-in-Picture|Картинка в картинке)$" },
    float = true,
    pin   = true,
    size  = "monitor_w*0.28 monitor_h*0.28",
    move  = "monitor_w*0.71 monitor_h*0.70",
    keep_aspect_ratio = true,
})

-- Telegram: просмотр фото/видео — плавающее окно
hl.window_rule({
    name  = "telegram-media",
    match = { class = "^(org\\.telegram\\.desktop)$", title = "^(Media viewer|Просмотр медиа)$" },
    float = true,
    center = true,
})
