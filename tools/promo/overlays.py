"""Animated trailer overlays (title, kickers, name tags, CTA) as RGBA PNG sequences.

Every overlay is rendered per canvas ("h" = 1920x1080, "v" = 1080x1920) at 60 fps
so ffmpeg can composite it with `-framerate 60 -i seq/%04d.png`.
"""
from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FPS = 60
IMPACT = "C:/Windows/Fonts/impact.ttf"
BAHN = "C:/Windows/Fonts/bahnschrift.ttf"
GOLD_TOP = (255, 232, 140)
GOLD_BOTTOM = (214, 150, 40)
CYAN = (70, 220, 216)
RED = (240, 86, 107)
CANVAS = {"h": (1920, 1080), "v": (1080, 1920)}


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def ease_out_back(t: float) -> float:
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2


def ease_out(t: float) -> float:
    return 1 - (1 - t) ** 3


def text_layer(text: str, fnt: ImageFont.FreeTypeFont, fill, stroke=8, tracking=0, gradient=None, glow=None) -> Image.Image:
    """Render one line of text on a transparent, padded layer."""
    pad = stroke + 40
    widths = [fnt.getlength(c) + tracking for c in text]
    w = int(sum(widths)) + pad * 2
    asc, desc = fnt.getmetrics()
    h = asc + desc + pad * 2
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    x = pad
    for c, cw in zip(text, widths):
        md.text((x, pad), c, font=fnt, fill=255)
        x += cw
    if glow:
        halo = Image.new("RGBA", (w, h), glow + (0,))
        halo.putalpha(mask.filter(ImageFilter.GaussianBlur(18)).point(lambda v: min(255, v * 2)))
        layer.alpha_composite(halo)
    if stroke:
        outline = mask.filter(ImageFilter.MaxFilter(stroke * 2 + 1))
        dark = Image.new("RGBA", (w, h), (8, 10, 18, 255))
        dark.putalpha(outline)
        layer.alpha_composite(dark)
    if gradient:
        top, bottom = gradient
        grad = Image.new("RGBA", (w, h))
        gd = ImageDraw.Draw(grad)
        for y in range(h):
            t = y / max(1, h - 1)
            gd.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
        grad.putalpha(mask)
        layer.alpha_composite(grad)
    else:
        solid = Image.new("RGBA", (w, h), tuple(fill) + (255,))
        solid.putalpha(mask)
        layer.alpha_composite(solid)
    return layer.crop(layer.getbbox()) if layer.getbbox() else layer


