#!/usr/bin/env bash
# karin-shell: удаление. Пакеты не трогает — только файлы karin-shell.
set -uo pipefail
KS="$HOME/.config/karin-shell"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/karin-shell"
STAMP="$(date +%Y%m%d-%H%M%S)"
P=$'\e[38;2;243;139;168m'; N=$'\e[0m'
ask() { read -rp "${P}?${N} $1 [y/N] " r; [[ "$r" =~ ^[YyДд]$ ]]; }

rm -f "$HOME/.local/bin/karin-shell" && echo "  команда karin-shell удалена"

if [[ -e "$KS" ]] && ask "Удалить конфиг $KS (будет бэкап в ~/karin-shell-config-$STAMP.tar.gz)?"; then
    tar czhf "$HOME/karin-shell-config-$STAMP.tar.gz" -C "$HOME/.config" karin-shell && rm -rf "$KS"
    echo "  конфиг удалён, бэкап: ~/karin-shell-config-$STAMP.tar.gz"
fi
if [[ -e "$DATA" ]] && ask "Удалить оболочку и обои ($DATA)?"; then
    rm -rf "$DATA" && echo "  $DATA удалён"
fi
if [[ -d "$HOME/.config/Brain_Shell" ]] && ask "Удалить настройки Brain Shell (~/.config/Brain_Shell: хоткеи, канбан, буфер)?"; then
    rm -rf "$HOME/.config/Brain_Shell" && echo "  ~/.config/Brain_Shell удалён"
fi
echo "Готово. Обычный Hyprland (~/.config/hypr) не трогали."
