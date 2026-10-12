#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  karin-shell installer
#
#   ./install.sh            установить (пакеты + конфиг + оболочка + обои)
#   ./install.sh --update   обновить файлы, не трогая пакеты и твои настройки
#   ./install.sh --link     режим разработки: симлинки на этот репозиторий
#   ./install.sh --no-deps  не ставить пакеты
#   ./install.sh --yes      не задавать вопросов
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KS="$HOME/.config/karin-shell"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/karin-shell"
BS_CFG="$HOME/.config/Brain_Shell"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"

MODE="install"; DEPS=1; YES=0
for a in "$@"; do
    case "$a" in
        --update)  MODE="update"; DEPS=0 ;;
        --link)    MODE="link" ;;
        --no-deps) DEPS=0 ;;
        --yes|-y)  YES=1 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "неизвестный флаг: $a"; exit 1 ;;
    esac
done

P=$'\e[38;2;243;139;168m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
step() { echo; echo "${P}━━ $*${N}"; }
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
die()  { echo "  ${R}✗${N} $*"; exit 1; }
ask()  { ((YES)) && return 0; read -rp "  ${P}?${N} $1 [Y/n] " r; [[ -z "$r" || "$r" =~ ^[YyДд]$ ]]; }

cat <<EOF
${P}
   ██╗  ██╗ █████╗ ██████╗ ██╗███╗   ██╗
   ██║ ██╔╝██╔══██╗██╔══██╗██║████╗  ██║
   █████╔╝ ███████║██████╔╝██║██╔██╗ ██║
   ██╔═██╗ ██╔══██║██╔══██╗██║██║╚██╗██║
   ██║  ██╗██║  ██║██║  ██║██║██║ ╚████║
   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝${N}  ${D}shell · ${MODE}${N}
EOF

# ── 0. Проверки ──────────────────────────────────────────────────────────────
step "Проверка системы"
command -v pacman >/dev/null || die "Нужен Arch Linux (или производный с pacman)."
[[ $EUID -ne 0 ]] || die "Запускай от обычного пользователя, не от root."
ok "Arch / pacman"

# ── 1. Пакеты ────────────────────────────────────────────────────────────────
PKGS=(
    hyprland hypridle hyprlock hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    quickshell qt6ct qt6-svg qt6-imageformats
    matugen awww cliphist wl-clipboard grim slurp wf-recorder
    pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils upower
    brightnessctl playerctl libnotify polkit
    kitty rofi fastfetch cava jq rsync python imagemagick
    papirus-icon-theme ttf-jetbrains-mono-nerd ttf-jetbrains-mono
)

