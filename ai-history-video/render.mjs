// Renders the video frames and pipes them to ffmpeg.
//
//   node render.mjs --from 0 --to 1200 --out build/seg0.mp4   frames [from, to)
//   node render.mjs --stills 12.5,40,95 --dir build/stills     PNG previews at those times
//
// Every frame is a pure function of its time, so frame ranges can be rendered
// in parallel and concatenated.
import { createCanvas } from '@napi-rs/canvas';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  C, clamp, lerp, prog, easeOut, easeInOut, rgba, mixHex, rr, card, text, wrap, fade, glow, circle, rng,
} from './lib.mjs';
import { VISUALS } from './scenes.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const W = 1920, H = 1080, FPS = 30;
const PANEL = { x: 940, y: 110, w: 860, h: 690 };
const TL = { x0: 140, x1: 1780, y: 992, from: 1950, to: 2026 };

const script = JSON.parse(fs.readFileSync(path.join(HERE, 'script.json'), 'utf8'));
const timeline = JSON.parse(fs.readFileSync(path.join(HERE, 'build/timeline.json'), 'utf8'));
const ERAS = Object.fromEntries(script.eras.map((e) => [e.id, e]));
const NEUTRAL = '#63B3ED';

const scenes = script.scenes.map((s, i) => {
  const tl = timeline.scenes[i];
  if (tl.id !== s.id) throw new Error(`timeline out of date: ${tl.id} != ${s.id}; rerun tts.py`);
  return {
    ...s,
    start: tl.start,
    end: tl.end,
    dur: tl.end - tl.start,
    S: tl.sentences.map((x) => x.start - tl.start),
    E: tl.sentences.map((x) => x.end - tl.start),
    sentences: tl.sentences,
    color: s.era ? ERAS[s.era].color : NEUTRAL,
  };
});
const DURATION = timeline.duration;

function sceneIndexAt(t) {
  for (let i = 0; i < scenes.length; i++) if (t < scenes[i].end) return i;
  return scenes.length - 1;
}

// ---------------------------------------------------------------- background
const dots = (() => {
  const r = rng(11);
  return Array.from({ length: 75 }, () => ({
    x: r() * (W + 200), y: r() * (H + 200), vx: (r() - 0.5) * 14, vy: (r() - 0.5) * 10, s: 1 + r() * 2,
  }));
})();

function sceneColorAt(t) {
  const i = sceneIndexAt(t);
  const sc = scenes[i];
  if (i === 0) return sc.color;
  return mixHex(scenes[i - 1].color, sc.color, prog(t - sc.start, 0, 1.4));
}

function background(ctx, t) {
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, C.bg0);
  g.addColorStop(1, C.bg1);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);

  const col = sceneColorAt(t);
  glow(ctx, 1480, 260, 1100, col, 0.11);
  glow(ctx, 200, 1000, 800, col, 0.05);

  const i = sceneIndexAt(t);
  const sc = scenes[i];
  let boost = 1;
  if (sc.visual === 'intro') boost = 2.2 - prog(t - sc.start, sc.dur - 2, sc.dur) * 1.2;
  if (sc.visual === 'outro') boost = 1 + prog(t - sc.start, 0, 2) * 1.0;
  const pts = dots.map((d) => ({
    x: ((d.x + d.vx * t) % (W + 200) + (W + 200)) % (W + 200) - 100,
    y: ((d.y + d.vy * t) % (H + 200) + (H + 200)) % (H + 200) - 100,
    s: d.s,
  }));
  ctx.lineWidth = 1;
  for (let a = 0; a < pts.length; a++) {
    for (let b = a + 1; b < pts.length; b++) {
      const dx = pts[a].x - pts[b].x, dy = pts[a].y - pts[b].y;
      const d2 = dx * dx + dy * dy;
      if (d2 < 190 * 190) {
        ctx.strokeStyle = rgba(col, (1 - Math.sqrt(d2) / 190) * 0.07 * boost);
        ctx.beginPath();
        ctx.moveTo(pts[a].x, pts[a].y);
        ctx.lineTo(pts[b].x, pts[b].y);
        ctx.stroke();
      }
    }
  }
  for (const p of pts) circle(ctx, p.x, p.y, p.s, rgba('#FFFFFF', 0.12 * boost));
}

