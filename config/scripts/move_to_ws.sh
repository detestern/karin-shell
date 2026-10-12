#!/bin/bash

# ПУТИ
WS_ICONS="$HOME/.config/karin-shell/assets/ws-icons"
KARIN_IMG="$HOME/.config/karin-shell/assets/teleport.png"
DEFAULT_ICON="$WS_ICONS/6.jpeg"

# 1. Получаем данные о воркспейсах
EXISTING_WS=$(hyprctl workspaces -j | jq -r '.[].id' | sort -n)
MAX_WS=$(echo "$EXISTING_WS" | tail -n 1)
NEXT_WS=$((MAX_WS + 1))

# Собираем полный список (текущие + один новый)
FULL_LIST=$(echo -e "$EXISTING_WS\n$NEXT_WS" | sort -n | uniq)

# Определяем текущий воркспейс и его позицию в списке (для фокуса)
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
# Находим номер строки, где стоит наш текущий WS, и вычитаем 1 (так как rofi считает с 0)
ROW_INDEX=$(echo "$FULL_LIST" | grep -n "^$CURRENT_WS$" | cut -d: -f1)
SELECTED_ROW=$((ROW_INDEX - 1))

# 2. Генерация списка для Rofi
generate_list() {
    for i in $FULL_LIST; do
        icon="$WS_ICONS/$i.jpeg"
        if [ ! -f "$icon" ]; then
            icon="$DEFAULT_ICON"
        fi
        echo -en "$i\0icon\x1f$icon\n"
    done
}

# 3. Запуск Rofi
# Добавлен флаг -selected-row $SELECTED_ROW
selected=$(generate_list | rofi -dmenu -i -p "Teleport" \
    -selected-row "$SELECTED_ROW" \
    -theme-str 'window { location: south; anchor: south; width: 1560px; height: 280px; y-offset: -20px; background-color: #11111bE6; border: 3px; border-radius: 20px; border-color: #f38ba8; }' \
    -theme-str 'mainbox { orientation: horizontal; children: [ "karin-box", "listview" ]; background-color: transparent; }' \
    -theme-str 'karin-box { expand: false; width: 260px; background-image: url("'$KARIN_IMG'", height); background-repeat: false; background-position: center; margin: 0 10px 0 20px; }' \
    -theme-str 'listview { layout: horizontal; spacing: 20px; padding: 40px 20px 20px 20px; fixed-columns: false; }' \
    -theme-str 'element { orientation: vertical; width: 160px; border-radius: 12px; background-color: transparent; spacing: 0px; padding: 0px; }' \
    -theme-str 'element selected { background-color: #dc8add33; border: 2px; border-color: #f38ba8; }' \
    -theme-str 'element-icon { size: 150px; horizontal-align: 0.5; vertical-align: 0.5; border-radius: 8px; margin: 0px; }' \
    -theme-str 'element-text { text-color: transparent; font: "Ubuntu Nerd Font 1"; }' \
    -theme-str 'inputbar { enabled: false; }')

# 4. Перемещение окна
if [ -n "$selected" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = $selected })" >/dev/null
fi