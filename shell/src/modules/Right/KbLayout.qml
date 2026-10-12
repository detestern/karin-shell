import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

// Индикатор раскладки (karin-shell). Клик — следующая раскладка.
// Слушает событие Hyprland "activelayout", стартовое значение берёт из `hyprctl devices -j`.
Item {
    id: root

    property string layout: ""

    implicitWidth:  pill.width
    implicitHeight: pill.height
    visible: layout !== ""

    function short(name) {
        const n = (name || "").toLowerCase()
        if (n.startsWith("russian"))  return "RU"
        if (n.startsWith("english"))  return "EN"
        if (n.startsWith("hebrew"))   return "HE"
        return (name || "").slice(0, 2).toUpperCase()
    }

    Process {
        id: initial
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            id: initialOut
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(initialOut.text).keyboards || []
                    const kb = kbs.find(k => k.main) || kbs[0]
                    if (kb) root.layout = root.short(kb.active_keymap)
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return
            const data = event.data
            root.layout = root.short(data.substring(data.lastIndexOf(",") + 1))
        }
    }

    Process { id: switcher; command: ["hyprctl", "switchxkblayout", "all", "next"] }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

    Rectangle {
        id: pill
        width:  label.implicitWidth + 12
        height: 20
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        color: hov.hovered ? Qt.rgba(1, 0.4, 0.6, 0.22) : Qt.rgba(1, 1, 1, 0.06)
        border.color: Theme.active
        border.width: hov.hovered ? 1 : 0
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.layout
            color: hov.hovered ? Theme.active : Theme.text
            font.family: "JetBrains Mono"
            font.pixelSize: 11
            font.weight: Font.Bold
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // маленький «щелчок» при смене раскладки
        scale: 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
    }

    onLayoutChanged: { pill.scale = 1.15; bounce.restart() }
    Timer { id: bounce; interval: 120; onTriggered: pill.scale = 1 }

    MouseArea {
        anchors.fill: parent
        onClicked: { switcher.running = false; switcher.running = true }
    }
}
