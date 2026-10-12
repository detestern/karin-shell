import Quickshell
import QtQuick
import "./src/windows"
import "./src/popups"
import "./src/"

ShellRoot {
    // Force-instantiate lazy singletons that need startup behavior
    property var _keybinds:   KeybindService
    property var _ipc:        IpcManager

    Variants {
        // Оболочка живёт на основном экране: встроенный экран ноутбука (eDP-*),
        // а если его нет (обычный ПК) — первый монитор.
        model: {
            const s = Quickshell.screens
            const main = s.find(x => x.name.startsWith("eDP")) || s[0]
            return main ? [main] : []
        }

        delegate: Component {
            Scope {
                required property var modelData

                // ── Windows ──────────────────────────────────────
                TopBar    { id: topBar;        screen: modelData }

                Border    { 
                    id: leftBorder
                    screen: modelData
                    edge: "left"
                }
                
                Border    { id: rightBorder;   screen: modelData; edge: "right"  }
                Border    { id: bottomBorder;  screen: modelData; edge: "bottom" }

                // ── Overlays ─────────────────────────────────────
                // Dismisses all popups on click-outside or Escape
                PopupDismiss { screen: modelData }

                // GPU mode change confirmation modal
                ConfirmDialog { screen: modelData }

                // karin-shell: настройка внешнего монитора (IPC: monitor-setup)
                MonitorSetup { screen: modelData }

                // ── All popups ───────────────────────────────────
                // Add new popups in src/popups/PopupLayer.qml only
                PopupLayer {
                    topBar:       topBar
                    leftBorder:   leftBorder
                    rightBorder:  rightBorder
                    bottomBorder: bottomBorder
                }
            }
        }
    }
}