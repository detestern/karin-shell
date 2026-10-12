import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../../"

// ─────────────────────────────────────────────────────────────────────────────
// ThemePage (karin-shell) — единая тема: цвета Brain Shell, рамки окон Hyprland,
// скругления/отступы, курсор, иконки, тёмный режим GTK/Qt.
// Данные: ~/.config/karin-shell/theme.json через scripts/theme_store.py
// («Сохранить» = записать + применить + hyprctl reload).
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    readonly property string store: Quickshell.env("HOME") + "/.config/karin-shell/scripts/theme_store.py"

    property var  cfg:   ({})
    property bool dirty: false
    property string toast: ""
    property var  cursors: []
    property var  icons:   []

    readonly property var swatches: ["#ff6699", "#f38ba8", "#cba6f7", "#89b4fa", "#94e2d5", "#a6e3a1",
                                     "#f9e2af", "#fab387", "#ffffff", "#cdd6f4", "#313244", "#1a1a24"]

    function set(key, value) {
        const c = Object.assign({}, root.cfg)
        c[key] = value
        root.cfg = c
        root.dirty = true
    }
    function load() { loadProc.running = false; loadProc.running = true }
    function save() {
        saveProc.command = ["python3", root.store, "save", JSON.stringify(root.cfg)]
        saveProc.running = false; saveProc.running = true
    }
    function resetDefaults() { defProc.running = false; defProc.running = true }
    function cycle(list, cur, step) {
        if (!list || list.length === 0) return cur
        let i = list.indexOf(cur)
        if (i < 0) i = 0
        return list[(i + step + list.length) % list.length]
    }

    onVisibleChanged: if (visible && !root.dirty) root.load()
    Component.onCompleted: { root.load(); listProc.running = true }

    Process {
        id: loadProc
        command: ["python3", root.store, "load"]
        stdout: StdioCollector { id: loadOut
            onStreamFinished: { try { root.cfg = JSON.parse(loadOut.text); root.dirty = false } catch (e) {} } }
    }
    Process {
        id: defProc
        command: ["python3", root.store, "defaults"]
        stdout: StdioCollector { id: defOut
            onStreamFinished: { try { root.cfg = JSON.parse(defOut.text); root.dirty = true } catch (e) {} } }
    }
    Process {
        id: listProc
        command: ["python3", root.store, "list"]
        stdout: StdioCollector { id: listOut
            onStreamFinished: { try { const l = JSON.parse(listOut.text); root.cursors = l.cursors; root.icons = l.icons } catch (e) {} } }
    }
    Process {
        id: saveProc
        stdout: StdioCollector { id: saveOut
            onStreamFinished: {
                try {
                    root.cfg = JSON.parse(saveOut.text)
                    root.dirty = false
                    root.toast = "Тема применена"
                    reloadProc.running = false; reloadProc.running = true
                } catch (e) { root.toast = "Ошибка сохранения темы" }
            }
        }
    }
    Process { id: reloadProc; command: ["hyprctl", "reload"] }
    Timer { interval: 3000; running: root.toast !== ""; onTriggered: root.toast = "" }

    // ── Шапка ────────────────────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14; topMargin: 6 }
        height: 34
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.toast !== "" ? root.toast : "Единая тема: Brain Shell, рамки окон, GTK/Qt, курсор"
            color: root.toast !== "" ? Theme.active : Qt.rgba(1, 1, 1, 0.45)
            font.family: "JetBrains Mono"; font.pixelSize: 11
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8
            SmallBtn { text: "По умолчанию"; onClicked: root.resetDefaults() }
            SmallBtn { visible: root.dirty; text: "Отмена"; onClicked: root.load() }
            SmallBtn { visible: root.dirty; text: "Сохранить"; accent: true; onClicked: root.save() }
        }
    }

    // ── Настройки ────────────────────────────────────────────────────────────
    Flickable {
        id: list
        anchors { top: header.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { implicitWidth: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.22) }
            background: Item {}
        }

        Column {
            id: col
            width: list.width - 8
            spacing: 6

            Section { page: root; title: "Цвета" }
            ColorRow { page: root; label: "Акцент оболочки";        key: "accent" }
            ColorRow { page: root; label: "Рамка активного окна";   key: "border_active" }
            ColorRow { page: root; label: "Рамка неактивного окна"; key: "border_inactive" }
            ColorRow { page: root; label: "Фон панелей";            key: "background" }
            ColorRow { page: root; label: "Текст";                  key: "text" }
            ColorRow { page: root; label: "Второстепенный текст";   key: "subtext" }

            Section { page: root; title: "Окна и панели" }
            NumRow { page: root; label: "Толщина рамки";     key: "border_size"; minV: 0; maxV: 10 }
            NumRow { page: root; label: "Скругление углов";  key: "rounding";    minV: 0; maxV: 30 }
            NumRow { page: root; label: "Отступ между окнами"; key: "gaps_in";   minV: 0; maxV: 40 }
            NumRow { page: root; label: "Отступ от краёв";   key: "gaps_out";    minV: 0; maxV: 60 }
            NumRow { page: root; label: "Непрозрачность панели"; key: "bar_opacity"; minV: 0.3; maxV: 1; stepV: 0.05; percent: true }

            Section { page: root; title: "Система" }
            PickRow { page: root; label: "Курсор"; key: "cursor_theme"; options: root.cursors }
            NumRow  { label: "Размер курсора"; key: "cursor_size"; minV: 16; maxV: 64; stepV: 4 }
            PickRow { page: root; label: "Иконки"; key: "icon_theme"; options: root.icons }
            Row {
                spacing: 10
                height: 36
                Text { width: 190; anchors.verticalCenter: parent.verticalCenter; text: "Тёмная тема программ (GTK/Qt)"
                       color: Qt.rgba(1, 1, 1, 0.75); font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 22; radius: 11
                    color: root.cfg.dark ? Theme.active : Qt.rgba(1, 1, 1, 0.12)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        width: 16; height: 16; radius: 8; y: 3
                        x: root.cfg.dark ? 21 : 3
                        color: "#ffffff"
                        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
                    TapHandler { onTapped: root.set("dark", !root.cfg.dark) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
            Item { width: 1; height: 8 }
        }
    }

    // ── Компоненты строк ─────────────────────────────────────────────────────
    component Section: Item {
        property var page
        property string title: ""
        width: parent ? parent.width : 400; height: 28
        Text {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            text: parent.title
            font.pixelSize: 10; font.weight: Font.Bold; font.family: "JetBrains Mono"
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
        }
    }

    component ColorRow: Row {
        property var page
        id: cr
        property string label: ""
        property string key: ""
        readonly property string value: page && page.cfg[key] ? page.cfg[key] : "#000000"
        onValueChanged: hexIn.text = value
        spacing: 10
        height: 32
        Text { width: 190; anchors.verticalCenter: parent.verticalCenter; text: cr.label
               color: Qt.rgba(1, 1, 1, 0.75); font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26; height: 26; radius: 7
            color: cr.value
            border.color: Qt.rgba(1, 1, 1, 0.25)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 88; height: 26; radius: 7
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: hexIn.activeFocus ? Theme.active : "transparent"
            TextInput {
                id: hexIn
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                text: cr.value
                color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 11
                selectionColor: Theme.active
                maximumLength: 7
                onEditingFinished: if (/^#?[0-9a-fA-F]{6}$/.test(text)) page.set(cr.key, (text[0] === "#" ? "" : "#") + text.toLowerCase())
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: page.swatches
                delegate: Rectangle {
                    id: sw
                    required property string modelData
                    width: 16; height: 16; radius: 5
                    color: modelData
                    border.color: cr.value === modelData ? "#ffffff" : Qt.rgba(1, 1, 1, 0.12)
                    border.width: cr.value === modelData ? 2 : 1
                    TapHandler { onTapped: cr.page.set(cr.key, sw.modelData) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    component NumRow: Row {
        property var page
        id: nr
        property string label: ""
        property string key: ""
        property real minV: 0
        property real maxV: 10
        property real stepV: 1
        property bool percent: false
        readonly property real value: page && page.cfg[key] !== undefined ? page.cfg[key] : 0
        function setV(v) { page.set(nr.key, Math.round(Math.max(nr.minV, Math.min(nr.maxV, v)) * 100) / 100) }
        spacing: 10
        height: 32
        Text { width: 190; anchors.verticalCenter: parent.verticalCenter; text: nr.label
               color: Qt.rgba(1, 1, 1, 0.75); font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 110; height: 28; radius: 8
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            RoundBtn { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                       text: "−"; enabled: nr.value > nr.minV; onClicked: nr.setV(nr.value - nr.stepV) }
            Text {
                anchors.centerIn: parent
                text: nr.percent ? Math.round(nr.value * 100) + "%" : nr.value
                color: Theme.active; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold
            }
            RoundBtn { anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                       text: "+"; enabled: nr.value < nr.maxV; onClicked: nr.setV(nr.value + nr.stepV) }
        }
    }

    component PickRow: Row {
        property var page
        id: pr
        property string label: ""
        property string key: ""
        property var options: []
        readonly property string value: page && page.cfg[key] ? page.cfg[key] : ""
        spacing: 10
        height: 32
        Text { width: 190; anchors.verticalCenter: parent.verticalCenter; text: pr.label
               color: Qt.rgba(1, 1, 1, 0.75); font.family: "JetBrains Mono"; font.pixelSize: 12; elide: Text.ElideRight }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 230; height: 28; radius: 8
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            RoundBtn { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
                       text: "‹"; enabled: pr.options.length > 1; onClicked: page.set(pr.key, page.cycle(pr.options, pr.value, -1)) }
            Text {
                anchors { left: parent.left; right: parent.right; leftMargin: 30; rightMargin: 30; verticalCenter: parent.verticalCenter }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: pr.value
                color: Theme.text; font.family: "JetBrains Mono"; font.pixelSize: 11
            }
            RoundBtn { anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                       text: "›"; enabled: pr.options.length > 1; onClicked: page.set(pr.key, page.cycle(pr.options, pr.value, 1)) }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: pr.options.length > 0 && pr.options.indexOf(pr.value) < 0
            text: "не установлена"
            color: "#ff7a8a"; font.pixelSize: 10; font.family: "JetBrains Mono"
        }
    }

    component RoundBtn: Rectangle {
        id: rb
        property string text: ""
        signal clicked()
        width: 24; height: 24; radius: 7
        opacity: enabled ? 1 : 0.3
        color: rbH.hovered && enabled ? Qt.rgba(1, 0.4, 0.6, 0.22) : Qt.rgba(1, 1, 1, 0.06)
        Text { anchors.centerIn: parent; text: rb.text; font.pixelSize: 15; font.weight: Font.Bold
               color: rbH.hovered && rb.enabled ? Theme.active : Theme.text }
        HoverHandler { id: rbH; cursorShape: rb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (rb.enabled) rb.clicked() }
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
               color: sb.accent ? Theme.active : Qt.rgba(1, 1, 1, 0.6) }
        HoverHandler { id: sbH; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: sb.clicked() }
    }
}
