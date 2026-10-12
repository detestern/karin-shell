pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../."

// Global shell state.
//
// WiFi / Bluetooth  — owned by QuickSettings (nmcli / bluetoothctl)
// Night Light       — owned by QuickSettings (hyprsunset)
// Caffeine          — owned by QuickSettings (systemd-inhibit)
// Hotspot           — owned by QuickSettings (nmcli hotspot)
// Airplane Mode     — owned by QuickSettings (rfkill)
// Focus Mode        — owned by QuickSettings; TopBar reacts to hide + zero gaps
// DND               — read by NotificationService to suppress incoming notifications
// VPN               — written by VPNTab; read by Network.qml for bar icon

QtObject {
    id: root

    property int topBarLWidth: 0
    property int topBarCWidth: 0
    property int topBarRWidth: 0
    
    
    property bool focusMode:    false
    property bool dnd:          false
    property bool screenRecord: false
    property bool hotspot:      false
    property bool airplane:     false

    // WiFi — false when radio is off OR hotspot is using the interface
    property bool wifiOn:       false

    // VPN — set by VPNTab, read by Network.qml bar indicator
    property bool   vpnActive:     false
    property bool   vpnConnecting: false
    property string vpnName:       ""

    // Bluetooth — written by BluetoothTab immediately on action, read by Network.qml
    // This avoids the 5s poll lag when a device disconnects or adapter toggles.
    property bool btPowered:   false   // adapter is on
    property bool btConnected: false   // at least one device connected

    // ── Hardware Detection ──────────────────────────────────────────
    property bool hasBattery: false
    
    function _checkBattery() {
        if (UPower.displayDevice && UPower.displayDevice.ready) {
            hasBattery = UPower.displayDevice.isLaptopBattery
        }
    }
    
    Component.onCompleted: _checkBattery()
    
    property var _batConn: Connections {
        target: UPower.displayDevice
        function onReadyChanged() {
            _checkBattery()
        }
    }

    // ── Keybind Interception / Hyprland Submap Controller ─────────────────────
    
    property Process submapProcess: Process {}

    property Connections keybindListener: Connections {
        target: KeybindService 
        
        function onIsCapturingChanged() {
            if (KeybindService.isCapturing) {
                // Enter passthrough mode (disables Hyprland binds)
                if (configProvider === "lua") {
                    submapProcess.command = ["hyprctl", "dispatch", "hl.dsp.submap('BrainShell_clean')"]
                } else {
                    submapProcess.command = ["hyprctl", "dispatch", "submap", "BrainShell_clean"]
                }
            } else {
                // Exit passthrough mode (re-enables Hyprland binds)
                if (configProvider === "lua") {
                    submapProcess.command = ["hyprctl", "dispatch", "hl.dsp.submap('reset')"]
                } else {
                    submapProcess.command = ["hyprctl", "dispatch", "submap", "reset"]
                }
            }
            
            submapProcess.running = true
        }
    }
    
    property string configProvider: "lua"

    // karin-shell: вкладка VPN показывает KarinProxy, если установлен KarinCore
    property bool hasKarinCore: false
    property var _karinCoreProc: Process {
        running: true
        command: ["bash", "-c", "command -v karincore >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            id: kcOut
            onStreamFinished: root.hasKarinCore = kcOut.text.trim() === "yes"
        }
    }
    
    // Watch the JSON file written by the installer
    property var _providerFile: FileView {
        id: providerFile
        path: Quickshell.env("HOME") + "/.config/Brain_Shell/src/user_data/config_Provider.json"
        watchChanges: true
        
        onFileChanged: {
            reload()
        }
        
        onLoaded: {
            _parse(providerFile.text())
        }
    }
    
    // karin-shell: реальный режим берём у запущенного Hyprland — `hyprctl eval`
    // отвечает "ok" только с Lua-конфигом. Так шелл работает и под karin-shell (Lua),
    // и под старым `Hyprland` (.conf), без ручного переключения JSON.
    property bool _providerDetected: false
    property var _detectProc: Process {
        running: true
        command: ["hyprctl", "eval", "return true"]
        stdout: StdioCollector {
            id: detectOut
            onStreamFinished: {
                root.configProvider = detectOut.text.trim() === "ok" ? "lua" : "conf"
                root._providerDetected = true
                console.log("Brain Shell: Hyprland config provider = " + root.configProvider)
            }
        }
    }

    function _parse(jsonString) {
        if (root._providerDetected) return;
        if (!jsonString || jsonString === "") return;
        try {
            let data = JSON.parse(jsonString)
            if (data.configProvider) {
                root.configProvider = data.configProvider
            }
        } catch (e) {
            console.error("Brain Shell: Failed to parse config_Provider.json")
        }
    }
}