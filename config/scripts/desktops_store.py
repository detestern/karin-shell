#!/usr/bin/env python3
"""Рабочие столы при запуске (karin-shell) — хранилище для вкладки Config → Desktops в Brain Shell.

  desktops_store.py load            → JSON текущей настройки (создаёт по умолчанию, если нет)
  desktops_store.py save '<json>'   → сохранить desktops.json и сгенерировать desktops.lua
  desktops_store.py apps            → JSON установленных программ (.desktop) с WM-классом

Источник правды — desktops.json; Hyprland читает desktops.lua (modules/desktops.lua).
Формат: {"count": 5, "focus": 1,
         "desktops": [{"id": 1, "apps": [{"name", "exec", "icon", "class", "pin"}]}, ...]}
  pin=true — окно этой программы всегда открывается на своём столе (правило окна по class).
"""
import configparser, json, os, re, sys

KC = os.path.expanduser("~/.config/karin-shell")
JSON_PATH = os.path.join(KC, "desktops.json")
LUA_PATH = os.path.join(KC, "desktops.lua")
MAX_DESKTOPS = 10

DEFAULT = {
    "count": 5,
    "focus": 1,
    "desktops": [
        {"id": 1, "apps": [{"name": "Приветствие Карин", "exec": "kitty --class desktop_info -e karin-shell welcome",
                            "icon": "kitty", "class": "desktop_info", "pin": False}]},
        {"id": 2, "apps": [{"name": "Firefox", "exec": "firefox", "icon": "firefox", "class": "firefox", "pin": False}]},
    ],
}


def normalize(d):
    count = max(1, min(MAX_DESKTOPS, int(d.get("count", 5))))
    focus = max(1, min(count, int(d.get("focus", 1))))
    by_id = {int(x.get("id", 0)): x for x in d.get("desktops", [])}
    desktops = []
    for i in range(1, count + 1):
        apps = []
        for a in by_id.get(i, {}).get("apps", []):
            exec_ = str(a.get("exec", "")).strip()
            if not exec_:
                continue
            apps.append({
                "name": str(a.get("name") or exec_.split()[0]),
                "exec": exec_,
                "icon": str(a.get("icon", "")),
                "class": str(a.get("class") or os.path.basename(exec_.split()[0])),
                "pin": bool(a.get("pin", False)),
            })
        desktops.append({"id": i, "apps": apps})
    return {"count": count, "focus": focus, "desktops": desktops}


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def write(d):
    d = normalize(d)
    os.makedirs(KC, exist_ok=True)
    with open(JSON_PATH, "w") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
    out = ["-- Сгенерировано scripts/desktops_store.py из desktops.json.",
           "-- Править удобнее в Brain Shell: Dashboard → Config → Desktops.",
           "return {",
           "    count = %d," % d["count"],
           "    focus = %d," % d["focus"],
           "    desktops = {"]
    for ws in d["desktops"]:
        apps = ", ".join("{ name = %s, exec = %s, class = %s, pin = %s }" % (
            lua_str(a["name"]), lua_str(a["exec"]), lua_str(a["class"]), "true" if a["pin"] else "false")
            for a in ws["apps"])
        out.append("        [%d] = { %s }," % (ws["id"], apps))
    out += ["    },", "}"]
    with open(LUA_PATH, "w") as f:
        f.write("\n".join(out) + "\n")
    return d


def load():
    try:
        with open(JSON_PATH) as f:
            return normalize(json.load(f))
    except (OSError, ValueError):
        return write(DEFAULT)


def list_apps():
    dirs = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications"),
            "/var/lib/flatpak/exports/share/applications",
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]
    apps, seen = [], set()
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for fname in sorted(os.listdir(d)):
            if not fname.endswith(".desktop") or fname in seen:
                continue
            seen.add(fname)
            try:
                cp = configparser.ConfigParser(interpolation=None, strict=False)
                cp.read(os.path.join(d, fname), encoding="utf-8")
                de = cp["Desktop Entry"]
                if de.get("Type", "") != "Application" or de.get("NoDisplay", "false").lower() == "true":
                    continue
                name = de.get("Name", "").strip()
                exec_ = re.sub(r"\s*%[a-zA-Z]", "", de.get("Exec", "")).strip()
                if not name or not exec_:
                    continue
                cls = de.get("StartupWMClass", "").strip() or fname[:-8]
                apps.append({"name": name, "exec": exec_, "icon": de.get("Icon", ""), "class": cls})
            except Exception:
                continue
    apps.sort(key=lambda a: a["name"].lower())
    return apps


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "load"
    if cmd == "save":
        print(json.dumps(write(json.loads(sys.argv[2])), ensure_ascii=False))
    elif cmd == "apps":
        print(json.dumps(list_apps(), ensure_ascii=False))
    else:
        print(json.dumps(load(), ensure_ascii=False))


if __name__ == "__main__":
    main()
