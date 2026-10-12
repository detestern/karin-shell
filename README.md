<div align="center">

<img src="docs/banner.gif" alt="karin-shell" width="100%">

# karin-shell

**A complete, cozy Hyprland desktop for Arch Linux — booted with one word from the TTY.**

<p>
<img src="https://img.shields.io/badge/Arch_Linux-1e1e2e?style=for-the-badge&logo=archlinux&logoColor=dc8add">
<img src="https://img.shields.io/badge/Hyprland_0.55+-1e1e2e?style=for-the-badge&logo=hyprland&logoColor=dc8add">
<img src="https://img.shields.io/badge/Lua_config-1e1e2e?style=for-the-badge&logo=lua&logoColor=dc8add">
<img src="https://img.shields.io/badge/Quickshell-1e1e2e?style=for-the-badge&logo=qt&logoColor=dc8add">
<img src="https://img.shields.io/badge/license-MIT-1e1e2e?style=for-the-badge&labelColor=1e1e2e&color=dc8add">
</p>

[Русская версия](README.ru.md) · [Install](#-install) · [Keybindings](#%EF%B8%8F-keybindings) · [KarinCore](#-karincore-tab)

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

## ✨ Features

- **One word to boot** — log in on a TTY, type `karin-shell`, watch Karin assemble herself from glyphs and land on your desktop.
- **Pure Lua config** for Hyprland 0.55+ — small modules, every path in one file, personal tweaks in a separate `local.lua` that updates never touch.
- **Brain Shell** (Quickshell) as the bar, dashboard, launcher, clipboard, media, network and audio panels — plus karin-shell additions:
  - **Config → Theme** — accent, borders, rounding, gaps, bar opacity, cursor, icons, dark mode. One click applies it to Hyprland, the shell, GTK and Qt apps.
  - **Config → Desktops** — how many workspaces exist at startup and what opens on each; pin an app to "always on this desktop".
  - **Monitor popup** — plug in a screen, pick left / right / above / mirror / off, scale and mode on a live diagram. Tick *Remember* and it never asks again.
  - **KarinCore tab** — your VPN right in the dashboard (see below).
  - Keyboard layout indicator in the bar.
- **Smart windows** — terminals float centered at a sane size, dialogs and utilities float, wide TUIs (`btop`, `sigye`, `cava`…) tile themselves, fullscreen video keeps the screen awake.
- **Lock & idle** — hyprlock with Karin; dim → lock → screen off → suspend; closing the lid locks.
- **Wallpapers included** — two curated sets, *anime* and *nature*, switch with `Super + W`.
- **Safe to try** — the installer backs everything up and never touches your `~/.config/hypr`; plain `Hyprland` keeps working.

## 📦 Install

> **Requirements:** Arch Linux (or Arch-based), a regular user with `sudo`, and `yay` or `paru` for a couple of AUR packages.

```bash
git clone https://github.com/detestern/karin-shell
cd karin-shell
./install.sh
```

Log out, switch to a TTY and run:

```bash
karin-shell
```

What the installer does:

1. installs dependencies via `pacman` and your AUR helper (asks first);
2. copies the config to `~/.config/karin-shell`, the shell and wallpapers to `~/.local/share/karin-shell`;
3. links the `karin-shell` command into `~/.local/bin`;
4. backs up anything it replaces.

| Command | |
|---|---|
| `karin-shell update` | `git pull` + update, keeps your theme / desktops / monitors |
| `./install.sh --update` | same, without pulling |
| `./install.sh --link` | dev mode: symlink everything to this repo |
| `./uninstall.sh` | remove karin-shell (asks first, makes a backup) |

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
| `Super + Shift + P` | monitor setup |
| `Super + L` | lock |
| `Super + Shift + C` | reload config |
| `Super + Shift + E` | exit |
| `Print` / `Shift + Print` | screenshot area → clipboard / full screen → `~/Pictures` |
| `Super + Alt + W/B/G/H/S/I` | Wi-Fi / Bluetooth / VPN / hotspot / output / input |
| `Alt + F9` | screen recording |

Every Brain Shell binding can be remapped in **Super + C → Config → Keybinds**.

## 🌐 KarinCore tab

The dashboard has a tab for **[KarinCore](https://github.com/detestern/KarinCore)** — a fast VPN / proxy client for Linux (VLESS, VMess, Trojan, Shadowsocks, WireGuard, OpenVPN).

- click the core to connect / disconnect, watch it spin while connecting;
- pick a profile from the dropdown — it reconnects on the fly;
- current profile and public IP at a glance.

Not installed? The tab shows how to get it:

```bash
yay -S karincore-git
```

The shell and KarinCore talk through a tiny, secret-free bridge — see [docs/karincore-bridge.md](docs/karincore-bridge.md).

## 🎨 Customizing

| What | Where |
|---|---|
| Colors, borders, gaps, cursor, icons | `Super + C` → **Theme** |
| Workspaces and startup apps | `Super + C` → **Desktops** |
| External monitors | just plug in, or `Super + Shift + P` |
| Boot intro | `karin-shell demo` · `karin-shell effect decrypt\|matrix\|scan\|random` · `karin-shell art laptop\|knees\|photos\|standing` |
| Screen scale, layouts, your own binds & rules | `~/.config/karin-shell/local.lua` (see `local.lua.example`) |

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
├── wallpapers/             → ~/.local/share/karin-shell/wallpapers
└── docs/
```

## 🙏 Credits

- **[Brain Shell](https://github.com/Brainitech/Brain_Shell)** by Venkat Saahit Kamu (Brainitech) — the Quickshell shell this project builds on, MIT (`shell/LICENSE`).
- [Hyprland](https://hypr.land) · [Quickshell](https://quickshell.org) · [matugen](https://github.com/InioX/matugen) · [awww](https://codeberg.org/LGFae/awww)
- Wallpapers belong to their respective authors and are included for personal use only.

## 📄 License

[MIT](LICENSE) © detestern

<div align="center">
<br>
<sub>made with 🩷 by <a href="https://github.com/detestern">detestern</a></sub>
</div>
