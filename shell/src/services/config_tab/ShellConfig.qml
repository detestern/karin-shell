import QtQuick
import "../"
import "../../"

// Config: хоткеи Brain Shell + рабочие столы при запуске (karin-shell)
Item {
    id: root

    property string _page: "keybinds"

    readonly property var _tabs: [
        { key: "keybinds", icon: "󰌌", label: "Keybinds" },
        { key: "desktops", icon: "󱂬", label: "Desktops" },
        { key: "theme",    icon: "󰏘", label: "Theme"    },
    ]

    // ── Вкладки сверху (сегменты) ────────────────────────────────────────────
    Row {
        id: tabs
        anchors { top: parent.top; left: parent.left; topMargin: 10; leftMargin: 14 }
        spacing: 4

        Repeater {
            model: root._tabs
            delegate: Rectangle {
                id: tab
                required property var modelData
                readonly property bool current: root._page === tab.modelData.key
                width: tabRow.implicitWidth + 24
                height: 30
                radius: 9
                color: current ? Qt.rgba(1, 0.4, 0.6, 0.18) : (tabH.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                border.color: current ? Qt.rgba(1, 0.4, 0.6, 0.5) : "transparent"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Row {
                    id: tabRow
                    anchors.centerIn: parent
                    spacing: 7
                    Text { text: tab.modelData.icon; font.pixelSize: 14
                           color: tab.current ? Theme.active : Qt.rgba(1, 1, 1, 0.55)
                           anchors.verticalCenter: parent.verticalCenter }
                    Text { text: tab.modelData.label; font.pixelSize: 12; font.family: "JetBrains Mono"
                           font.weight: tab.current ? Font.Bold : Font.Normal
                           color: tab.current ? Theme.active : Qt.rgba(1, 1, 1, 0.65)
                           anchors.verticalCenter: parent.verticalCenter }
                }
                HoverHandler { id: tabH; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root._page = tab.modelData.key }
            }
        }
    }

    // ── Содержимое ───────────────────────────────────────────────────────────
    Item {
        anchors { top: tabs.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }

        KeybindsPage { anchors.fill: parent; visible: root._page === "keybinds" }
        DesktopsPage { anchors.fill: parent; visible: root._page === "desktops" }
        ThemePage    { anchors.fill: parent; visible: root._page === "theme" }
    }
}
