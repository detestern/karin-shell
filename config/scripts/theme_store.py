#!/usr/bin/env python3
"""Единая тема karin-shell — хранилище для вкладки Config → Theme в Brain Shell.

  theme_store.py load              → JSON текущей темы (создаёт по умолчанию, если нет)
  theme_store.py save '<json>'     → сохранить theme.json, сгенерировать theme.lua и применить
  theme_store.py apply             → применить текущую тему (GTK, Qt, курсор, иконки)
  theme_store.py list              → доступные темы курсоров и иконок

theme.json — источник правды. Его читают:
  * Hyprland      — через theme.lua (modules/theme.lua): рамки, скругления, отступы, курсор
  * Brain Shell   — напрямую (src/theme/ColorLoader.qml): цвета панелей, прозрачность
  * GTK / Qt      — этот скрипт пишет settings.ini, gsettings, qt6ct
"""
import configparser, json, os, shutil, subprocess, sys

HOME = os.path.expanduser("~")
KS = os.path.join(HOME, ".config", "karin-shell")
JSON_PATH = os.path.join(KS, "theme.json")
LUA_PATH = os.path.join(KS, "theme.lua")

DEFAULT = {
    "accent":          "#ff6699",   # акцент Brain Shell (кнопки, иконки, выделение)
    "background":      "#1a1a24",   # фон панелей Brain Shell
    "text":            "#ffffff",
    "subtext":         "#ffb3cb",
    "border_active":   "#f38ba8",   # рамка активного окна
    "border_inactive": "#313244",
    "border_size":     3,
    "rounding":        10,
    "gaps_in":         7,
    "gaps_out":        10,
    "bar_opacity":     0.8,
    "cursor_theme":    "Adwaita",
    "cursor_size":     24,
    "icon_theme":      "Papirus-Dark",
    "dark":            True,
}


def _hex(c, fallback):
    c = str(c or "").strip().lstrip("#").lower()
    if len(c) == 3:
        c = "".join(ch * 2 for ch in c)
    return "#" + c if len(c) == 6 and all(ch in "0123456789abcdef" for ch in c) else fallback


def normalize(t):
    out = dict(DEFAULT)
    for k, v in (t or {}).items():
        if k not in DEFAULT:
            continue
        d = DEFAULT[k]
        try:
            if isinstance(d, bool):
                out[k] = bool(v)
            elif isinstance(d, int):
                out[k] = int(v)
            elif isinstance(d, float):
                out[k] = float(v)
            elif k in ("cursor_theme", "icon_theme"):
                out[k] = str(v).strip() or d
            else:
                out[k] = _hex(v, d)
        except (TypeError, ValueError):
            pass
    out["border_size"] = max(0, min(10, out["border_size"]))
    out["rounding"] = max(0, min(30, out["rounding"]))
    out["gaps_in"] = max(0, min(40, out["gaps_in"]))
    out["gaps_out"] = max(0, min(60, out["gaps_out"]))
    out["bar_opacity"] = round(max(0.3, min(1.0, out["bar_opacity"])), 2)
    out["cursor_size"] = max(12, min(96, out["cursor_size"]))
    return out


def load():
    try:
        with open(JSON_PATH) as f:
            return normalize(json.load(f))
    except (OSError, ValueError):
        return save(DEFAULT, apply_now=False)


def write_lua(t):
    rgb = lambda c: "rgb(%s)" % c.lstrip("#")
    lines = [
        "-- Сгенерировано scripts/theme_store.py из theme.json. Править: Brain Shell → Config → Theme.",
        "return {",
        '    border_active   = "%s",' % rgb(t["border_active"]),
        '    border_inactive = "%s",' % rgb(t["border_inactive"]),
        "    border_size     = %d," % t["border_size"],
        "    rounding        = %d," % t["rounding"],
        "    gaps_in         = %d," % t["gaps_in"],
        "    gaps_out        = %d," % t["gaps_out"],
        '    cursor_theme    = "%s",' % t["cursor_theme"].replace('"', ""),
        "    cursor_size     = %d," % t["cursor_size"],
        "}",
    ]
    with open(LUA_PATH, "w") as f:
        f.write("\n".join(lines) + "\n")


def save(t, apply_now=True):
    t = normalize(t)
    os.makedirs(KS, exist_ok=True)
    with open(JSON_PATH, "w") as f:
        json.dump(t, f, ensure_ascii=False, indent=2)
    write_lua(t)
    if apply_now:
        apply(t)
    return t


# ── применение в системе ──────────────────────────────────────────────────────
def _run(*cmd):
    if shutil.which(cmd[0]):
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _ini_merge(path, section, values):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
    except configparser.Error:
        pass
    if not cp.has_section(section):
        cp.add_section(section)
    for k, v in values.items():
        cp.set(section, k, str(v))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        cp.write(f, space_around_delimiters=False)


