#!/usr/bin/env python3
"""Хранилище запомненных мониторов для karin-shell.

  monitor_store.py save '<json>'   json: {"description": "...", "mode": "...", "position": "...",
                                          "scale": "...", "mirror": "...", "disabled": false}
  monitor_store.py forget '<description>'
  monitor_store.py list

Источник правды — monitors.json, из него генерируется monitors.saved.lua (читает modules/monitors.lua).
"""
import json, os, sys

KC = os.path.expanduser("~/.config/karin-shell")
JSON_PATH = os.path.join(KC, "monitors.json")
LUA_PATH = os.path.join(KC, "monitors.saved.lua")
KEYS = ("mode", "position", "scale", "mirror", "disabled")


def load():
    try:
        with open(JSON_PATH) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(data):
    with open(JSON_PATH, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    out = ["-- Сгенерировано scripts/monitor_store.py. Удобнее править через попап (Super+Shift+P).", "return {"]
    for desc, rule in sorted(data.items()):
        fields = []
        for k in KEYS:
            if k not in rule or rule[k] in ("", None):
                continue
            v = rule[k]
            fields.append("%s = %s" % (k, ("true" if v else "false") if isinstance(v, bool) else lua_str(v)))
        out.append("    [%s] = { %s }," % (lua_str(desc), ", ".join(fields)))
    out.append("}")
    with open(LUA_PATH, "w") as f:
        f.write("\n".join(out) + "\n")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    data = load()
    if cmd == "save":
        entry = json.loads(sys.argv[2])
        desc = entry.pop("description", "").strip()
        if not desc:
            sys.exit("у монитора нет описания — запомнить нельзя")
        data[desc] = {k: entry[k] for k in KEYS if k in entry}
        write(data)
    elif cmd == "forget":
        data.pop(sys.argv[2], None)
        write(data)
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