if ((DEPS)); then
    step "Пакеты"
    REPO_PKGS=(); AUR_PKGS=()
    for p in "${PKGS[@]}"; do
        pacman -Qq "$p" &>/dev/null && continue
        if pacman -Si "$p" &>/dev/null; then REPO_PKGS+=("$p"); else AUR_PKGS+=("$p"); fi
    done
    if ((${#REPO_PKGS[@]})); then
        echo "  из репозиториев: ${REPO_PKGS[*]}"
        ask "Установить через pacman?" && sudo pacman -S --needed "${REPO_PKGS[@]}"
    fi
    if ((${#AUR_PKGS[@]})); then
        AUR=""; command -v yay >/dev/null && AUR=yay; command -v paru >/dev/null && [[ -z $AUR ]] && AUR=paru
        echo "  из AUR: ${AUR_PKGS[*]}"
        if [[ -n $AUR ]]; then
            ask "Установить через $AUR?" && "$AUR" -S --needed "${AUR_PKGS[@]}"
        else
            warn "Нет yay/paru — поставь эти пакеты из AUR вручную."
        fi
    fi
    ok "пакеты на месте"
fi

# Hyprland ≥ 0.55 — нужен Lua-конфиг
if command -v Hyprland >/dev/null; then
    hv=$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+' | head -1 | awk '{print $2}')
    if [[ -n "$hv" ]] && awk -v v="$hv" 'BEGIN{split(v,a,"."); exit !(a[1]==0 && a[2]<55)}'; then
        die "Нужен Hyprland 0.55+ (Lua-конфиг), установлен $hv."
    fi
    ok "Hyprland ${hv:-?}"
fi

# ── 2. Конфиг ~/.config/karin-shell ──────────────────────────────────────────
step "Конфиг → $KS"
# Файлы, которые меняются через интерфейс — их не перезаписываем
STATE=(theme.json theme.lua desktops.json desktops.lua monitors.json monitors.saved.lua local.lua
       intro/art intro/effect intro/style)

if [[ $MODE == link ]]; then
    if [[ -e "$KS" && ! -L "$KS" ]]; then
        # перенести состояние пользователя в репозиторий (оно в .gitignore)
        for f in "${STATE[@]}"; do [[ -e "$KS/$f" ]] && cp -p "$KS/$f" "$REPO/config/$f"; done
        mv "$KS" "$KS.backup-$STAMP"; warn "старый конфиг → $KS.backup-$STAMP"
    fi
    ln -sfn "$REPO/config" "$KS"
    ok "симлинк на $REPO/config"
else
    if [[ -L "$KS" ]]; then rm "$KS"; fi
    if [[ -d "$KS" && $MODE == install ]]; then
        tar czf "$KS.backup-$STAMP.tar.gz" -C "$HOME/.config" karin-shell && ok "бэкап: $KS.backup-$STAMP.tar.gz"
    fi
    mkdir -p "$KS"
    EXC=(); for f in "${STATE[@]}"; do EXC+=(--exclude "/$f"); done
    rsync -a "${EXC[@]}" --exclude '__pycache__' "$REPO/config/" "$KS/"
    ok "файлы скопированы (твои настройки темы/столов/мониторов сохранены)"
fi
chmod +x "$KS"/bin/* "$KS"/scripts/*.sh "$KS"/scripts/*.py "$KS"/intro/intro.py 2>/dev/null || true

# ── 3. Оболочка (Brain Shell) и обои → ~/.local/share/karin-shell ────────────
step "Оболочка и обои → $DATA"
mkdir -p "$DATA"
if [[ $MODE == link ]]; then
    [[ -e "$DATA/shell" && ! -L "$DATA/shell" ]] && mv "$DATA/shell" "$DATA/shell.backup-$STAMP"
    ln -sfn "$REPO/shell" "$DATA/shell"
    [[ -e "$DATA/wallpapers" && ! -L "$DATA/wallpapers" ]] || ln -sfn "$REPO/wallpapers" "$DATA/wallpapers"
    ok "симлинки на репозиторий"
else
    rsync -a --delete --exclude '/src/config/colors.conf' "$REPO/shell/" "$DATA/shell/"
    mkdir -p "$DATA/wallpapers"
    rsync -a --ignore-existing "$REPO/wallpapers/" "$DATA/wallpapers/"
    ok "оболочка и $(find "$DATA/wallpapers" -type f | wc -l) обоев"
fi
echo "$REPO" > "$DATA/repo"
( git -C "$REPO" describe --tags --always 2>/dev/null || echo dev ) > "$DATA/version"

# ── 4. Команда karin-shell ───────────────────────────────────────────────────
step "Команда karin-shell"
mkdir -p "$BIN"
ln -sfn "$KS/bin/karin-shell" "$BIN/karin-shell"
ok "$BIN/karin-shell"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN нет в PATH — добавь в ~/.bash_profile:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac

# ── 5. Настройки Brain Shell по умолчанию ────────────────────────────────────
step "Brain Shell"
UD="$BS_CFG/src/user_data"; mkdir -p "$UD"
[[ -f "$UD/config_Provider.json" ]] || echo '{"configProvider": "lua"}' > "$UD/config_Provider.json"
echo '{"autoUpdate":false}' > "$UD/update_prefs.json"
[[ -f "$UD/wallpaper.json" ]] || printf '{"currentWall":"","wallpaperDir":"%s","scheme":"tonal-spot"}\n' \
    "$DATA/wallpapers/anime" > "$UD/wallpaper.json"
if [[ ! -f "$BS_CFG/Brain_ShellKeybinds.lua" ]]; then
    sed "s|@SHELL@|$DATA/shell|g" "$REPO/config/defaults/Brain_ShellKeybinds.lua.in" > "$BS_CFG/Brain_ShellKeybinds.lua"
    ok "хоткеи по умолчанию"
fi
ok "user_data"

# ── 6. Тема и рабочие столы ──────────────────────────────────────────────────
step "Тема и рабочие столы"
python3 "$KS/scripts/theme_store.py" load >/dev/null && ok "theme.json"
python3 "$KS/scripts/desktops_store.py" load >/dev/null && ok "desktops.json"
[[ -f "$KS/intro/art" ]] || echo laptop > "$KS/intro/art"

# ── Готово ───────────────────────────────────────────────────────────────────
step "Готово"
cat <<EOF
  Выйди из текущей сессии и в TTY набери:  ${P}karin-shell${N}

  ${D}Super+Enter  терминал       Super+D  приложения     Super+S  дашборд
  Super+W      обои           Super+C  настройки (тема, столы, хоткеи)
  Свои правки — ~/.config/karin-shell/local.lua (пример: local.lua.example)${N}
EOF
