// Drawing helpers shared by the frame renderer and the scene illustrations.
import { GlobalFonts } from '@napi-rs/canvas';

const FONTS = {
  Reg: '/usr/share/fonts/opentype/inter/Inter-Regular.otf',
  Med: '/usr/share/fonts/opentype/inter/Inter-Medium.otf',
  Semi: '/usr/share/fonts/opentype/inter/Inter-SemiBold.otf',
  Bold: '/usr/share/fonts/opentype/inter/Inter-Bold.otf',
  DispBold: '/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf',
  DispBlack: '/usr/share/fonts/opentype/inter/InterDisplay-Black.otf',
  DispLight: '/usr/share/fonts/opentype/inter/InterDisplay-Light.otf',
  Mono: '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
  MonoBold: '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
  Serif: '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
  SerifBold: '/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf',
  SerifItalic: '/usr/share/fonts/truetype/liberation/LiberationSerif-Italic.ttf',
  Sym: '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
};
for (const [name, path] of Object.entries(FONTS)) GlobalFonts.registerFromPath(path, name);

export const C = {
  bg0: '#060A16',
  bg1: '#0C1430',
  text: '#F2F4FA',
  sub: '#AEB6CC',
  dim: '#6B7593',
  faint: 'rgba(255,255,255,0.08)',
  panel: 'rgba(255,255,255,0.035)',
  line: 'rgba(255,255,255,0.14)',
  ice: '#8FB8DE',
  amber: '#F5B84B',
  teal: '#4FD1C5',
  green: '#68D391',
  pink: '#F687B3',
  red: '#FC8181',
  violet: '#B794F6',
  blue: '#63B3ED',
};

export const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
export const lerp = (a, b, t) => a + (b - a) * t;
export const easeInOut = (x) => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2);
export const easeOut = (x) => 1 - Math.pow(1 - x, 3);
export const easeOutBack = (x) => {
  const c1 = 1.4, c3 = c1 + 1;
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
};
// Eased 0..1 progress of t through [a, b]
export const prog = (t, a, b, ease = easeInOut) => ease(clamp((t - a) / (b - a)));
// 0..1..0 window: fades in over `fin` after a, fades out over `fout` before b
export const win = (t, a, b, fin = 0.4, fout = 0.4) =>
  Math.min(prog(t, a, a + fin, easeOut), 1 - prog(t, b - fout, b, easeInOut));

export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function hexToRgb(hex) {
  const h = hex.replace('#', '');
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}
export const rgba = (hex, a) => {
  const [r, g, b] = hexToRgb(hex);
  return `rgba(${r},${g},${b},${a})`;
};
export function mixHex(a, b, t) {
  const A = hexToRgb(a), B = hexToRgb(b);
  const m = A.map((v, i) => Math.round(lerp(v, B[i], t)));
  return '#' + m.map((v) => v.toString(16).padStart(2, '0')).join('');
}

export function rr(ctx, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export function card(ctx, x, y, w, h, { r = 18, fill = 'rgba(255,255,255,0.05)', stroke = 'rgba(255,255,255,0.12)', lw = 1.5 } = {}) {
  rr(ctx, x, y, w, h, r);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
}

export function text(ctx, s, x, y, { font = '28px Reg', color = C.text, align = 'left', baseline = 'alphabetic', alpha = 1 } = {}) {
  if (alpha <= 0) return;
  ctx.save();
  ctx.globalAlpha *= alpha;
  ctx.font = font;
  ctx.fillStyle = color;
  ctx.textAlign = align;
  ctx.textBaseline = baseline;
  ctx.fillText(s, x, y);
  ctx.restore();
}

export function wrap(ctx, s, maxW, font) {
  if (font) ctx.font = font;
  const words = s.split(' ');
  const lines = [];
  let cur = '';
  for (const w of words) {
    const test = cur ? cur + ' ' + w : w;
    if (ctx.measureText(test).width > maxW && cur) {
      lines.push(cur);
      cur = w;
    } else cur = test;
  }
  if (cur) lines.push(cur);
  return lines;
}

export function arrow(ctx, x1, y1, x2, y2, { color = C.sub, lw = 3, head = 12, alpha = 1 } = {}) {
  if (alpha <= 0) return;
  const a = Math.atan2(y2 - y1, x2 - x1);
  ctx.save();
  ctx.globalAlpha *= alpha;
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = lw;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2 - Math.cos(a) * head * 0.8, y2 - Math.sin(a) * head * 0.8);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - Math.cos(a - 0.45) * head, y2 - Math.sin(a - 0.45) * head);
  ctx.lineTo(x2 - Math.cos(a + 0.45) * head, y2 - Math.sin(a + 0.45) * head);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

export function circle(ctx, x, y, r, fill, stroke, lw = 2) {
  ctx.beginPath();
  ctx.arc(x, y, Math.max(0, r), 0, Math.PI * 2);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
}

export function glow(ctx, x, y, r, color, a = 0.5) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, rgba(color, a));
  g.addColorStop(1, rgba(color, 0));
  ctx.fillStyle = g;
  ctx.fillRect(x - r, y - r, r * 2, r * 2);
}

// Run fn with extra opacity a (skips work when invisible)
export function fade(ctx, a, fn) {
  if (a <= 0.001) return;
  ctx.save();
  ctx.globalAlpha *= a;
  fn();
  ctx.restore();
}

// Typewriter: the first n characters of s, n driven by progress p
export const typed = (s, p) => s.slice(0, Math.round(clamp(p) * s.length));

// Stylized person icon (head + shoulders)
export function person(ctx, x, y, s, color) {
  ctx.fillStyle = color;
  circle(ctx, x, y - s * 0.55, s * 0.32, color);
  ctx.beginPath();
  ctx.moveTo(x - s * 0.55, y + s * 0.45);
  ctx.quadraticCurveTo(x - s * 0.55, y - s * 0.12, x, y - s * 0.12);
  ctx.quadraticCurveTo(x + s * 0.55, y - s * 0.12, x + s * 0.55, y + s * 0.45);
  ctx.closePath();
  ctx.fill();
}

// Small monitor icon
export function monitor(ctx, x, y, s, color, screen = 'rgba(0,0,0,0.35)') {
  rr(ctx, x - s * 0.6, y - s * 0.5, s * 1.2, s * 0.8, s * 0.08);
  ctx.fillStyle = color;
  ctx.fill();
  rr(ctx, x - s * 0.5, y - s * 0.42, s, s * 0.62, s * 0.04);
  ctx.fillStyle = screen;
  ctx.fill();
  ctx.fillStyle = color;
  ctx.fillRect(x - s * 0.08, y + s * 0.3, s * 0.16, s * 0.18);
  rr(ctx, x - s * 0.3, y + s * 0.46, s * 0.6, s * 0.08, s * 0.04);
  ctx.fill();
}
