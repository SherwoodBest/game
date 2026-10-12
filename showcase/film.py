#!/usr/bin/env python3
"""SEED: a 48-second film generated entirely from code.

Every frame and every audio sample is computed in this file. There is no
footage, no sample library and no image asset; the only inputs are system
fonts. Needs numpy, Pillow and ffmpeg.

    python3 showcase/film.py            # renders showcase/seed.mp4
    python3 showcase/film.py --stills   # a few test frames per scene
"""
import math
import os
import subprocess
import sys
import tempfile
import wave
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FPS = 1280, 720, 30
ASPECT = W / H
SR = 44100
BPM = 90
BEAT = 60 / BPM
BAR = 4 * BEAT
TOTAL = 48.0
# (name, global start, global end); neighbours overlap by one second and crossfade.
SCENES = [("point", 0, 5), ("bloom", 4, 14), ("flow", 13, 23),
          ("land", 22, 32), ("julia", 31, 41), ("finale", 40, 48)]
FLASH = 64 * BEAT  # 42.667s: everything collapses back into a point

FONT_DIR = "/usr/share/fonts/opentype/inter/"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

GA = math.pi * (3 - math.sqrt(5))  # the golden angle, 137.508 degrees
N_BLOOM = 2000
C_BLOOM = 0.66 / math.sqrt(N_BLOOM)
CY = 0.05  # the seed sits a little above centre, clear of the captions

# One palette for the whole film: gold, coral, rose, violet, blue, teal.
STOPS = np.array([[1.00, 0.86, 0.55], [1.00, 0.56, 0.36], [0.93, 0.34, 0.55],
                  [0.58, 0.36, 0.88], [0.27, 0.55, 0.95], [0.30, 0.86, 0.80]],
                 np.float32)


def palette(u):
    u = np.clip(np.asarray(u, np.float32), 0, 1) * (len(STOPS) - 1)
    i = np.minimum(u.astype(int), len(STOPS) - 2)
    f = (u - i)[..., None]
    return STOPS[i] * (1 - f) + STOPS[i + 1] * f


def palette_cyc(u):
    s = np.vstack([STOPS, STOPS[:1]])
    u = (np.asarray(u, np.float32) % 1.0) * (len(s) - 1)
    i = np.minimum(u.astype(int), len(s) - 2)
    f = (u - i)[..., None]
    return s[i] * (1 - f) + s[i + 1] * f


YS, XS = np.mgrid[0:H, 0:W].astype(np.float32)
X = (XS - W / 2) / (H / 2)          # x in [-1.78, 1.78]
Y = (H / 2 - YS) / (H / 2)          # y in [-1, 1], up is positive
R2 = X * X + (Y - CY) ** 2
BG = (np.array([0.010, 0.012, 0.026], np.float32)
      * (1 + 1.2 * np.exp(-R2 / 0.9))[..., None])
VIG = (1 - 0.30 * ((X / ASPECT) ** 2 + Y ** 2) * 0.6)[..., None]
BLOOM_COLS = palette(np.arange(N_BLOOM) / N_BLOOM)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def fade(t, t0, t1, f=0.8):
    return float(smoothstep(t0, t0 + f, t) * (1 - smoothstep(t1 - f, t1, t)))


def pulse(tg, start, end, decay=0.12, period=BEAT):
    if tg < start or tg >= end:
        return 0.0
    return math.exp(-((tg - start) % period) / decay)


# ---------------------------------------------------------------- text ----
_text_cache = {}


def text_mask(lines):
    key = tuple(lines)
    if key in _text_cache:
        return _text_cache[key]
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for text, fname, size, yc, track in lines:
        f = ImageFont.truetype(MONO if fname == "mono" else FONT_DIR + fname, size)
        asc, desc = f.getmetrics()
        y = yc - (asc + desc) / 2
        if track == 0:
            d.text(((W - f.getlength(text)) / 2, y), text, font=f, fill=255)
            continue
        widths = [f.getlength(ch) for ch in text]
        x = (W - sum(widths) - track * (len(text) - 1)) / 2
        for ch, w in zip(text, widths):
            d.text((x, y), ch, font=f, fill=255)
            x += w + track
    a = np.asarray(im, np.float32)[..., None] / 255
    sh = np.asarray(im.filter(ImageFilter.GaussianBlur(9)), np.float32)[..., None] / 255
    _text_cache[key] = (a, np.minimum(sh * 2.5, 1))
    return _text_cache[key]


