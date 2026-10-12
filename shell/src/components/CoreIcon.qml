import QtQuick

// Маленький значок «ядра» KarinCore: кольцо и лучи с узлами (как на главном экране приложения).
Canvas {
    id: root
    property color ringColor: "#dc8add"
    property color nodeColor: "#a6e3a1"
    width: 16; height: 16
    onRingColorChanged: requestPaint()
    onNodeColorChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset()
        const s = width, cx = s / 2, cy = s / 2, R = s * 0.26
        c.lineWidth = Math.max(1, s * 0.08)
        c.strokeStyle = ringColor
        c.beginPath(); c.arc(cx, cy, R, 0, Math.PI * 2); c.stroke()
        c.lineWidth = Math.max(0.8, s * 0.05)
        for (let i = 0; i < 6; i++) {
            const a = (i * 60 - 90 + 12 * (i % 2)) * Math.PI / 180
            const r2 = s * (i % 2 ? 0.43 : 0.38)
            const x1 = cx + R * 1.05 * Math.cos(a), y1 = cy + R * 1.05 * Math.sin(a)
            const x2 = cx + r2 * Math.cos(a),       y2 = cy + r2 * Math.sin(a)
            c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke()
            c.fillStyle = nodeColor
            c.beginPath(); c.arc(x2, y2, s * 0.065, 0, Math.PI * 2); c.fill()
        }
    }
}
