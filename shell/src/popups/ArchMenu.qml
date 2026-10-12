import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shapes"
import "../services"
import "../components"
import "../"

// Переписано на PanelWindow для поддержки перехвата клавиатуры (как в Dashboard)
PanelWindow {
    id: root

    required property var anchorWindow

    readonly property int fw: Theme.cornerRadius
    readonly property int fh: Theme.cornerRadius

    readonly property var pageHeights: ({
        "power":       270,
        "performance": 190,
        "stats":       250
    })
    readonly property var pageWidths: ({
        "power":       220,
        "performance": 260,
        "stats":       390
    })

    readonly property int contentWidth:  pageWidths[page]  ?? 220
    readonly property int contentHeight: pageHeights[page] ?? 220

    property string page: "power"

    // ─── WAYLAND FOCUS FIX (Магия из Dashboard) ──────────────────────────
    color: "transparent"
    visible: windowVisible

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    property bool wantsFocus: false
    WlrLayershell.keyboardFocus: wantsFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    property bool windowVisible: false

    Timer {
        id: focusGrabTimer
        interval: 15
        onTriggered: if (windowVisible && Popups.archMenuOpen) root.wantsFocus = true
    }

    Connections {
        target: Popups
        function onArchMenuOpenChanged() {
            if (Popups.archMenuOpen) {
                closeTimer.stop()
                root.windowVisible = true
                focusGrabTimer.restart()
            } else {
                root.wantsFocus = false
                focusGrabTimer.stop()
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.animDuration + 20
        onTriggered: root.windowVisible = false
    }

    // Закрытие при клике мимо меню (Overlay)
    MouseArea {
        anchors.fill: parent
        onClicked: Popups.archMenuOpen = false
    }
    // ─────────────────────────────────────────────────────────────────────

    PopupSlide {
        id: slide
        anchors.fill: parent
        edge: "left"
        hoverEnabled: false
        triggerHovered: Popups.archMenuTriggerHovered
        open: Popups.archMenuOpen
        onCloseRequested: Popups.archMenuOpen = false

        Item {
            id: sizer
            // Привязываем ровно по центру левого края
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            width:  root.contentWidth  + root.fw
            height: root.contentHeight + root.fh * 2

            Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

            // Перехват кликов внутри меню, чтобы оно не закрывалось
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            PopupShape {
                id: bg
                anchors.fill: parent
                attachedEdge: "left"
                color: Theme.background
                radius: Theme.cornerRadius
                flareWidth: root.fw
                flareHeight: root.fh
            }

            Item {
                anchors {
                    fill: parent
                    leftMargin: root.fw - 4
                    rightMargin: 8
                    topMargin: root.fh + 6
                    bottomMargin: root.fh + 6
                }

                //── Page content ──────────────────────────────────────────
                Item {
                    width: parent.width
                    height: parent.height
                    clip: true

                    PopupPage {
                        anchors.fill: parent
                        visible: root.page === "power"

                        PowerMenu {
                            width: parent.width
                        }
                    }
                }
            }
        }
    }
}