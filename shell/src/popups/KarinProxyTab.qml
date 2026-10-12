import QtQuick
import Quickshell.Io
import "../"
import "../components"

// ── KarinProxy (Rust/Tauri) Integration ──────────────────────────────────────

Item {
    id: root

    property bool _isRunning: false
    property bool _isBusy:    false
    property string _currentIp: "Fetching..."

    // ── Status Poller ─────────────────────────────────────────────────────────
    Process {
        id: statusProc
        running: false
        command: ["bash", "-c", "systemctl is-active karin-proxy-daemon.service"]
        stdout: SplitParser {
            onRead: function(data) {
                var status = data.trim()
                if (status === "active") {
                    root._isRunning = true
                    ShellState.vpnActive = true
                    ShellState.vpnName = "KarinProxy"
                } else {
                    root._isRunning = false
                    ShellState.vpnActive = false
                    ShellState.vpnName = ""
                }
                root._isBusy = false
            }
        }
    }

    // ── IP Fetcher ────────────────────────────────────────────────────────────
    Process {
        id: ipProc
        running: false
        command: ["curl", "-s", "-m", "3", "ifconfig.me"]
        stdout: SplitParser {
            onRead: function(data) {
                var ip = data.trim()
                if (ip) root._currentIp = ip
            }
        }
        onExited: function(code) {
            // Если curl упал (нет интернета), показываем ошибку
            if (code !== 0) root._currentIp = "Offline"
        }
    }

    // ── Open GUI Process ──────────────────────────────────────────────────────
    Process {
        id: launchProc
        running: false
        command: []
    }

    function _openKarinGui() {
        if (root._isBusy) return
        root._isBusy = true
        
        launchProc.command = ShellState.configProvider === "lua"
            ? ["hyprctl", "eval", "hl.exec_cmd(\"karincore\")"]
            : ["hyprctl", "dispatch", "exec", "--", "karincore"]
        launchProc.running = false
        launchProc.running = true
        
        Popups.dashboardOpen = false
        root._isBusy = false
    }

    // ── Polling logic ─────────────────────────────────────────────────────────
    function _refresh() {
        if (!statusProc.running) statusProc.running = true
        
        // Перезапускаем проверку IP
        root._currentIp = "Fetching..."
        ipProc.running = false
        ipProc.running = true
    }

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen && root.visible) root._refresh()
        }
    }

    Timer {
        interval: 2000; repeat: true; running: Popups.networkOpen
        onTriggered: {
            if (!statusProc.running) statusProc.running = true
            // IP обновляем реже, чтобы не спамить ifconfig.me каждые 2 секунды
        }
    }

    Component.onCompleted: root._refresh()

    // ── Layout ────────────────────────────────────────────────────────────────
    Column {
        anchors.fill: parent; spacing: 0

        // Header
        Item {
            width: parent.width; height: 40
            Text {
                anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                text: "PROXY"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text
            }
            
            // Refresh Button
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 32; height: 32; radius: 8
                color: rfH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15) : Qt.rgba(1,1,1,0.05)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: rfIcon; anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 15
                    color: Theme.active
                    RotationAnimator {
                        target: rfIcon; from: 0; to: 360; duration: 900
                        loops: Animation.Infinite; running: statusProc.running || ipProc.running
                        easing.type: Easing.Linear
                    }
                }
                HoverHandler { id: rfH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._refresh() }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 12 }

        // ── KarinProxy Main Card ──────────────────────────────────────────────
        Item {
            width: parent.width; height: 68

            Rectangle {
                id: card; anchors.fill: parent; radius: 12
                color: root._isRunning
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                    : vHov.hovered ? Qt.rgba(1,1,1,0.06) : Qt.rgba(1,1,1,0.02)
                border.color: root._isRunning
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40)
                    : Qt.rgba(1,1,1,0.10)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }

            Row {
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 16

                // Proxy Shield Glyph
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰦝"; font.pixelSize: 24
                    color: root._isRunning ? Theme.active : Qt.rgba(1,1,1,0.28)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 4
                    Text {
                        text: "KarinCore"; font.pixelSize: 15
                        font.weight: root._isRunning ? Font.Bold : Font.Medium
                        color: root._isRunning ? Theme.text : Qt.rgba(1,1,1,0.7)
                    }
                    Text {
                        font.pixelSize: 11
                        text: root._isRunning ? "Daemon is active & routing" : "Daemon stopped"
                        color: root._isRunning ? Theme.active : Qt.rgba(1,1,1,0.35)
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // Right: status dot
            Item {
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: 28; height: 28

                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: root._isRunning
                        ? Theme.active
                        : vHov.hovered ? Qt.rgba(1,1,1,0.35) : Qt.rgba(1,1,1,0.18)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            HoverHandler { id: vHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: root._openKarinGui()
            }
        }

        Item { width: parent.width; height: 8 }

        // ── Output IP Display ─────────────────────────────────────────────────
        Rectangle {
            width: parent.width; height: 36; radius: 8
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰩠" // Иконка глобуса/сети
                    font.pixelSize: 14
                    color: root._isRunning ? Theme.active : Qt.rgba(1,1,1,0.3)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._currentIp
                    font.pixelSize: 13
                    font.family: "JetBrains Mono" // Выглядит строго и технично
                    color: Theme.text
                }
            }
        }
    }
}