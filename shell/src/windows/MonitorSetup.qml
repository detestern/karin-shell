import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// ─────────────────────────────────────────────────────────────────────────────
// MonitorSetup — попап при подключении внешнего монитора (karin-shell).
//
// Открывается:  qs ipc -c ~/.local/share/karin-shell/shell call monitor-setup open <ИМЯ>
// (это делает ~/.config/karin-shell/scripts/monitor_setup.sh по событию monitor.added
//  или по Super+Shift+P)
//
// Клавиши:  ← → ↑  — сторона,  M — зеркало,  O — выключить,
//           Tab — масштаб,  R — запомнить,  Enter — применить,  Esc — отмена
// ─────────────────────────────────────────────────────────────────────────────

PanelWindow {
    id: root

    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer:     WlrLayer.Overlay
    WlrLayershell.namespace: "karin-monitor-setup"

    // Тот же приём с фокусом, что и в Dashboard/Clipboard: Exclusive с задержкой
    property bool wantsFocus: false
    WlrLayershell.keyboardFocus: wantsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string internalName: "eDP-1"   // уточняется по hyprctl monitors
    readonly property string kcDir: Quickshell.env("HOME") + "/.config/karin-shell"

    property bool   isOpen:        false
    property bool   windowVisible: false
    visible: windowVisible

    // Данные мониторов
    property string monName: ""
    property string monDesc: ""
    property int    monW:  1920
    property int    monH:  1080
    property real   monHz: 60
    property int    lapW:  1920
    property int    lapH:  1080

    // Выбор пользователя
    property string posSel:   "right"
    property string scaleSel: "auto"
    property string modeSel:  "preferred"
    property bool   remember: true

    readonly property var positions: [
        { id: "left",   icon: "󰁍", label: "Слева"   },
        { id: "up",     icon: "󰁝", label: "Сверху"  },
        { id: "right",  icon: "󰁔", label: "Справа"  },
        { id: "mirror", icon: "󰍺", label: "Зеркало" },
        { id: "off",    icon: "󰶐", label: "Выкл."   }
    ]
    readonly property var scales: ["auto", "1", "1.25", "1.5", "1.6", "2"]
    readonly property var modes: [
        { id: "preferred", label: "Родной"         },
        { id: "highres",   label: "Макс. разреш."  },
        { id: "highrr",    label: "Макс. частота"  }
    ]

    // ── IPC ──────────────────────────────────────────────────────────────────
    IpcHandler {
        target: "monitor-setup"
        function open(name: string): void { root.show(name) }
        function close(): void { root.hide() }
    }

    function show(name) {
        root.monName = name
        query.running = false
        query.running = true
    }

    function hide() {
        root.isOpen = false
        root.wantsFocus = false
        closeTimer.restart()
    }

    function apply() {
        let lua
        const m = root.modeSel, s = root.scaleSel, n = root.monName
        if (root.posSel === "off")
            lua = `hl.monitor({ output = "${n}", disabled = true })`
        else if (root.posSel === "mirror")
            lua = `hl.monitor({ output = "${n}", mode = "${m}", position = "auto", scale = "${s}", mirror = "${root.internalName}" })`
        else
            lua = `hl.monitor({ output = "${n}", mode = "${m}", position = "auto-${root.posSel}", scale = "${s}" })`

        applyProc.command = ["hyprctl", "eval", lua]
        applyProc.running = true

        if (root.remember && root.monDesc !== "") {
            const entry = { description: root.monDesc, mode: m, scale: s }
            if (root.posSel === "off")         entry.disabled = true
            else if (root.posSel === "mirror") { entry.position = "auto"; entry.mirror = root.internalName }
            else                                 entry.position = "auto-" + root.posSel
            storeProc.command = ["python3", root.kcDir + "/scripts/monitor_store.py", "save", JSON.stringify(entry)]
            storeProc.running = true
        }
        root.hide()
    }

    function cycle(list, cur, step) {
        const i = list.indexOf(cur)
        return list[(i + step + list.length) % list.length]
    }

    // ── Процессы ─────────────────────────────────────────────────────────────
    Process {
        id: query
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            id: queryOut
            onStreamFinished: {
                let mons = []
                try { mons = JSON.parse(queryOut.text) } catch (e) { return }
                const main = mons.find(m => m.name.startsWith("eDP")) || mons[0]
                if (main) root.internalName = main.name
                const lap = mons.find(m => m.name === root.internalName)
                let ext = mons.find(m => m.name === root.monName)
                if (!ext) ext = mons.find(m => m.name !== root.internalName)
                if (!ext) return
                if (lap) { root.lapW = lap.width / (lap.scale || 1); root.lapH = lap.height / (lap.scale || 1) }
                root.monName = ext.name
                root.monDesc = ext.description || ""
                root.monW    = ext.width  > 0 ? ext.width  : 1920
                root.monH    = ext.height > 0 ? ext.height : 1080
                root.monHz   = ext.refreshRate || 60
                root.posSel = ext.disabled ? "off" : "right"
                root.scaleSel    = (ext.width === 2560 && ext.height === 1600) ? "1.6" : "auto"   // как было в старом monitor_hotplug.sh
                root.modeSel     = "preferred"
                closeTimer.stop()
                root.windowVisible = true
                root.isOpen = true
                focusTimer.restart()
            }
        }
    }
    Process { id: applyProc }
    Process { id: storeProc }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.isOpen) { root.wantsFocus = true; keyCatcher.forceActiveFocus() }
    }
    Timer { id: closeTimer; interval: 260; onTriggered: if (!root.isOpen) root.windowVisible = false }

    // ── Клавиатура ───────────────────────────────────────────────────────────
    // Невидимый TextInput ловит клавиши (тот же «троянский конь», что в PowerMenu —
    // обычный Item на layer-shell фокус получает ненадёжно)
    TextInput {
        id: keyCatcher
        width: 0; height: 0
        clip: true
        color: "transparent"
        selectionColor: "transparent"
        z: -1
        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_Left:    root.posSel = "left";   break
                case Qt.Key_Right:   root.posSel = "right";  break
                case Qt.Key_Up:      root.posSel = "up";     break
                case Qt.Key_M:       root.posSel = "mirror"; break
                case Qt.Key_O:       root.posSel = "off";    break
                case Qt.Key_Tab:     root.scaleSel = root.cycle(root.scales, root.scaleSel, 1);  break
                case Qt.Key_Backtab: root.scaleSel = root.cycle(root.scales, root.scaleSel, -1); break
                case Qt.Key_R:       root.remember = !root.remember; break
                case Qt.Key_Return:
                case Qt.Key_Enter:   root.apply(); break
                case Qt.Key_Escape:  root.hide();  break
                default: return
            }
            event.accepted = true
        }
    }

    // ── Затемнение ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.isOpen ? 0.55 : 0)
        Behavior on color { ColorAnimation { duration: 220 } }
        MouseArea { anchors.fill: parent; onClicked: root.hide() }
    }

    // ── Карточка ─────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  520
        height: body.implicitHeight + 52
        radius: Theme.notchRadius
        color:  Theme.background
        border.color: Qt.rgba(1, 0.4, 0.6, 0.35)
        border.width: 1

        opacity: root.isOpen ? 1 : 0
        scale:   root.isOpen ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 26 }
            spacing: 18

            // Заголовок
            Row {
                spacing: 12
                Text {
                    text: "󰍹"; font.pixelSize: 26; color: Theme.active
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    Text {
                        text: "Подключён монитор"
                        color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 16; font.weight: Font.Bold
                    }
                    Text {
                        text: root.monName + "  ·  " + root.monW + "×" + root.monH + " @ " + Math.round(root.monHz) + " Гц"
                        color: Theme.subtext; font.family: "JetBrains Mono"; font.pixelSize: 11
                    }
                    Text {
                        visible: root.monDesc !== ""
                        width: 400; elide: Text.ElideRight
                        text: root.monDesc
                        color: Qt.rgba(1, 1, 1, 0.35); font.family: "JetBrains Mono"; font.pixelSize: 10
                    }
                }
            }

            // Схема расположения
            Rectangle {
                id: stage
                width: parent.width
                height: 190
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.06)

                // логические размеры внешнего экрана с учётом масштаба
                readonly property real extScale: root.scaleSel === "auto" ? Math.max(1, root.monW / 1920) : parseFloat(root.scaleSel)
                readonly property real extW: root.posSel === "mirror" ? root.lapW : root.monW / extScale
                readonly property real extH: root.posSel === "mirror" ? root.lapH : root.monH / extScale

                // раскладка в «мировых» координатах: ноутбук в (0,0)
                readonly property real ex: root.posSel === "left"  ? -extW
                                         : root.posSel === "right" ? root.lapW
                                         : root.posSel === "up"    ? (root.lapW - extW) / 2
                                         : root.posSel === "mirror"? 0
                                         : root.lapW + root.lapW * 0.15
                readonly property real ey: root.posSel === "up" ? -extH : 0
                readonly property real minX: Math.min(0, ex)
                readonly property real minY: Math.min(0, ey)
                readonly property real bw: Math.max(root.lapW, ex + extW) - minX
                readonly property real bh: Math.max(root.lapH, ey + extH) - minY
                readonly property real k: Math.min((width - 60) / bw, (height - 40) / bh)
                readonly property real offX: (width  - bw * k) / 2 - minX * k
                readonly property real offY: (height - bh * k) / 2 - minY * k

                // Внешний монитор
                Rectangle {
                    id: extRect
                    x: stage.offX + stage.ex * stage.k + (root.posSel === "mirror" ? 10 : 0)
                    y: stage.offY + stage.ey * stage.k + (root.posSel === "mirror" ? -10 : 0)
                    width:  stage.extW * stage.k
                    height: stage.extH * stage.k
                    radius: 8
                    color: root.posSel === "off" ? "transparent" : Qt.rgba(1, 0.4, 0.6, 0.18)
                    border.color: root.posSel === "off" ? Qt.rgba(1, 1, 1, 0.2) : Theme.active
                    border.width: 2
                    opacity: root.posSel === "off" ? 0.5 : 1
                    z: root.posSel === "mirror" ? 0 : 1
                    Behavior on x      { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on y      { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.posSel === "off" ? "󰶐" : "󰍹"
                            font.pixelSize: 20; color: root.posSel === "off" ? Qt.rgba(1,1,1,0.4) : Theme.active
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.monName
                            font.family: "JetBrains Mono"; font.pixelSize: 10; color: Theme.text
                        }
                    }
                }

                // Ноутбук
                Rectangle {
                    x: stage.offX
                    y: stage.offY
                    width:  root.lapW * stage.k
                    height: root.lapH * stage.k
                    radius: 8
                    z: root.posSel === "mirror" ? 1 : 0
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.color: Qt.rgba(1, 1, 1, 0.45)
                    border.width: 2
                    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰌢"; font.pixelSize: 20; color: Theme.text
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.internalName
                            font.family: "JetBrains Mono"; font.pixelSize: 10; color: Theme.subtext
                        }
                    }
                }
            }

            // Сторона
            Row {
                spacing: 8
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: root.positions
                    delegate: Chip {
                        required property var modelData
                        width: 84
                        icon: modelData.icon
                        label: modelData.label
                        selected: root.posSel === modelData.id
                        onClicked: root.posSel = modelData.id
                    }
                }
            }

            // Масштаб
            Column {
                spacing: 6
                visible: root.posSel !== "off"
                Text { text: "Масштаб"; color: Theme.subtext; font.family: "JetBrains Mono"; font.pixelSize: 11 }
                Row {
                    spacing: 6
                    Repeater {
                        model: root.scales
                        delegate: Chip {
                            required property string modelData
                            width: 70
                            label: modelData === "auto" ? "авто" : modelData + "×"
                            selected: root.scaleSel === modelData
                            onClicked: root.scaleSel = modelData
                        }
                    }
                }
            }

            // Режим
            Column {
                spacing: 6
                visible: root.posSel !== "off"
                Text { text: "Режим"; color: Theme.subtext; font.family: "JetBrains Mono"; font.pixelSize: 11 }
                Row {
                    spacing: 6
                    Repeater {
                        model: root.modes
                        delegate: Chip {
                            required property var modelData
                            width: 150
                            label: modelData.label
                            selected: root.modeSel === modelData.id
                            onClicked: root.modeSel = modelData.id
                        }
                    }
                }
            }

            // Запомнить + кнопки
            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Rectangle {
                        width: 18; height: 18; radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.remember ? Theme.active : "transparent"
                        border.color: Theme.active; border.width: 2
                        Text {
                            anchors.centerIn: parent; text: "󰄬"; visible: root.remember
                            font.pixelSize: 12; color: Theme.background
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Запомнить для этого монитора"
                        color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
                    }
                }
                MouseArea {
                    width: 290; height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.remember = !root.remember
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Chip { width: 86; label: "Отмена"; onClicked: root.hide() }
                    Chip { width: 110; label: "Применить"; accent: true; onClicked: root.apply() }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "← ↑ →  сторона   M зеркало   O выкл   Tab масштаб   R запомнить   Enter ok"
                color: Qt.rgba(1, 1, 1, 0.3); font.family: "JetBrains Mono"; font.pixelSize: 10
            }
        }
    }

    // ── Кнопка-чип ───────────────────────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property bool selected: false
        property bool accent: false
        signal clicked()

        height: icon !== "" ? 56 : 34
        radius: 10
        color: accent ? Theme.active
             : selected ? Qt.rgba(1, 0.4, 0.6, 0.22)
             : hov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
        border.color: selected ? Theme.active : "transparent"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                visible: chip.icon !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.icon; font.pixelSize: 18
                color: chip.selected ? Theme.active : Theme.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: chip.label
                font.family: "JetBrains Mono"; font.pixelSize: 11
                font.weight: chip.accent ? Font.Bold : Font.Normal
                color: chip.accent ? Theme.background : (chip.selected ? Theme.active : Theme.text)
            }
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.clicked() }
    }
}