def put_text(img, lines, op, color=(1.0, 0.97, 0.92)):
    if op <= 0.002:
        return img
    a, sh = text_mask(lines)
    img = img * (1 - 0.6 * sh * op)
    return img * (1 - a * op) + np.array(color, np.float32) * a * op


def caption(img, t, text, t0, t1):
    return put_text(img, ((text, "Inter-Light.otf", 34, int(H * 0.86), 1),),
                    fade(t, t0, t1))


# ---------------------------------------------------------------- post ----
def post(img, seed):
    small = img.reshape(H // 4, 4, W // 4, 4, 3).mean((1, 3))
    br = np.clip(small - 0.5, 0, 2)
    b = Image.fromarray((br * 127).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))
    bloom = np.asarray(b.resize((W, H), Image.BILINEAR), np.float32) / 127
    img = (img + bloom * 0.7) * VIG
    knee = 0.8
    img = np.where(img > knee, knee + (1 - knee) * np.tanh((img - knee) / (1 - knee)), img)
    rng = np.random.default_rng(seed)
    img = img + rng.standard_normal((H, W, 1), dtype=np.float32) * 0.009
    return (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)


def splat(img, x, y, rad, color, amp):
    """Additive gaussian blob at normalized coords."""
    cx, cy = W / 2 + x * H / 2, H / 2 - y * H / 2
    r = int(rad * 3) + 1
    x0, x1 = max(int(cx) - r, 0), min(int(cx) + r + 1, W)
    y0, y1 = max(int(cy) - r, 0), min(int(cy) + r + 1, H)
    if x0 >= x1 or y0 >= y1:
        return
    gx = np.arange(x0, x1) - cx
    gy = np.arange(y0, y1) - cy
    g = np.exp(-(gy[:, None] ** 2 + gx[None, :] ** 2) / (2 * rad * rad)) * amp
    img[y0:y1, x0:x1] += g[..., None] * np.asarray(color, np.float32)


# ------------------------------------------------------------- scene 0 ----
_rs = np.random.default_rng(11)
DUST = np.c_[_rs.uniform(0, W, 260), _rs.uniform(0, H, 260),
             _rs.uniform(0.02, 0.10, 260), _rs.uniform(0, 6.3, 260)]


def seed_glow(r2, intensity, breath):
    core = np.exp(-r2 / (2 * 0.0055 ** 2)) * 2.2
    halo = 0.05 * breath / (1 + r2 / 0.0025) + 0.22 * breath * np.exp(-r2 / 0.012)
    return intensity * (core[..., None] * np.array([1, 0.97, 0.9], np.float32)
                        + halo[..., None] * np.array([1, 0.70, 0.38], np.float32))


def r_point(t, tg):
    img = BG.copy()
    tw = DUST[:, 2] * (0.6 + 0.4 * np.sin(1.3 * t + DUST[:, 3])) * smoothstep(0.5, 3, t)
    img[DUST[:, 1].astype(int), DUST[:, 0].astype(int)] += tw[:, None] * np.array([0.8, 0.85, 1.0])
    breath = 1 + 0.2 * math.sin(2 * math.pi * t / (2 * BEAT))
    img += seed_glow(R2, float(smoothstep(0.3, 1.6, t)), breath)
    img = caption(img, t, "Every world begins as a single point.", 1.1, 4.5)
    return img * float(smoothstep(0, 0.8, t))


# ------------------------------------------------------------- scene 1 ----
def _appear_times():
    e = BEAT / 2
    k = np.arange(N_BLOOM, dtype=np.float64)
    u = np.sqrt(np.clip((k - 8) / (N_BLOOM - 8), 0, 1))
    return np.where(k < 8, k * e, 8 * e + 5.6 * u)


APPEAR = _appear_times()


def draw_bloom(cx, cy, z, rot, size_mul, bright, extra=None, counter=None):
    """Phyllotaxis: point k sits at angle k*GA, radius c*sqrt(k)."""
    cv = Image.new("RGB", (2 * W, 2 * H), 0)
    d = ImageDraw.Draw(cv)
    k = np.arange(N_BLOOM)
    r = C_BLOOM * np.sqrt(k + 0.5) * z
    th = k * GA + rot
    px = W + (cx + r * np.cos(th)) * H
    py = H - (cy + r * np.sin(th)) * H
    rad = z * C_BLOOM * 0.62 * (0.75 + 0.35 * np.sqrt(k / N_BLOOM)) * size_mul * H
    col = BLOOM_COLS * bright[:, None]
    if extra is not None:
        col = col + extra[:, None] * np.array([1, 0.95, 0.85])
    col = np.clip(col * 255, 0, 255).astype(int)
    for i in np.nonzero(rad > 0.3)[0]:
        q = rad[i]
        d.ellipse((px[i] - q, py[i] - q, px[i] + q, py[i] + q), fill=tuple(col[i]))
    if counter:
        f = ImageFont.truetype(MONO, 30)
        for j, (s, g) in enumerate(counter):
            d.text((80, 64 + j * 44), s, font=f, fill=(g, g, g))
    return np.asarray(cv.reduce(2), np.float32) / 255


