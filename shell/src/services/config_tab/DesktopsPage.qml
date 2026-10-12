import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"

// ─────────────────────────────────────────────────────────────────────────────
// DesktopsPage (karin-shell) — какие рабочие столы создаются при запуске и какие
// программы на них открываются. Данные: ~/.config/karin-shell/desktops.json
// (через scripts/desktops_store.py, он же генерирует desktops.lua для Hyprland).
// Изменения применяются при следующем входе (karin-shell); число столов — сразу.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    readonly property string store: Quickshell.env("HOME") + "/.config/karin-shell/scripts/desktops_store.py"
    readonly property int maxDesktops: 10

    property var  cfg:     ({ count: 5, focus: 1, desktops: [] })
    property bool dirty:   false
    property bool loaded:  false
    property string toast: ""

    // Пикер программ
    property int    pickerFor: 0          // id стола, 0 — закрыт
    property var    apps:      []
    property string query:     ""
    readonly property var filteredApps: {
        const q = root.query.trim().toLowerCase()
        if (q === "") return root.apps
        return root.apps.filter(a => a.name.toLowerCase().indexOf(q) !== -1
                                  || a.exec.toLowerCase().indexOf(q) !== -1)
    }

    // ── Работа с моделью ─────────────────────────────────────────────────────
    function clone(o) { return JSON.parse(JSON.stringify(o)) }

    function appsOf(id) {
        const d = root.cfg.desktops.find(x => x.id === id)
        return d ? d.apps : []
    }

    function mutate(fn) {
        const c = root.clone(root.cfg)
        fn(c)
        // поддерживаем список столов 1..count
        const list = []
        for (let i = 1; i <= c.count; i++) {
            const d = c.desktops.find(x => x.id === i)
            list.push(d ? d : { id: i, apps: [] })
        }
        c.desktops = list
        if (c.focus > c.count) c.focus = c.count
        root.cfg = c
        root.dirty = true
    }

    function setCount(n) { root.mutate(c => c.count = Math.max(1, Math.min(root.maxDesktops, n))) }
    function setFocus(n) { root.mutate(c => c.focus = Math.max(1, Math.min(c.count, n))) }

    function addApp(id, app) {
        root.mutate(c => {
            let d = c.desktops.find(x => x.id === id)
            if (!d) { d = { id: id, apps: [] }; c.desktops.push(d) }
            d.apps.push({ name: app.name, exec: app.exec, icon: app.icon || "",
                          class: app.class || app.exec.split(" ")[0].split("/").pop(), pin: false })
        })
    }
    function removeApp(id, idx) { root.mutate(c => c.desktops.find(x => x.id === id).apps.splice(idx, 1)) }
    function togglePin(id, idx) {
        root.mutate(c => {
            const a = c.desktops.find(x => x.id === id).apps[idx]
            a.pin = !a.pin
        })
    }
    function moveApp(id, idx, dir) {
        const to = id + dir
        if (to < 1 || to > root.cfg.count) return
        root.mutate(c => {
            const a = c.desktops.find(x => x.id === id).apps.splice(idx, 1)[0]
            let d = c.desktops.find(x => x.id === to)
            if (!d) { d = { id: to, apps: [] }; c.desktops.push(d) }
            d.apps.push(a)
        })
    }

    function load() {
        loadProc.running = false
        loadProc.running = true
    }
    function save() {
        saveProc.command = ["python3", root.store, "save", JSON.stringify(root.cfg)]
        saveProc.running = false
        saveProc.running = true
    }
    function openPicker(id) {
        root.query = ""
        customInput.text = ""
        root.pickerFor = id
        if (root.apps.length === 0) { appsProc.running = false; appsProc.running = true }
        focusSearch.restart()
    }

    onVisibleChanged: if (visible && !root.dirty) root.load()
    Component.onCompleted: root.load()

    // ── Процессы ─────────────────────────────────────────────────────────────
    Process {
        id: loadProc
        command: ["python3", root.store, "load"]
        stdout: StdioCollector {
            id: loadOut
            onStreamFinished: {
                try { root.cfg = JSON.parse(loadOut.text); root.dirty = false; root.loaded = true }
                catch (e) { root.toast = "Не удалось прочитать desktops.json" }
            }
        }
    }
    Process {
        id: saveProc
        stdout: StdioCollector {
            id: saveOut
            onStreamFinished: {
                try {
                    root.cfg = JSON.parse(saveOut.text)
                    root.dirty = false
                    root.toast = "Сохранено. Программы откроются так при следующем входе"
                    reloadProc.running = false
                    reloadProc.running = true
                } catch (e) { root.toast = "Ошибка сохранения" }
            }
        }
    }
    Process { id: reloadProc; command: ["hyprctl", "reload"] }
    Process {
        id: appsProc
        command: ["python3", root.store, "apps"]
        stdout: StdioCollector {
            id: appsOut
            onStreamFinished: { try { root.apps = JSON.parse(appsOut.text) } catch (e) { root.apps = [] } }
        }
    }
    Timer { id: focusSearch; interval: 60; onTriggered: searchInput.forceActiveFocus() }
    Timer { interval: 3500; running: root.toast !== ""; onTriggered: root.toast = "" }

    // ── Верхняя панель ───────────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; topMargin: 6 }
        height: 34

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Столов при запуске"
                color: Qt.rgba(1, 1, 1, 0.6); font.family: "JetBrains Mono"; font.pixelSize: 12
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 96; height: 28; radius: 8
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                RoundBtn { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                           text: "−"; enabled: root.cfg.count > 1; onClicked: root.setCount(root.cfg.count - 1) }
                Text {
                    anchors.centerIn: parent
                    text: root.cfg.count
                    color: Theme.active; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold
                }
                RoundBtn { anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                           text: "+"; enabled: root.cfg.count < root.maxDesktops; onClicked: root.setCount(root.cfg.count + 1) }
            }
        }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.toast !== ""
                text: root.toast
                color: Theme.active; font.pixelSize: 10; font.family: "JetBrains Mono"
            }
            SmallBtn { visible: root.dirty; text: "Отмена"; onClicked: root.load() }
            SmallBtn { visible: root.dirty; text: "Сохранить"; accent: true; onClicked: root.save() }
        }
    }

    // ── Список столов ────────────────────────────────────────────────────────
    Flickable {
        id: list
        anchors { top: header.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: footer.top
                  leftMargin: 14; rightMargin: 14; bottomMargin: 6 }
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: list.width
            spacing: 6

            Repeater {
                model: root.cfg.count
                delegate: Rectangle {
                    id: card
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var wsApps: root.appsOf(wsId)
                    readonly property bool isStart: root.cfg.focus === wsId
                    width: col.width
                    height: Math.max(48, flow.implicitHeight + 16)
                    radius: 10
                    color: cardH.hovered ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.035)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: cardH }

                    // номер стола; клик — сделать стартовым
                    Rectangle {
                        id: badge
                        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        width: 32; height: 32; radius: 8
                        color: card.isStart ? Theme.active : (badgeH.hovered ? Qt.rgba(1, 0.4, 0.6, 0.2) : Qt.rgba(1, 1, 1, 0.07))
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: card.wsId
                            font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold
                            color: card.isStart ? Theme.background : Theme.text
                        }
                        HoverHandler { id: badgeH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.setFocus(card.wsId) }
                    }

                    Flow {
                        id: flow
                        anchors { left: badge.right; leftMargin: 10; right: addBtn.left; rightMargin: 8
                                  verticalCenter: parent.verticalCenter }
                        spacing: 6

                        Repeater {
                            model: card.wsApps
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                required property int index
                                readonly property bool hot: chipH.hovered
                                height: 30
                                width: chipRow.width + 22
                                radius: 8
                                color: hot ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06)
                                Behavior on color { ColorAnimation { duration: 100 } }
                                HoverHandler { id: chipH }

                                // имя и действия занимают одно место: при наведении имя
                                // сменяется кнопками, ширина фишки не меняется
                                Item {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    implicitWidth: Math.max(nameRow.implicitWidth, actions.implicitWidth)
                                    implicitHeight: 20
                                    width: implicitWidth; height: implicitHeight

                                    Row {
                                        id: nameRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        opacity: chip.hot ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: chip.modelData.pin
                                            text: "󰐃"; font.pixelSize: 12; color: Theme.active
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: chip.modelData.name
                                            color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
                                        }
                                    }

                                    Row {
                                        id: actions
                                        anchors.centerIn: parent
                                        spacing: 2
                                        opacity: chip.hot ? 1 : 0
                                        enabled: chip.hot
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        IconBtn2 { text: "󰁍"; visible: card.wsId > 1; onClicked: root.moveApp(card.wsId, chip.index, -1) }
                                        IconBtn2 { text: chip.modelData.pin ? "󰐄" : "󰐃"; active: chip.modelData.pin
                                                   onClicked: root.togglePin(card.wsId, chip.index) }
                                        IconBtn2 { text: "󰅖"; danger: true; onClicked: root.removeApp(card.wsId, chip.index) }
                                        IconBtn2 { text: "󰁔"; visible: card.wsId < root.cfg.count; onClicked: root.moveApp(card.wsId, chip.index, 1) }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: card.wsApps.length === 0
                            height: 30
                            verticalAlignment: Text.AlignVCenter
                            text: "пусто"
                            color: Qt.rgba(1, 1, 1, 0.25); font.family: "JetBrains Mono"; font.pixelSize: 11
                        }
                    }

                    // добавить программу
                    RoundBtn {
                        id: addBtn
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "+"
                        opacity: cardH.hovered ? 1 : 0.45
                        onClicked: root.openPicker(card.wsId)
                    }
                }
            }
        }
    }

    Text {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; bottomMargin: 10 }
        text: "Клик по номеру — стол после запуска  ·  наведи на программу: 󰁍 󰁔 перенести, 󰐃 всегда на этом столе, 󰅖 убрать"
        color: Qt.rgba(1, 1, 1, 0.3); font.family: "JetBrains Mono"; font.pixelSize: 9
        elide: Text.ElideRight
    }

    // ── Пикер программ ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.pickerFor > 0
        color: Qt.rgba(0, 0, 0, 0.55)
        radius: Theme.cornerRadius
        z: 10
        MouseArea { anchors.fill: parent; onClicked: root.pickerFor = 0 }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 420)
            height: parent.height - 40
            radius: 12
            color: Theme.background
            border.color: Qt.rgba(1, 0.4, 0.6, 0.35)
            MouseArea { anchors.fill: parent }

            Column {
                id: pickHead
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                spacing: 10

                Text {
                    text: "Добавить на стол " + root.pickerFor
                    color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold
                }

                Rectangle {
                    width: parent.width; height: 32; radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: searchInput.activeFocus ? Theme.active : "transparent"
                    TextInput {
                        id: searchInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12
                        selectionColor: Theme.active
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: root.pickerFor = 0
                        Keys.onReturnPressed: if (root.filteredApps.length > 0) {
                            root.addApp(root.pickerFor, root.filteredApps[0]); root.pickerFor = 0
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "󰍉  поиск программы…"
                            color: Qt.rgba(1, 1, 1, 0.3); font.family: "JetBrains Mono"; font.pixelSize: 12
                        }
                    }
                }
            }

            ListView {
                id: appList
                anchors { top: pickHead.bottom; topMargin: 8; left: parent.left; right: parent.right
                          bottom: customBox.top; bottomMargin: 8; leftMargin: 8; rightMargin: 8 }
                clip: true
                model: root.filteredApps
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.22) }
                    background: Item {}
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: appList.width - 6
                    height: 40
                    radius: 8
                    color: rowH.hovered ? Qt.rgba(1, 0.4, 0.6, 0.15) : "transparent"
                    Column {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10
                                  verticalCenter: parent.verticalCenter }
                        Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.name
                               color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                        Text { width: parent.width; elide: Text.ElideRight; text: row.modelData.exec
                               color: Qt.rgba(1, 1, 1, 0.35); font.family: "JetBrains Mono"; font.pixelSize: 9 }
                    }
                    HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { root.addApp(root.pickerFor, row.modelData); root.pickerFor = 0 } }
                }
                Text {
                    anchors.centerIn: parent
                    visible: appList.count === 0
                    text: root.apps.length === 0 ? "загружаю программы…" : "ничего не нашлось"
                    color: Qt.rgba(1, 1, 1, 0.3); font.pixelSize: 11
                }
            }

            // своя команда
            Row {
                id: customBox
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                spacing: 8
                Rectangle {
                    width: parent.width - addCustom.width - 8; height: 32; radius: 8
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: customInput.activeFocus ? Theme.active : "transparent"
                    TextInput {
                        id: customInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 11
                        selectionColor: Theme.active
                        clip: true
                        Keys.onEscapePressed: root.pickerFor = 0
                        Keys.onReturnPressed: addCustom.go()
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: customInput.text === ""
                            text: "своя команда, напр. kitty -e btop"
                            color: Qt.rgba(1, 1, 1, 0.3); font.family: "JetBrains Mono"; font.pixelSize: 11
                        }
                    }
                }
                SmallBtn {
                    id: addCustom
                    text: "Добавить"; accent: true
                    function go() {
                        const cmd = customInput.text.trim()
                        if (cmd === "") return
                        root.addApp(root.pickerFor, { name: cmd.split(" ")[0].split("/").pop(), exec: cmd })
                        root.pickerFor = 0
                    }
                    onClicked: go()
                }
            }
        }
    }

    // ── Мелкие компоненты ────────────────────────────────────────────────────
    component RoundBtn: Rectangle {
        id: rb
        property string text: ""
        signal clicked()
        width: 24; height: 24; radius: 7
        opacity: enabled ? 1 : 0.3
        color: rbH.hovered && enabled ? Qt.rgba(1, 0.4, 0.6, 0.22) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 100 } }
        Text { anchors.centerIn: parent; text: rb.text; font.pixelSize: 15; font.weight: Font.Bold
               color: rbH.hovered && rb.enabled ? Theme.active : Theme.text }
        HoverHandler { id: rbH; cursorShape: rb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (rb.enabled) rb.clicked() }
    }

    component IconBtn2: Rectangle {
        id: ib
        property string text: ""
        property bool danger: false
        property bool active: false
        signal clicked()
        width: 20; height: 20; radius: 5
        color: ibH.hovered ? (danger ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(1, 0.4, 0.6, 0.25)) : "transparent"
        Text { anchors.centerIn: parent; text: ib.text; font.pixelSize: 12
               color: ibH.hovered ? (ib.danger ? "#ff7a8a" : Theme.active) : (ib.active ? Theme.active : Qt.rgba(1, 1, 1, 0.6)) }
        HoverHandler { id: ibH; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ib.clicked() }
    }

    component SmallBtn: Rectangle {
        id: sb
        property string text: ""
        property bool accent: false
        signal clicked()
        width: sbT.implicitWidth + 22; height: 26; radius: 7
        color: accent ? (sbH.hovered ? Qt.rgba(1, 0.4, 0.6, 0.32) : Qt.rgba(1, 0.4, 0.6, 0.18))
                      : (sbH.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
        border.color: accent ? Qt.rgba(1, 0.4, 0.6, 0.45) : Qt.rgba(1, 1, 1, 0.13)
        border.width: 1
        Text { id: sbT; anchors.centerIn: parent; text: sb.text; font.pixelSize: 10
               font.weight: sb.accent ? Font.Medium : Font.Normal
               color: sb.accent ? Theme.active : Qt.rgba(1, 1, 1, 0.6) }
        HoverHandler { id: sbH; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sb.clicked() }
    }
}
