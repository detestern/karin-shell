import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../"

Item {
    id: root

    readonly property var pinned:  ClipboardService.pinned  ?? []
    readonly property var history: ClipboardService.entries ?? []

    // ── Индекс для навигации с клавиатуры ──────────────────────────────────────
    property int selIndex: 0

    // ── Flat unified model ─────────────────────────────────────────────────────
    readonly property var flatModel: {
        var result = []
        var pins   = root.pinned
        var hist   = root.history

        // Build fast-lookup set of pinned previews/texts for O(1) dedup
        var lookup = {}
        for (var k = 0; k < pins.length; k++) {
            if (pins[k].preview) lookup[pins[k].preview] = true
            if (pins[k].text)    lookup[pins[k].text]    = true
        }

        // Pinned section (top)
        for (var pi = 0; pi < pins.length; pi++) {
            result.push({
                kind:     "pinned",
                text:     pins[pi].text    ?? "",
                preview:  pins[pi].preview ?? pins[pi].text ?? "",
                storedId: pins[pi].id      ?? "",
                pinIndex: pi,
                isImage:  false
            })
        }

        // History section
        for (var hi = 0; hi < hist.length; hi++) {
            var e = hist[hi]
            if (!e.isImage && (lookup[e.preview] || lookup[(e.preview ?? "").trim()])) continue
            result.push({
                kind:    "entry",
                id:      e.id,
                preview: e.preview,
                isImage: e.isImage ?? false
            })
        }

        return result
    }

    // ── Trojan Horse: Перехватчик фокуса ───────────────────────────────────────
    onVisibleChanged: {
        if (visible && Popups.clipboardOpen) {
            root.selIndex = 0
            focusTimer.restart()
        }
    }

    Connections {
        target: Popups
        function onClipboardOpenChanged() {
            if (Popups.clipboardOpen && root.visible) {
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

    TextInput {
        id: hiddenInput
        width: 0; height: 0
        clip: true
        color: "transparent"
        selectionColor: "transparent"
        activeFocusOnTab: true

        Keys.onUpPressed: {
            if (root.selIndex > 0) {
                root.selIndex--
                mainList.positionViewAtIndex(root.selIndex, ListView.Contain)
            }
            event.accepted = true
        }

        Keys.onDownPressed: {
            if (root.selIndex < root.flatModel.length - 1) {
                root.selIndex++
                mainList.positionViewAtIndex(root.selIndex, ListView.Contain)
            }
            event.accepted = true
        }

        Keys.onReturnPressed: {
            if (root.selIndex >= 0 && root.selIndex < root.flatModel.length) {
                let item = root.flatModel[root.selIndex]
                
                // 1. Убираем фокус с нашего шпиона, чтобы он перестал быть "активным"
                hiddenInput.focus = false
                
                // 2. Закрываем окно
                Popups.clipboardOpen = false
                
                // 3. Используем таймер вместо callLater для более надежной задержки
                Qt.createQmlObject('import QtQuick; Timer { interval: 150; running: true; onTriggered: { ClipboardService.typeFromClipboard(); destroy() } }', root);
                
                // 4. Логика копирования
                if (item.kind === "pinned") {
                    ClipboardService.copyText(item.text || item.preview)
                } else {
                    ClipboardService.copyEntry(item.id)
                }
            }
            event.accepted = true
        }

        Keys.onEscapePressed: {
            Popups.clipboardOpen = false
            event.accepted = true
        }
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Header ─────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 44

            Text {
                anchors.centerIn: parent
                text:           "Clipboard"
                font.pixelSize: 14
                font.weight:    Font.DemiBold
                color:          Theme.text
            }

            // Clear unpinned history button
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 4 }
                width:  clearRow.implicitWidth + 14
                height: 26; radius: 8
                color: clearH.hovered
                    ? Qt.rgba(248/255, 113/255, 113/255, 0.18)
                    : Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(248/255, 113/255, 113/255, clearH.hovered ? 0.38 : 0.12)
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰩺"; font.pixelSize: 12
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clear"; font.pixelSize: 10
                        color: Qt.rgba(248/255, 113/255, 113/255, 0.80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                HoverHandler { id: clearH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: ClipboardService.wipeHistory() }
            }
        }

        // Divider
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

        // ── Content ────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: parent.height - 45

            // Loading state
            Column {
                anchors.centerIn: parent; spacing: 10
                visible: (ClipboardService.loading ?? false)
                         && root.history.length === 0
                         && root.pinned.length  === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "○"; font.pixelSize: 22; color: Theme.active
                    SequentialAnimation on opacity {
                        running: parent.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 500 }
                        NumberAnimation { to: 1.0;  duration: 500 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Loading…"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.25)
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent; spacing: 10
                visible: !(ClipboardService.loading ?? false)
                         && root.history.length === 0
                         && root.pinned.length  === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰅍"; font.pixelSize: 32; color: Qt.rgba(1,1,1,0.08)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Clipboard is empty"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.20)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Copy something to get started"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.13)
                }
            }

            // ── List ───────────────────────────────────────────────────────────
            ListView {
                id: mainList
                anchors {
                    fill:         parent
                    topMargin:    6
                    leftMargin:   2
                    rightMargin:  12 
                    bottomMargin: 4
                }
                clip:           true
                spacing:        4
                boundsBehavior: Flickable.StopAtBounds
                visible:        root.flatModel.length > 0
                model:          root.flatModel

                ScrollBar.vertical: vbar

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
                }

                delegate: ClipRow {
                    required property var modelData
                    required property int index
                    width: mainList.width - 4

                    isPinned:    modelData.kind === "pinned"
                    entryId:     modelData.kind === "pinned" ? (modelData.storedId ?? "") : (modelData.id ?? "")
                    previewText: modelData.preview ?? ""
                    fullText:    modelData.kind === "pinned" ? (modelData.text ?? "") : ""
                    isImage:     modelData.isImage ?? false
                    pinnedIndex: modelData.kind === "pinned" ? modelData.pinIndex : -1
                    
                    // Передаем состояние выделения внутрь строки
                    isSel: root.selIndex === index

                    // Синхронизируем мышку с клавиатурой (при наведении фокус переходит на этот элемент)
                    onHoveredChanged: {
                        if (hovered) root.selIndex = index
                    }
                }
            }

            // ── External Scrollbar ─────────────────────────────────────────────
            ScrollBar {
                id: vbar
                anchors {
                    top:    parent.top
                    bottom: parent.bottom
                    right:  parent.right
                    topMargin: 6
                    bottomMargin: 4
                }
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth:  4
                    implicitHeight: 10
                    radius:         2
                    color:          Qt.rgba(1, 1, 1, 0.22)
                }
            }
        }
    }

