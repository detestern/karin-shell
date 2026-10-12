#!/usr/bin/env bash
# Первый запуск: если обои ещё ни разу не ставились — поставить первые из набора karin-shell.
# Дальше обои меняются через Brain Shell (Super+W), awww сам помнит последние.
[[ -e "$HOME/.curr_wall" ]] && exit 0
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/karin-shell"
for _ in $(seq 1 20); do awww query &>/dev/null && break; sleep 0.25; done
img=$(find "$DATA/wallpapers/anime" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \) | sort | head -1)
[[ -n "$img" ]] || exit 0
awww img "$img" --transition-type grow && ln -sf "$img" "$HOME/.curr_wall" && ln -sf "$img" "$HOME/.curr_wall_static.jpg"
