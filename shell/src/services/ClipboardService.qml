pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

QtObject {
    id: root

    property var  entries: []
    property var  pinned:  []
    property bool loading: false

    readonly property string _pinsPath:
        Quickshell.env("HOME") + "/.config/Brain_Shell/src/user_data/clipboard_pins.json"

    // ── Pins: load ─────────────────────────────────────────────────────────────
    property var _loadPinsProc: Process {
        command: ["bash", "-c",
            "[ -f '" + root._pinsPath + "' ] && cat '" + root._pinsPath + "' || " +
            "(mkdir -p \"$(dirname '" + root._pinsPath + "')\" && echo '[]')"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try   { root.pinned = JSON.parse(text.trim()) }
                catch (e) { root.pinned = [] }
            }
        }
    }

    // ── Pins: save ─────────────────────────────────────────────────────────────
    property var _savePinsProc: Process { command: []; running: false }

    function _savePins() {
        var json = JSON.stringify(root.pinned)
        _savePinsProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._pinsPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root._pinsPath + "'"]
        _savePinsProc.running = false
        _savePinsProc.running = true
    }

    // ── History: list ──────────────────────────────────────────────────────────
    property var _partialEntries: []

    property var _listProc: Process {
        command: ["bash", "-c", "cliphist list 2>/dev/null"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "") return
                var tabIdx = line.indexOf("\t")
                if (tabIdx < 0) return
                var id      = line.substring(0, tabIdx).trim()
                var preview = line.substring(tabIdx + 1).trim()
                if (id === "" || preview === "") return
                var isImage = preview.indexOf("binary data") >= 0 ||
                              preview.startsWith("[[") ||
                              preview.indexOf("image/") >= 0
                root._partialEntries.push({ id: id, preview: preview, isImage: isImage })
            }
        }

        onRunningChanged: {
            if (running) {
                root._partialEntries = []
                root.loading = true
            } else {
                root.entries = root._partialEntries.slice()
                root._partialEntries = []
                root.loading = false
            }
        }
    }

    // ── Prune history to max 100 items ─────────────────────────────────────────
    property var _pruneProc: Process {
        // Берем все элементы начиная с 101-го и удаляем их из базы
        command: ["bash", "-c", "cliphist list 2>/dev/null | tail -n +101 | cut -f 1 | cliphist delete 2>/dev/null || true"]
        running: false
    }

    function load() {
        if (_listProc.running) _listProc.running = false
        _listProc.running = true

        // При каждом обновлении списка отрезаем старые хвосты (>100 элементов)
        if (_pruneProc.running) _pruneProc.running = false
        _pruneProc.running = true
    }

    // ── Copy ───────────────────────────────────────────────────────────────────
    property var _copyProc: Process { command: []; running: false }

    function copyEntry(id) {
        _copyProc.command = ["bash", "-c",
            "cliphist decode '" + id + "' 2>/dev/null | wl-copy"]
        _copyProc.running = false
        _copyProc.running = true
    }

    function copyText(t) {
        _copyProc.command = ["bash", "-c",
            "printf '%s' '" + t.replace(/\\/g, "\\\\").replace(/'/g, "'\\''") + "' | wl-copy"]
        _copyProc.running = false
        _copyProc.running = true
    }

    // ── Type: copy first, then wtype after popup closes ────────────────────────
    property var _wtypeProc: Process { command: []; running: false }

    function typeFromClipboard() {
        _wtypeProc.command = ["bash", "-c", "sleep 0.35 && wl-paste -n | wtype -"]
        _wtypeProc.running = false
        _wtypeProc.running = true
    }

    // ── Delete ─────────────────────────────────────────────────────────────────
    property var _deleteProc: Process {
        command: []
        running: false
        onRunningChanged: if (!running) root.load()
    }

    function deleteEntry(id) {
        if (!id || id === "") return
        _deleteProc.command = ["bash", "-c",
            "cliphist list 2>/dev/null | awk -F'\\t' -v id='" + id +
            "' '$1==id' | cliphist delete 2>/dev/null"]
        _deleteProc.running = false
        _deleteProc.running = true
    }

    // ── Pin ────────────────────────────────────────────────────────────────────
    property var  _pinQueue: []
    property bool _isDecodingPin: false

    property var _decodeProc: Process {
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var decoded = text.trim()
                if (decoded !== "" && root._pinQueue.length > 0) {
                    var currentItem = root._pinQueue[0]
                    var list = root.pinned.filter(function(p) { return p.text !== decoded })
                    list.unshift({
                        text:      decoded,
                        preview:   currentItem.preview,
                        id:        currentItem.id,
                        timestamp: new Date().getTime()
                    })
                    root.pinned = list
                    root._savePins()
                }

                if (root._pinQueue.length > 0) {
                    root._pinQueue.shift()
                }

                root._isDecodingPin = false
                root._processNextPin()
            }
        }
    }

    function pinEntry(id, preview) {
        root._pinQueue.push({ id: id, preview: preview })
        root._processNextPin()
    }

    function _processNextPin() {
        if (root._isDecodingPin || root._pinQueue.length === 0) return

        root._isDecodingPin = true
        var nextItem = root._pinQueue[0]

        _decodeProc.command = ["bash", "-c", "cliphist decode '" + nextItem.id + "' 2>/dev/null"]
        _decodeProc.running = false
        _decodeProc.running = true
    }

    function unpinAt(index) {
        var list = root.pinned.slice()
        list.splice(index, 1)
        root.pinned = list
        root._savePins()
    }

    // ── Wipe unpinned history ──────────────────────────────────────────────────
    property var _wipeProc: Process {
        command: ["bash", "-c", "cliphist wipe 2>/dev/null"]
        running: false
        onRunningChanged: if (!running) root.load()
    }

    function wipeHistory() {
        _wipeProc.running = false
        _wipeProc.running = true
    }

    // ── Убиваем старую службу systemd, которая стирала буфер ───────────────────
    property var _cleanupServiceProc: Process {
        command: ["bash", "-c",
            "systemctl --user disable --now cliphist-wipe.service 2>/dev/null || true; " +
            "rm -f ~/.config/systemd/user/cliphist-wipe.service; " +
            "systemctl --user daemon-reload"]
        running: false
    }

    // ── Init ───────────────────────────────────────────────────────────────────
    Component.onCompleted: {
        _loadPinsProc.running = true
        // Запускаем очистку старой службы один раз при старте
        _cleanupServiceProc.running = true 
        load()
    }

    // Reload when popup opens; poll every 5 s while open
    property var _popupConnection: Connections {
        target: Popups
        function onClipboardOpenChanged() {
            if (Popups.clipboardOpen) root.load()
        }
    }

    property var _pollTimer: Timer {
        interval: 5000
        running:  Popups.clipboardOpen
        repeat:   true
        onTriggered: root.load()
    }
}