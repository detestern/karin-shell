import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ─────────────────────────────────────────────────────────────────────────────
// KarinCorePage — вкладка дашборда «KarinCore» (karin-shell).
//
// Три состояния:
//   • KarinCore не установлен      → карточка с установкой и ссылками
//   • установлен, но без «мостика» → ядро открывает приложение, статус из демона
//   • установлен с мостиком        → ядро = вкл/выкл, выбор профиля, IP
//
// Мостик (KarinCore ≥ версии с shell bridge), см. docs/karincore-bridge.md:
//   статус:  ${XDG_STATE_HOME:-~/.local/state}/karincore/shell.json
//   команды: karincore --connect [<id>] | --disconnect | --select <id>
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    // ── Цвета KarinCore (тёмная тема приложения) ─────────────────────────────
    readonly property color kcAccent:  "#dc8add"
    readonly property color kcSuccess: "#a6e3a1"
    readonly property color kcDim:     "#7f849c"
    readonly property color kcBorder:  "#45475a"
    readonly property color kcPanel:   "#1e1e2e"
    readonly property color kcText:    "#cdd6f4"

    readonly property string statusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
                                         + "/karincore/shell.json"

    // ── Состояние ────────────────────────────────────────────────────────────
    property bool   installed:   false
    property bool   bridge:      false        // есть shell.json с bridge >= 1
    property bool   appRunning:  false        // жив ли процесс из shell.json
    property bool   daemonOn:    false        // запасной статус без мостика
    property string connState:   "disconnected"   // disconnected | connecting | connected
    property string selected:    ""
    property string profileName: ""
    property string ip:          ""
    property var    profiles:    []
    property bool   listOpen:    false
    property real   listY:       0
    property string toast:       ""

    readonly property string phase: !installed ? "idle"
                                  : bridge ? (appRunning ? (connState === "connected" ? "on" : connState === "connecting" ? "connecting" : "idle") : "idle")
                                  : (daemonOn ? "on" : "idle")

    // ── Опрос ────────────────────────────────────────────────────────────────
    Process {
        id: whichProc
        running: true
        command: ["bash", "-c", "command -v karincore >/dev/null && echo yes || echo no"]
        stdout: StdioCollector { id: whichOut; onStreamFinished: root.installed = whichOut.text.trim() === "yes" }
    }

    FileView {
        id: statusFile
        path: root.statusPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(statusFile.text())
        onLoadFailed: root.bridge = false
    }

    function _parse(raw) {
        try {
            const s = JSON.parse(raw)
            root.bridge      = (s.bridge || 0) >= 1
            root.connState   = s.state || "disconnected"
            root.selected    = s.selected || ""
            root.profileName = s.profile_name || ""
            root.ip          = s.ip || ""
            root.profiles    = Array.isArray(s.profiles) ? s.profiles : []
            pidProc.pid      = s.pid || 0
            pidProc.running  = false; pidProc.running = true
        } catch (e) { root.bridge = false }
    }

    Process {
        id: pidProc
        property int pid: 0
        command: ["bash", "-c", pid > 0 ? "[ -d /proc/" + pid + " ] && echo yes || echo no" : "echo no"]
        stdout: StdioCollector { id: pidOut; onStreamFinished: root.appRunning = pidOut.text.trim() === "yes" }
    }

    Process {
        id: daemonProc
        command: ["bash", "-c", "systemctl is-active --quiet karin-proxy-daemon.service && echo yes || echo no"]
        stdout: StdioCollector { id: daemonOut; onStreamFinished: root.daemonOn = daemonOut.text.trim() === "yes" }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible && root.installed
        triggeredOnStart: true
        onTriggered: {
            if (root.bridge) { pidProc.running = false; pidProc.running = true }
            else { daemonProc.running = false; daemonProc.running = true; statusFile.reload() }
        }
    }

    function _onShown() { whichProc.running = false; whichProc.running = true; statusFile.reload() }

    // ── Действия ─────────────────────────────────────────────────────────────
    Process { id: actProc }
    function run(args) {
        actProc.command = ["bash", "-c", "setsid " + args + " >/dev/null 2>&1 &"]
        actProc.running = false; actProc.running = true
    }
    function toggle() {
        if (!root.installed) return
        if (!root.bridge) { root.run("karincore"); root.toast = "Opening KarinCore…"; return }
        if (root.phase === "on" || root.phase === "connecting") root.run("karincore --disconnect")
        else root.run("karincore --connect" + (root.selected ? " '" + root.selected.replace(/'/g, "") + "'" : ""))
    }
    function choose(p) {
        root.listOpen = false
        root.selected = p.id; root.profileName = p.name
        const id = "'" + String(p.id).replace(/'/g, "") + "'"
        root.run(root.phase === "on" ? "karincore --connect " + id : "karincore --select " + id)
    }
    function openUrl(u) { root.run("xdg-open '" + u + "'") }
    Process { id: copyProc }
    function copy(t) {
        copyProc.command = ["wl-copy", t]; copyProc.running = false; copyProc.running = true
        root.toast = "Copied"
    }
    Timer { interval: 2200; running: root.toast !== ""; onTriggered: root.toast = "" }

    // ═════════════════════════════════════════════════════════════════════════
    //  Ядро (как на главном экране KarinCore)
    // ═════════════════════════════════════════════════════════════════════════
    component Core: Item {
        id: core
        property string phase: "idle"         // idle | connecting | on
        property string label: "null"
        property color accent:  "#dc8add"
        property color success: "#a6e3a1"
        property color dim:     "#7f849c"
        property color border:  "#45475a"
        property color panel:   "#1e1e2e"
        signal clicked()

        width: 240; height: 240
        readonly property real k: width / 320

        // мягкое свечение за кольцом
        Rectangle {
            anchors.centerIn: parent
            width: 300 * core.k; height: width; radius: width / 2
            color: "transparent"
            opacity: core.phase === "on" ? 0.5 : core.phase === "connecting" ? 0.35 : (hov.hovered ? 0.25 : 0)
            Behavior on opacity { NumberAnimation { duration: 600 } }
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    const g = c.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2)
                    g.addColorStop(0, Qt.rgba(core.accent.r, core.accent.g, core.accent.b, 0.45))
                    g.addColorStop(1, Qt.rgba(core.accent.r, core.accent.g, core.accent.b, 0))
                    c.fillStyle = g; c.fillRect(0, 0, width, height)
                }
            }
        }

        // вращающаяся сеть линий и узлов
        Item {
            id: net
            anchors.fill: parent
            property real spin: 0
            property real rate: 0
            readonly property real target: core.phase === "connecting" ? 6.5 : core.phase === "on" ? 1 : 0
            rotation: spin
            Timer {
                interval: 16; repeat: true
                running: core.visible && (net.rate > 0.001 || net.target > 0)
                onTriggered: {
                    net.rate += (net.target - net.rate) * 0.04
                    net.spin = (net.spin + net.rate * 360 / 46 / 60) % 360
                }
            }
            Canvas {
                id: netCanvas
                anchors.fill: parent
                property string phase: core.phase
                onPhaseChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset(); c.scale(core.k, core.k)
                    const P = [[173,84,180,44],[219,111,261,76],[238,168,273,170],[219,209,266,248],[180,235,193,281],
                               [128,230,110,269],[93,200,46,226],[84,140,51,131],[116,96,89,58]]
                    const S = [[261,76,291,41],[266,248,304,273],[46,226,10,254],[89,58,60,16]]
                    const lit = phase !== "idle", on = phase === "on"
                    c.lineWidth = 1.2
                    c.strokeStyle = lit ? core.accent : core.border
                    for (const l of P) { c.beginPath(); c.moveTo(l[0], l[1]); c.lineTo(l[2], l[3]); c.stroke() }
                    if (on) {
                        c.strokeStyle = Qt.rgba(core.success.r, core.success.g, core.success.b, 0.8); c.lineWidth = 1
                        for (const l of S) { c.beginPath(); c.moveTo(l[0], l[1]); c.lineTo(l[2], l[3]); c.stroke() }
                        c.fillStyle = core.success
                        for (const l of S) { c.beginPath(); c.arc(l[2], l[3], 4.5, 0, Math.PI * 2); c.fill() }
                    }
                    for (const l of P) {
                        c.beginPath(); c.arc(l[2], l[3], 5, 0, Math.PI * 2)
                        c.fillStyle = on ? core.success : core.panel; c.fill()
                        c.lineWidth = 1.2; c.strokeStyle = on ? core.success : lit ? core.accent : core.border; c.stroke()
                    }
                }
            }
        }

        // «дыхание» кольца
        Rectangle {
            id: glow
            anchors.centerIn: parent
            property real r: 78
            width: r * 2 * core.k; height: width; radius: width / 2
            color: "transparent"
            border.color: core.accent; border.width: 1
            opacity: 0
            function reset() { opacity = 0; r = 78 }
            // подключено: спокойное «дыхание» 2.2 c; подключение: частое 1.1 c
            SequentialAnimation {
                running: core.phase === "on"
                loops: Animation.Infinite
                onRunningChanged: if (!running) glow.reset()
                ParallelAnimation {
                    NumberAnimation { target: glow; property: "r"; from: 78; to: 118; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { target: glow; property: "opacity"; from: 0.55; to: 0; duration: 1100; easing.type: Easing.InOutSine }
                }
                ParallelAnimation {
                    NumberAnimation { target: glow; property: "r"; from: 118; to: 78; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { target: glow; property: "opacity"; from: 0; to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
            SequentialAnimation {
                running: core.phase === "connecting"
                loops: Animation.Infinite
                onRunningChanged: if (!running) glow.reset()
                ParallelAnimation {
                    NumberAnimation { target: glow; property: "r"; from: 78; to: 118; duration: 1100; easing.type: Easing.OutCubic }
                    NumberAnimation { target: glow; property: "opacity"; from: 0.55; to: 0; duration: 1100; easing.type: Easing.OutCubic }
                }
            }
        }

        // кольцо
        Rectangle {
            anchors.centerIn: parent
            width: 156 * core.k; height: width; radius: width / 2
            color: "transparent"
            border.color: core.accent; border.width: 1.5
        }

        // [ ~$ ... ] — печатается по буквам, как в приложении
        Text {
            id: coreText
            anchors.centerIn: parent
            property string full: core.label
            property int shown: full.length
            onFullChanged: { shown = 0; typeTimer.restart() }
            Timer { id: typeTimer; interval: 100; repeat: true
                    onTriggered: { coreText.shown++; if (coreText.shown >= coreText.full.length) stop() } }
            text: "[ ~$ " + full.slice(0, shown) + " ]"
            font.family: "monospace"; font.pixelSize: 16 * core.k * 1.15
            color: core.phase === "on" ? core.success : core.phase === "connecting" ? core.accent : core.dim
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        scale: tap.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: core.clicked() }
    }

    // ═════════════════════════════════════════════════════════════════════════
    //  Установлен
    // ═════════════════════════════════════════════════════════════════════════
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: root.installed

        Core {
            anchors.horizontalCenter: parent.horizontalCenter
            phase: root.phase
            label: root.phase === "on" ? "connect" : root.phase === "connecting" ? "..." : "null"
            accent: root.kcAccent; success: root.kcSuccess; dim: root.kcDim; border: root.kcBorder; panel: root.kcPanel
            onClicked: root.toggle()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.phase === "on" ? "Active" : root.phase === "connecting" ? "Connecting…" : "Inactive"
            color: root.phase === "on" ? root.kcSuccess : root.phase === "connecting" ? root.kcAccent : root.kcDim
            font.pixelSize: 17; font.family: "JetBrains Mono"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.phase === "on" && root.ip !== ""
            text: "IP: " + root.ip
            color: root.kcDim; font.pixelSize: 11; font.family: "JetBrains Mono"
        }

        Item { width: 1; height: 8 }

        // выбор профиля
        Rectangle {
            id: picker
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.bridge
            width: 300; height: 36; radius: 10
            color: pickH.hovered || root.listOpen ? Qt.rgba(0.86, 0.54, 0.87, 0.14) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.listOpen ? root.kcAccent : Qt.rgba(1, 1, 1, 0.08)
            Text {
                anchors { left: parent.left; leftMargin: 14; right: arrow.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: root.profileName !== "" ? root.profileName : (root.profiles.length ? "Choose a profile" : "No profiles yet — add one in KarinCore")
                elide: Text.ElideRight
                color: root.profileName !== "" ? root.kcText : root.kcDim
                font.pixelSize: 12; font.family: "JetBrains Mono"
            }
            Text { id: arrow; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                   text: root.listOpen ? "󰅃" : "󰅀"; color: root.kcAccent; font.pixelSize: 14 }
            HoverHandler { id: pickH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: {
                if (!root.profiles.length) return
                root.listY = picker.mapToItem(root, 0, picker.height + 4).y
                root.listOpen = !root.listOpen
            } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.bridge
            width: 320
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Tap the core to open KarinCore.\nUpdate KarinCore to switch profiles right from here."
            color: root.kcDim; font.pixelSize: 11; font.family: "JetBrains Mono"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.toast !== "" ? root.toast : "open app"
            color: root.toast !== "" ? root.kcAccent : (openH.hovered ? root.kcAccent : Qt.rgba(1, 1, 1, 0.3))
            font.pixelSize: 10; font.family: "JetBrains Mono"; font.underline: openH.hovered && root.toast === ""
            HoverHandler { id: openH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.run("karincore") }
        }
    }

    // выпадающий список профилей — отдельное всплывающее окно,
    // чтобы список выходил за границы дашборда
    PopupWindow {
        id: profilePopup
        anchor.item: picker
        anchor.rect.x: 0
        anchor.rect.y: picker.height + 4
        anchor.rect.width: picker.width
        anchor.rect.height: 1
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: 300
        implicitHeight: Math.min(listCol.implicitHeight + 12, 340)
        visible: root.listOpen && root.installed && root.visible && Popups.dashboardOpen
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: root.kcPanel
            border.color: Qt.rgba(0.86, 0.54, 0.87, 0.45)

            Flickable {
                anchors { fill: parent; margins: 6 }
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: listCol
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: root.profiles
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: listCol.width; height: 32; radius: 7
                            readonly property bool cur: row.modelData.id === root.selected
                            color: rowH.hovered ? Qt.rgba(0.86, 0.54, 0.87, 0.16) : cur ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 10; right: typeTag.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                text: (row.cur ? "● " : "") + row.modelData.name
                                elide: Text.ElideRight
                                color: row.cur ? root.kcAccent : root.kcText
                                font.pixelSize: 12; font.family: "JetBrains Mono"
                            }
                            Text {
                                id: typeTag
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                text: (row.modelData.type || "").toUpperCase()
                                color: root.kcDim; font.pixelSize: 9; font.family: "JetBrains Mono"
                            }
                            HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.choose(row.modelData) }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Popups
        function onDashboardOpenChanged() { if (!Popups.dashboardOpen) root.listOpen = false }
    }
    onVisibleChanged: if (visible) root._onShown(); else root.listOpen = false

    // ═════════════════════════════════════════════════════════════════════════
    //  Не установлен — карточка-приглашение
    // ═════════════════════════════════════════════════════════════════════════
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !root.installed
        width: 420

        Core {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 170; height: 170
            phase: hovCard.hovered ? "connecting" : "idle"
            label: "install"
            accent: root.kcAccent; success: root.kcSuccess; dim: root.kcDim; border: root.kcBorder; panel: root.kcPanel
            onClicked: root.openUrl("https://karincore.ru")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "KarinCore"
            color: root.kcAccent; font.pixelSize: 22; font.weight: Font.Bold; font.family: "JetBrains Mono"
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "A fast VPN / proxy client for Linux — VLESS, VMess, Trojan, Shadowsocks, WireGuard, OpenVPN. Toggle it and switch profiles right from this tab."
            color: root.kcText; opacity: 0.8; font.pixelSize: 12; font.family: "JetBrains Mono"
        }

        Item { width: 1; height: 4 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "You can install KarinCore via"
            color: root.kcDim; font.pixelSize: 11; font.family: "JetBrains Mono"
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: cmd.implicitWidth + 60; height: 36; radius: 9
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: cmdH.hovered ? root.kcAccent : Qt.rgba(1, 1, 1, 0.1)
            Text {
                id: cmd
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                text: "<font color='#a6e3a1'>$</font> yay -S karincore-git"
                textFormat: Text.RichText
                color: root.kcText; font.pixelSize: 13; font.family: "JetBrains Mono"
            }
            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: root.toast === "Copied" ? "󰄬" : "󰆏"
                color: root.kcAccent; font.pixelSize: 14
            }
            HoverHandler { id: cmdH; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.copy("yay -S karincore-git") }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "or visit"
            color: root.kcDim; font.pixelSize: 11; font.family: "JetBrains Mono"
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            LinkBtn { icon: "󰊤"; label: "GitHub";        url: "https://github.com/detestern/KarinCore" }
            LinkBtn { icon: "󰖟"; label: "karincore.ru"; url: "https://karincore.ru" }
        }

        HoverHandler { id: hovCard }
    }

    component LinkBtn: Rectangle {
        id: lb
        property string icon: ""
        property string label: ""
        property string url: ""
        width: lbRow.implicitWidth + 28; height: 34; radius: 9
        color: lbH.hovered ? Qt.rgba(0.86, 0.54, 0.87, 0.2) : Qt.rgba(1, 1, 1, 0.05)
        border.color: lbH.hovered ? "#dc8add" : Qt.rgba(1, 1, 1, 0.1)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: lbRow
            anchors.centerIn: parent
            spacing: 8
            Text { text: lb.icon; color: "#dc8add"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
            Text { text: lb.label; color: "#cdd6f4"; font.pixelSize: 12; font.family: "JetBrains Mono"; anchors.verticalCenter: parent.verticalCenter }
        }
        HoverHandler { id: lbH; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Qt.openUrlExternally(lb.url) }
    }
}