def bloom_state(t):
    n = float(np.interp(t, APPEAR, np.arange(N_BLOOM) + 1, left=0))
    z = min(4.5, 0.66 / (C_BLOOM * math.sqrt(n + 0.5)))
    return n, z, 0.12 * t


def ease_out_back(x):
    c = 1.9
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


def r_bloom(t, tg):
    n, z, rot = bloom_state(t)
    age = t - APPEAR
    pop = np.where(age < 0, 0, ease_out_back(np.clip(age / 0.35, 0, 1)))
    beat = pulse(tg, 4.0, 14.0, 0.10, BEAT / 2)
    k = np.arange(N_BLOOM)
    # light up the 21 spiral arms (a Fibonacci number) one per eighth note
    j = int((tg - 4.0) / (BEAT / 2))
    arm = np.exp(-((j - k) % 21) / 1.6) * fade(t, 4.6, 9.8, 0.8)
    bright = 0.85 + 0.5 * arm
    op = int(160 * fade(t, 0.3, 9.6, 0.6))
    nv = int(np.sum(age >= 0))
    img = draw_bloom(0, CY, z, rot, pop * (1 + 0.10 * beat), bright, arm * 0.35,
                     [(f"n = {nv:4d}", op), ("θ = 137.508°", op)])
    img += BG + seed_glow(R2, 0.5 * (1 - smoothstep(0, 2, t)), 1)
    img = caption(img, t, "Add one rule: turn 137.5°, step outward.", 0.8, 4.7)
    img = caption(img, t, "Spirals appear that nobody drew.", 5.2, 9.3)
    return img


# ------------------------------------------------------------- scene 2 ----
_rf = np.random.default_rng(5)
_kmag = _rf.uniform(1.0, 3.2, 6)
_kdir = _rf.uniform(0, 2 * math.pi, 6)
FIELD = np.c_[_kmag * np.cos(_kdir), _kmag * np.sin(_kdir),
              _rf.uniform(0.15, 0.5, 6), _rf.uniform(0, 6.3, 6)]


def field_angle(x, y, t):
    s = np.zeros_like(x)
    for kx, ky, w, ph in FIELD:
        s += np.sin(kx * x + ky * y + w * t + ph)
    return s * (math.pi * 1.2 / 3) + 0.3 * t


def flow_frames(nframes):
    rng = np.random.default_rng(3)
    _, z, rot = bloom_state(9.0)
    k = np.arange(N_BLOOM)
    r = C_BLOOM * np.sqrt(k + 0.5) * z
    th = k * GA + rot
    K = 7
    px = np.repeat(r * np.cos(th), K) + rng.normal(0, 0.004, N_BLOOM * K)
    py = CY + np.repeat(r * np.sin(th), K) + rng.normal(0, 0.004, N_BLOOM * K)
    col = np.repeat(BLOOM_COLS, K, axis=0) * rng.uniform(0.8, 1.15, (N_BLOOM * K, 1))
    npart = len(px)
    buf = np.zeros((H * W, 3), np.float32)
    sub = 4
    dt = 1 / (FPS * sub)
    for f in range(nframes):
        t = f / FPS
        tg = 13 + t
        spd = 0.40 * float(smoothstep(0.2, 2.2, t))
        swirl = 1.0 * math.exp(-t / 2.5) * float(smoothstep(0.0, 1.0, t))
        buf *= 0.93
        w = 0.22 * (1 + 1.2 * pulse(tg, 20 * BEAT, 34 * BEAT, 0.10))
        for s in range(sub):
            a = field_angle(px, py, t + s * dt)
            vx = spd * np.cos(a) - swirl * (py - CY)
            vy = spd * np.sin(a) + swirl * px
            px = px + vx * dt
            py = py + vy * dt
            # the field is not periodic, so wrapping would pile particles up on the
            # seams; anything that leaves the frame is reborn somewhere inside it
            out = (np.abs(px) >= ASPECT) | (np.abs(py) >= 1)
            px[out] = rng.uniform(-ASPECT, ASPECT, out.sum())
            py[out] = rng.uniform(-1, 1, out.sum())
            ix = (px * H / 2 + W / 2).astype(int)
            iy = (H / 2 - py * H / 2).astype(int)
            ok = (ix >= 0) & (ix < W) & (iy >= 0) & (iy < H)
            idx = iy[ok] * W + ix[ok]
            for c in range(3):
                buf[:, c] += np.bincount(idx, weights=col[ok, c] * w, minlength=H * W)
        m = rng.random(npart) < 0.0015 * float(smoothstep(1, 3, t))
        px[m] = rng.uniform(-ASPECT, ASPECT, m.sum())
        py[m] = rng.uniform(-1, 1, m.sum())
        img = 1 - np.exp(-buf.reshape(H, W, 3) * 1.1 * (1 + 0.9 * float(smoothstep(3, 8, t))))
        img += BG
        img = caption(img, t, "Set them loose on an invisible wind,", 0.9, 4.7)
        img = caption(img, t, "and motion becomes weather.", 5.2, 9.3)
        yield img