def stack(layers: list[Image.Image], gap: int) -> Image.Image:
    w = max(l.width for l in layers)
    h = sum(l.height for l in layers) + gap * (len(layers) - 1)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for l in layers:
        out.alpha_composite(l, ((w - l.width) // 2, y))
        y += l.height + gap
    return out


def render_sequence(art: Image.Image, canvas: str, anchor: tuple[float, float], dur: float, outdir: str,
                    pop: float = 0.16, tail: float = 0.12, overshoot: bool = True, start_scale: float = 1.7, shake: float = 0.0) -> int:
    """Pop `art` in at `anchor` (fractions of the canvas), hold, then fade out. Returns frame count."""
    os.makedirs(outdir, exist_ok=True)
    cw, ch = CANVAS[canvas]
    frames = max(1, round(dur * FPS))
    for i in range(frames):
        t = i / FPS
        p = min(1.0, t / pop)
        k = ease_out_back(p) if overshoot else ease_out(p)
        scale = start_scale + (1.0 - start_scale) * k
        alpha = min(1.0, p * 1.6)
        remaining = dur - t
        if remaining < tail:
            alpha *= max(0.0, remaining / tail)
        frame = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        w, h = max(1, int(art.width * scale)), max(1, int(art.height * scale))
        scaled = art.resize((w, h), Image.LANCZOS)
        if alpha < 1.0:
            a = scaled.getchannel("A").point(lambda v, a=alpha: int(v * a))
            scaled.putalpha(a)
        dx = dy = 0
        if shake and t < 0.35:
            dx = int(math.sin(t * 90) * shake * (1 - t / 0.35))
            dy = int(math.cos(t * 70) * shake * 0.6 * (1 - t / 0.35))
        frame.alpha_composite(scaled, (int(cw * anchor[0] - w / 2) + dx, int(ch * anchor[1] - h / 2) + dy))
        frame.save(os.path.join(outdir, f"{i:04d}.png"))
    return frames


def title(canvas: str, outdir: str, dur: float = 1.5) -> int:
    big = 250 if canvas == "h" else 250
    art1 = text_layer("WORLD FIGHT", font(IMPACT, big), None, stroke=10, gradient=(GOLD_TOP, GOLD_BOTTOM), glow=(255, 170, 40))
    art2 = text_layer("ELECTION EDITION", font(IMPACT, big // 4), (240, 244, 246), stroke=4, tracking=int(big * 0.07))
    art = stack([art1, art2], 14)
    if canvas == "v" and art.width > 1000:
        art = art.resize((1000, int(art.height * 1000 / art.width)), Image.LANCZOS)
    return render_sequence(art, canvas, (0.5, 0.40 if canvas == "h" else 0.40), dur, outdir, shake=14)


def kicker(canvas: str, outdir: str, text: str, dur: float, anchor=None, color=CYAN, size=None) -> int:
    size = size or (96 if canvas == "h" else 104)
    art = text_layer(text, font(IMPACT, size), (245, 248, 250), stroke=6, tracking=4, glow=color)
    max_w = 1700 if canvas == "h" else 1000
    if art.width > max_w:
        art = art.resize((max_w, int(art.height * max_w / art.width)), Image.LANCZOS)
    anchor = anchor or ((0.5, 0.17) if canvas == "h" else (0.5, 0.2))
    return render_sequence(art, canvas, anchor, dur, outdir, pop=0.12, start_scale=1.35, overshoot=False)


def nametag(canvas: str, outdir: str, left: str, right: str, dur: float) -> int:
    """`LEFT  VS  RIGHT` lower-third in the fighter HUD colours."""
    size = 70 if canvas == "h" else 66
    a = text_layer(left, font(IMPACT, size), CYAN, stroke=5, tracking=3)
    v = text_layer("VS", font(IMPACT, int(size * 0.62)), GOLD_TOP, stroke=4, tracking=2)
    b = text_layer(right, font(IMPACT, size), RED, stroke=5, tracking=3)
    gap = 36
    row = Image.new("RGBA", (a.width + v.width + b.width + gap * 2, max(a.height, b.height)), (0, 0, 0, 0))
    row.alpha_composite(a, (0, (row.height - a.height) // 2))
    row.alpha_composite(v, (a.width + gap, (row.height - v.height) // 2))
    row.alpha_composite(b, (a.width + v.width + gap * 2, (row.height - b.height) // 2))
    max_w = 1500 if canvas == "h" else 1000
    if row.width > max_w:
        row = row.resize((max_w, int(row.height * max_w / row.width)), Image.LANCZOS)
    anchor = (0.5, 0.86) if canvas == "h" else (0.5, 0.78)
    return render_sequence(row, canvas, anchor, dur, outdir, pop=0.1, start_scale=1.25, overshoot=False)


def cta(canvas: str, outdir: str, dur: float, url: str) -> int:
    f1 = 150 if canvas == "h" else 140
    l1 = text_layer("PLAY FREE", font(IMPACT, f1), None, stroke=9, gradient=(GOLD_TOP, GOLD_BOTTOM), glow=(255, 170, 40))
    l2 = text_layer("IN YOUR BROWSER", font(IMPACT, int(f1 * 0.5)), (240, 244, 246), stroke=5, tracking=6)
    l3 = text_layer(url, font(BAHN, 60 if canvas == "h" else 46), CYAN, stroke=3)
    art = stack([l1, l2, l3], 22)
    if art.width > (1500 if canvas == "h" else 1000):
        w = 1500 if canvas == "h" else 1000
        art = art.resize((w, int(art.height * w / art.width)), Image.LANCZOS)
    n = render_sequence(art, canvas, (0.5, 0.46 if canvas == "h" else 0.42), dur, outdir + "_main", pop=0.2, tail=0.0)
    return n


def disclaimer(canvas: str, outdir: str, dur: float) -> int:
    lines = ["SATIRE  ·  FICTIONAL CARICATURES  ·  NOT AFFILIATED WITH ANY PARTY OR CANDIDATE", "CHARACTERS AND EVENTS ARE INVENTED FOR ENTERTAINMENT"]
    size = 28 if canvas == "h" else 25
    layers = [text_layer(t, font(BAHN, size), (225, 232, 236), stroke=2) for t in lines]
    art = stack(layers, 8)
    max_w = 1700 if canvas == "h" else 1000
    if art.width > max_w:
        art = art.resize((max_w, int(art.height * max_w / art.width)), Image.LANCZOS)
    return render_sequence(art, canvas, (0.5, 0.93 if canvas == "h" else 0.9), dur, outdir, pop=0.2, tail=0.0, overshoot=False, start_scale=1.0)
