import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// ColorLoader (karin-shell) — цвета из единой темы
// ~/.config/karin-shell/theme.json (Config → Theme). Следит за файлом
// и обновляет цвета на лету. Значения ниже — запасные.
// ============================================================

QtObject {
    id: root

    property color background: "#1a1a24"
    property color active:     "#FF6699"
    property color border:     "#FF6699"
    property color iconFont:   "#FF6699"
    property color text:       "#ffffff"
    property color subtext:    "#ffb3cb"
    property color icon:       "#ffffff"
    property real  barOpacity: 0.8

    property var _file: FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.config/karin-shell/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(themeFile.text())
    }

    function _parse(raw) {
        if (!raw || raw.trim() === "") return
        try {
            const t = JSON.parse(raw)
            if (t.background) root.background = t.background
            if (t.accent)     { root.active = t.accent; root.border = t.accent; root.iconFont = t.accent }
            if (t.text)       { root.text = t.text; root.icon = t.text }
            if (t.subtext)    root.subtext = t.subtext
            if (t.bar_opacity !== undefined) root.barOpacity = t.bar_opacity
        } catch (e) {
            console.warn("karin-shell: theme.json не читается — оставляю прежние цвета")
        }
    }
}