# ------------------------------------------------------------- scene 3 ----
_rn = np.random.default_rng(7)
NOISE = _rn.random(4096).astype(np.float32)


def vnoise(x):
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    a = NOISE[i % 4096]
    b = NOISE[(i + 1) % 4096]
    return a + (b - a) * f


def fbm(x, octaves=6, ridged=False):
    s, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        n = vnoise(x * 2 ** o + 17.3 * o)
        if ridged:
            n = 1 - abs(2 * n - 1)
        s = s + amp * n
        norm += amp
        amp *= 0.5
    return s / norm


STARS = np.c_[_rn.uniform(0, W, 420), _rn.uniform(0, H * 0.55, 420),
              _rn.uniform(0.15, 1.0, 420) ** 2, _rn.uniform(0, 6.3, 420)]
FIREFLIES = np.c_[_rn.uniform(-ASPECT, ASPECT, 46), _rn.uniform(0, 1, 46),
                  _rn.uniform(0.04, 0.09, 46), _rn.uniform(0, 6.3, 46)]
# melody note times (global beats) -> a new star is born on each note
MELODY = [(36, 78, 2), (38, 81, 1), (39, 76, 1), (40, 74, 3), (43, 76, 1),
          (44, 78, 2), (46, 81, 1), (47, 83, 1), (48, 81, 4)]
LAYERS = [  # base v, amplitude, frequency, ridged, scroll speed, colour
    (0.52, 0.20, 2.2, True, 0.010, (0.58, 0.34, 0.46)),
    (0.58, 0.13, 2.8, True, 0.020, (0.42, 0.24, 0.40)),
    (0.66, 0.10, 2.4, False, 0.035, (0.27, 0.15, 0.30)),
    (0.74, 0.08, 2.0, False, 0.055, (0.15, 0.08, 0.20)),
    (0.83, 0.07, 1.6, False, 0.085, (0.07, 0.04, 0.11)),
    (0.92, 0.05, 1.3, False, 0.130, (0.02, 0.015, 0.04)),
]