// ── ClipRow ────────────────────────────────────────────────────────────────────
component ClipRow: Item {
    id: row

    property bool   isPinned:    false
    property string entryId:     ""   
    property string previewText: ""   
    property string fullText:    ""   
    property bool   isImage:     false
    property int    pinnedIndex: -1
    
    // Новое свойство для подсветки активного элемента
    property bool   isSel:       false
    // Экспортируем состояние наведения для синхронизации с ListView
    readonly property bool hovered: rHov.hovered

    property string _imgPath: ""

    property var _imgDecodeProc: Process {
        command: []
        running: false
        onRunningChanged: {
            if (!running) row._imgPath = "/tmp/clip_prev_" + row.entryId
        }
    }

    Component.onCompleted: {
        if (row.isImage && row.entryId !== "") {
            _imgDecodeProc.command = ["bash", "-c",
                "cliphist decode '" + row.entryId + "' > '/tmp/clip_prev_" + row.entryId + "' 2>/dev/null"]
            _imgDecodeProc.running = true
        }
    }

    property bool _removing: false

    height:  _removing ? 0 : (card.height + 2)
    opacity: _removing ? 0 : 1
    clip: true

    Behavior on height  { NumberAnimation { duration: 210; easing.type: Easing.InCubic } }
    Behavior on opacity { NumberAnimation { duration: 160 } }

    // ── Card ──────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 1 }

        height: Math.max(row.isImage ? 66 : 42, innerRow.height + 18)
        radius: 9

        // Обновленная логика цвета: теперь активный элемент подсвечивается
        color: row.isSel
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
            : row.isPinned
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.055)
                : Qt.rgba(1, 1, 1, 0.024)

        border.color: row.isSel
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
            : row.isPinned
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                : Qt.rgba(1, 1, 1, 0.065)
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // ── Inner layout ──────────────────────────────────────────────────────
        Row {
            id: innerRow
            anchors {
                left:           parent.left;  leftMargin:  10
                right:          parent.right; rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            spacing: 8
            height: Math.max(row.isImage ? 56 : 22, previewLabel.implicitHeight)

            Item {
                id:     leftSlot
                width:  row.isImage ? 74 : 18
                height: innerRow.height
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    visible: row.isImage
                    anchors {
                        left: parent.left; top: parent.top
                        bottom: parent.bottom; right: parent.right
                        rightMargin: 6
                    }
                    radius: 6
                    color:  Qt.rgba(1, 1, 1, 0.05)
                    clip:   true

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source:   row._imgPath !== "" ? ("file://" + row._imgPath) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth:   true
                        asynchronous: true
                        opacity: thumbImg.status === Image.Ready ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }

                    Item {
                        anchors.fill: parent
                        visible: thumbImg.status !== Image.Ready
                        Rectangle { anchors.fill: parent; color: Qt.rgba(1,1,1,0.03) }
                        Text { anchors.centerIn: parent; text: "🖼"; font.pixelSize: 18; opacity: 0.22 }
                    }
                }

                Text {
                    visible: !row.isImage
                    anchors.verticalCenter: parent.verticalCenter
                    text:           "󰅍"
                    font.pixelSize: 12
                    color:          Qt.rgba(1, 1, 1, 0.22)
                }
            }

            Text {
                id: previewLabel
                width: innerRow.width - leftSlot.width - actionsRow.implicitWidth - innerRow.spacing * 2 - 2
                anchors.verticalCenter: parent.verticalCenter

                text: row.isImage ? "Image" : row.previewText
                font.pixelSize:   12
                color: row.isImage
                    ? Qt.rgba(1, 1, 1, 0.28)
                    : Qt.rgba(1, 1, 1, 0.78)
                font.italic:      row.isImage
                elide:            Text.ElideRight
                maximumLineCount: 2
                wrapMode:         Text.WordWrap
            }

            Row {
                id: actionsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                opacity: rHov.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                ActionBtn {
                    icon: "󰆏"
                    onClicked: {
                        if (row.isPinned) ClipboardService.copyText(row.fullText || row.previewText)
                        else             ClipboardService.copyEntry(row.entryId)
                        Popups.clipboardOpen = false
                    }
                }

                ActionBtn {
                    icon:    row.isPinned ? "󰐄" : "󰐃"
                    active:  row.isPinned
                    visible: !row.isImage
                    onClicked: {
                        if (row.isPinned) ClipboardService.unpinAt(row.pinnedIndex)
                        else              ClipboardService.pinEntry(row.entryId, row.previewText)
                    }
                }

                ActionBtn {
                    icon:   "󰩺"
                    danger: true
                    onClicked: {
                        row._removing = true
                        delayedAction.isPinned    = row.isPinned
                        delayedAction.pinnedIndex = row.pinnedIndex
                        delayedAction.entryId     = row.entryId
                        delayedAction.restart()
                    }
                }
            }
        }

        Rectangle {
            visible: row.isPinned
            anchors { top: parent.top; right: parent.right; topMargin: 5; rightMargin: 4 }
            width: 18; height: 18; radius: 8
            color: Theme.active

            Text {
                anchors.centerIn: parent
                text: " 󰐃"; font.pixelSize: 8; font.weight: Font.Bold
                color: Qt.rgba(0, 0, 0, 0.65)
            }

            scale: row.isPinned ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        }
    }

    HoverHandler { id: rHov }

    TapHandler {
        onDoubleTapped: {
            if (row.isPinned) ClipboardService.copyText(row.fullText || row.previewText)
            else             ClipboardService.copyEntry(row.entryId)
            Popups.clipboardOpen = false
            ClipboardService.typeFromClipboard()
        }
    }

    Timer {
        id: delayedAction
        property bool   isPinned:    false
        property int    pinnedIndex: -1
        property string entryId:     ""
        interval: 220
        onTriggered: {
            if (isPinned) {
                if (pinnedIndex >= 0) ClipboardService.unpinAt(pinnedIndex)
                if (entryId !== "") ClipboardService.deleteEntry(entryId)
            } else {
                if (entryId !== "") ClipboardService.deleteEntry(entryId)
            }
        }
    }
}

