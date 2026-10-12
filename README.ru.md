<div align="center">

<img src="docs/banner.gif" alt="karin-shell" width="100%">

# karin-shell

**Цельный уютный рабочий стол на Hyprland для Arch Linux — запускается одним словом из TTY.**

<p>
<img src="https://img.shields.io/badge/Arch_Linux-1e1e2e?style=for-the-badge&logo=archlinux&logoColor=dc8add">
<img src="https://img.shields.io/badge/Hyprland_0.55+-1e1e2e?style=for-the-badge&logo=hyprland&logoColor=dc8add">
<img src="https://img.shields.io/badge/Lua_config-1e1e2e?style=for-the-badge&logo=lua&logoColor=dc8add">
<img src="https://img.shields.io/badge/Quickshell-1e1e2e?style=for-the-badge&logo=qt&logoColor=dc8add">
<img src="https://img.shields.io/badge/license-MIT-1e1e2e?style=for-the-badge&labelColor=1e1e2e&color=dc8add">
</p>

[English version](README.md) · [Установка](#-установка) · [Хоткеи](#%EF%B8%8F-хоткеи) · [KarinCore](#-вкладка-karincore)

</div>

<br>

<p align="center">
  <img src="docs/screenshots/desktop.png" width="100%">
</p>

<table>
<tr>
<td width="50%"><img src="docs/screenshots/dashboard.png"></td>
<td width="50%"><img src="docs/screenshots/karincore.png"></td>
</tr>
<tr>
<td colspan="2"><img src="docs/screenshots/theme.png"></td>
</tr>
</table>

## ✨ Что внутри

- **Запуск одним словом** — входишь в TTY, пишешь `karin-shell`, Карин собирается из символов, и ты на рабочем столе.
- **Конфиг Hyprland целиком на Lua** (0.55+) — маленькие модули, все пути в одном файле, личные правки в отдельном `local.lua`, который обновления не трогают.
- **Brain Shell** (Quickshell) — панель, дашборд, лаунчер, буфер обмена, медиа, сеть и звук. Плюс дополнения karin-shell:
  - **Config → Theme** — акцент, рамки, скругления, отступы, прозрачность панели, курсор, иконки, тёмный режим. Одна кнопка применяет тему к Hyprland, оболочке, GTK и Qt.
  - **Config → Desktops** — сколько столов при запуске и что на них открывается; можно закрепить программу «всегда на этом столе».
  - **Попап мониторов** — подключил экран, выбрал слева / справа / сверху / зеркало / выкл, масштаб и режим на живой схеме. Галочка «Запомнить» — и больше не спросит.
  - **Вкладка KarinCore** — твой VPN прямо в дашборде (ниже).
  - Индикатор раскладки в панели.
- **Умные окна** — терминал плавающий по центру, диалоги и утилиты плавающие, широкие TUI (`btop`, `sigye`, `cava`…) сами уходят в плитку, полноэкранное видео не даёт экрану заснуть.
- **Блокировка и сон** — hyprlock с Карин; затемнение → блокировка → экран off → сон; закрыл крышку — блокировка.
- **Обои в комплекте** — два набора, *anime* и *nature*, смена по `Super + W`.
- **Можно просто попробовать** — установщик всё бэкапит и не трогает `~/.config/hypr`; обычный `Hyprland` работает как раньше.

## 📦 Установка

> **Нужно:** Arch Linux (или производный), обычный пользователь с `sudo` и `yay` или `paru` для пары пакетов из AUR.

```bash
git clone https://github.com/detestern/karin-shell
cd karin-shell
./install.sh
```

Выйди из сессии, переключись в TTY и набери:

```bash
karin-shell
```

Что делает установщик:

1. ставит зависимости через `pacman` и AUR-помощник (спрашивает перед этим);
2. копирует конфиг в `~/.config/karin-shell`, оболочку и обои — в `~/.local/share/karin-shell`;
3. кладёт команду `karin-shell` в `~/.local/bin`;
4. делает бэкап всего, что заменяет.

| Команда | |
|---|---|
| `karin-shell update` | `git pull` + обновление, тема / столы / мониторы сохраняются |
| `./install.sh --update` | то же, без `git pull` |
| `./install.sh --link` | режим разработки: симлинки на репозиторий |
| `./uninstall.sh` | удалить karin-shell (спросит, сделает бэкап) |

## ⌨️ Хоткеи

| Клавиши | Действие |
|---|---|
| `Super + Enter` | терминал (kitty) |
| `Super + D` | приложения |
| `Super + S` / `T` / `C` | дашборд / канбан / настройки |
| `Super + W` | обои |
| `Super + V` | история буфера обмена |
| `Super + M` | микшер звука |
| `Super + Esc` | меню питания |
| `Super + Q` | закрыть окно |
| `Super + F` | на весь экран |
| `Super + ↑` / `↓` | плавающее по центру / обратно в плитку |
| `Super + 1…9` | перейти на стол (`+ Shift` — перенести туда окно) |
| `Super + Tab`, `Super + ← / →` | следующий / предыдущий стол |
| `Super + N` / `Super + Shift + N` | новый стол / закрыть текущий дополнительный |
| `Super + A` | «телепорт» окна на стол |
| `Super + H` | окно на другой монитор |
| `Super + Shift + P` | настройка монитора |
| `Super + L` | блокировка |
| `Super + Shift + C` | перечитать конфиг |
| `Super + Shift + E` | выход |
| `Print` / `Shift + Print` | скрин области → буфер / весь экран → `~/Pictures` |
| `Super + Alt + W/B/G/H/S/I` | Wi-Fi / Bluetooth / VPN / точка доступа / вывод / ввод звука |
| `Alt + F9` | запись экрана |

Хоткеи Brain Shell переназначаются в **Super + C → Config → Keybinds**.

## 🌐 Вкладка KarinCore

В дашборде есть вкладка для **[KarinCore](https://github.com/detestern/KarinCore)** — быстрого VPN / прокси-клиента для Linux (VLESS, VMess, Trojan, Shadowsocks, WireGuard, OpenVPN).

- клик по ядру — подключиться / отключиться, пока идёт подключение, ядро крутится;
- профиль выбирается из списка — переподключение на лету;
- текущий профиль и внешний IP сразу видно.

Не установлен? Вкладка подскажет, как поставить:

```bash
yay -S karincore-git
```

Оболочка и KarinCore общаются через маленький мост без секретов — [docs/karincore-bridge.md](docs/karincore-bridge.md).

## 🎨 Настройка

| Что | Где |
|---|---|
| Цвета, рамки, отступы, курсор, иконки | `Super + C` → **Theme** |
| Столы и программы при запуске | `Super + C` → **Desktops** |
| Внешние мониторы | просто подключи, или `Super + Shift + P` |
| Заставка | `karin-shell demo` · `karin-shell effect decrypt\|matrix\|scan\|random` · `karin-shell art laptop\|knees\|photos\|standing` |
| Масштаб, раскладки, свои хоткеи и правила | `~/.config/karin-shell/local.lua` (пример — `local.lua.example`) |

## 🗂 Структура

```
karin-shell/
├── install.sh / uninstall.sh
├── config/                 → ~/.config/karin-shell
│   ├── hyprland.lua        точка входа (только подключает модули)
│   ├── modules/            paths · look · input · monitors · rules · autostart · binds · theme · desktops
│   ├── scripts/            хранилища темы / столов / мониторов, утилиты
│   ├── intro/              заставка в TTY + арты
│   ├── assets/             экран блокировки, аватар, логотипы fastfetch
│   ├── hyprlock.conf, hypridle.conf
│   └── bin/karin-shell     команда запуска
├── shell/                  → ~/.local/share/karin-shell/shell   (Brain Shell, Quickshell)
├── wallpapers/             → ~/.local/share/karin-shell/wallpapers
└── docs/
```

## 🙏 Благодарности

- **[Brain Shell](https://github.com/Brainitech/Brain_Shell)** от Venkat Saahit Kamu (Brainitech) — оболочка на Quickshell, на которой построен проект, MIT (`shell/LICENSE`).
- [Hyprland](https://hypr.land) · [Quickshell](https://quickshell.org) · [matugen](https://github.com/InioX/matugen) · [awww](https://codeberg.org/LGFae/awww)
- Обои принадлежат их авторам и включены только для личного использования.

## 📄 Лицензия

[MIT](LICENSE) © detestern

<div align="center">
<br>
<sub>сделано с 🩷 — <a href="https://github.com/detestern">detestern</a></sub>
</div>