// ---------------------------------------------------------------- timeline
const X = (year) => TL.x0 + ((year - TL.from) / (TL.to - TL.from)) * (TL.x1 - TL.x0);

function markerYear(t) {
  const i = sceneIndexAt(t);
  const sc = scenes[i];
  const prev = i > 0 ? scenes[i - 1].year : sc.year;
  return lerp(prev, sc.year, prog(t - sc.start, 0.2, 1.8));
}

function timelineBar(ctx, t) {
  const i = sceneIndexAt(t);
  const sc = scenes[i];
  const lt = t - sc.start;
  let alpha = 1;
  if (sc.visual === 'intro') alpha = prog(lt, sc.dur - 3.5, sc.dur - 1.5);
  if (alpha <= 0) return;
  const my = markerYear(t);
  const mx = X(my);
  const y = TL.y;
  fade(ctx, alpha, () => {
    ctx.fillStyle = 'rgba(255,255,255,0.08)';
    rr(ctx, TL.x0, y - 2, TL.x1 - TL.x0, 4, 2);
    ctx.fill();
    for (const e of script.eras) {
      const xa = X(e.from), xb = X(e.to);
      ctx.fillStyle = rgba(e.color, 0.25);
      ctx.fillRect(xa + 1, y - 2, xb - xa - 2, 4);
      if (mx > xa) {
        ctx.fillStyle = rgba(e.color, 0.95);
        ctx.fillRect(xa + 1, y - 2, Math.min(mx, xb) - xa - 2, 4);
      }
      if (e.winter) text(ctx, '❄', (xa + xb) / 2, y - 14, { font: '16px Sym', color: rgba(C.ice, mx > xa ? 0.9 : 0.35), align: 'center' });
    }
    for (let d = 1950; d <= 2020; d += 10) {
      ctx.fillStyle = 'rgba(255,255,255,0.25)';
      ctx.fillRect(X(d) - 0.5, y + 8, 1, 8);
      text(ctx, String(d), X(d), y + 38, { font: '17px Med', color: C.dim, align: 'center' });
    }
    for (const s of scenes) {
      if (!s.era) continue;
      const x = X(s.year);
      if (s.year <= my + 0.01) circle(ctx, x, y, 5, s.color);
      else circle(ctx, x, y, 4, C.bg0, 'rgba(255,255,255,0.35)', 1.5);
    }
    const mcol = sceneColorAt(t);
    glow(ctx, mx, y, 34, mcol, 0.55);
    circle(ctx, mx, y, 8, '#FFFFFF');
    if (sc.era || sc.visual === 'outro') {
      text(ctx, String(Math.round(my)), mx, y - 22, { font: '19px Bold', color: C.text, align: 'center' });
    }
  });
}