// ── ActionBtn ──────────────────────────────────────────────────────────────────
component ActionBtn: Rectangle {
    id: ab
    property string icon:   ""
    property bool   active: false
    property bool   danger: false
    signal clicked()

    width: 26; height: 26; radius: 7

    color: ab.danger
        ? (aH.hovered ? Qt.rgba(248/255, 113/255, 113/255, 0.20) : "transparent")
        : ab.active
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
            : (aH.hovered ? Qt.rgba(1, 1, 1, 0.11) : "transparent")

    Behavior on color { ColorAnimation { duration: 110 } }

    transform: Scale {
        origin.x: 13; origin.y: 13
        xScale: aH.hovered ? 1.10 : 1.0
        yScale: aH.hovered ? 1.10 : 1.0
        Behavior on xScale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on yScale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    Text {
        anchors.centerIn: parent
        text:           ab.icon
        font.pixelSize: 13
        color: ab.danger
            ? (aH.hovered ? "#f87171" : Qt.rgba(248/255, 113/255, 113/255, 0.50))
            : ab.active
                ? Theme.active
                : (aH.hovered ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, 0.38))
        Behavior on color { ColorAnimation { duration: 110 } }
    }

    HoverHandler { id: aH; cursorShape: Qt.PointingHandCursor }
    MouseArea    { anchors.fill: parent; onClicked: ab.clicked() }
}
}    