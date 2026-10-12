#!/usr/bin/env python3
"""karin-shell intro: анимированная заставка из символов перед запуском Hyprland.

Эффекты: decrypt (расшифровка), matrix (дождь), scan (построчная развёртка).
Работает и в голом TTY (TERM=linux: своя палитра из 16 цветов), и в kitty (truecolor).
Любая клавиша — пропустить. Только стандартная библиотека Python.
"""
import argparse, json, os, random, select, shutil, sys, termios, time, tty

HERE = os.path.dirname(os.path.abspath(__file__))
GLYPHS = "!#$%&*+<>?/\\|{}[]=~^01KARIN"
FPS = 30

LOGO_FONT = {
    "K": ["██  ██", "██ ██ ", "████  ", "██ ██ ", "██  ██"],
    "A": [" ████ ", "██  ██", "██████", "██  ██", "██  ██"],
    "R": ["█████ ", "██  ██", "█████ ", "██ ██ ", "██  ██"],
    "I": ["██████", "  ██  ", "  ██  ", "  ██  ", "██████"],
    "N": ["██  ██", "███ ██", "██████", "██ ███", "██  ██"],
}


def logo_lines(word="KARIN"):
    return ["  ".join(LOGO_FONT[ch][r] for ch in word) for r in range(5)]


class Screen:
    def __init__(self, palette):
        self.tty = os.environ.get("TERM") == "linux"
        self.palette = palette
        self.buf = []
        self.cols, self.rows = shutil.get_terminal_size((80, 25))
        self.glyphs = GLYPHS

    def _rgb(self, h):
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

    def color(self, fg, bg=None):
        """fg/bg: индекс палитры (int) или hex-строка 'rrggbb' (только truecolor)."""
        if self.tty:
            idx = fg if isinstance(fg, int) else 15
            return "\033[0;3%dm" % idx if idx < 8 else "\033[1;3%dm" % (idx - 8)
        if isinstance(fg, int):
            fg = self.palette[fg]
        out = "\033[0m\033[38;2;%d;%d;%dm" % self._rgb(fg)
        if bg:
            out += "\033[48;2;%d;%d;%dm" % self._rgb(bg)
        return out

    def put(self, x, y, ch, fg, bg=None):
        if 0 <= x < self.cols and 0 <= y < self.rows:
            self.buf.append("\033[%d;%dH%s%s" % (y + 1, x + 1, self.color(fg, bg), ch))

    def flush(self):
        if self.buf:
            sys.stdout.write("".join(self.buf))
            sys.stdout.flush()
            self.buf = []

    def start(self):
        out = "\033[?25l\033[0m\033[2J"
        if self.tty:  # подменяем 16 цветов консоли на палитру Карин
            out += "".join("\033]P%x%s" % (i, h) for i, h in enumerate(self.palette))
            out += "\033[2J"
        sys.stdout.write(out)
        sys.stdout.flush()

    def stop(self, clear=True):
        out = "\033[0m"
        if self.tty:
            out += "\033]R"  # вернуть стандартную палитру консоли
        if clear:
            out += "\033[2J\033[H"
        sys.stdout.write(out + "\033[?25h")
        sys.stdout.flush()


class Keys:
    """Неблокирующее чтение клавиатуры: любая клавиша пропускает заставку."""
    def __enter__(self):
        self.fd = sys.stdin.fileno() if sys.stdin.isatty() else None
        if self.fd is not None:
            self.old = termios.tcgetattr(self.fd)
            tty.setcbreak(self.fd)
        return self

    def pressed(self):
        if self.fd is None:
            return False
        r, _, _ = select.select([sys.stdin], [], [], 0)
        if r:
            os.read(self.fd, 64)
            return True
        return False

    def __exit__(self, *a):
        if self.fd is not None:
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.old)


SUBTITLE = "karin-shell by detestern"