// ---------------------------------------------------------------- captions
const CAP = { font: '33px Med', maxW: 1500, lh: 44 };
const measureCtx = createCanvas(10, 10).getContext('2d');
const captionChunks = [];
// Split a long sentence into caption chunks of at most two lines, balanced by
// length and preferring to break after punctuation.
function splitCaption(textStr) {
  const lines = wrap(measureCtx, textStr, CAP.maxW, CAP.font);
  const k = Math.ceil(lines.length / 2);
  if (k <= 1) return [lines];
  const words = textStr.split(' ');
  const chunks = [];
  let start = 0;
  for (let c = 1; c < k; c++) {
    const target = (textStr.length * c) / k;
    let best = -1, bestScore = Infinity, pos = 0;
    for (let i = 0; i < words.length - 1; i++) {
      pos += words[i].length + 1;
      if (i < start) continue;
      const punct = /[,:;.]$/.test(words[i]) ? 0.55 : 1;
      const score = Math.abs(pos - target) * punct;
      if (score < bestScore) { bestScore = score; best = i; }
    }
    chunks.push(words.slice(start, best + 1).join(' '));
    start = best + 1;
  }
  chunks.push(words.slice(start).join(' '));
  return chunks.map((c) => wrap(measureCtx, c, CAP.maxW, CAP.font));
}
for (const sc of scenes) {
  for (const s of sc.sentences) {
    const groups = splitCaption(s.text);
    const total = groups.reduce((n, g) => n + g.join(' ').length, 0);
    let t0 = s.start;
    groups.forEach((g, k) => {
      const d = ((s.end - s.start) * g.join(' ').length) / total;
      captionChunks.push({ lines: g, start: k === 0 ? t0 - 0.1 : t0, end: k === groups.length - 1 ? t0 + d + 0.3 : t0 + d });
      t0 += d;
    });
  }
}

function captions(ctx, t) {
  const ch = captionChunks.find((c) => t >= c.start && t < c.end);
  if (!ch) return;
  const a = Math.min(clamp((t - ch.start) / 0.12), clamp((ch.end - t) / 0.12));
  ctx.font = CAP.font;
  const w = Math.max(...ch.lines.map((l) => ctx.measureText(l).width));
  const n = ch.lines.length;
  const cy = 878;
  const top = cy - (n * CAP.lh) / 2;
  fade(ctx, a, () => {
    card(ctx, 960 - w / 2 - 28, top - 14, w + 56, n * CAP.lh + 28, { r: 16, fill: 'rgba(4,7,18,0.62)', stroke: null });
    ch.lines.forEach((l, k) => text(ctx, l, 960, top + CAP.lh * (k + 0.5) + 12, { font: CAP.font, color: C.text, align: 'center' }));
  });
}

// ---------------------------------------------------------------- scene layout
function eraChip(ctx, sc, lt) {
  const era = ERAS[sc.era];
  const label = era.label.toUpperCase();
  ctx.font = '17px Bold';
  const w = ctx.measureText(label).width + 56;
  const p = prog(lt, 0.05, 0.6, easeOut);
  fade(ctx, p, () => {
    card(ctx, 120, 112, w, 38, { r: 19, fill: rgba(era.color, 0.14), stroke: rgba(era.color, 0.5) });
    circle(ctx, 142, 131, 6, era.color);
    text(ctx, label, 158, 137, { font: '17px Bold', color: era.color });
  });
}

function leftColumn(ctx, sc, lt) {
  eraChip(ctx, sc, lt);
  const maxW = 760;
  let size = 150;
  ctx.font = `${size}px DispBlack`;
  while (ctx.measureText(sc.yearLabel).width > maxW && size > 60) {
    size -= 4;
    ctx.font = `${size}px DispBlack`;
  }
  const py = prog(lt, 0.1, 0.8, easeOut);
  text(ctx, sc.yearLabel, 114, 300 + (1 - py) * 30, { font: `${size}px DispBlack`, color: sc.color, alpha: py });

  const tp = prog(lt, 0.3, 1.0, easeOut);
  const tlines = wrap(ctx, sc.title, maxW, '56px DispBold');
  tlines.forEach((l, k) => text(ctx, l, 120, 384 + k * 66 + (1 - tp) * 24, { font: '56px DispBold', color: C.text, alpha: tp }));

  let y = 384 + (tlines.length - 1) * 66 + 70;
  for (const f of sc.facts || []) {
    const p = prog(lt, sc.S[f.at] - 0.15, sc.S[f.at] + 0.5, easeOut);
    const lines = wrap(ctx, f.text, 690, '28px Reg');
    fade(ctx, p, () => {
      ctx.fillStyle = sc.color;
      rr(ctx, 120, y - 24, 5, lines.length * 38 - 6, 2.5);
      ctx.fill();
      lines.forEach((l, k) => text(ctx, l, 146 - (1 - p) * 24, y + k * 38, { font: '28px Reg', color: '#D5DAE8' }));
    });
    y += lines.length * 38 + 22;
  }
}

