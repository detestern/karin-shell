import QtQuick
import Quickshell.Io
import "../"

Item {
    id: root
    width: parent.width
    height: 234

    property int selIndex: 0

    readonly property var actions: [
        { label: "Shutdown",   icon: "⏻",  danger: true,  action: "shutdown" },
        { label: "Reboot     ",icon: "↺",  danger: true,  action: "reboot" },
        { label: "Log Out  ",  icon: "󰍃",  danger: true,  action: "logout" },
        { label: "Lock        ",icon: "󰌾",  danger: false, action: "lock" }
    ]

    onVisibleChanged: {
        if (visible && Popups.archMenuOpen) {
            root.selIndex = 0
            focusTimer.restart()
        }
    }

    Connections {
        target: Popups
        function onArchMenuOpenChanged() {
            if (Popups.archMenuOpen && root.visible) {
                root.selIndex = 0
                focusTimer.restart()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: hiddenInput.forceActiveFocus()
    }

    // ── ИСПРАВЛЕННЫЙ Троянский конь (без opacity: 0) ─────────────
    TextInput {
        id: hiddenInput
        
        // Делаем его невидимым за счет размера и цвета, а не opacity
        width: 0; height: 0
        clip: true
        color: "transparent"
        selectionColor: "transparent"
        
        // Включаем фокус
        activeFocusOnTab: true

        Keys.onUpPressed: {
            if (root.selIndex > 0) root.selIndex--
            event.accepted = true
        }

        Keys.onDownPressed: {
            if (root.selIndex < root.actions.length - 1) root.selIndex++
            event.accepted = true
        }

        Keys.onReturnPressed: {
            root.runDirect(root.actions[root.selIndex].action)
            event.accepted = true
        }

        Keys.onEscapePressed: {
            Popups.archMenuOpen = false
            event.accepted = true
        }
    }

    Process {
        id: runner
        property var pendingCmd: []
        command: pendingCmd
        onRunningChanged: if (!running) pendingCmd = []
    }

    function runDirect(action) {
        switch (action) {
            case "shutdown": runner.pendingCmd = ["systemctl", "poweroff"]; break
            case "reboot":   runner.pendingCmd = ["systemctl", "reboot"];   break
            case "logout":   runner.pendingCmd = ["bash", "-c", "hyprctl dispatch 'hl.dsp.exit()' || hyprctl dispatch exit"]; break
            case "lock":     runner.pendingCmd = ["loginctl", "lock-session"]; break
        }
        runner.running = true
        Popups.archMenuOpen = false
    }

    Column {
        anchors.fill: parent
        spacing: 6

        Repeater {
            model: root.actions

            delegate: Rectangle {
                width:  root.width
                height: 54
                radius: Theme.cornerRadius

                readonly property bool isSel: root.selIndex === index || hov.hovered

                color: isSel
                        ? (modelData.danger ? "#4d2020" : Theme.active)
                        : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text:           modelData.icon
                        font.pixelSize: 20
                        color:          modelData.danger && isSel ? "#ff6b6b" : isSel ? "#000000" : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text:           modelData.label
                        font.pixelSize: 15
                        font.weight:    Font.Medium
                        color:          modelData.danger && isSel ? "#ff6b6b" : isSel ? "#000000" : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selIndex = index
                    onClicked: root.runDirect(modelData.action)
                }
            }
        }
    }
}