def r_land(t, tg):
    v = YS / H
    u = XS[0] / W
    dusk = t / 10
    top = np.array([0.03, 0.035, 0.10])
    mid = np.array([0.36, 0.17, 0.38])
    hor = np.array([1.00, 0.58, 0.36]) * (1 - 0.30 * dusk)
    g = np.clip(v / 0.62, 0, 1)[..., None]
    sky = np.where(g < 0.55, top + (mid - top) * (g / 0.55),
                   mid + (hor - mid) * np.clip((g - 0.55) / 0.45, 0, 1) ** 1.3).astype(np.float32)
    # sun, setting behind the far range
    sx, sy = 0.63 * W, (0.40 + 0.11 * dusk) * H
    d2 = ((XS - sx) ** 2 + (YS - sy) ** 2) / (H * H)
    sun = (smoothstep(0.0036, 0.0030, d2) * 1.6 + 0.35 * np.exp(-d2 / 0.006)
           + 0.25 * np.exp(-d2 / 0.05))[..., None] * np.array([1, 0.78, 0.5], np.float32)
    img = sky + sun
    # stars come out as it gets dark
    sa = STARS[:, 2] * (0.7 + 0.3 * np.sin(3 * t + STARS[:, 3])) * float(smoothstep(2, 8, t))
    sa = sa * (1 - STARS[:, 1] / (H * 0.6))
    img[STARS[:, 1].astype(int), STARS[:, 0].astype(int)] += sa[:, None] * 0.9
    for beat, midi, _ in MELODY:
        age = tg - beat * BEAT
        if 0 <= age < 4:
            rs = np.random.default_rng(midi * 31 + beat)
            splat(img, rs.uniform(-1.4, 1.4), rs.uniform(0.45, 0.9), 2.2,
                  (1, 0.95, 0.85), 1.4 * math.exp(-age / 0.5) + 0.4 * float(smoothstep(0, 0.2, age)))
    haze = np.array([0.95, 0.56, 0.48]) * (1 - 0.35 * dusk)
    for i, (base, amp, freq, ridged, speed, colr) in enumerate(LAYERS):
        x = u * freq * ASPECT + speed * t * 6 + 40 * i
        ridge = base - amp * (fbm(x, 6, ridged) - 0.35)
        inside = v > ridge[None, :]
        depth = i / (len(LAYERS) - 1)
        mist = (0.55 - 0.45 * depth) * smoothstep(0, 0.16, v - ridge[None, :])
        c = np.array(colr) * (1 - 0.25 * dusk)
        layer = c + (haze * (0.75 - 0.5 * depth) - c) * mist[..., None]
        img = np.where(inside[..., None], layer, img).astype(np.float32)
    for x0, y0, sp, ph in FIREFLIES:
        y = -1 + ((y0 + sp * t) % 1.0) * 1.3
        x = x0 + 0.04 * math.sin(1.7 * t + ph)
        a = (0.5 + 0.5 * math.sin(5 * t + 3 * ph)) * float(smoothstep(0.5, 2.5, t))
        splat(img, x, y, 2.5, (1, 0.8, 0.4), 0.9 * a)
    img = caption(img, t, "Give it time, and weather carves a horizon.", 1.0, 9.2)
    return img


# ------------------------------------------------------------- scene 4 ----
def r_julia(t, tg):
    a = 2.62 + 0.055 * t
    c = 0.7885 * complex(math.cos(a), math.sin(a))
    zoom = math.exp(0.11 * t)
    rot = 0.05 * t
    zc = (X + 1j * Y).astype(np.complex64) * np.complex64(1.05 / zoom * complex(math.cos(rot), math.sin(rot)))
    z = zc.ravel()
    out = np.full(z.shape, -1.0, np.float32)
    trap = np.full(z.shape, 9.0, np.float32)
    idx = np.arange(z.size)
    maxit = 140
    for it in range(maxit):
        z = z * z + c
        mag = (z.real * z.real + z.imag * z.imag)
        trap[idx] = np.minimum(trap[idx], np.abs(z.real))
        esc = mag > 256
        if esc.any():
            out[idx[esc]] = it + 1 - np.log2(np.log2(mag[esc]) / 2)
            keep = ~esc
            z, idx = z[keep], idx[keep]
        if z.size == 0:
            break
    out = out.reshape(H, W)
    trap = trap.reshape(H, W)
    inside = out < 0
    s = np.where(inside, 0, out)
    col = palette_cyc(s * 0.045 + 0.08 * t)
    glow = (1 - np.exp(-s / 9))[..., None]
    img = col * glow
    inner = (np.array([0.05, 0.03, 0.12]) + np.array([0.5, 0.35, 0.9])
             * np.exp(-trap * 14)[..., None] * 0.5)
    img = np.where(inside[..., None], inner, img).astype(np.float32)
    img *= 1 + 0.08 * pulse(tg, 46 * BEAT, 60 * BEAT, 0.15, BAR / 4)
    img = caption(img, t, "Look closer: every edge hides another world.", 1.0, 9.2)
    return img