function panel(ctx, sc, lt, t) {
  const p = prog(lt, 0.15, 0.9, easeOut);
  const vis = VISUALS[sc.visual];
  ctx.save();
  ctx.globalAlpha *= p;
  const s = 0.97 + 0.03 * p;
  ctx.translate(PANEL.x + PANEL.w / 2, PANEL.y + PANEL.h / 2);
  ctx.scale(s, s);
  ctx.translate(-PANEL.w / 2, -PANEL.h / 2);
  card(ctx, 0, 0, PANEL.w, PANEL.h, { r: 28, fill: 'rgba(255,255,255,0.03)', stroke: 'rgba(255,255,255,0.09)' });
  rr(ctx, 0, 0, PANEL.w, PANEL.h, 28);
  ctx.clip();
  vis(ctx, { lt, t, dur: sc.dur, S: sc.S, E: sc.E, w: PANEL.w, h: PANEL.h, color: sc.color, sc });
  ctx.restore();
}

function content(ctx, sc, lt, t) {
  const out = sc.visual === 'outro' ? 0 : prog(lt, sc.dur - 0.55, sc.dur - 0.05);
  const a = Math.min(prog(lt, 0, 0.6, easeOut), 1 - out);
  fade(ctx, a, () => {
    if (!sc.era) {
      VISUALS[sc.visual](ctx, { lt, t, dur: sc.dur, S: sc.S, E: sc.E, w: W, h: H, color: sc.color, sc, script });
      return;
    }
    leftColumn(ctx, sc, lt);
    panel(ctx, sc, lt, t);
  });
}

export function drawFrame(ctx, t) {
  background(ctx, t);
  const sc = scenes[sceneIndexAt(t)];
  content(ctx, sc, t - sc.start, t);
  timelineBar(ctx, t);
  captions(ctx, t);
  const black = Math.max(1 - t / 0.8, prog(t, DURATION - 1.8, DURATION - 0.2));
  if (black > 0) {
    ctx.fillStyle = `rgba(0,0,0,${clamp(black)})`;
    ctx.fillRect(0, 0, W, H);
  }
}

// ---------------------------------------------------------------- main
function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 ? process.argv[i + 1] : def;
}

async function main() {
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');

  const stills = arg('stills');
  if (stills) {
    const dir = arg('dir', path.join(HERE, 'build/stills'));
    fs.mkdirSync(dir, { recursive: true });
    for (const ts of stills.split(',')) {
      const t = parseFloat(ts);
      ctx.save();
      drawFrame(ctx, t);
      ctx.restore();
      fs.writeFileSync(path.join(dir, `t${t.toFixed(1).padStart(6, '0')}.png`), canvas.toBuffer('image/png'));
    }
    return;
  }

  const total = Math.ceil(DURATION * FPS);
  const from = parseInt(arg('from', '0'), 10);
  const to = Math.min(total, parseInt(arg('to', String(total)), 10));
  const out = arg('out', path.join(HERE, 'build/video.mp4'));
  const ff = spawn('ffmpeg', [
    '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-r', String(FPS), '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', '-g', '60', out,
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((res, rej) => ff.on('close', (code) => (code === 0 ? res() : rej(new Error('ffmpeg ' + code)))));
  const t0 = Date.now();
  for (let f = from; f < to; f++) {
    ctx.save();
    drawFrame(ctx, f / FPS);
    ctx.restore();
    if (!ff.stdin.write(Buffer.from(canvas.data()))) await new Promise((r) => ff.stdin.once('drain', r));
    if ((f - from) % 300 === 0) console.log(`[${from}-${to}] frame ${f} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
  }
  ff.stdin.end();
  await done;
  console.log(`[${from}-${to}] done in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
