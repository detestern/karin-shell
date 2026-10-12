#!/usr/bin/env python3
"""Генерирует intro/art.json для заставки karin-shell из картинки с прозрачным фоном.

    gen_art.py karin_cut.png art.json

Стили:
  face   — пиксельный портрет блоками █ (16 цветов, работает и в голом TTY)
  ascii  — портрет из символов .:-=+*#%@ цветом (16 цветов, работает в TTY)
  hires  — двойная вертикальная чёткость полублоками ▀ (64 цвета, только kitty/truecolor)
Каждый стиль хранится в нескольких размерах, заставка берёт самый большой, что влезает.
Нужны Pillow, numpy, opencv-python.
"""
import json, sys
import numpy as np, cv2
from PIL import Image, ImageEnhance

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGBA')
bbox = im.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox()
im = im.crop(bbox)
bg = Image.new('RGBA', im.size, (0, 0, 0, 255)); bg.alpha_composite(im)
rgb = ImageEnhance.Color(ImageEnhance.Contrast(bg.convert('RGB')).enhance(1.1)).enhance(1.35)
alpha = im.getchannel('A')

def kmeans_palette(n):
    px = np.array(rgb)[np.array(alpha) > 200].reshape(-1, 3).astype(np.float32)
    lab = cv2.cvtColor(px.reshape(-1, 1, 3) / 255.0, cv2.COLOR_RGB2LAB).reshape(-1, 3)
    _, _, cen = cv2.kmeans(lab, n, None, (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 60, 0.2),
                           4, cv2.KMEANS_PP_CENTERS)
    c = (cv2.cvtColor(cen.reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3) * 255).clip(0, 255).astype(int)
    return sorted(c.tolist(), key=lambda v: -(0.299 * v[0] + 0.587 * v[1] + 0.114 * v[2]))

def pimg(colors):
    q = Image.new('P', (1, 1)); flat = []
    for c in colors: flat += list(c)
    q.putpalette(flat + [0] * (768 - len(flat)))
    return q

hexs = lambda c: '%02x%02x%02x' % tuple(c)
pal14 = kmeans_palette(14)
palette = ['000000'] + [hexs(c) for c in pal14] + ['ff6699']   # 15 — фирменный розовый
q14 = pimg(pal14)
pal64 = kmeans_palette(63)
q64 = pimg(pal64)
ALPH = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/"   # индекс 0..63
RAMP = " .:-=+*#%@$"

def cells(cols, rows):
    small = rgb.resize((cols, rows), Image.LANCZOS)
    a = np.array(alpha.resize((cols, rows), Image.LANCZOS))
    return small, a

def style_face(cols):
    rows = max(1, round(cols * im.height / im.width * 0.5))
    small, a = cells(cols, rows)
    qi = np.minimum(np.array(small.quantize(palette=q14, dither=Image.Dither.NONE)), len(pal14) - 1)
    lines, colors = [], []
    for y in range(rows):
        lines.append(''.join(' ' if a[y, x] < 60 else ('█' if a[y, x] > 200 else '▓') for x in range(cols)))
        colors.append(''.join('%x' % (qi[y, x] + 1) for x in range(cols)))
    return {'w': cols, 'h': rows, 'lines': lines, 'colors': colors}

def style_ascii(cols):
    rows = max(1, round(cols * im.height / im.width * 0.5))
    small, a = cells(cols, rows)
    g = np.array(small.convert('L')).astype(np.float32)
    # локальный контраст + контуры — чтобы глаза/рот читались, а не всё в '@'
    g = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(4, 4)).apply(g.astype(np.uint8)).astype(np.float32)
    edges = cv2.Canny(g.astype(np.uint8), 60, 140).astype(np.float32) / 255
    lum = np.clip((g / 255) ** 0.55 * (1 - 0.6 * edges), 0, 1)
    qi = np.minimum(np.array(small.quantize(palette=q14, dither=Image.Dither.NONE)), len(pal14) - 1)
    lines, colors = [], []
    for y in range(rows):
        l, c = [], []
        for x in range(cols):
            if a[y, x] < 60:
                l.append(' '); c.append('0'); continue
            l.append(RAMP[max(1, min(len(RAMP) - 1, int(lum[y, x] * len(RAMP))))])
            c.append('%x' % (qi[y, x] + 1))
        lines.append(''.join(l)); colors.append(''.join(c))
    return {'w': cols, 'h': rows, 'lines': lines, 'colors': colors}

def style_hires(cols):
    rows = max(1, round(cols * im.height / im.width * 0.5))
    small, a = cells(cols, rows * 2)
    qi = np.minimum(np.array(small.quantize(palette=q64, dither=Image.Dither.NONE)), len(pal64) - 1)
    lines, top, bot = [], [], []
    for y in range(rows):
        l, t, b = [], [], []
        for x in range(cols):
            ot, ob = a[2 * y, x] > 110, a[2 * y + 1, x] > 110
            if not ot and not ob:
                l.append(' '); t.append('0'); b.append('0')
            elif ot and ob:
                l.append('▀'); t.append(ALPH[qi[2 * y, x] + 1]); b.append(ALPH[qi[2 * y + 1, x] + 1])
            elif ot:
                l.append('▀'); t.append(ALPH[qi[2 * y, x] + 1]); b.append('0')
            else:
                l.append('▄'); t.append(ALPH[qi[2 * y + 1, x] + 1]); b.append('0')
        lines.append(''.join(l)); top.append(''.join(t)); bot.append(''.join(b))
    return {'w': cols, 'h': rows, 'lines': lines, 'colors': top, 'bg': bot}

SIZES = [16, 20, 24, 28, 32, 36, 40, 46, 52, 58, 64, 72, 80, 90, 100, 110, 120, 140, 160, 180, 200]
data = {
    'palette': palette,
    'palette64': ['000000'] + [hexs(c) for c in pal64],
    'alphabet': ALPH,
    'styles': {
        'face':  [style_face(c) for c in SIZES],
        'ascii': [style_ascii(c) for c in SIZES],
        'hires': [style_hires(c) for c in SIZES],
    },
}
json.dump(data, open(out, 'w'), ensure_ascii=False, separators=(',', ':'))
print('ok', {k: [(s['w'], s['h']) for s in v][:3] for k, v in data['styles'].items()})