def _mix(a, b, k):
    a, b = a.lstrip("#"), b.lstrip("#")
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join("%02x" % round(x + (y - x) * k) for x, y in zip(ca, cb))


def write_qt(t):
    bg, fg, acc = t["background"], t["text"], t["accent"]
    base = _mix(bg, "#000000", 0.25)
    alt = _mix(bg, fg, 0.06)
    btn = _mix(bg, fg, 0.10)
    mid = _mix(bg, fg, 0.30)
    dim = _mix(bg, fg, 0.45)
    # порядок ролей QPalette, как ждёт qt6ct
    roles = [fg, btn, _mix(btn, fg, 0.2), _mix(btn, fg, 0.1), _mix(bg, "#000000", 0.4), mid, fg, "#ffffff",
             fg, base, bg, "#000000", acc, "#ffffff", acc, _mix(acc, "#8888ff", 0.4), alt, bg, bg, fg, dim]
    dis = [dim if r in (fg,) else r for r in roles]
    fmt = lambda lst: ", ".join("#ff" + c.lstrip("#") for c in lst)
    colors_dir = os.path.join(HOME, ".config", "qt6ct", "colors")
    os.makedirs(colors_dir, exist_ok=True)
    scheme = os.path.join(colors_dir, "karin-shell.conf")
    with open(scheme, "w") as f:
        f.write("[ColorScheme]\nactive_colors=%s\ndisabled_colors=%s\ninactive_colors=%s\n" % (fmt(roles), fmt(dis), fmt(roles)))
    _ini_merge(os.path.join(HOME, ".config", "qt6ct", "qt6ct.conf"), "Appearance", {
        "custom_palette": "true", "color_scheme_path": scheme, "icon_theme": t["icon_theme"], "style": "Fusion",
        "standard_dialogs": "default",
    })


def apply(t=None):
    t = t or load()
    dark = t["dark"]
    gtk = {
        "gtk-application-prefer-dark-theme": "1" if dark else "0",
        "gtk-icon-theme-name": t["icon_theme"],
        "gtk-cursor-theme-name": t["cursor_theme"],
        "gtk-cursor-theme-size": t["cursor_size"],
    }
    _ini_merge(os.path.join(HOME, ".config", "gtk-3.0", "settings.ini"), "Settings",
               dict(gtk, **{"gtk-theme-name": "Adwaita-dark" if dark else "Adwaita"}))
    _ini_merge(os.path.join(HOME, ".config", "gtk-4.0", "settings.ini"), "Settings", gtk)

    gs = "org.gnome.desktop.interface"
    _run("gsettings", "set", gs, "color-scheme", "prefer-dark" if dark else "default")
    _run("gsettings", "set", gs, "gtk-theme", "Adwaita-dark" if dark else "Adwaita")
    _run("gsettings", "set", gs, "icon-theme", t["icon_theme"])
    _run("gsettings", "set", gs, "cursor-theme", t["cursor_theme"])
    _run("gsettings", "set", gs, "cursor-size", str(t["cursor_size"]))

    # курсор по умолчанию для XWayland и программ, не читающих gsettings
    _ini_merge(os.path.join(HOME, ".local", "share", "icons", "default", "index.theme"), "Icon Theme",
               {"Name": "Default", "Inherits": t["cursor_theme"]})

    write_qt(t)
    _run("hyprctl", "setcursor", t["cursor_theme"], str(t["cursor_size"]))
    return t


def list_themes():
    dirs = [os.path.join(HOME, ".local", "share", "icons"), os.path.join(HOME, ".icons"), "/usr/share/icons"]
    cursors, icons = set(), set()
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            p = os.path.join(d, name)
            if name == "default" or not os.path.isdir(p):
                continue
            if os.path.isdir(os.path.join(p, "cursors")) or os.path.isdir(os.path.join(p, "hyprcursors")):
                cursors.add(name)
            if os.path.isfile(os.path.join(p, "index.theme")) and any(
                    os.path.isdir(os.path.join(p, s)) for s in ("scalable", "48x48", "32x32", "symbolic", "16x16", "64x64")):
                icons.add(name)
    return {"cursors": sorted(cursors, key=str.lower), "icons": sorted(icons, key=str.lower)}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "load"
    if cmd == "save":
        print(json.dumps(save(json.loads(sys.argv[2])), ensure_ascii=False))
    elif cmd == "apply":
        print(json.dumps(apply(), ensure_ascii=False))
    elif cmd == "list":
        print(json.dumps(list_themes(), ensure_ascii=False))
    elif cmd == "defaults":
        print(json.dumps(DEFAULT, ensure_ascii=False))
    else:
        print(json.dumps(load(), ensure_ascii=False))


if __name__ == "__main__":
    main()
