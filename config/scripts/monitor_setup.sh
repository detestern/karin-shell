#!/usr/bin/env bash
# Настройка внешнего монитора.
#   monitor_setup.sh [ИМЯ]   — без имени берёт первый внешний монитор
# Сначала пробует красивый попап Brain Shell, если шелл ещё не поднялся — ждёт,
# в крайнем случае показывает простой rofi-выбор.

KC="$HOME/.config/karin-shell"
SHELL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/karin-shell/shell"
INTERNAL=$(hyprctl monitors all -j | jq -r '([.[] | select(.name | startswith("eDP"))][0].name) // .[0].name')
NAME="$1"

if [[ -z "$NAME" ]]; then
    NAME=$(hyprctl monitors all -j | jq -r --arg i "$INTERNAL" '[.[] | select(.name != $i)][0].name // empty')
    [[ -z "$NAME" ]] && { notify-send "Мониторы" "Внешний монитор не подключён"; exit 0; }
fi

for _ in $(seq 1 20); do
    if qs ipc -c "$SHELL_DIR" call monitor-setup open "$NAME" >/dev/null 2>&1; then
        exit 0
    fi
    sleep 0.5
done

# ── запасной вариант: rofi ─────────────────────────────────────────────
choice=$(printf '→  Справа\n←  Слева\n↑  Сверху\n⧉  Зеркало\n' | \
    rofi -dmenu -i -p "Монитор $NAME" -theme "$KC/scripts/rofi/karin.rasi")
case "$choice" in
    *Справа*)  pos='position = "auto-right"' ;;
    *Слева*)   pos='position = "auto-left"' ;;
    *Сверху*)  pos='position = "auto-up"' ;;
    *Зеркало*) pos="position = \"auto\", mirror = \"$INTERNAL\"" ;;
    *) exit 0 ;;
esac
hyprctl eval "hl.monitor({ output = \"$NAME\", mode = \"preferred\", scale = \"auto\", $pos })" >/dev/null