def build_scene(scr, art, style):
    """Целевая картинка: портрет + KARIN + подпись. Возвращает dict (x,y)->(ch, fg, bg)."""
    if scr.tty and style == "hires":
        style = "face"  # в голом TTY нет truecolor и ярких фонов
    logo = logo_lines()
    reserve = len(logo) + 4                       # пустая строка, логотип, пустая, подпись
    sizes = art["styles"][style]
    fit = [s for s in sizes if s["w"] <= scr.cols - 2 and s["h"] <= scr.rows - reserve]
    size = fit[-1] if fit else sizes[0]          # картинка есть всегда, хоть самая маленькая
    total_h = size["h"] + 1 + len(logo) + 2
    top = max(0, (scr.rows - total_h) // 2)
    ox = (scr.cols - size["w"]) // 2
    alph = art.get("alphabet", "")
    pal64 = art.get("palette64", [])
    cells = {}
    for y in range(size["h"]):
        line, fgs = size["lines"][y], size["colors"][y]
        bgs = size.get("bg", [None] * size["h"])[y]
        for x, ch in enumerate(line):
            if ch == " ":
                continue
            if style == "hires":
                fg = pal64[alph.index(fgs[x])]
                b = bgs[x]
                bg = pal64[alph.index(b)] if b != "0" else None
                cells[(ox + x, top + y)] = (ch, fg, bg)
            else:
                cells[(ox + x, top + y)] = (ch, int(fgs[x], 16), None)
    top += size["h"] + 1
    lx = (scr.cols - len(logo[0])) // 2
    for y, line in enumerate(logo):
        for x, ch in enumerate(line):
            if ch != " ":
                cells[(lx + x, top + y)] = (ch, 15, None)
    sub_pos = ((scr.cols - len(SUBTITLE)) // 2, top + len(logo) + 1)
    return cells, SUBTITLE, sub_pos


def typewriter(scr, keys, text, pos, idx, delay=0.025):
    x, y = pos
    for i, ch in enumerate(text):
        scr.put(x + i, y, ch, idx)
        scr.put(x + i + 1, y, "▌", 15)
        scr.flush()
        if keys.pressed():
            return True
        time.sleep(delay)
    scr.put(x + len(text), y, " ", 0)
    scr.flush()
    return False


def dim_idx(palette):
    """Самый тёмный ненулевой цвет палитры — для «шума»."""
    return min(range(1, 15), key=lambda i: sum(int(palette[i][k:k + 2], 16) for k in (0, 2, 4)))


def fx_decrypt(scr, keys, cells):
    noise = dim_idx(scr.palette)
    pts = list(cells)
    t_rev = {p: 0.15 + random.random() * 1.2 + (p[1] / max(1, scr.rows)) * 0.6 for p in pts}
    for p in pts:
        scr.put(p[0], p[1], random.choice(scr.glyphs), noise)
    scr.flush()
    t0 = time.time()
    pending = set(pts)
    while pending:
        t = time.time() - t0
        done = [p for p in pending if t_rev[p] <= t]
        for p in done:
            ch, fg, bg = cells[p]
            scr.put(p[0], p[1], ch, fg, bg)
            pending.discard(p)
        for p in random.sample(sorted(pending), min(len(pending), 250)):
            scr.put(p[0], p[1], random.choice(scr.glyphs), random.choice((noise, 15)))
        scr.flush()
        if keys.pressed():
            return True
        time.sleep(1 / FPS)
    return False


def fx_matrix(scr, keys, cells):
    trail = 8
    xs = sorted({p[0] for p in cells})
    xmin, xmax = (xs[0], xs[-1]) if xs else (0, scr.cols - 1)
    cols = [x for x in range(scr.cols) if xmin - 6 <= x <= xmax + 6 or x % 3 == 0]
    start = {x: random.random() * 1.0 for x in cols}
    speed = {x: random.uniform(30, 55) for x in cols}  # строк в секунду
    head_prev = {x: -1 for x in cols}
    t0 = time.time()
    end_row = scr.rows + trail
    while True:
        t = time.time() - t0
        alive = False
        for x in cols:
            h = int((t - start[x]) * speed[x])
            if h < 0:
                alive = True
                continue
            if head_prev[x] >= end_row:
                continue
            alive = True
            for y in range(max(0, head_prev[x] - trail), min(scr.rows, h + 1)):
                d = h - y
                if d == 0:
                    scr.put(x, y, random.choice(scr.glyphs), 1)
                elif d < trail:
                    tgt = cells.get((x, y))
                    if tgt and d > trail // 2:
                        scr.put(x, y, *tgt)
                    else:
                        scr.put(x, y, random.choice(scr.glyphs), 15 if d < 3 else dim_idx(scr.palette))
                else:
                    tgt = cells.get((x, y))
                    if tgt:
                        scr.put(x, y, *tgt)
                    else:
                        scr.put(x, y, " ", 0)
            head_prev[x] = h
        scr.flush()
        if keys.pressed():
            return True
        if not alive:
            break
        time.sleep(1 / FPS)
    for (x, y), v in cells.items():  # добить пропущенные клетки
        scr.put(x, y, *v)
    scr.flush()
    return False


def fx_scan(scr, keys, cells):
    rows = sorted({p[1] for p in cells})
    if not rows:
        return False
    by_row = {}
    for (x, y), v in cells.items():
        by_row.setdefault(y, []).append((x, v))
    xs = [p[0] for p in cells]
    x0, x1 = min(xs) - 2, max(xs) + 2
    prev_beam = None
    for y in range(rows[0], rows[-1] + 2):
        if prev_beam is not None:
            for x in range(x0, x1 + 1):
                scr.put(x, prev_beam, " ", 0)
            for x, v in by_row.get(prev_beam, []):
                scr.put(x, prev_beam, *v)
        if y <= rows[-1]:
            for x in range(x0, x1 + 1):
                scr.put(x, y, "▀" if random.random() > 0.08 else random.choice(scr.glyphs), 15)
            prev_beam = y
        scr.flush()
        if keys.pressed():
            return True
        time.sleep(0.035)
    return False


EFFECTS = {"decrypt": fx_decrypt, "matrix": fx_matrix, "scan": fx_scan}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--effect", default="decrypt", choices=list(EFFECTS) + ["random"])
    ap.add_argument("--art", default=os.path.join(HERE, "arts", "laptop.json"))
    ap.add_argument("--style", default="face", choices=["face", "ascii", "hires"],
                    help="face — пиксельный портрет, ascii — из символов, hires — полублоки (только kitty)")
    ap.add_argument("--hold", type=float, default=1.2, help="пауза на финальном кадре, сек")
    ap.add_argument("--keep", action="store_true", help="не очищать экран в конце (для демо)")
    args = ap.parse_args()

    art = json.load(open(args.art))
    scr = Screen(art["palette"])
    cells, sub, sub_pos = build_scene(scr, art, args.style)
    effect = random.choice(list(EFFECTS)) if args.effect == "random" else args.effect
    scr.start()
    try:
        with Keys() as keys:
            skipped = EFFECTS[effect](scr, keys, cells)
            if not skipped:
                skipped = typewriter(scr, keys, sub, sub_pos, 1)
            if not skipped:
                t_end = time.time() + args.hold
                while time.time() < t_end and not keys.pressed():
                    time.sleep(0.05)
    except KeyboardInterrupt:
        pass
    finally:
        if args.keep:
            sys.stdout.write("\033[%d;1H" % scr.rows)
        scr.stop(clear=not args.keep)


if __name__ == "__main__":
    main()
