# KarinCore ↔ karin-shell bridge (v1)

The **KarinCore** tab in the karin-shell dashboard talks to KarinCore through two things:
a status file that KarinCore writes, and a few command-line flags it accepts.
Nothing secret (links, keys, UUIDs, passwords) ever leaves KarinCore.

## 1. Status file

Path: `${XDG_STATE_HOME:-$HOME/.local/state}/karincore/shell.json`

KarinCore rewrites it atomically (write `shell.json.tmp`, then rename) whenever any of these change:
app start, app exit, connection state, selected profile, profile list, public IP.

```json
{
  "bridge": 1,
  "app_version": "1.4.0",
  "pid": 12345,
  "state": "connected",
  "selected": "a1b2c3d4e5f6",
  "profile_name": "Netherlands · Reality",
  "ip": "203.0.113.7",
  "profiles": [
    { "id": "a1b2c3d4e5f6", "name": "Netherlands · Reality", "type": "vless",     "group": "My VPN" },
    { "id": "0f9e8d7c6b5a", "name": "Home WireGuard",        "type": "wireguard", "group": "" }
  ],
  "updated": 1791800000
}
```

| Field | Meaning |
|---|---|
| `bridge` | protocol version, `1` |
| `pid` | PID of the running KarinCore GUI process; `0` after exit |
| `state` | `disconnected` \| `connecting` \| `connected` |
| `selected` | id of the selected profile (or `""`) |
| `profile_name` | display name of the selected profile |
| `ip` | public IP while connected, else `""` |
| `profiles[]` | all profiles: `id`, display `name`, `type` (`vless`, `vmess`, `trojan`, `shadowsocks`, `wireguard`, `openvpn`), optional `group` |
| `updated` | unix time of the write |

**Profile id** — a stable, non-secret identifier, e.g. the first 12 hex chars of `sha256(link)`.
Never the link itself.

On exit KarinCore writes `"pid": 0, "state": "disconnected", "ip": ""` (the shell also checks that `pid` is alive).

## 2. Command-line flags

| Command | Behaviour |
|---|---|
| `karincore --connect [<id>]` | select `<id>` (if given) and connect. If KarinCore is not running, it starts normally (window opens, as today) and connects. |
| `karincore --disconnect` | disconnect (no-op if not running) |
| `karincore --select <id>` | select a profile without connecting (starts the app if needed) |

A second `karincore …` invocation must be forwarded to the already running instance
(e.g. `tauri-plugin-single-instance`) instead of opening a new window.
Closing the window keeps today's behaviour (VPN stops, status file goes to `pid: 0`).