# ------------------------------------------------------------- scene 5 ----
def r_finale(t, tg):
    tf = FLASH - 40
    u = float(smoothstep(0, tf, t))
    cy = CY + 0.17 * u
    img = BG.copy()
    if t < tf:
        m = (1 - u) ** 1.4
        rot = 0.12 * 9 + 3.2 * u * u
        img += draw_bloom(0, cy, m, rot, np.full(N_BLOOM, 0.5 + 0.5 * m),
                          np.full(N_BLOOM, 0.9 + 0.8 * u))
    r2 = X * X + (Y - cy) ** 2
    pre = float(smoothstep(tf - 1.2, tf, t))
    post_ = 2.5 * math.exp(-(t - tf) / 0.5) + 0.9 if t >= tf else 0
    img += seed_glow(r2, pre * 0.8 + post_, 1 + 0.15 * math.sin(2 * math.pi * t / (2 * BEAT)))
    if t >= tf:
        rr = (t - tf) * 1.1
        ring = np.exp(-((np.sqrt(r2) - rr) / 0.012) ** 2) * math.exp(-(t - tf) / 0.8) * 1.4
        img += ring[..., None] * np.array([1, 0.8, 0.6], np.float32)
        img += (2.0 * math.exp(-(t - tf) / 0.12)) * np.array([1, 0.9, 0.8], np.float32) * 0.5
    img = put_text(img, (("SEED", "Inter-Thin.otf", 132, int(H * 0.60), 44),), fade(t, tf + 0.5, 9, 1.0))
    img = put_text(img, (("A SHORT FILM MADE ENTIRELY FROM CODE", "Inter-Light.otf", 19, int(H * 0.73), 5),),
                   fade(t, tf + 1.2, 9, 1.0), (0.85, 0.82, 0.78))
    img = put_text(img, (("Visuals, music and words generated by Claude", "Inter-ExtraLightItalic.otf", 24, int(H * 0.78), 1),),
                   fade(t, tf + 1.7, 9, 1.0), (1.0, 0.80, 0.55))
    return img * (1 - float(smoothstep(6.6, 7.9, t)))


RENDER = {"point": r_point, "bloom": r_bloom, "land": r_land, "julia": r_julia, "finale": r_finale}


# ---------------------------------------------------------------- audio ----
def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


CHORDS = {
    "Dmaj9": [50, 57, 61, 64, 66], "Bm11": [47, 54, 57, 62, 64],
    "Gmaj7#11": [43, 50, 54, 57, 61], "Asus4": [45, 52, 57, 62, 64],
    "Em9": [40, 55, 59, 62, 66], "F#m7": [42, 52, 57, 61, 64],
}
PROG = ["Dmaj9", "Dmaj9", "Bm11", "Gmaj7#11", "Dmaj9", "Asus4", "Em9", "Gmaj7#11", "Bm11",
        "Asus4", "Gmaj7#11", "Dmaj9", "Em9", "F#m7", "Gmaj7#11", "Asus4", "Dmaj9", "Dmaj9"]


class Mix:
    def __init__(self):
        n = int((TOTAL + 1) * SR)
        self.dry = np.zeros((2, n))
        self.send = np.zeros((2, n))

    def add(self, t0, sig, pan=0.0, gain=1.0, wet=0.5):
        i = int(t0 * SR)
        if i >= self.dry.shape[1]:
            return
        sig = sig[: self.dry.shape[1] - i] * gain
        lr = np.array([math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)])
        self.dry[:, i:i + len(sig)] += lr[:, None] * sig * (1 - wet * 0.5)
        self.send[:, i:i + len(sig)] += lr[:, None] * sig * wet


def env(n, attack, release_at, release):
    t = np.arange(n) / SR
    e = np.minimum(t / attack, 1)
    return e * np.where(t < release_at, 1, np.exp(-(t - release_at) / release))


def pad_note(f, dur, detune):
    n = int((dur + 3) * SR)
    t = np.arange(n) / SR
    ff = f * 2 ** (detune / 1200)
    vib = 0.002 * np.sin(2 * math.pi * 0.3 * t + detune)
    s = sum(np.sin(2 * math.pi * ff * h * t * (1 + vib)) * math.exp(-h / 3.2) / h for h in range(1, 9))
    return s * env(n, 1.4, dur, 0.9)


