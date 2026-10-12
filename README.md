<div align="center">

<img src="docs/intro.png" alt="karin-shell boot intro" width="760">

# karin-shell

**A complete, opinionated Hyprland desktop for Arch Linux — launched with one word from the TTY.**

Hyprland (Lua config) · Brain Shell on Quickshell · hyprlock · hypridle · a pink, dark, cozy setup with Karin

[Русская версия](README.ru.md)

</div>

---

## ✨ Features

- **One command to boot** — log in on a TTY, type `karin-shell`, watch Karin assemble herself from glyphs, land in your desktop.
- **Pure Lua config** for Hyprland 0.55+ — split into small modules, every path in one place, personal tweaks in a separate `local.lua`.
- **Brain Shell** (Quickshell) as the bar, dashboard, launcher, clipboard, media, network and audio panels — with karin-shell additions:
  - **Config → Theme** — accent, window borders, rounding, gaps, bar opacity, cursor, icons, dark mode. One click applies it to Hyprland, the shell, GTK and Qt apps.
  - **Config → Desktops** — how many workspaces exist at startup and which apps open on each; pin an app to "always open on this desktop".
  - **Monitor popup** — plug in a screen and pick left / right / above / mirror / off, scale and mode on a live diagram. Tick *Remember* and it is never asked again.
  - Keyboard layout indicator in the bar.
- **Smart windows** — terminals float centered at a sane size, utilities and dialogs float, wide TUIs (`btop`, `sigye`, `cava`…) automatically tile, video in fullscreen never lets the screen sleep.
- **Lock & idle** — hyprlock with Karin, dim → lock → screen off → suspend, lid close locks.
- **Wallpapers included** — two curated sets, *anime* and *nature*, switch with `Super+W`.

## 📦 Install

> Requirements: **Arch Linux** (or an Arch-based distro), a regular user with `sudo`, and an AUR helper (`yay` or `paru`) for a couple of packages.

```bash
git clone https://github.com/detestern/karin-shell
cd karin-shell
./install.sh
```

Then log out, switch to a TTY and run:

```bash
karin-shell
```

The installer:

1. installs dependencies via `pacman` and your AUR helper (asks first);
2. copies the config to `~/.config/karin-shell`, the shell and wallpapers to `~/.local/share/karin-shell`;
3. links the `karin-shell` command into `~/.local/bin`;
4. backs up anything it replaces and **never touches** your regular `~/.config/hypr` — plain `Hyprland` keeps working as before.

| Command | |
|---|---|
| `./install.sh --update` | update files, keep your theme / desktops / monitors |
| `./install.sh --link` | dev mode: symlink everything to this repo |
| `karin-shell update` | `git pull` + update in one go |
| `./uninstall.sh` | remove karin-shell (asks before deleting, makes a backup) |

## ⌨️ Keybindings

| Keys | Action |
|---|---|
| `Super + Enter` | terminal (kitty) |
| `Super + D` | app launcher |
| `Super + S` / `T` / `C` | dashboard / kanban / settings |
| `Super + W` | wallpapers |
| `Super + V` | clipboard history |
| `Super + M` | audio mixer |
| `Super + Esc` | power menu |
| `Super + Q` | close window |
| `Super + F` | fullscreen |
| `Super + ↑` / `↓` | float centered / back to tiling |
| `Super + 1…9` | go to workspace (`+ Shift` — move window there) |
| `Super + Tab`, `Super + ← / →` | next / previous workspace |
| `Super + N` / `Super + Shift + N` | new workspace / close the current extra one |
| `Super + A` | teleport window to a workspace |
| `Super + H` | move window to the other monitor |
| `Super + Shift + P` | monitor setup popup |
| `Super + L` | lock |
| `Super + Shift + C` | reload config |
| `Super + Shift + E` | exit |
| `Print` / `Shift + Print` | screenshot area → clipboard / full screen → `~/Pictures` |
| `Super + Alt + W/B/G/H/S/I` | Wi-Fi / Bluetooth / VPN / hotspot / output / input |
| `Alt + F9` | screen recording |

All Brain Shell bindings can be remapped in **Super + C → Config → Keybinds**.

## 🎨 Customizing

| What | Where |
|---|---|
| Colors, borders, gaps, cursor, icons | `Super + C` → **Theme** |
| Workspaces and apps at startup | `Super + C` → **Desktops** |
| External monitors | plug in, or `Super + Shift + P` |
| Boot intro | `karin-shell demo`, `karin-shell effect decrypt\|matrix\|scan\|random`, `karin-shell art laptop\|knees\|photos\|standing` |
| Screen scale, keyboard layouts, your own binds & rules | `~/.config/karin-shell/local.lua` (see `local.lua.example`) |

## 🗂 Layout

```
karin-shell/
├── install.sh / uninstall.sh
├── config/                 → ~/.config/karin-shell
│   ├── hyprland.lua        entry point (only requires modules)
│   ├── modules/            paths · look · input · monitors · rules · autostart · binds · theme · desktops
│   ├── scripts/            theme / desktops / monitors stores, helpers
│   ├── intro/              TTY boot animation + art
│   ├── assets/             lock screen, avatar, fastfetch logos
│   ├── hyprlock.conf, hypridle.conf
│   └── bin/karin-shell     the launcher
├── shell/                  → ~/.local/share/karin-shell/shell   (Brain Shell, Quickshell)
└── wallpapers/             → ~/.local/share/karin-shell/wallpapers
```

## 🙏 Credits

- **[Brain Shell](https://github.com/Brainitech/Brain_Shell)** by Venkat Saahit Kamu (Brainitech) — the Quickshell desktop shell this project builds on, MIT License (`shell/LICENSE`).
- [Hyprland](https://hypr.land), [Quickshell](https://quickshell.org), [matugen](https://github.com/InioX/matugen), [awww](https://codeberg.org/LGFae/awww).
- Wallpapers belong to their respective authors and are included for personal use only.

## 📄 License

[MIT](LICENSE) © detestern
