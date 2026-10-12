import QtQuick
import Quickshell.Io

// Две «GPU-шкалы» на DashStats.
//  * Обычный режим (как в Brain Shell): Intel iGPU — частота из sysfs,
//    NVIDIA dGPU — nvidia-smi, когда envycontrol не в режиме "integrated".
//  * Режим двух батарей (karin-shell): если в системе есть BAT1 (ноутбуки с
//    внутренней + внешней батареей, например ThinkPad), шкалы показывают
//    заряд BAT0 и BAT1. Определяется автоматически при старте.
//
// Exposes:
//   batteryMode       — true, если шкалы показывают батареи
//   igpu.freqPercent / igpu.curMhz / igpu.maxMhz
//   dgpu.active / dgpu.usagePercent / dgpu.usedVram / dgpu.totalVram

QtObject {
    id: root

    property bool   active:      true
    property string envyMode:    "integrated"
    property bool   batteryMode: false

    property QtObject igpu: QtObject {
        property real   freqPercent: 0.0
        property string curMhz:     "— MHz"
        property string maxMhz:     "— MHz"
    }

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
    }

    // ── Определение режима ────────────────────────────────────────────────────
    property var _detectProc: Process {
        command: ["bash", "-c", "[ -e /sys/class/power_supply/BAT1/capacity ] && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.batteryMode = text.trim() === "yes"
                if (root.batteryMode) {
                    root.igpu.curMhz = "—"; root.igpu.maxMhz = ""
                    root.dgpu.active = true; root.dgpu.usedVram = "—"; root.dgpu.totalVram = ""
                    root._pollBatteries()
                } else {
                    root._actProc.running = true
                    root._maxProc.running = true
                    if (root.envyMode !== "integrated") root._nvProc.running = true
                }
            }
        }
    }

    // ── Режим двух батарей ────────────────────────────────────────────────────
    function _pollBatteries() {
        _bat0Proc.running = false; _bat0Proc.running = true
        _bat1Proc.running = false; _bat1Proc.running = true
    }

    property var _bat0Proc: Process {
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseFloat(text.trim())
                root.igpu.freqPercent = isNaN(v) ? 0 : v
                root.igpu.curMhz      = isNaN(v) ? "Off" : v + "%"
            }
        }
    }

    property var _bat1Proc: Process {
        command: ["cat", "/sys/class/power_supply/BAT1/capacity"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseFloat(text.trim())
                root.dgpu.usagePercent = isNaN(v) ? 0 : v
                root.dgpu.usedVram     = isNaN(v) ? "Off" : v + "%"
            }
        }
    }

    property var _batTimer: Timer {
        interval: 5000
        running:  root.active && root.batteryMode
        repeat:   true
        onTriggered: root._pollBatteries()
    }

    // ── Обычный режим: Intel iGPU ─────────────────────────────────────────────
    property real _actMhz: 0
    property real _maxMhz: 0

    property var _actProc: Process {
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_act_freq_mhz"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var a = parseFloat(text.trim())
                if (!isNaN(a)) {
                    root._actMhz     = a
                    root.igpu.curMhz = a + " MHz"
                    if (root._maxMhz > 0)
                        root.igpu.freqPercent = Math.round((a / root._maxMhz) * 100)
                }
            }
        }
    }

    property var _maxProc: Process {
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_max_freq_mhz"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = parseFloat(text.trim())
                if (!isNaN(m)) {
                    root._maxMhz     = m
                    root.igpu.maxMhz = m + " MHz"
                }
            }
        }
    }

    // ── Обычный режим: NVIDIA dGPU ────────────────────────────────────────────
    property var _nvProc: Process {
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line === "") return
                var parts = line.split(",").map(function(s) { return s.trim() })
                if (parts.length < 3) return
                root.dgpu.active       = true
                root.dgpu.usagePercent = parseFloat(parts[0]) || 0
                root.dgpu.usedVram     = parts[1] + " MB"
                root.dgpu.totalVram    = parts[2] + " MB"
            }
        }
    }

    property var _igpuTimer: Timer {
        interval: 1000
        running:  root.active && !root.batteryMode
        repeat:   true
        onTriggered: {
            _actProc.running = false; _actProc.running = true
            _maxProc.running = false; _maxProc.running = true
        }
    }

    property var _nvTimer: Timer {
        interval: 1000
        running:  root.active && !root.batteryMode && root.envyMode !== "integrated"
        repeat:   true
        onTriggered: { _nvProc.running = false; _nvProc.running = true }
    }

    onEnvyModeChanged: {
        if (!batteryMode && envyMode === "integrated") {
            dgpu.active       = false
            dgpu.usagePercent = 0
            dgpu.usedVram     = "— MB"
            dgpu.totalVram    = "— MB"
        }
    }
}