def pluck(f, dur=2.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = sum(0.62 ** h * np.sin(2 * math.pi * f * h * t) * np.exp(-t * (2.6 + 1.7 * h)) for h in range(1, 7))
    return s * np.minimum(t / 0.003, 1)


def bell(f, dur=5.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    parts = [(1, 1.0, 1.0), (2.0, 0.45, 1.6), (2.76, 0.35, 2.4), (5.4, 0.18, 3.6), (8.93, 0.08, 5.0)]
    s = sum(a * np.sin(2 * math.pi * f * r * t) * np.exp(-t * d) for r, a, d in parts)
    return s * np.minimum(t / 0.002, 1)


def kick(dur=0.6, low=45):
    t = np.arange(int(dur * SR)) / SR
    f = low + 80 * np.exp(-t * 28)
    ph = 2 * math.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 6.5) + 0.3 * np.exp(-t * 400) * np.sin(2 * math.pi * 1800 * t)


def compose(path):
    rng = np.random.default_rng(1)
    mx = Mix()
    # drone and pads
    for f in (midi_hz(38), midi_hz(45)):
        mx.add(0, pad_note(f, 6.0, 0), gain=0.10, wet=0.6)
    for b, name in enumerate(PROG):
        t0 = b * BAR
        dur = BAR + (3.0 if b >= 16 else 0.4)
        if b == 17:
            continue
        g = 0.035 if b < 2 else 0.05
        if b >= 16:
            dur, g = TOTAL - FLASH - 1.6, 0.06
        for m in CHORDS[name]:
            for det, pan in ((-7, -0.6), (0, 0), (7, 0.6)):
                mx.add(t0, pad_note(midi_hz(m), dur, det), pan=pan, gain=g, wet=0.7)
    mx.add(0.55, bell(midi_hz(86)), gain=0.10, pan=0.1, wet=0.8)  # the first point
    # arpeggio: one pluck per new point in the bloom, then a steady pulse
    pattern = [0, 2, 1, 3, 4, 2, 3, 1]
    for e in range(12, 120):  # eighth notes from beat 6
        tb = e * BEAT / 2
        beat = e / 2
        bar = int(tb // BAR)
        tones = sorted(set(m % 12 for m in CHORDS[PROG[bar]]))
        notes = [60 + ((x - 2) % 12) + 2 for x in tones]
        notes = sorted(notes)
        if beat < 34:
            m = notes[pattern[e % 8] % len(notes)] + (12 if beat >= 20 and e % 4 == 3 else 0)
            mx.add(tb, pluck(midi_hz(m)), pan=0.35 * math.sin(e * 1.3), gain=0.16, wet=0.55)
        elif beat < 46 and e % 2 == 0:
            m = notes[pattern[(e // 2) % 8] % len(notes)] - 12
            mx.add(tb, pluck(midi_hz(m), 3.0), pan=0.3 * math.sin(e), gain=0.12, wet=0.6)
    # shimmer over the fractal: sixteenth-note bells, high and soft
    for s16 in range(46 * 4, 60 * 4):
        tb = s16 * BEAT / 4
        bar = int(tb // BAR)
        tones = sorted(set(m % 12 for m in CHORDS[PROG[bar]]))
        m = 84 + tones[rng.integers(len(tones))]
        mx.add(tb, bell(midi_hz(m), 2.5), pan=rng.uniform(-0.8, 0.8),
               gain=0.035 * (0.6 + 0.4 * (s16 % 4 == 0)), wet=0.85)
    # melody over the landscape
    for beat, m, d in MELODY:
        mx.add(beat * BEAT, bell(midi_hz(m), 4 + d), pan=-0.15, gain=0.12, wet=0.7)
    # kick, hats and sub under the flow field
    for beat in range(20, 34):
        mx.add(beat * BEAT, kick(), gain=0.55 * (1 - 0.5 * (beat >= 32)), wet=0.08)
        if beat >= 22:
            n = int(0.09 * SR)
            hn = np.diff(rng.standard_normal(n + 1)) * np.exp(-np.arange(n) / SR * 45)
            mx.add((beat + 0.5) * BEAT, hn, pan=0.3, gain=0.05, wet=0.2)
    for b in range(5, 12):
        root = min(CHORDS[PROG[b]]) - 12
        t = np.arange(int((BAR + 0.5) * SR)) / SR
        sub = np.sin(2 * math.pi * midi_hz(root) * t) * env(len(t), 0.05, BAR - 0.2, 0.15)
        mx.add(b * BAR, sub, gain=0.16, wet=0.0)
    # riser into the collapse, then the flash
    t = np.arange(int((FLASH - 40) * SR)) / SR
    e = (t / t[-1]) ** 3
    noise = np.diff(rng.standard_normal(len(t) + 1)) * 0.5 + rng.standard_normal(len(t)) * 0.3
    sweep = np.sin(2 * math.pi * np.cumsum(midi_hz(50) * 2 ** (2 * t / t[-1])) / SR)
    mx.add(40, (noise * 0.25 + sweep * 0.5) * e, gain=0.30, wet=0.6)
    mx.add(FLASH, kick(2.5, 32), gain=0.8, wet=0.25)
    tt = np.arange(int(5 * SR)) / SR
    mx.add(FLASH, np.sin(2 * math.pi * midi_hz(26) * tt) * np.exp(-tt / 1.6), gain=0.35, wet=0.1)
    for i, m in enumerate([62, 66, 69, 73, 76, 81]):
        mx.add(FLASH + 0.025 * i, bell(midi_hz(m), 5.3), pan=-0.5 + 0.2 * i, gain=0.09, wet=0.8)

    # reverb: convolve the send bus with a decaying stereo noise tail
    n = mx.dry.shape[1]
    ir_t = np.arange(int(3.8 * SR)) / SR
    irs = []
    for ch in range(2):
        ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t / 0.62) * np.minimum(ir_t / 0.02, 1)
        ir = np.convolve(ir, np.ones(6) / 6, mode="same")
        irs.append(ir / np.sqrt(np.sum(ir ** 2)))
    size = 1 << int(math.ceil(math.log2(n + len(ir_t))))
    wet = np.stack([np.fft.irfft(np.fft.rfft(mx.send[ch], size) * np.fft.rfft(irs[ch], size), size)[:n]
                    for ch in range(2)])
    out = mx.dry + mx.send * 0.35 + wet * 0.55
    out = np.tanh(out * 1.3) / 1.3
    out = out[:, : int(TOTAL * SR)]
    out *= 0.89 / np.max(np.abs(out))
    tail = int(1.2 * SR)
    out[:, -tail:] *= np.linspace(1, 0, tail) ** 2
    pcm = (out.T * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


# ------------------------------------------------------------- driver ----
def encoder(path):
    return subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "fast",
         "-crf", "10", "-pix_fmt", "yuv420p", path], stdin=subprocess.PIPE)


def render_chunk(job):
    name, f0, f1, path = job
    start = dict((s[0], s[1]) for s in SCENES)[name]
    enc = encoder(path)
    if name == "flow":
        frames = flow_frames(f1)
        for f, img in enumerate(frames):
            enc.stdin.write(post(img, 7919 * (start * FPS + f)).tobytes())
    else:
        for f in range(f0, f1):
            t = f / FPS
            img = RENDER[name](t, start + t)
            enc.stdin.write(post(img, 7919 * (start * FPS + f)).tobytes())
    enc.stdin.close()
    enc.wait()
    return path


def main():
    out = os.path.join(HERE, "seed.mp4")
    if "--stills" in sys.argv:
        os.makedirs(os.path.join(HERE, "stills"), exist_ok=True)
        for name, s, e in SCENES:
            if name == "flow":
                for f, img in enumerate(flow_frames(int(8 * FPS))):
                    if f in (15, 120, 239):
                        Image.fromarray(post(img, f)).save(os.path.join(HERE, "stills", f"flow_{f}.png"))
                continue
            for t in (1.0, 3.0, 5.5, 8.0):
                if t < e - s:
                    Image.fromarray(post(RENDER[name](t, s + t), 1)).save(
                        os.path.join(HERE, "stills", f"{name}_{t}.png"))
        return
    work = tempfile.mkdtemp(dir=os.environ.get("FILM_TMP"))
    jobs = []
    for name, s, e in SCENES:
        n = int((e - s) * FPS)
        step = n if name == "flow" else 60
        for f0 in range(0, n, step):
            jobs.append((name, f0, min(f0 + step, n), os.path.join(work, f"{name}_{f0:04d}.mp4")))
    jobs.sort(key=lambda j: (j[0] != "flow", j[0] != "julia"))  # longest jobs first
    with Pool(os.cpu_count()) as pool:
        audio = pool.apply_async(compose, (os.path.join(work, "score.wav"),))
        for p in pool.imap_unordered(render_chunk, jobs):
            print("done", os.path.basename(p), flush=True)
        audio.get()
    inputs = []
    for name, s, e in SCENES:
        lst = os.path.join(work, f"{name}.txt")
        with open(lst, "w") as fh:
            for j in sorted(j[3] for j in jobs if j[0] == name):
                fh.write(f"file '{j}'\n")
        inputs += ["-f", "concat", "-safe", "0", "-i", lst]
    chain, prev = [], "[0:v]"
    for i in range(1, len(SCENES)):
        lab = f"[v{i}]"
        chain.append(f"{prev}[{i}:v]xfade=transition=fade:duration=1:offset={SCENES[i][1]}{lab}")
        prev = lab
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-i", os.path.join(work, "score.wav"),
                    "-filter_complex", ";".join(chain), "-map", prev, "-map", f"{len(SCENES)}:a",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", str(TOTAL), out],
                   check=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
