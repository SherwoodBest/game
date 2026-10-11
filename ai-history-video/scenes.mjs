// One illustration per scene. Each receives the panel-local context
// (0,0)-(w,h) and P = { lt: seconds into the scene, dur, S/E: sentence
// start/end times within the scene, color: era color }.
import { createCanvas } from '@napi-rs/canvas';
import {
  C, clamp, lerp, prog, easeOut, easeInOut, easeOutBack, win, rng, rgba, mixHex,
  rr, card, text, wrap, arrow, circle, glow, fade, typed, person, monitor,
} from './lib.mjs';

const TAU = Math.PI * 2;
const stage = (lt, a, b, f = 0.45) => win(lt, a, b, f, f);

function line(ctx, x1, y1, x2, y2, color, lw = 2) {
  ctx.strokeStyle = color;
  ctx.lineWidth = lw;
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();
}

function label(ctx, s, x, y, opts = {}) {
  text(ctx, s, x, y, { font: '18px Semi', color: C.dim, ...opts });
}

// "10" with a superscript exponent
function pow10(ctx, mant, exp, x, y, size, color, align = 'left') {
  ctx.font = `${size}px DispBold`;
  const w1 = ctx.measureText(mant).width;
  ctx.font = `${Math.round(size * 0.55)}px DispBold`;
  const w2 = ctx.measureText(exp).width;
  const x0 = align === 'center' ? x - (w1 + w2) / 2 : align === 'right' ? x - w1 - w2 : x;
  text(ctx, mant, x0, y, { font: `${size}px DispBold`, color });
  text(ctx, exp, x0 + w1 + 2, y - size * 0.45, { font: `${Math.round(size * 0.55)}px DispBold`, color });
}

// Moving dot along a segment, phase 0..1
function pulse(ctx, x1, y1, x2, y2, ph, color, r = 4) {
  const x = lerp(x1, x2, ph), y = lerp(y1, y2, ph);
  glow(ctx, x, y, r * 4, color, 0.5);
  circle(ctx, x, y, r, color);
}

function snow(ctx, lt, w, h, density, seed = 3) {
  if (density <= 0) return;
  const r = rng(seed);
  const n = Math.floor(160 * density);
  for (let i = 0; i < 160; i++) {
    const x0 = r() * w, sp = 25 + r() * 45, sz = 1.5 + r() * 2.5, ph = r() * h, sway = r() * TAU;
    if (i >= n) continue;
    const y = (ph + lt * sp) % (h + 20) - 10;
    const x = x0 + Math.sin(lt * 0.8 + sway) * 14;
    circle(ctx, x, y, sz, 'rgba(220,235,255,0.75)');
  }
}

function stamp(ctx, s, x, y, p, color = C.red, rot = -0.12, size = 34) {
  if (p <= 0) return;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rot);
  const sc = lerp(1.6, 1, easeOut(p));
  ctx.scale(sc, sc);
  ctx.globalAlpha *= clamp(p * 1.5);
  ctx.font = `${size}px DispBlack`;
  const w = ctx.measureText(s).width + 36;
  rr(ctx, -w / 2, -size * 0.85, w, size * 1.4, 8);
  ctx.strokeStyle = color;
  ctx.lineWidth = 4;
  ctx.stroke();
  text(ctx, s, 0, size * 0.35, { font: `${size}px DispBlack`, color, align: 'center' });
  ctx.restore();
}

// ------------------------------------------------------------------ intro
function intro(ctx, P) {
  const { lt } = P;
  const layers = [4, 6, 6, 3];
  const lx = (i) => 640 + i * 213;
  const ly = (i, j) => 290 + (j - (layers[i] - 1) / 2) * 54;
  const net = prog(lt, 0.2, 2.2);
  fade(ctx, net, () => {
    for (let i = 0; i < layers.length - 1; i++) {
      for (let a = 0; a < layers[i]; a++) {
        for (let b = 0; b < layers[i + 1]; b++) {
          line(ctx, lx(i), ly(i, a), lx(i + 1), ly(i + 1, b), 'rgba(170,195,255,0.12)', 1.2);
          const ph = (lt * 0.45 + a * 0.37 + b * 0.23 + i * 0.31) % 1;
          if ((a + b + i) % 3 === 0) pulse(ctx, lx(i), ly(i, a), lx(i + 1), ly(i + 1, b), ph, i % 2 ? C.pink : C.amber, 2.5);
        }
      }
    }
    for (let i = 0; i < layers.length; i++) {
      for (let j = 0; j < layers[i]; j++) {
        const act = 0.5 + 0.5 * Math.sin(lt * 1.6 + i * 1.3 + j * 0.9);
        glow(ctx, lx(i), ly(i, j), 30, C.blue, 0.25 * act);
        circle(ctx, lx(i), ly(i, j), 9, '#0B1226', rgba('#9EC5FF', 0.5 + 0.5 * act), 2);
      }
    }
  });

  const tp = prog(lt, 0.5, 1.9, easeOut);
  ctx.font = '150px DispBlack';
  const tw = ctx.measureText('Thinking Machines').width;
  const g = ctx.createLinearGradient(960 - tw / 2, 0, 960 + tw / 2, 0);
  g.addColorStop(0, '#FFE2A8');
  g.addColorStop(0.5, '#FFFFFF');
  g.addColorStop(1, '#FFC2DC');
  fade(ctx, tp, () => {
    ctx.font = '150px DispBlack';
    ctx.fillStyle = g;
    ctx.textAlign = 'center';
    ctx.fillText('Thinking Machines', 960, 610 + (1 - tp) * 30);
  });
  text(ctx, 'A short history of artificial intelligence', 960, 680, {
    font: '42px DispLight', color: C.sub, align: 'center', alpha: prog(lt, 1.2, 2.4),
  });
  text(ctx, '1950  →  2026', 960, 745, { font: '30px Semi', color: C.amber, align: 'center', alpha: prog(lt, 1.8, 3.0) });
}

// ------------------------------------------------------------------ outro
function outro(ctx, P) {
  const { lt, S, E, dur } = P;
  const a1 = prog(lt, S[0] - 0.3, S[0] + 0.8, easeOut);
  text(ctx, '“Can machines think?”', 960, 360 + (1 - a1) * 20, { font: '84px DispBold', color: C.text, align: 'center', alpha: a1 });
  text(ctx, '— Alan Turing, 1950', 960, 425, { font: '30px Reg', color: C.sub, align: 'center', alpha: prog(lt, S[0] + 0.8, S[0] + 1.8) });

  const a2 = prog(lt, S[1] + 1.6, S[1] + 2.8, easeOut);
  ctx.font = '64px DispBold';
  const q = 'What will we choose to do with them?';
  const qw = ctx.measureText(q).width;
  const g = ctx.createLinearGradient(960 - qw / 2, 0, 960 + qw / 2, 0);
  g.addColorStop(0, C.amber);
  g.addColorStop(1, C.pink);
  fade(ctx, a2, () => {
    ctx.font = '64px DispBold';
    ctx.fillStyle = g;
    ctx.textAlign = 'center';
    ctx.fillText(q, 960, 560 + (1 - a2) * 20);
  });

  const a3 = prog(lt, E[1] + 0.3, E[1] + 1.3);
  text(ctx, 'THINKING MACHINES', 960, 680, { font: '26px Bold', color: C.text, align: 'center', alpha: a3 });
  text(ctx, 'Narration: synthetic voice (Piper TTS)  ·  Music and visuals generated in code', 960, 722, {
    font: '21px Reg', color: C.dim, align: 'center', alpha: a3,
  });
}

// ------------------------------------------------------------------ 1950 Turing
function turing(ctx, P) {
  const { lt, S, E, w } = P;
  // Transcript from the 1950 paper
  card(ctx, 36, 32, w - 72, 300, { r: 20, fill: 'rgba(0,0,0,0.25)' });
  label(ctx, 'FROM TURING’S 1950 PAPER', 62, 70, { color: C.amber });
  const lines = [
    ['Q', 'Please write me a sonnet on the subject of the Forth Bridge.'],
    ['A', 'Count me out on this one. I never could write poetry.'],
    ['Q', 'Do you play chess?'],
    ['A', 'Yes.'],
  ];
  const t0 = S[0] + 1.5, t1 = E[2];
  const total = lines.reduce((n, l) => n + l[1].length, 0);
  let acc = 0, y = 118;
  for (const [who, s] of lines) {
    const a = t0 + ((t1 - t0) * acc) / total;
    const b = t0 + ((t1 - t0) * (acc + s.length)) / total;
    acc += s.length;
    if (P.lt < a) break;
    const col = who === 'Q' ? C.amber : C.teal;
    text(ctx, who + ':', 62, y, { font: '25px Bold', color: col });
    const shown = typed(s, (lt - a) / (b - a));
    const ls = wrap(ctx, shown, 680, '25px Reg');
    ls.forEach((l, k) => text(ctx, l, 104, y + k * 34, { font: '25px Reg', color: C.text }));
    y += ls.length * 34 + 16;
  }

  // The imitation game
  const top = 370;
  const ix = 140, iy = 545;
  person(ctx, ix, iy, 90, '#C9D3EA');
  label(ctx, 'Interrogator', ix, iy + 88, { align: 'center', color: C.sub });
  ctx.setLineDash([10, 10]);
  line(ctx, 400, top + 10, 400, 660, 'rgba(255,255,255,0.35)', 3);
  ctx.setLineDash([]);
  label(ctx, 'WALL', 412, top + 30);
  const rooms = [{ y: 455, k: 'A' }, { y: 600, k: 'B' }];
  const reveal = prog(lt, S[3] + 0.3, S[3] + 1.2);
  rooms.forEach((rm, i) => {
    const x = 640;
    card(ctx, x - 70, rm.y - 58, 140, 116, { r: 16, fill: 'rgba(255,255,255,0.05)' });
    text(ctx, rm.k, x - 54, rm.y - 30, { font: '20px Bold', color: C.dim });
    fade(ctx, 1 - reveal, () => text(ctx, '?', x, rm.y + 24, { font: '68px DispBlack', color: C.amber, align: 'center' }));
    fade(ctx, reveal, () => {
      if (i === 0) person(ctx, x, rm.y + 10, 70, '#E9D5B5');
      else monitor(ctx, x, rm.y + 4, 74, '#9EC5FF', 'rgba(20,40,80,0.9)');
    });
    text(ctx, i === 0 ? 'Human' : 'Machine', x + 90, rm.y + 8, { font: '22px Semi', color: i === 0 ? '#E9D5B5' : '#9EC5FF', alpha: reveal });
    // messages through the wall
    line(ctx, ix + 60, iy - 20, x - 75, rm.y, 'rgba(255,255,255,0.1)', 2);
    if (lt > S[0] + 1) {
      const ph = ((lt - S[0]) * 0.35 + i * 0.5) % 1;
      const back = Math.floor((lt - S[0]) * 0.35 + i * 0.5) % 2 === 1;
      const p = back ? 1 - ph : ph;
      pulse(ctx, ix + 60, iy - 20, x - 75, rm.y, p, back ? C.teal : C.amber, 5);
    }
  });
}

// ------------------------------------------------------------------ 1956 Dartmouth
function dartmouth(ctx, P) {
  const { lt, S, E } = P;
  const paper = '#F1E9D8', ink = '#2A2A33';
  ctx.save();
  ctx.translate(300, 345);
  ctx.rotate(-0.025);
  ctx.translate(-250, -305);
  ctx.shadowColor = 'rgba(0,0,0,0.5)';
  ctx.shadowBlur = 30;
  ctx.fillStyle = paper;
  ctx.fillRect(0, 0, 500, 610);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';
  const hl = prog(lt, S[1] + 4.5, S[1] + 5.8);
  if (hl > 0) {
    ctx.font = '20px SerifBold';
    const hw = ctx.measureText('ON ARTIFICIAL INTELLIGENCE').width;
    ctx.fillStyle = 'rgba(245,184,75,0.6)';
    ctx.fillRect(250 - hw / 2 - 6, 108, (hw + 12) * hl, 30);
  }
  ['A PROPOSAL FOR THE', 'DARTMOUTH SUMMER RESEARCH PROJECT', 'ON ARTIFICIAL INTELLIGENCE'].forEach((s, k) =>
    text(ctx, s, 250, 70 + k * 30, { font: '20px SerifBold', color: ink, align: 'center' }));
  text(ctx, 'August 31, 1955', 250, 178, { font: 'italic 19px SerifItalic', color: '#55555F', align: 'center' });
  const quote = 'We propose that a 2 month, 10 man study of artificial intelligence be carried out during the summer of 1956 at Dartmouth College in Hanover, New Hampshire.';
  const q = typed(quote, prog(lt, 0.8, S[1] + 1, (x) => x));
  wrap(ctx, q, 420, '22px Serif').forEach((l, k) => text(ctx, l, 40, 236 + k * 33, { font: '22px Serif', color: ink }));
  const names = [
    ['J. McCarthy', 'Dartmouth College'],
    ['M. L. Minsky', 'Harvard University'],
    ['N. Rochester', 'I.B.M. Corporation'],
    ['C. E. Shannon', 'Bell Telephone Laboratories'],
  ];
  names.forEach(([n, org], k) => {
    const a = prog(lt, S[1] + 0.3 + k * 0.6, S[1] + 0.9 + k * 0.6);
    text(ctx, n, 40, 440 + k * 38, { font: '20px SerifBold', color: ink, alpha: a });
    text(ctx, org, 190, 440 + k * 38, { font: '19px SerifItalic', color: '#55555F', alpha: a });
  });
  ctx.restore();

  // Expected vs actual
  const base = 600, bx = 640;
  const ea = prog(lt, S[2] - 0.2, S[2] + 0.8);
  const aa = prog(lt, S[3] - 0.1, S[3] + 2.2);
  fade(ctx, ea, () => {
    label(ctx, 'HOW LONG?', 700, 80, { align: 'center', color: C.amber });
    line(ctx, 590, base, 820, base, 'rgba(255,255,255,0.3)', 2);
    const eh = 18 * ea;
    card(ctx, bx - 40, base - eh, 80, eh, { r: 4, fill: C.amber, stroke: null });
    text(ctx, 'Expected', bx, base + 32, { font: '19px Semi', color: C.sub, align: 'center' });
    text(ctx, '1 summer', bx, base - eh - 14, { font: '20px Bold', color: C.amber, align: 'center' });
  });
  fade(ctx, aa > 0 ? 1 : 0, () => {
    const ah = 400 * aa;
    card(ctx, bx + 120 - 40, base - ah, 80, ah, { r: 4, fill: C.pink, stroke: null });
    text(ctx, 'Actual', bx + 120, base + 32, { font: '19px Semi', color: C.sub, align: 'center' });
    text(ctx, '70 years', bx + 120, base - ah - 40, { font: '22px Bold', color: C.pink, align: 'center', alpha: aa });
    text(ctx, 'and counting', bx + 120, base - ah - 16, { font: '17px Med', color: C.pink, align: 'center', alpha: aa });
  });
}

// ------------------------------------------------------------------ 1958 Perceptron
const PERC_PTS = (() => {
  const r = rng(5);
  const pts = [];
  for (let i = 0; i < 26; i++) {
    const cls = i % 2;
    const cx = cls ? 0.7 : 0.32, cy = cls ? 0.3 : 0.68;
    pts.push({ x: clamp(cx + (r() - 0.5) * 0.42, 0.05, 0.95), y: clamp(cy + (r() - 0.5) * 0.42, 0.05, 0.95), cls });
  }
  return pts;
})();

const RETINA_A = (() => {
  const c = createCanvas(20, 20);
  const g = c.getContext('2d');
  g.fillStyle = '#000';
  g.fillRect(0, 0, 20, 20);
  g.strokeStyle = '#fff';
  g.lineWidth = 2.4;
  g.beginPath();
  g.moveTo(4, 17); g.lineTo(10, 3); g.lineTo(16, 17);
  g.moveTo(6.5, 12); g.lineTo(13.5, 12);
  g.stroke();
  const d = g.getImageData(0, 0, 20, 20).data;
  return Array.from({ length: 400 }, (_, i) => d[i * 4] / 255);
})();

function perceptron(ctx, P) {
  const { lt, S } = P;
  // neuron diagram
  const init = [0.9, -0.6, 0.2, -0.8, 0.5];
  const target = [0.42, 0.75, -0.31, 0.58, -0.66];
  const k = 1 - Math.exp(-Math.max(0, lt - S[1]) / 3.5);
  const ws = init.map((v, i) => lerp(v, target[i], k) + 0.04 * Math.sin(lt * 2 + i));
  const sx = 470, sy = 180;
  for (let i = 0; i < 5; i++) {
    const y = 60 + i * 60;
    const wv = ws[i];
    const col = wv >= 0 ? C.teal : C.pink;
    line(ctx, 130, y, sx - 46, sy, rgba(col, 0.75), 1 + Math.abs(wv) * 7);
    const ph = (lt * 0.5 + i * 0.17) % 1;
    pulse(ctx, 130, y, sx - 46, sy, ph, col, 3.5);
    circle(ctx, 106, y, 24, '#0E1730', 'rgba(255,255,255,0.4)', 2);
    text(ctx, 'x' + (i + 1), 106, y + 7, { font: '19px Semi', color: C.sub, align: 'center' });
    const mx = lerp(130, sx - 46, 0.3), my = lerp(y, sy, 0.3);
    text(ctx, (wv >= 0 ? '+' : '−') + Math.abs(wv).toFixed(2), mx, my - 8, { font: '16px Bold', color: col, align: 'center' });
  }
  glow(ctx, sx, sy, 90, P.color, 0.3);
  circle(ctx, sx, sy, 46, '#121C38', P.color, 3);
  text(ctx, 'Σ', sx, sy + 15, { font: '44px Sym', color: C.text, align: 'center' });
  arrow(ctx, sx + 48, sy, 588, sy, { color: C.sub });
  card(ctx, 590, sy - 40, 100, 80, { r: 12 });
  ctx.strokeStyle = P.color;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(606, sy + 22); ctx.lineTo(640, sy + 22); ctx.lineTo(640, sy - 22); ctx.lineTo(674, sy - 22);
  ctx.stroke();
  arrow(ctx, 692, sy, 748, sy, { color: C.sub });
  const out = Math.sin(lt * 1.3) > 0 ? '1' : '0';
  circle(ctx, 785, sy, 32, '#121C38', 'rgba(255,255,255,0.45)', 2);
  text(ctx, out, 785, sy + 12, { font: '32px DispBold', color: C.text, align: 'center' });
  label(ctx, 'inputs', 106, 30, { align: 'center' });
  label(ctx, 'weights', 290, 30, { align: 'center' });
  label(ctx, 'sum', sx, 106, { align: 'center' });
  label(ctx, 'threshold', 640, sy + 70, { align: 'center' });
  label(ctx, 'output', 785, sy + 62, { align: 'center' });

  // learning a boundary
  const bx = 34, by = 368, bw = 392, bh = 292;
  card(ctx, bx, by, bw, bh, { r: 16, fill: 'rgba(0,0,0,0.2)' });
  label(ctx, 'LEARNING FROM EXAMPLES', bx + 20, by + 32, { color: P.color });
  const step = Math.floor(Math.max(0, lt - S[1] + 0.5) / 0.9);
  const kk = 1 - Math.pow(0.62, step);
  const ang = lerp(-0.25, 0.79, kk);
  const off = lerp(0.18, 0, kk);
  const nx = Math.cos(ang), ny = Math.sin(ang);
  const px = (x) => bx + 24 + x * (bw - 48), py = (y) => by + 50 + y * (bh - 92);
  let errors = 0;
  for (const p of PERC_PTS) {
    const side = (p.x - 0.5) * nx - (p.y - 0.5) * ny + off > 0 ? 1 : 0;
    const wrong = side !== p.cls;
    if (wrong) errors++;
    const col = p.cls ? C.amber : C.teal;
    circle(ctx, px(p.x), py(p.y), 7, col);
    if (wrong) circle(ctx, px(p.x), py(p.y), 13, null, C.red, 2.5);
  }
  // boundary line: points where (x-.5)nx - (y-.5)ny + off = 0
  const cxm = 0.5 - off * nx, cym = 0.5 + off * ny;
  const dx = ny, dy = nx;
  ctx.save();
  ctx.beginPath();
  ctx.rect(bx, by + 40, bw, bh - 76);
  ctx.clip();
  line(ctx, px(cxm - dx), py(cym - dy), px(cxm + dx), py(cym + dy), C.text, 3);
  ctx.restore();
  text(ctx, `mistakes: ${errors}`, bx + bw - 20, by + bh - 16, { font: '18px Bold', color: errors ? C.red : C.green, align: 'right' });

  // Mark I retina, then the newspaper
  const rx = 446, ry = 368;
  const ra = 1 - prog(lt, S[2] - 0.4, S[2] + 0.4);
  fade(ctx, ra, () => {
    card(ctx, rx, ry, 380, 292, { r: 16, fill: 'rgba(0,0,0,0.2)' });
    label(ctx, 'MARK I “RETINA”: 20 × 20 PHOTOCELLS', rx + 20, ry + 32, { color: P.color });
    const cs = 11;
    const ox = rx + 190 - 10 * cs, oy = ry + 52;
    for (let i = 0; i < 400; i++) {
      const v = RETINA_A[i] * prog(lt, 0.8 + (i % 20) * 0.04, 1.6 + (i % 20) * 0.04);
      ctx.fillStyle = v > 0.05 ? rgba(C.amber, 0.25 + 0.75 * v) : 'rgba(255,255,255,0.06)';
      ctx.fillRect(ox + (i % 20) * cs, oy + Math.floor(i / 20) * cs, cs - 2, cs - 2);
    }
  });
  const na = prog(lt, S[2] - 0.2, S[2] + 0.7, easeOut);
  if (na > 0) {
    ctx.save();
    ctx.translate(rx + 190 + (1 - na) * 300, ry + 150);
    ctx.rotate(0.03);
    ctx.globalAlpha *= na;
    ctx.fillStyle = '#ECE5D3';
    ctx.fillRect(-180, -138, 360, 276);
    const ink = '#22232A';
    text(ctx, 'The New York Times', 0, -104, { font: '26px SerifBold', color: ink, align: 'center' });
    line(ctx, -160, -92, 160, -92, ink, 1.5);
    text(ctx, 'July 8, 1958', 0, -72, { font: '15px SerifItalic', color: '#55555F', align: 'center' });
    ['NEW NAVY DEVICE', 'LEARNS BY DOING'].forEach((s, i) => text(ctx, s, 0, -32 + i * 34, { font: '31px SerifBold', color: ink, align: 'center' }));
    wrap(ctx, 'Psychologist Shows Embryo of Computer Designed to Read and Grow Wiser', 300, '17px Serif').forEach((s, i) =>
      text(ctx, s, 0, 34 + i * 22, { font: '17px Serif', color: ink, align: 'center' }));
    for (let i = 0; i < 3; i++) {
      ctx.fillStyle = 'rgba(0,0,0,0.18)';
      ctx.fillRect(-160, 90 + i * 14, i === 2 ? 200 : 320, 6);
    }
    ctx.restore();
  }
}

// ------------------------------------------------------------------ 1960s symbolic AI, ELIZA, Shakey
function terminalLines(ctx, lines, x, y, lt, t0, t1, lh = 34, font = '22px Mono', maxW = 740) {
  const total = lines.reduce((n, l) => n + l.s.length + 8, 0);
  let acc = 0, yy = y, last = null;
  for (const l of lines) {
    const a = t0 + ((t1 - t0) * acc) / total;
    const b = t0 + ((t1 - t0) * (acc + l.s.length)) / total;
    acc += l.s.length + 8;
    if (lt < a) break;
    const shown = l.instant ? (lt >= a ? l.s : '') : typed(l.s, (lt - a) / (b - a));
    const ls = wrap(ctx, shown, maxW, font);
    ls.forEach((s, k) => text(ctx, s, x, yy + k * lh, { font, color: l.color }));
    if (ls.length) {
      ctx.font = font;
      last = { x: x + ctx.measureText(ls[ls.length - 1]).width + 4, y: yy + (ls.length - 1) * lh };
    }
    yy += Math.max(1, ls.length) * lh + (l.gap || 0);
  }
  return last;
}

const SHAKEY_PATH = [[0.08, 0.75], [0.3, 0.75], [0.3, 0.3], [0.62, 0.3], [0.62, 0.7], [0.9, 0.7]];
function pathPoint(path, p) {
  const segs = [];
  let L = 0;
  for (let i = 1; i < path.length; i++) {
    const d = Math.hypot(path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]);
    segs.push(d);
    L += d;
  }
  let target = p * L;
  for (let i = 0; i < segs.length; i++) {
    if (target <= segs[i] || i === segs.length - 1) {
      const f = clamp(target / segs[i]);
      return [lerp(path[i][0], path[i + 1][0], f), lerp(path[i][1], path[i + 1][1], f)];
    }
    target -= segs[i];
  }
  return path[path.length - 1];
}

function eliza(ctx, P) {
  const { lt, S, E, w } = P;
  const tx = 30, ty = 28, tw = w - 60, th = 392;
  card(ctx, tx, ty, tw, th, { r: 14, fill: '#050A07', stroke: 'rgba(124,242,154,0.35)' });
  const green = '#7CF29A', white = '#E8F2EA';
  const elizaOn = lt > S[1] - 0.4;
  const lta = 1 - prog(lt, S[1] - 0.6, S[1] - 0.2);
  text(ctx, elizaOn ? 'ELIZA — MIT, 1966' : 'LOGIC THEORIST — 1956', tx + 24, ty + 34, { font: '17px MonoBold', color: rgba(green, 0.7) });
  line(ctx, tx, ty + 50, tx + tw, ty + 50, 'rgba(124,242,154,0.25)', 1);
  let cursor = null;
  if (!elizaOn) {
    fade(ctx, lta, () => {
      cursor = terminalLines(ctx, [
        { s: 'GOAL: Principia Mathematica, theorem 2.01', color: white, gap: 8 },
        { s: '  (p ⊃ ~p) ⊃ ~p', color: green, gap: 8 },
        { s: 'SEARCHING axioms and substitutions...', color: white },
        { s: '  apply 1.2  (p ∨ p) ⊃ p', color: green },
        { s: '  substitute ~p for p', color: green },
        { s: '  replace (~p ∨ ~p) by (p ⊃ ~p)', color: green, gap: 8 },
        { s: 'PROVED.', color: C.amber },
      ], tx + 26, ty + 92, lt, 1.0, S[1] - 1.2, 36);
    });
  } else {
    cursor = terminalLines(ctx, [
      { s: '> Men are all alike.', color: white },
      { s: 'IN WHAT WAY?', color: green, gap: 12 },
      { s: '> They’re always bugging us about something or other.', color: white },
      { s: 'CAN YOU THINK OF A SPECIFIC EXAMPLE?', color: green, gap: 12 },
      { s: '> Well, my boyfriend made me come here.', color: white },
      { s: 'YOUR BOYFRIEND MADE YOU COME HERE?', color: green },
    ], tx + 26, ty + 92, lt, S[1] + 0.2, E[1] + 1.8, 36);
  }
  if (cursor && Math.floor(lt * 2) % 2 === 0) {
    ctx.fillStyle = green;
    ctx.fillRect(cursor.x, cursor.y - 20, 12, 24);
  }

  // Shakey plans a route
  const gx = 30, gy = 440, gw = w - 60, gh = 226;
  card(ctx, gx, gy, gw, gh, { r: 14, fill: 'rgba(0,0,0,0.22)' });
  for (let i = 1; i < 16; i++) line(ctx, gx + (gw * i) / 16, gy, gx + (gw * i) / 16, gy + gh, 'rgba(255,255,255,0.05)', 1);
  for (let i = 1; i < 5; i++) line(ctx, gx, gy + (gh * i) / 5, gx + gw, gy + (gh * i) / 5, 'rgba(255,255,255,0.05)', 1);
  label(ctx, 'SHAKEY, SRI (1966–72)', gx + 18, gy + 30, { color: P.color });
  const boxes = [[0.15, 0.2, 0.1, 0.38], [0.44, 0.45, 0.1, 0.55], [0.76, 0.12, 0.1, 0.4]];
  for (const [bxr, byr, bwr, bhr] of boxes) {
    card(ctx, gx + bxr * gw, gy + byr * gh, bwr * gw, bhr * gh, { r: 6, fill: 'rgba(183,148,246,0.25)', stroke: 'rgba(183,148,246,0.6)' });
  }
  const X = (v) => gx + v * gw, Y = (v) => gy + v * gh;
  const plan = prog(lt, S[2], S[2] + 1.6, (x) => x);
  if (plan > 0) {
    ctx.setLineDash([8, 8]);
    ctx.strokeStyle = C.amber;
    ctx.lineWidth = 3;
    ctx.beginPath();
    const n = 60;
    for (let i = 0; i <= n * plan; i++) {
      const [px, py] = pathPoint(SHAKEY_PATH, i / n);
      if (i === 0) ctx.moveTo(X(px), Y(py));
      else ctx.lineTo(X(px), Y(py));
    }
    ctx.stroke();
    ctx.setLineDash([]);
  }
  circle(ctx, X(0.9), Y(0.7), 10, null, C.amber, 3);
  text(ctx, 'goal', X(0.9), Y(0.7) - 18, { font: '16px Semi', color: C.amber, align: 'center' });
  const move = prog(lt, S[2] + 1.6, P.dur - 0.6);
  const [rx, ry] = pathPoint(SHAKEY_PATH, move);
  drawShakey(ctx, X(rx), Y(ry), lt);
}

function drawShakey(ctx, x, y, lt) {
  ctx.save();
  ctx.translate(x, y);
  ctx.fillStyle = '#2B3550';
  rr(ctx, -20, -6, 40, 14, 4); ctx.fill();
  circle(ctx, -12, 9, 5, '#111');
  circle(ctx, 12, 9, 5, '#111');
  ctx.fillStyle = '#A9B6D6';
  rr(ctx, -16, -38, 32, 32, 4); ctx.fill();
  ctx.fillStyle = '#7C89A8';
  ctx.fillRect(-2, -64, 4, 26);
  ctx.fillStyle = '#C9D3EA';
  rr(ctx, -12, -78, 24, 16, 3); ctx.fill();
  circle(ctx, 6, -70, 3.5, Math.floor(lt * 3) % 2 ? C.red : '#552222');
  line(ctx, 0, -78, 0, -92, '#C9D3EA', 2);
  ctx.restore();
}

// ------------------------------------------------------------------ First AI winter
function winter(ctx, P) {
  const { lt, S, E, w } = P;
  const cx0 = 70, cx1 = w - 50, cy0 = 95, cy1 = 340;
  label(ctx, 'ENTHUSIASM AND FUNDING  (ILLUSTRATIVE)', cx0, 44, { color: C.ice });
  line(ctx, cx0, cy1, cx1, cy1, 'rgba(255,255,255,0.3)', 2);
  for (const yr of [1956, 1962, 1968, 1974, 1980]) {
    const x = lerp(cx0, cx1, (yr - 1956) / 24);
    text(ctx, String(yr), x, cy1 + 28, { font: '17px Med', color: C.dim, align: 'center' });
  }
  const f = (yr) => {
    if (yr < 1969) return 0.25 + 0.6 * ((yr - 1956) / 13) ** 1.3;
    if (yr < 1975) return 0.85 - 0.7 * easeInOut((yr - 1969) / 6);
    return 0.15 + 0.03 * Math.sin(yr);
  };
  const drawn = prog(lt, 0.4, S[2] + 1.5, (x) => x);
  ctx.strokeStyle = C.ice;
  ctx.lineWidth = 4;
  ctx.beginPath();
  for (let i = 0; i <= 120 * drawn; i++) {
    const yr = 1956 + (i / 120) * 24;
    const x = lerp(cx0, cx1, i / 120), y = lerp(cy1, cy0, f(yr));
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
  // promises keep climbing
  ctx.setLineDash([10, 10]);
  ctx.strokeStyle = rgba(C.amber, 0.8);
  ctx.lineWidth = 3;
  ctx.beginPath();
  for (let i = 0; i <= 120 * Math.min(drawn, 0.6); i++) {
    const x = lerp(cx0, cx1, i / 120), y = lerp(cy1, cy0, 0.25 + 0.75 * (i / 72) ** 1.2);
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
  ctx.setLineDash([]);
  text(ctx, 'promises', lerp(cx0, cx1, 0.6) + 12, cy0 + 4, { font: '19px Semi', color: C.amber, alpha: prog(lt, 2, 3) });
  text(ctx, 'funding', lerp(cx0, cx1, 0.3) + 20, lerp(cy1, cy0, 0.55) + 30, { font: '19px Semi', color: C.ice, alpha: prog(lt, 2, 3) });
  stamp(ctx, 'FUNDING CUT', lerp(cx0, cx1, 0.78), 180, prog(lt, S[2] + 0.3, S[2] + 0.8), '#9DC8F0');

  // The two documents
  const docs = [
    { t: ['Perceptrons'], a: 'Marvin Minsky & Seymour Papert', y: '1969', col: '#C8553D' },
    { t: ['Artificial Intelligence:', 'A General Survey'], a: 'Sir James Lighthill', y: '1973', col: '#2F4B7C' },
  ];
  docs.forEach((d, i) => {
    const a = prog(lt, S[1] + i * 4.5, S[1] + i * 4.5 + 0.8, easeOut);
    const x = 90 + i * 380, y = 410 + (1 - a) * 40;
    fade(ctx, a, () => {
      ctx.save();
      ctx.translate(x + 150, y + 120);
      ctx.rotate(i ? 0.03 : -0.03);
      ctx.fillStyle = d.col;
      ctx.fillRect(-150, -115, 300, 230);
      ctx.fillStyle = 'rgba(255,255,255,0.12)';
      ctx.fillRect(-150, -115, 14, 230);
      d.t.forEach((s, k) => text(ctx, s, 8, -50 + k * 32, { font: '27px SerifBold', color: '#F6F1E6', align: 'center' }));
      text(ctx, d.a, 8, 40, { font: '17px SerifItalic', color: '#F0E6D2', align: 'center' });
      text(ctx, d.y, 8, 88, { font: '24px DispBold', color: '#F6F1E6', align: 'center' });
      ctx.restore();
    });
  });
  snow(ctx, lt, w, P.h, prog(lt, 0.5, S[2] + 1.5));
}

// ------------------------------------------------------------------ 1980s expert systems + backprop
const NET = [3, 5, 5, 2];
function drawNet(ctx, x0, x1, ycen, spread, lt, t0, color) {
  const lx = (i) => lerp(x0, x1, i / (NET.length - 1));
  const ly = (i, j) => ycen + (j - (NET[i] - 1) / 2) * spread;
  const cyc = 3.2;
  const tt = Math.max(0, lt - t0);
  const ph = (tt % cyc) / cyc;
  const fwd = ph < 0.5, p = fwd ? ph / 0.5 : (ph - 0.5) / 0.5;
  const pos = fwd ? p * (NET.length - 1) : (1 - p) * (NET.length - 1);
  for (let i = 0; i < NET.length - 1; i++) {
    for (let a = 0; a < NET[i]; a++) {
      for (let b = 0; b < NET[i + 1]; b++) {
        const wv = Math.sin(a * 2.1 + b * 1.3 + i * 0.7 + Math.floor(tt / cyc) * 0.9);
        line(ctx, lx(i), ly(i, a), lx(i + 1), ly(i + 1, b), rgba(wv > 0 ? C.teal : C.pink, 0.15 + 0.3 * Math.abs(wv)), 1 + 2 * Math.abs(wv));
        if (tt > 0 && pos >= i && pos <= i + 1 && (a + b) % 2 === 0) {
          const f = pos - i;
          pulse(ctx, lx(i), ly(i, a), lx(i + 1), ly(i + 1, b), f, fwd ? C.teal : C.amber, 3.5);
        }
      }
    }
  }
  for (let i = 0; i < NET.length; i++) {
    for (let j = 0; j < NET[i]; j++) circle(ctx, lx(i), ly(i, j), 13, '#121C38', color, 2.5);
  }
  return { fwd, active: tt > 0 };
}

function expert(ctx, P) {
  const { lt, S, E, w } = P;
  label(ctx, 'RULE ENGINE', 30, 42, { color: P.color });
  const rules = [
    ['IF', 'order has CPU AND no cabinet', 'ADD cabinet'],
    ['IF', 'disk drives > 2', 'ADD expansion box'],
    ['IF', 'cabinet AND power < needed', 'ADD power supply'],
    ['IF', 'all parts placed', 'PRINT layout'],
  ];
  const facts = ['CPU: VAX-11/780', '+ cabinet', '+ expansion box', '+ power supply', '✓ layout ready'];
  const cyc = 1.5;
  const fired = Math.floor(Math.max(0, lt - 1.2) / cyc);
  rules.forEach((r, i) => {
    const y = 60 + i * 64;
    const on = fired % 6 === i;
    const done = (fired % 6) > i || (fired % 6) === 5;
    card(ctx, 30, y, 540, 54, { r: 10, fill: on ? rgba(P.color, 0.28) : 'rgba(255,255,255,0.04)', stroke: on ? P.color : 'rgba(255,255,255,0.1)' });
    text(ctx, r[0], 48, y + 35, { font: '19px MonoBold', color: P.color });
    text(ctx, r[1], 84, y + 35, { font: '17px Mono', color: C.text });
    text(ctx, '→ ' + r[2], 556, y + 35, { font: '17px MonoBold', color: done || on ? C.amber : C.dim, align: 'right' });
  });
  card(ctx, 596, 60, 234, 248, { r: 12, fill: 'rgba(0,0,0,0.25)' });
  label(ctx, 'WORKING MEMORY', 614, 88, { color: C.sub });
  const nf = Math.min(5, 1 + (fired % 6));
  for (let i = 0; i < nf; i++) text(ctx, facts[i], 614, 124 + i * 36, { font: '18px Mono', color: i === 0 ? C.text : C.amber });
  text(ctx, 'Illustrative rules in the style of XCON', 30, 336, { font: '16px Med', color: C.dim });

  // knowledge engineering, then backprop
  const ka = 1 - prog(lt, S[2] - 0.4, S[2] + 0.2);
  fade(ctx, ka, () => {
    const y = 510;
    person(ctx, 120, y + 10, 80, '#E9D5B5');
    text(ctx, 'Human expert', 120, y + 90, { font: '19px Semi', color: C.sub, align: 'center' });
    arrow(ctx, 190, y, 330, y, { color: C.sub, alpha: prog(lt, 1, 2) });
    text(ctx, 'interviews', 260, y - 16, { font: '16px Med', color: C.dim, align: 'center', alpha: prog(lt, 1, 2) });
    fade(ctx, prog(lt, 1.5, 2.5), () => {
      card(ctx, 350, y - 60, 140, 120, { r: 10, fill: 'rgba(255,255,255,0.08)' });
      for (let i = 0; i < 6; i++) {
        ctx.fillStyle = rgba(P.color, 0.6);
        ctx.fillRect(368, y - 40 + i * 17, i % 2 ? 80 : 104, 7);
      }
      text(ctx, 'IF–THEN rules', 420, y + 90, { font: '19px Semi', color: C.sub, align: 'center' });
    });
    arrow(ctx, 510, y, 640, y, { color: C.sub, alpha: prog(lt, 2.2, 3.2) });
    fade(ctx, prog(lt, 2.7, 3.7), () => {
      monitor(ctx, 720, y, 110, '#B7C6E6', 'rgba(40,30,80,0.95)');
      text(ctx, 'Expert system', 720, y + 90, { font: '19px Semi', color: C.sub, align: 'center' });
    });
  });
  const na = prog(lt, S[2] - 0.1, S[2] + 0.6);
  fade(ctx, na, () => {
    label(ctx, 'BACKPROPAGATION (1986)', 30, 392, { color: P.color });
    const st = drawNet(ctx, 120, 740, 528, 54, lt, S[2] + 0.5, P.color);
    if (st.active) {
      text(ctx, st.fwd ? 'forward: make a prediction' : 'backward: send the error back, nudge every weight', 430, 672, {
        font: '19px Semi', color: st.fwd ? C.teal : C.amber, align: 'center',
      });
    }
    text(ctx, 'input', 120, 666, { font: '16px Med', color: C.dim, align: 'center' });
    text(ctx, 'hidden layers', 430, 400, { font: '16px Med', color: C.dim, align: 'center' });
    text(ctx, 'output', 740, 666, { font: '16px Med', color: C.dim, align: 'center' });
  });
}

// ------------------------------------------------------------------ Second AI winter
const TOWER = (() => {
  const blocks = [];
  const r = rng(9);
  const rows = 7;
  for (let row = 0; row < rows; row++) {
    const n = row % 2 ? 2 : 3;
    const bw = n === 3 ? 100 : 150;
    for (let k = 0; k < n; k++) {
      blocks.push({
        x: 90 + k * bw + bw / 2, y: 640 - 22 - row * 46, w: bw - 6, h: 40, row,
        label: `RULE ${1000 + Math.floor(r() * 9000)}`,
        dir: r() > 0.5 ? 1 : -1, vx: (r() - 0.3) * 160, spin: (r() - 0.5) * 4, delay: (rows - row) * 0.05 + r() * 0.15,
      });
    }
  }
  return blocks;
})();

function winter2(ctx, P) {
  const { lt, S, w, h } = P;
  label(ctx, 'A TOWER OF RULES', 80, 44, { color: C.ice });
  const hit = S[0] + 2.2;
  // the edge case that breaks it
  const ea = prog(lt, S[0] + 0.6, hit, (x) => x * x);
  const ex = lerp(-100, 300, ea), ey = lerp(120, 330, ea);
  if (lt < hit + 0.6) {
    fade(ctx, 1 - prog(lt, hit, hit + 0.6), () => {
      card(ctx, ex - 70, ey - 22, 140, 44, { r: 8, fill: rgba(C.red, 0.85), stroke: null });
      text(ctx, 'EDGE CASE', ex, ey + 7, { font: '18px Bold', color: '#fff', align: 'center' });
    });
  }
  const floor = 640;
  line(ctx, 40, floor, 440, floor, 'rgba(255,255,255,0.3)', 2);
  for (const b of TOWER) {
    const tt = Math.max(0, lt - hit - b.delay);
    let x = b.x, y = b.y, a = 0;
    if (tt > 0) {
      const g = 900;
      y = Math.min(floor - b.h / 2 + 4, b.y + 0.5 * g * tt * tt);
      const fallT = Math.sqrt((2 * Math.max(1, floor - b.h / 2 - b.y)) / g);
      const te = Math.min(tt, fallT);
      x = b.x + b.vx * te;
      a = b.spin * te;
    }
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(a);
    card(ctx, -b.w / 2, -b.h / 2, b.w, b.h, { r: 6, fill: rgba(C.violet, 0.3 + 0.1 * (b.row % 2)), stroke: rgba(C.violet, 0.8) });
    text(ctx, b.label, 0, 6, { font: '15px MonoBold', color: '#E9DDFF', align: 'center' });
    ctx.restore();
  }

  // Lisp machine market
  const mx = 640, my = 360;
  const dead = prog(lt, S[1] + 0.5, S[1] + 2.5);
  fade(ctx, prog(lt, 0.3, 1.2), () => {
    label(ctx, 'LISP MACHINE', mx, 44, { color: C.ice, align: 'center' });
    const body = mixHex('#3B4A78', '#2A2F3C', dead);
    card(ctx, mx - 85, 70, 170, 400, { r: 10, fill: body, stroke: 'rgba(255,255,255,0.25)' });
    card(ctx, mx - 65, 92, 130, 96, { r: 6, fill: dead > 0.5 ? '#0A0C12' : '#123', stroke: 'rgba(255,255,255,0.2)' });
    if (dead < 0.6) {
      for (let i = 0; i < 4; i++) {
        ctx.fillStyle = rgba(C.green, 0.6 * (1 - dead));
        ctx.fillRect(mx - 52, 108 + i * 18, 40 + ((i * 37) % 60), 6);
      }
    }
    for (let i = 0; i < 6; i++) line(ctx, mx - 60, 230 + i * 26, mx + 60, 230 + i * 26, 'rgba(0,0,0,0.35)', 3);
    for (let i = 0; i < 3; i++) circle(ctx, mx - 40 + i * 40, 440, 6, i === 0 && dead < 0.5 ? C.green : '#222');
  });
  const sa = prog(lt, S[1] + 0.6, S[1] + 1.4, easeOut);
  fade(ctx, sa, () => {
    ctx.strokeStyle = C.red;
    ctx.lineWidth = 5;
    ctx.beginPath();
    const pts = [[480, 520], [540, 505], [590, 530], [640, 560], [700, 600], [780, 650]];
    pts.forEach(([x, y], i) => {
      const yy = lerp(520, y, sa);
      if (i === 0) ctx.moveTo(x, yy); else ctx.lineTo(x, yy);
    });
    ctx.stroke();
    text(ctx, '1987: market collapses', 470, 645, { font: '22px Bold', color: C.red });
  });
  snow(ctx, lt, w, h, prog(lt, S[1], S[1] + 3), 8);
}

// ------------------------------------------------------------------ 1989-1997 LeNet + Deep Blue
const DIGITS = (() => {
  const make = (draw) => {
    const c = createCanvas(28, 28);
    const g = c.getContext('2d');
    g.fillStyle = '#000';
    g.fillRect(0, 0, 28, 28);
    g.strokeStyle = '#fff';
    g.lineWidth = 2.8;
    g.lineCap = 'round';
    g.lineJoin = 'round';
    g.beginPath();
    draw(g);
    g.stroke();
    const d = g.getImageData(0, 0, 28, 28).data;
    return Array.from({ length: 784 }, (_, i) => d[i * 4] / 255);
  };
  return [
    { label: 3, px: make((g) => { g.moveTo(8, 7); g.bezierCurveTo(13, 2, 22, 5, 18, 11); g.quadraticCurveTo(16, 13.5, 12, 13.5); g.moveTo(12, 13.5); g.bezierCurveTo(22, 13, 22, 23, 15, 23.5); g.quadraticCurveTo(10, 24, 7, 21); }) },
    { label: 7, px: make((g) => { g.moveTo(6, 6.5); g.lineTo(21, 5.5); g.quadraticCurveTo(16, 13, 11.5, 23.5); g.moveTo(10, 14.5); g.lineTo(18, 14); }) },
    { label: 2, px: make((g) => { g.moveTo(7, 9); g.bezierCurveTo(8, 3, 20, 3, 19, 10); g.quadraticCurveTo(17, 15, 7, 22.5); g.lineTo(21, 22); }) },
  ];
})();
const EDGE_K = [[-1, -1, -1], [0, 0, 0], [1, 1, 1]];

function convMap(px) {
  const out = [];
  for (let y = 0; y < 26; y++) {
    for (let x = 0; x < 26; x++) {
      let s = 0;
      for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) s += px[(y + j) * 28 + x + i] * EDGE_K[j][i];
      out.push(s);
    }
  }
  return out;
}
const DIGIT_MAPS = DIGITS.map((d) => convMap(d.px));

const CHESS = [
  'r.bq.rk.',
  'pp..bppp',
  '..np.n..',
  '..p.p...',
  '....P...',
  '..NP.N..',
  'PPP.BPPP',
  'R.BQ.RK.',
];
const GLYPH = { k: '♚', q: '♛', r: '♜', b: '♝', n: '♞', p: '♟' };

function nineties(ctx, P) {
  const { lt, S, w } = P;
  const split = S[1] - 0.3;
  fade(ctx, stage(lt, 0.2, split + 0.3), () => {
    label(ctx, 'CONVOLUTIONAL NETWORK READING DIGITS', 34, 46, { color: P.color });
    const per = Math.max(2.5, (split - 0.5) / 3);
    const k = Math.min(2, Math.floor(Math.max(0, lt - 0.5) / per));
    const lp = clamp((lt - 0.5 - k * per) / per);
    const d = DIGITS[k], map = DIGIT_MAPS[k];
    const cs = 11, ox = 34, oy = 80;
    for (let i = 0; i < 784; i++) {
      const v = d.px[i];
      ctx.fillStyle = v > 0.04 ? `rgba(255,255,255,${0.15 + 0.85 * v})` : 'rgba(255,255,255,0.04)';
      ctx.fillRect(ox + (i % 28) * cs, oy + Math.floor(i / 28) * cs, cs - 1, cs - 1);
    }
    text(ctx, 'input pixels', ox + 154, oy + 340, { font: '17px Med', color: C.dim, align: 'center' });
    const scan = clamp(lp / 0.65);
    const pos = Math.floor(scan * 675);
    const sx = pos % 26, sy = Math.floor(pos / 26);
    if (scan < 1) {
      ctx.strokeStyle = C.amber;
      ctx.lineWidth = 2.5;
      ctx.strokeRect(ox + sx * cs - 1, oy + sy * cs - 1, cs * 3 + 1, cs * 3 + 1);
    }
    const fx = 380, fy = 117, fs = 9;
    for (let i = 0; i < 676; i++) {
      if (i > pos && scan < 1) break;
      const v = map[i];
      ctx.fillStyle = v > 0 ? rgba(C.teal, clamp(v / 2.2)) : rgba(C.pink, clamp(-v / 2.2));
      ctx.fillRect(fx + (i % 26) * fs, fy + Math.floor(i / 26) * fs, fs - 1, fs - 1);
    }
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    ctx.strokeRect(fx - 2, fy - 2, 26 * fs + 3, 26 * fs + 3);
    text(ctx, 'feature map (edge filter)', fx + 117, oy + 340, { font: '17px Med', color: C.dim, align: 'center' });
    if (scan < 1) {
      line(ctx, ox + (sx + 1.5) * cs, oy + (sy + 1.5) * cs, fx + sx * fs + 4, fy + sy * fs + 4, rgba(C.amber, 0.5), 1.5);
    }
    // output scores
    const sp = prog(lp, 0.65, 0.85);
    const bx = 660;
    for (let i = 0; i < 10; i++) {
      const y = 82 + i * 31;
      const v = i === d.label ? 0.97 : 0.03 * ((i * 7 + k * 3) % 5) / 4;
      text(ctx, String(i), bx, y + 17, { font: '19px Bold', color: i === d.label && sp > 0.5 ? C.amber : C.sub });
      ctx.fillStyle = 'rgba(255,255,255,0.06)';
      ctx.fillRect(bx + 26, y + 2, 140, 20);
      ctx.fillStyle = i === d.label ? C.amber : rgba(C.sub, 0.6);
      ctx.fillRect(bx + 26, y + 2, 140 * v * sp, 20);
    }
    text(ctx, 'prediction', bx + 90, oy + 340, { font: '17px Med', color: C.dim, align: 'center' });
    fade(ctx, prog(lp, 0.8, 0.9), () =>
      text(ctx, `“${d.label}”`, w / 2, 570, { font: '110px DispBlack', color: C.amber, align: 'center' }));
    text(ctx, 'LeNet-style networks went on to read handwritten bank checks', w / 2, 650, { font: '21px Med', color: C.sub, align: 'center' });
  });

  fade(ctx, stage(lt, split, P.dur + 1), () => {
    const bx = 34, by = 60, sq = 64;
    label(ctx, 'IBM DEEP BLUE vs. GARRY KASPAROV — MAY 1997', bx, 42, { color: P.color });
    for (let r = 0; r < 8; r++) {
      for (let c = 0; c < 8; c++) {
        ctx.fillStyle = (r + c) % 2 ? '#56688F' : '#C7D2E8';
        ctx.fillRect(bx + c * sq, by + r * sq, sq, sq);
        const ch = CHESS[r][c];
        if (ch === '.') continue;
        const white = ch === ch.toUpperCase();
        const g = GLYPH[ch.toLowerCase()];
        ctx.font = '50px Sym';
        ctx.textAlign = 'center';
        ctx.lineWidth = 2;
        ctx.strokeStyle = white ? '#1A1E2A' : '#E9EEF8';
        ctx.fillStyle = white ? '#FFFFFF' : '#141824';
        ctx.fillText(g, bx + c * sq + sq / 2, by + r * sq + 49);
        ctx.strokeText(g, bx + c * sq + sq / 2, by + r * sq + 49);
      }
    }
    const lt2 = lt - split;
    const sx = 600;
    card(ctx, sx - 40, 60, 260, 210, { r: 14, fill: 'rgba(0,0,0,0.25)' });
    text(ctx, 'FINAL SCORE', sx + 90, 96, { font: '17px Bold', color: C.dim, align: 'center' });
    text(ctx, 'Deep Blue', sx - 16, 150, { font: '26px Semi', color: C.text });
    text(ctx, '3½', sx + 200, 150, { font: '34px DispBold', color: P.color, align: 'right' });
    text(ctx, 'Kasparov', sx - 16, 210, { font: '26px Semi', color: C.sub });
    text(ctx, '2½', sx + 200, 210, { font: '34px DispBold', color: C.sub, align: 'right' });
    const n = Math.round(200e6 * prog(lt2, 1.5, 5, easeOut));
    text(ctx, n.toLocaleString('en-US'), sx + 90, 340, { font: '34px DispBold', color: C.amber, align: 'center', alpha: prog(lt2, 1.2, 1.8) });
    text(ctx, 'positions per second', sx + 90, 372, { font: '18px Med', color: C.sub, align: 'center', alpha: prog(lt2, 1.2, 1.8) });
    // search tree
    const rootX = sx + 90, rootY = 420;
    const sweep = (lt2 * 1.6) % 1;
    fade(ctx, prog(lt2, 1.5, 2.3), () => {
      for (let a = 0; a < 4; a++) {
        const ax = rootX + (a - 1.5) * 64, ay = rootY + 80;
        line(ctx, rootX, rootY, ax, ay, 'rgba(255,255,255,0.25)', 1.5);
        for (let b = 0; b < 4; b++) {
          const bxx = ax + (b - 1.5) * 15, byy = ay + 80;
          const lit = Math.abs((a * 4 + b) / 16 - sweep) < 0.08;
          line(ctx, ax, ay, bxx, byy, lit ? C.amber : 'rgba(255,255,255,0.18)', lit ? 2.5 : 1);
          circle(ctx, bxx, byy, 3.5, lit ? C.amber : 'rgba(255,255,255,0.4)');
        }
        circle(ctx, ax, ay, 6, 'rgba(255,255,255,0.6)');
      }
      circle(ctx, rootX, rootY, 8, P.color);
    });
  });
}

// ------------------------------------------------------------------ 2000s: data + GPUs
const TILES = (() => {
  const r = rng(21);
  const words = ['cat', 'dog', 'car', 'tree', 'boat', 'bird', 'cup', 'fish', 'bike', 'lamp', 'shoe', 'apple'];
  const t = [];
  for (let row = 0; row < 7; row++) {
    for (let col = 0; col < 16; col++) {
      t.push({ col, row, hue: Math.floor(r() * 360), shape: Math.floor(r() * 4), order: r(), word: words[Math.floor(r() * words.length)], lab: r() < 0.18 });
    }
  }
  return t;
})();

function tileShape(ctx, s, x, y, z, col) {
  ctx.fillStyle = col;
  ctx.beginPath();
  if (s === 0) ctx.arc(x, y, z, 0, TAU);
  else if (s === 1) { ctx.moveTo(x, y - z); ctx.lineTo(x + z, y + z * 0.8); ctx.lineTo(x - z, y + z * 0.8); ctx.closePath(); }
  else if (s === 2) ctx.rect(x - z * 0.8, y - z * 0.8, z * 1.6, z * 1.6);
  else { ctx.ellipse(x, y, z * 1.1, z * 0.6, 0.4, 0, TAU); }
  ctx.fill();
}

function data(ctx, P) {
  const { lt, S, w } = P;
  label(ctx, 'IMAGENET', 34, 44, { color: P.color });
  const ts = 46, gap = 4, ox = 34, oy = 62;
  const fill = prog(lt, 0.5, S[2], (x) => x);
  for (const t of TILES) {
    const a = clamp((fill - t.order * 0.9) * 8);
    const x = ox + t.col * (ts + gap), y = oy + t.row * (ts + gap);
    if (a <= 0) {
      ctx.fillStyle = 'rgba(255,255,255,0.04)';
      ctx.fillRect(x, y, ts, ts);
      continue;
    }
    ctx.save();
    ctx.globalAlpha *= a;
    ctx.fillStyle = `hsl(${t.hue},35%,22%)`;
    ctx.fillRect(x, y, ts, ts);
    tileShape(ctx, t.shape, x + ts / 2, y + ts / 2 - 2, 11, `hsl(${(t.hue + 160) % 360},65%,65%)`);
    if (t.lab) {
      ctx.fillStyle = 'rgba(0,0,0,0.65)';
      ctx.fillRect(x, y + ts - 15, ts, 15);
      text(ctx, t.word, x + ts / 2, y + ts - 3, { font: '11px Bold', color: '#fff', align: 'center' });
    }
    ctx.restore();
  }
  const ca = prog(lt, S[1] - 0.2, S[1] + 0.6);
  fade(ctx, ca, () => {
    const n = Math.round(14e6 * prog(lt, S[1], S[1] + 3.5, easeOut));
    card(ctx, w / 2 - 250, 250, 500, 110, { r: 16, fill: 'rgba(8,12,26,0.88)', stroke: rgba(P.color, 0.6) });
    text(ctx, n.toLocaleString('en-US') + (n >= 14e6 ? '+' : ''), w / 2, 310, { font: '50px DispBlack', color: P.color, align: 'center' });
    text(ctx, 'labeled images in 20,000+ categories', w / 2, 343, { font: '19px Med', color: C.sub, align: 'center' });
  });

  // CPU vs GPU
  const ga = prog(lt, S[2] - 0.2, S[2] + 0.6);
  fade(ctx, ga, () => {
    const y0 = 440;
    const lt2 = lt - S[2];
    // CPU
    card(ctx, 60, y0, 260, 180, { r: 12, fill: '#1B2238', stroke: 'rgba(255,255,255,0.25)' });
    for (let i = 0; i < 4; i++) {
      const on = Math.floor(lt2 * 4) % 4 === i;
      card(ctx, 80 + (i % 2) * 115, y0 + 20 + Math.floor(i / 2) * 75, 105, 65, { r: 8, fill: on ? rgba(C.amber, 0.8) : 'rgba(255,255,255,0.08)', stroke: null });
    }
    text(ctx, 'CPU: a few big cores', 190, y0 + 214, { font: '18px Semi', color: C.sub, align: 'center' });
    // GPU
    const gx = 400, gw = 400;
    card(ctx, gx, y0, gw, 180, { r: 12, fill: '#1B2238', stroke: rgba(P.color, 0.6) });
    const cols = 24, rows = 10;
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const wave = Math.sin(lt2 * 5 - c * 0.25 - r * 0.15) > 0.2;
        ctx.fillStyle = wave ? rgba(P.color, 0.85) : 'rgba(255,255,255,0.08)';
        ctx.fillRect(gx + 16 + c * 15.4, y0 + 14 + r * 15.4, 12, 12);
      }
    }
    text(ctx, 'GPU: thousands of small cores, in parallel', gx + gw / 2, y0 + 214, { font: '18px Semi', color: C.sub, align: 'center' });
  });
}

// ------------------------------------------------------------------ 2012 AlexNet
function alexnet(ctx, P) {
  const { lt, S, E } = P;
  const data = [[2010, 28.2], [2011, 25.8], [2012, 15.3], [2013, 11.7], [2014, 6.7], [2015, 3.6], [2016, 3.0], [2017, 2.3]];
  const x0 = 100, x1 = 820, y0 = 90, y1 = 560, max = 30;
  label(ctx, 'IMAGENET CHALLENGE: WINNING TOP-5 ERROR (%)', 40, 46, { color: P.color });
  const Y = (v) => lerp(y1, y0, v / max);
  for (const v of [0, 10, 20, 30]) {
    line(ctx, x0, Y(v), x1, Y(v), 'rgba(255,255,255,0.08)', 1);
    text(ctx, v + '%', x0 - 14, Y(v) + 6, { font: '17px Med', color: C.dim, align: 'right' });
  }
  const bw = 62, step = (x1 - x0) / data.length;
  const appear = (i) => (i < 2 ? 0.8 + i * 0.6 : i === 2 ? S[0] + 6 : S[1] + (i - 3) * 0.55);
  data.forEach(([yr, v], i) => {
    const p = prog(lt, appear(i), appear(i) + 0.9, easeOut);
    const x = x0 + step * i + (step - bw) / 2;
    const hi = yr === 2012;
    const deep = yr >= 2012;
    const col = hi ? P.color : deep ? rgba(P.color, 0.45) : 'rgba(170,180,205,0.55)';
    const top = Y(v * p);
    card(ctx, x, top, bw, y1 - top, { r: 6, fill: col, stroke: null });
    text(ctx, String(yr), x + bw / 2, y1 + 28, { font: '18px Semi', color: hi ? P.color : C.sub, align: 'center' });
    if (p > 0.6) text(ctx, v.toFixed(1), x + bw / 2, top - 12, { font: '18px Bold', color: hi ? P.color : C.text, align: 'center', alpha: prog(p, 0.6, 1) });
    if (hi && p > 0) {
      text(ctx, 'AlexNet', x + bw / 2, top - 40, { font: '22px Bold', color: P.color, align: 'center', alpha: prog(p, 0.6, 1) });
    }
    if (yr === 2015) text(ctx, 'ResNet', x + bw / 2, y1 + 52, { font: '17px Bold', color: P.color, align: 'center', alpha: prog(p, 0.6, 1) });
  });
  // the drop
  const da = prog(lt, S[0] + 7.5, S[0] + 8.5);
  fade(ctx, da, () => {
    const xa = x0 + step * 1 + step / 2, xb = x0 + step * 2 + step / 2;
    arrow(ctx, xa + 22, Y(25.8) - 30, xb + 8, Y(15.3) - 70, { color: C.amber, lw: 3 });
    text(ctx, '−10.5 points', (xa + xb) / 2 + 30, Y(25.8) - 44, { font: '20px Bold', color: C.amber, align: 'left' });
  });
  // human line
  const ha = prog(lt, S[1] + 2.5, S[1] + 3.5);
  fade(ctx, ha, () => {
    ctx.setLineDash([10, 8]);
    line(ctx, x0, Y(5.1), lerp(x0, x1, ha), Y(5.1), C.amber, 2.5);
    ctx.setLineDash([]);
    text(ctx, 'human estimate ≈ 5.1%', x1, Y(5.1) - 12, { font: '18px Bold', color: C.amber, align: 'right' });
  });
  text(ctx, 'Lower is better. Bars from 2012 on are deep neural networks.', 460, 650, { font: '18px Med', color: C.dim, align: 'center', alpha: prog(lt, S[1], S[1] + 1) });
}

// ------------------------------------------------------------------ 2013-2015: speech, GANs, Atari
const SMILE = [
  '..XXXX..',
  '.X....X.',
  'X.X..X.X',
  'X......X',
  'X.X..X.X',
  'X..XX..X',
  '.X....X.',
  '..XXXX..',
];
const NOISE = (() => { const r = rng(4); return Array.from({ length: 64 }, () => r()); })();

function pixGrid(ctx, x, y, cs, val, col) {
  for (let i = 0; i < 64; i++) {
    const v = val(i);
    ctx.fillStyle = rgba(col, 0.08 + 0.92 * clamp(v));
    ctx.fillRect(x + (i % 8) * cs, y + Math.floor(i / 8) * cs, cs - 2, cs - 2);
  }
}

function simBreakout(t) {
  const bricks = [];
  for (let r = 0; r < 4; r++) for (let c = 0; c < 10; c++) bricks.push({ r, c, alive: true });
  let x = 300, y = 300, vx = 230, vy = -260, score = 0;
  const dt = 1 / 60;
  const W = 600, H = 420;
  for (let s = 0; s < t * 60; s++) {
    x += vx * dt; y += vy * dt;
    if (x < 8 || x > W - 8) vx = -vx;
    if (y < 8) vy = -vy;
    if (y > H - 30 && vy > 0) vy = -vy;
    for (const b of bricks) {
      if (!b.alive) continue;
      const bx = 10 + b.c * 58, by = 40 + b.r * 24;
      if (x > bx && x < bx + 54 && y > by && y < by + 18) { b.alive = false; vy = -vy; score += 10 * (4 - b.r); break; }
    }
  }
  return { bricks, x, y, score };
}

function gan(ctx, P) {
  const { lt, S, E, w } = P;
  // speech + translation
  fade(ctx, stage(lt, 0.2, S[1] - 0.1), () => {
    label(ctx, 'SPEECH RECOGNITION', 50, 60, { color: P.color });
    ctx.strokeStyle = P.color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    for (let i = 0; i <= 300; i++) {
      const x = 50 + i * 2.53;
      const env = Math.max(0, Math.sin(i * 0.05 + 0.3)) * (0.4 + 0.6 * Math.abs(Math.sin(i * 0.013)));
      const y = 160 + Math.sin(i * 0.9 + lt * 12) * 60 * env * Math.sin(i * 0.21 + lt * 3);
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();
    const src = 'Where is the train station?';
    text(ctx, '“' + typed(src, prog(lt, 1.0, 3.0, (x) => x)) + '”', w / 2, 300, { font: '36px DispBold', color: C.text, align: 'center' });
    arrow(ctx, w / 2, 340, w / 2, 410, { color: C.sub, alpha: prog(lt, 3.0, 3.5) });
    label(ctx, 'MACHINE TRANSLATION', w / 2 + 20, 382, { alpha: prog(lt, 3.0, 3.5), color: P.color });
    const tr = 'Où est la gare ?';
    text(ctx, '« ' + typed(tr, prog(lt, 3.5, 5.0, (x) => x)) + ' »', w / 2, 470, { font: '36px DispBold', color: C.amber, align: 'center' });
  });
  // GAN
  fade(ctx, stage(lt, S[1] - 0.3, S[2] - 0.1), () => {
    const lt2 = lt - S[1];
    label(ctx, 'GENERATIVE ADVERSARIAL NETWORK (2014)', 40, 50, { color: P.color });
    ctx.translate(0, 50);
    const q = clamp(lt2 / 8);
    const target = (i) => (SMILE[Math.floor(i / 8)][i % 8] === 'X' ? 1 : 0);
    const shimmer = (i) => 0.5 + 0.5 * Math.sin(lt * 7 + i * 1.7);
    pixGrid(ctx, 50, 110, 14, (i) => shimmer(i), '#B0B8D0');
    text(ctx, 'random noise', 106, 248, { font: '17px Med', color: C.dim, align: 'center' });
    arrow(ctx, 172, 166, 222, 166, { color: C.sub });
    card(ctx, 226, 116, 150, 100, { r: 14, fill: rgba(C.pink, 0.18), stroke: C.pink });
    text(ctx, 'Generator', 301, 160, { font: '22px Bold', color: C.pink, align: 'center' });
    text(ctx, 'the forger', 301, 188, { font: '16px Med', color: C.sub, align: 'center' });
    arrow(ctx, 380, 166, 430, 166, { color: C.sub });
    const fake = (i) => lerp(NOISE[i], target(i), q) + 0.15 * (1 - q) * Math.sin(lt * 5 + i);
    pixGrid(ctx, 438, 110, 14, fake, C.pink);
    text(ctx, 'fake', 494, 248, { font: '17px Bold', color: C.pink, align: 'center' });
    pixGrid(ctx, 438, 340, 14, target, C.teal);
    text(ctx, 'real', 494, 478, { font: '17px Bold', color: C.teal, align: 'center' });
    arrow(ctx, 556, 166, 620, 260, { color: C.sub });
    arrow(ctx, 556, 396, 620, 320, { color: C.sub });
    card(ctx, 624, 236, 190, 110, { r: 14, fill: rgba(C.teal, 0.16), stroke: C.teal });
    text(ctx, 'Discriminator', 719, 282, { font: '22px Bold', color: C.teal, align: 'center' });
    text(ctx, 'the detective', 719, 310, { font: '16px Med', color: C.sub, align: 'center' });
    const pReal = lerp(0.04, 0.5, q);
    text(ctx, '“fake is real?”', 719, 390, { font: '18px Semi', color: C.sub, align: 'center' });
    card(ctx, 634, 404, 170, 18, { r: 9, fill: 'rgba(255,255,255,0.08)', stroke: null });
    card(ctx, 634, 404, 170 * pReal, 18, { r: 9, fill: C.amber, stroke: null });
    text(ctx, Math.round(pReal * 100) + '%', 719, 450, { font: '22px Bold', color: C.amber, align: 'center' });
    text(ctx, 'As they compete, the forger’s images get better and better', w / 2, 570, { font: '21px Med', color: C.sub, align: 'center' });
  });
  // Atari
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    const lt2 = Math.max(0, lt - S[2]);
    label(ctx, 'DEEPMIND DQN: LEARNING ATARI FROM PIXELS', 40, 50, { color: P.color });
    const gx = 40, gy = 80;
    card(ctx, gx, gy, 600, 420, { r: 8, fill: '#05070C', stroke: 'rgba(255,255,255,0.2)' });
    const sim = simBreakout(lt2);
    const cols = [C.red, C.amber, C.green, C.blue];
    for (const b of sim.bricks) {
      if (!b.alive) continue;
      ctx.fillStyle = cols[b.r];
      ctx.fillRect(gx + 10 + b.c * 58, gy + 40 + b.r * 24, 54, 18);
    }
    const px = clamp(sim.x, 45, 555);
    ctx.fillStyle = '#E8ECF5';
    ctx.fillRect(gx + px - 40, gy + 420 - 24, 80, 10);
    circle(ctx, gx + sim.x, gy + sim.y, 7, '#FFFFFF');
    text(ctx, 'SCORE ' + String(sim.score).padStart(4, '0'), gx + 590, gy + 26, { font: '17px MonoBold', color: C.text, align: 'right' });
    const sx = 680;
    ['pixels', 'network', 'action'].forEach((s, i) => {
      const y = 140 + i * 130;
      card(ctx, sx - 10, y - 30, 160, 64, { r: 12, fill: i === 1 ? rgba(P.color, 0.2) : 'rgba(255,255,255,0.05)', stroke: i === 1 ? P.color : 'rgba(255,255,255,0.15)' });
      text(ctx, s, sx + 70, y + 9, { font: '22px Bold', color: i === 1 ? P.color : C.text, align: 'center' });
      if (i < 2) arrow(ctx, sx + 70, y + 38, sx + 70, y + 92, { color: C.sub });
    });
    text(ctx, '←  →', sx + 70, 470, { font: '30px Sym', color: C.amber, align: 'center' });
    text(ctx, 'One network, dozens of games, no game-specific rules', w / 2, 590, { font: '21px Med', color: C.sub, align: 'center' });
  });
}

// ------------------------------------------------------------------ 2016 AlphaGo
const GO_STONES = (() => {
  const r = rng(37);
  const used = new Set();
  const out = [];
  const anchors = [[3, 3], [15, 3], [3, 15], [15, 15], [9, 9], [3, 9], [15, 9], [9, 3], [9, 15]];
  while (out.length < 90) {
    const a = anchors[Math.floor(r() * (out.length < 30 ? 4 : anchors.length))];
    const x = clamp(Math.round(a[0] + (r() - 0.5) * 7), 0, 18);
    const y = clamp(Math.round(a[1] + (r() - 0.5) * 7), 0, 18);
    const key = x + ',' + y;
    if (used.has(key) || (x === 14 && y === 9)) continue;
    used.add(key);
    out.push({ x, y, black: out.length % 2 === 0 });
  }
  return out;
})();

function alphago(ctx, P) {
  const { lt, S, E, w } = P;
  const bx = 44, by = 88, size = 540, cell = size / 18;
  label(ctx, 'GAME 2 — MARCH 10, 2016, SEOUL', 24, 44, { color: P.color });
  card(ctx, bx - 20, by - 20, size + 40, size + 40, { r: 8, fill: '#D6AE6B', stroke: null });
  for (let i = 0; i < 19; i++) {
    line(ctx, bx, by + i * cell, bx + size, by + i * cell, 'rgba(40,25,10,0.75)', 1.3);
    line(ctx, bx + i * cell, by, bx + i * cell, by + size, 'rgba(40,25,10,0.75)', 1.3);
  }
  for (const [x, y] of [[3, 3], [9, 3], [15, 3], [3, 9], [9, 9], [15, 9], [3, 15], [9, 15], [15, 15]]) circle(ctx, bx + x * cell, by + y * cell, 4, '#3A2810');
  const n = Math.floor(lerp(8, GO_STONES.length, prog(lt, 0.3, S[3] - 0.5, (x) => x)));
  for (let i = 0; i < n; i++) {
    const s = GO_STONES[i];
    const x = bx + s.x * cell, y = by + s.y * cell;
    circle(ctx, x + 2, y + 3, cell * 0.47, 'rgba(0,0,0,0.3)');
    const g = ctx.createRadialGradient(x - 5, y - 5, 2, x, y, cell * 0.5);
    g.addColorStop(0, s.black ? '#555' : '#FFFFFF');
    g.addColorStop(1, s.black ? '#0A0A0A' : '#C9C9C9');
    circle(ctx, x, y, cell * 0.47, g);
  }
  // Move 37
  const m = prog(lt, S[3], S[3] + 0.5, easeOutBack);
  if (m > 0) {
    const x = bx + 14 * cell, y = by + 9 * cell;
    const g = ctx.createRadialGradient(x - 5, y - 5, 2, x, y, cell * 0.5);
    g.addColorStop(0, '#555');
    g.addColorStop(1, '#0A0A0A');
    circle(ctx, x, y, cell * 0.47 * m, g);
    const pr = ((lt - S[3]) % 1.4) / 1.4;
    circle(ctx, x, y, cell * (0.6 + pr * 1.4), null, rgba(C.amber, 1 - pr), 3);
    fade(ctx, prog(lt, S[3] + 0.4, S[3] + 1), () => {
      card(ctx, x - 150, y - 80, 130, 40, { r: 10, fill: 'rgba(10,14,28,0.9)', stroke: C.amber });
      text(ctx, 'Move 37', x - 85, y - 53, { font: '21px Bold', color: C.amber, align: 'center' });
    });
  }
  // Score
  const sx = 640;
  card(ctx, sx, 64, 196, 230, { r: 14, fill: 'rgba(0,0,0,0.25)' });
  text(ctx, 'MATCH', sx + 98, 98, { font: '16px Bold', color: C.dim, align: 'center' });
  const s1 = Math.round(4 * prog(lt, 1, 3));
  text(ctx, 'AlphaGo', sx + 20, 150, { font: '23px Semi', color: C.text });
  text(ctx, String(s1), sx + 176, 152, { font: '40px DispBlack', color: P.color, align: 'right' });
  text(ctx, 'Lee Sedol', sx + 20, 220, { font: '23px Semi', color: C.sub });
  text(ctx, String(lt > 2.5 ? 1 : 0), sx + 176, 222, { font: '40px DispBlack', color: C.sub, align: 'right' });
  line(ctx, sx + 20, 252, sx + 176, 252, 'rgba(255,255,255,0.1)', 1);
  text(ctx, 'Best of five', sx + 98, 278, { font: '16px Med', color: C.dim, align: 'center' });
  // Big numbers
  fade(ctx, prog(lt, S[1] + 0.2, S[1] + 1.0), () => {
    text(ctx, 'Legal Go positions', sx + 98, 350, { font: '17px Semi', color: C.sub, align: 'center' });
    pow10(ctx, '~10', '170', sx + 98, 400, 44, C.amber, 'center');
  });
  fade(ctx, prog(lt, S[1] + 2.4, S[1] + 3.2), () => {
    text(ctx, 'Atoms in the', sx + 98, 460, { font: '17px Semi', color: C.sub, align: 'center' });
    text(ctx, 'observable universe', sx + 98, 482, { font: '17px Semi', color: C.sub, align: 'center' });
    pow10(ctx, '~10', '80', sx + 98, 532, 44, C.text, 'center');
  });
  fade(ctx, prog(lt, S[2], S[2] + 0.8), () => {
    text(ctx, 'self-play', sx + 98, 596, { font: '20px Bold', color: P.color, align: 'center' });
    const a = lt * 2;
    circle(ctx, sx + 98 + Math.cos(a) * 34, 640 + Math.sin(a) * 14, 9, '#111', 'rgba(255,255,255,0.5)', 1.5);
    circle(ctx, sx + 98 - Math.cos(a) * 34, 640 - Math.sin(a) * 14, 9, '#EEE');
  });
}

// ------------------------------------------------------------------ 2017 Transformer
const TOKENS = ['The', 'animal', 'didn’t', 'cross', 'the', 'street', 'because', 'it', 'was', 'too', 'tired'];
const ATT_A = [0.04, 0.55, 0.02, 0.03, 0.02, 0.12, 0.03, 0.06, 0.04, 0.03, 0.06];
const ATT_B = [0.03, 0.1, 0.02, 0.03, 0.04, 0.58, 0.03, 0.06, 0.03, 0.03, 0.05];

function transformer(ctx, P) {
  const { lt, S, E, w } = P;
  fade(ctx, prog(lt, 0.4, 1.2), () => {
    card(ctx, 30, 26, w - 60, 86, { r: 14, fill: '#F1EDE4', stroke: null });
    text(ctx, 'Attention Is All You Need', w / 2, 70, { font: '32px SerifBold', color: '#1D1D24', align: 'center' });
    text(ctx, 'Vaswani, Shazeer, Parmar, Uszkoreit, Jones, Gomez, Kaiser, Polosukhin · 2017', w / 2, 98, { font: '15px SerifItalic', color: '#55555F', align: 'center' });
  });
  const swap = prog(lt, S[1] + 4.2, S[1] + 5.2);
  const toks = TOKENS.slice();
  if (swap > 0.5) toks[10] = 'wide';
  let fs = 21, pad = 12, gap = 6;
  let widths, total;
  for (;;) {
    ctx.font = `${fs}px Semi`;
    widths = toks.map((t) => ctx.measureText(t).width + pad * 2);
    total = widths.reduce((a, b) => a + b, 0) + gap * (toks.length - 1);
    if (total <= w - 40 || fs <= 14) break;
    fs -= 1;
    pad = Math.max(8, pad - 1);
  }
  let x = (w - total) / 2;
  const centers = [];
  const ty = 320;
  const arcs = prog(lt, S[1] - 0.2, S[1] + 1.4);
  toks.forEach((t, i) => {
    centers.push(x + widths[i] / 2);
    const isIt = i === 7;
    const isLast = i === 10;
    card(ctx, x, ty - 22, widths[i], 44, {
      r: 10,
      fill: isIt && arcs > 0 ? rgba(P.color, 0.35) : isLast && swap > 0 && swap < 1 ? rgba(C.amber, 0.4) : 'rgba(255,255,255,0.07)',
      stroke: isIt && arcs > 0 ? P.color : 'rgba(255,255,255,0.15)',
    });
    text(ctx, t, x + widths[i] / 2, ty + 7, { font: `${fs}px Semi`, color: C.text, align: 'center' });
    x += widths[i] + gap;
  });
  if (arcs > 0) {
    const att = ATT_A.map((a, i) => lerp(a, ATT_B[i], swap));
    att.forEach((a, i) => {
      if (i === 7) return;
      const x1 = centers[7], x2 = centers[i];
      const hgt = Math.min(150, 36 + Math.abs(x2 - x1) * 0.3);
      ctx.strokeStyle = rgba(P.color, (0.25 + 0.75 * clamp(a * 2)) * arcs);
      ctx.lineWidth = 1 + a * 16;
      ctx.beginPath();
      ctx.moveTo(x1, ty - 24);
      ctx.bezierCurveTo(x1, ty - 24 - hgt, x2, ty - 24 - hgt, x2, ty - 24);
      ctx.stroke();
    });
    const strongest = swap > 0.5 ? 5 : 1;
    text(ctx, `“it” attends most to “${TOKENS[strongest]}”`, w / 2, 386, { font: '23px Bold', color: C.amber, align: 'center', alpha: arcs });
  }
  // attention matrix
  fade(ctx, prog(lt, S[2] - 0.2, S[2] + 0.6), () => {
    const cs = 20, mx = 50, my = 432;
    const r = rng(2);
    const fill = prog(lt, S[2], S[2] + 0.8);
    for (let i = 0; i < 11; i++) {
      for (let j = 0; j < 11; j++) {
        const v = i === j ? 0.6 : r() * 0.5 + (i === 7 && j === 1 ? 0.5 : 0);
        ctx.fillStyle = rgba(P.color, 0.08 + 0.85 * v * fill);
        ctx.fillRect(mx + j * cs, my + i * cs, cs - 2, cs - 2);
      }
    }
    text(ctx, 'every word × every word, at once', mx + 110, 672, { font: '16px Semi', color: C.sub, align: 'center' });
  });
  // stacked layers
  fade(ctx, prog(lt, S[3] - 0.3, S[3] + 0.5), () => {
    const sx = 330, sw = 490;
    for (let i = 0; i < 4; i++) {
      const y = 600 - i * 54;
      const lit = Math.floor((lt - S[3]) * 3) % 5 === i;
      card(ctx, sx, y, sw, 44, { r: 10, fill: lit ? rgba(P.color, 0.4) : 'rgba(255,255,255,0.06)', stroke: rgba(P.color, 0.5) });
      text(ctx, 'self-attention  +  feed-forward', sx + sw / 2, y + 28, { font: '17px Semi', color: C.text, align: 'center' });
    }
    text(ctx, 'stacked, layer upon layer', sx + sw / 2, 672, { font: '16px Bold', color: P.color, align: 'center' });
  });
}

// ------------------------------------------------------------------ 2018-2020 scaling
function scaling(ctx, P) {
  const { lt, S, E, w } = P;
  // next word
  fade(ctx, stage(lt, 0.3, S[2] - 0.1), () => {
    label(ctx, 'THE TRAINING TASK: PREDICT THE NEXT WORD', 40, 50, { color: P.color });
    const choose = prog(lt, 4.2, 4.8);
    text(ctx, 'The cat sat on the', 40, 116, { font: '38px DispBold', color: C.text });
    ctx.font = '38px DispBold';
    const bx = 40 + ctx.measureText('The cat sat on the').width + 14;
    card(ctx, bx, 80, 120, 50, { r: 10, fill: choose > 0 ? rgba(C.amber, 0.3) : 'rgba(255,255,255,0.06)', stroke: C.amber });
    text(ctx, choose > 0.5 ? 'mat' : '?', bx + 60, 116, { font: '34px DispBold', color: C.amber, align: 'center' });
    const cands = [['mat', 0.41], ['floor', 0.17], ['sofa', 0.09], ['roof', 0.04]];
    cands.forEach(([s, v], i) => {
      const p = prog(lt, 1.5 + i * 0.3, 2.6 + i * 0.3);
      const y = 160 + i * 30;
      text(ctx, s, 520, y + 18, { font: '19px Semi', color: i === 0 ? C.amber : C.sub, align: 'right' });
      ctx.fillStyle = i === 0 ? C.amber : rgba(C.sub, 0.5);
      ctx.fillRect(534, y + 4, 240 * v * 2 * p, 18);
      text(ctx, Math.round(v * 100) + '%', 540 + 480 * v * p + 4, y + 19, { font: '16px Bold', color: C.dim, alpha: p });
    });
  });
  // emerging skills
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    label(ctx, 'ABILITIES THAT APPEARED WITH SCALE', 40, 50, { color: P.color });
    const chips = ['Translation', 'Summarization', 'Question answering', 'Simple arithmetic', 'Writing code', 'Few-shot learning'];
    chips.forEach((c, i) => {
      const p = prog(lt, S[2] + 0.4 + i * 0.55, S[2] + 0.9 + i * 0.55, easeOutBack);
      const x = 40 + (i % 3) * 262, y = 80 + Math.floor(i / 3) * 76;
      ctx.save();
      ctx.translate(x + 120, y + 28);
      ctx.scale(Math.max(0.01, p), Math.max(0.01, p));
      card(ctx, -120, -28, 240, 56, { r: 28, fill: rgba(P.color, 0.18), stroke: P.color });
      text(ctx, c, 0, 8, { font: '20px Semi', color: C.text, align: 'center' });
      ctx.restore();
    });
  });
  // parameter counts
  const models = [['GPT-1', '2018', 117e6, '117M'], ['BERT-Large', '2018', 340e6, '340M'], ['GPT-2', '2019', 1.5e9, '1.5B'], ['GPT-3', '2020', 175e9, '175B']];
  const lx0 = 210, lx1 = 800;
  const L = (v) => lerp(lx0, lx1, (Math.log10(v) - 7.8) / 4.2);
  fade(ctx, prog(lt, S[1] - 0.6, S[1] + 0.2), () => {
    label(ctx, 'MODEL SIZE: PARAMETERS (LOG SCALE)', 40, 306, { color: P.color });
    [[1e8, '100M'], [1e9, '1B'], [1e10, '10B'], [1e11, '100B'], [1e12, '1T']].forEach(([v, s]) => {
      line(ctx, L(v), 330, L(v), 610, 'rgba(255,255,255,0.08)', 1);
      text(ctx, s, L(v), 640, { font: '16px Med', color: C.dim, align: 'center' });
    });
    models.forEach(([n, y, v, s], i) => {
      const p = prog(lt, S[1] + i * 1.2, S[1] + i * 1.2 + 1.0, easeOut);
      const yy = 340 + i * 66;
      text(ctx, n, 40, yy + 28, { font: '22px Bold', color: i === 3 ? P.color : C.text });
      text(ctx, y, 40, yy + 50, { font: '15px Med', color: C.dim });
      const x1 = lerp(lx0, L(v), p);
      card(ctx, lx0, yy + 8, Math.max(0, x1 - lx0), 34, { r: 8, fill: i === 3 ? P.color : rgba(P.color, 0.35 + i * 0.12), stroke: null });
      text(ctx, s, x1 + 10, yy + 33, { font: '20px Bold', color: i === 3 ? P.color : C.text, alpha: p });
    });
    text(ctx, '×1,500 in two years', 620, 690, { font: '17px Semi', color: C.sub, align: 'center', alpha: prog(lt, S[1] + 5, S[1] + 6) });
  });
}

// ------------------------------------------------------------------ 2020 AlphaFold
// A three-helix bundle: three alpha helices joined by two short loops.
const PROTEIN = (() => {
  const axes = [[4.6, 0], [-2.3, 4], [-2.3, -4]];
  const helix = (k, h, dir) => {
    const a = k * 1.745;
    const x = dir > 0 ? -13 + k * 1.5 : 13 - k * 1.5;
    return [x, axes[h][0] + 2.3 * Math.cos(a), axes[h][1] + 2.3 * Math.sin(a)];
  };
  const loop = (k, from, to, xEnd, sign) => {
    const f = (k + 1) / 6;
    return [xEnd + sign * 3.2 * Math.sin(f * Math.PI), lerp(axes[from][0], axes[to][0], f), lerp(axes[from][1], axes[to][1], f)];
  };
  const folded = [], seg = [];
  for (let k = 0; k < 18; k++) { folded.push(helix(k, 0, 1)); seg.push(0); }
  for (let k = 0; k < 5; k++) { folded.push(loop(k, 0, 1, 13, 1)); seg.push(3); }
  for (let k = 0; k < 18; k++) { folded.push(helix(k, 1, -1)); seg.push(1); }
  for (let k = 0; k < 5; k++) { folded.push(loop(k, 1, 2, -13, -1)); seg.push(3); }
  for (let k = 0; k < 18; k++) { folded.push(helix(k, 2, 1)); seg.push(2); }
  const n = folded.length;
  const straight = folded.map((_, i) => [-38 + i * (76 / (n - 1)), Math.sin(i * 0.45) * 2.2, Math.cos(i * 0.3) * 1.5]);
  return { n, folded, straight, seg };
})();

function alphafold(ctx, P) {
  const { lt, S, E, w } = P;
  const cols = [C.amber, C.teal, C.pink, '#8E9AB8'];
  const f = prog(lt, S[1] + 1, S[1] + 7);
  const scale = lerp(10, 15, f);
  const cx = w / 2, cy = 265;
  const spin = lt * 0.45;
  const pts = [];
  for (let i = 0; i < PROTEIN.n; i++) {
    const d = clamp(f * 1.3 - (i / PROTEIN.n) * 0.3);
    const e = easeInOut(d);
    const s = PROTEIN.straight[i], t = PROTEIN.folded[i];
    const x = lerp(s[0], t[0], e), y = lerp(s[1], t[1], e) + Math.sin(lt * 1.5 + i * 0.4) * 0.4 * (1 - e), z = lerp(s[2], t[2], e);
    const ang = spin * f;
    const cr = Math.cos(ang), sr = Math.sin(ang);
    const x2 = x * cr + z * sr, z2 = -x * sr + z * cr;
    const tilt = 0.45 * f;
    const y2 = y * Math.cos(tilt) - z2 * Math.sin(tilt), z3 = y * Math.sin(tilt) + z2 * Math.cos(tilt);
    const persp = 1 / (1 + z3 * 0.025);
    pts.push({ x: cx + x2 * scale * persp, y: cy - y2 * scale * persp, z: z3, k: persp });
  }
  // smooth tube, painted back to front
  const mid = (a, b) => ({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
  const segs = [];
  for (let i = 0; i < pts.length; i++) {
    const a = i > 0 ? mid(pts[i - 1], pts[i]) : pts[i];
    const b = i < pts.length - 1 ? mid(pts[i], pts[i + 1]) : pts[i];
    segs.push({ a, c: pts[i], b, z: pts[i].z, i });
  }
  segs.sort((p, q) => q.z - p.z);
  ctx.lineCap = 'round';
  for (const sg of segs) {
    const depth = clamp(0.62 - sg.z / 22, 0.3, 1);
    const width = 10 * sg.c.k * (scale / 15);
    ctx.beginPath();
    ctx.moveTo(sg.a.x, sg.a.y);
    ctx.quadraticCurveTo(sg.c.x, sg.c.y, sg.b.x, sg.b.y);
    ctx.strokeStyle = '#070B18';
    ctx.lineWidth = width + 4;
    ctx.stroke();
    ctx.strokeStyle = mixHex('#0C1430', cols[PROTEIN.seg[sg.i]], depth);
    ctx.lineWidth = width;
    ctx.stroke();
  }
  ctx.lineCap = 'butt';
  const la = 1 - prog(lt, S[1] + 1, S[1] + 2);
  text(ctx, 'amino-acid chain (1D sequence)', cx, 470, { font: '21px Semi', color: C.sub, align: 'center', alpha: la * prog(lt, 0.5, 1.2) });
  text(ctx, 'folded 3D structure', cx, 470, { font: '21px Semi', color: P.color, align: 'center', alpha: prog(lt, S[1] + 6, S[1] + 7) });
  label(ctx, 'ALPHAFOLD 2 · CASP14 (2020)', 34, 44, { color: P.color });

  const medals = [
    { at: S[2], t: 'Chemistry 2024', who: 'Demis Hassabis & John Jumper', note: 'shared with David Baker' },
    { at: S[3], t: 'Physics 2024', who: 'John Hopfield & Geoffrey Hinton', note: 'neural network foundations' },
  ];
  medals.forEach((m, i) => {
    const a = prog(lt, m.at - 0.1, m.at + 0.7, easeOut);
    const x = 40 + i * 400, y = 520 + (1 - a) * 30;
    fade(ctx, a, () => {
      card(ctx, x, y, 380, 140, { r: 16, fill: 'rgba(0,0,0,0.3)', stroke: 'rgba(245,184,75,0.45)' });
      const g = ctx.createRadialGradient(x + 62, y + 62, 4, x + 70, y + 70, 46);
      g.addColorStop(0, '#FFE7A3');
      g.addColorStop(1, '#B9832A');
      circle(ctx, x + 70, y + 70, 44, g);
      circle(ctx, x + 70, y + 70, 36, null, 'rgba(120,80,20,0.6)', 2);
      text(ctx, 'NOBEL', x + 70, y + 76, { font: '15px Bold', color: '#6B4A12', align: 'center' });
      text(ctx, m.t, x + 134, y + 48, { font: '22px Bold', color: C.amber });
      wrap(ctx, m.who, 230, '18px Semi').forEach((l, k) => text(ctx, l, x + 134, y + 78 + k * 23, { font: '18px Semi', color: C.text }));
      text(ctx, m.note, x + 134, y + 126, { font: '15px Med', color: C.dim });
    });
  });
}

// ------------------------------------------------------------------ 2022 Generative AI + ChatGPT
const LIGHTHOUSE = (() => {
  const c = createCanvas(520, 340);
  const g = c.getContext('2d');
  const sky = g.createLinearGradient(0, 0, 0, 230);
  sky.addColorStop(0, '#2B1E55');
  sky.addColorStop(0.55, '#D9577A');
  sky.addColorStop(1, '#FFB45E');
  g.fillStyle = sky;
  g.fillRect(0, 0, 520, 340);
  const sun = g.createRadialGradient(330, 210, 5, 330, 210, 90);
  sun.addColorStop(0, 'rgba(255,240,200,1)');
  sun.addColorStop(0.3, 'rgba(255,210,140,0.9)');
  sun.addColorStop(1, 'rgba(255,180,100,0)');
  g.fillStyle = sun;
  g.fillRect(200, 100, 260, 220);
  g.fillStyle = '#1E2A55';
  g.fillRect(0, 225, 520, 115);
  for (let i = 0; i < 9; i++) {
    g.fillStyle = `rgba(255,200,140,${0.5 - i * 0.05})`;
    g.fillRect(300 - i * 4, 232 + i * 11, 60 + i * 8, 3);
  }
  g.fillStyle = '#121626';
  g.beginPath();
  g.moveTo(0, 340); g.lineTo(0, 190); g.lineTo(70, 175); g.lineTo(150, 200); g.lineTo(190, 260); g.lineTo(210, 340);
  g.fill();
  g.fillStyle = '#EDE6DA';
  g.beginPath();
  g.moveTo(84, 182); g.lineTo(96, 92); g.lineTo(118, 92); g.lineTo(130, 186);
  g.fill();
  g.fillStyle = '#C8453D';
  g.fillRect(90, 120, 34, 14);
  g.fillRect(87, 150, 40, 14);
  g.fillStyle = '#1B1F2E';
  g.fillRect(92, 74, 30, 20);
  g.fillStyle = '#FFE9A8';
  g.fillRect(97, 78, 20, 12);
  const beam = g.createLinearGradient(110, 84, 330, 40);
  beam.addColorStop(0, 'rgba(255,240,180,0.55)');
  beam.addColorStop(1, 'rgba(255,240,180,0)');
  g.fillStyle = beam;
  g.beginPath();
  g.moveTo(112, 84); g.lineTo(360, 20); g.lineTo(360, 90);
  g.fill();
  return c;
})();
const NOISE_TEX = [0, 1, 2, 3, 4, 5].map((s) => {
  const c = createCanvas(520, 340);
  const g = c.getContext('2d');
  const r = rng(100 + s);
  for (let y = 0; y < 340; y += 10) {
    for (let x = 0; x < 520; x += 10) {
      const v = Math.floor(r() * 255);
      g.fillStyle = `rgb(${v},${Math.floor(v * (0.7 + r() * 0.6)) % 256},${Math.floor(r() * 255)})`;
      g.fillRect(x, y, 10, 10);
    }
  }
  return c;
});

function chatgpt(ctx, P) {
  const { lt, S, E, w } = P;
  // diffusion
  fade(ctx, stage(lt, 0.2, S[1] - 0.1), () => {
    label(ctx, 'TEXT-TO-IMAGE DIFFUSION', 40, 50, { color: P.color });
    card(ctx, 40, 72, w - 80, 56, { r: 28, fill: 'rgba(255,255,255,0.06)' });
    const prompt = 'a lighthouse on a cliff at sunset';
    text(ctx, '“' + typed(prompt, prog(lt, 0.8, 2.4, (x) => x)) + '”', 70, 109, { font: '24px Semi', color: C.text });
    const ix = (w - 520) / 2, iy = 160;
    const steps = 50;
    const p = prog(lt, 2.6, S[1] - 1.2, (x) => x);
    const step = Math.min(steps, Math.floor(p * steps));
    const noise = Math.pow(1 - step / steps, 1.6);
    ctx.drawImage(LIGHTHOUSE, ix, iy);
    ctx.save();
    ctx.globalAlpha *= noise;
    ctx.drawImage(NOISE_TEX[step % NOISE_TEX.length], ix, iy);
    ctx.restore();
    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
    ctx.lineWidth = 2;
    ctx.strokeRect(ix, iy, 520, 340);
    text(ctx, `denoising step ${step} / ${steps}`, w / 2, 540, { font: '19px Semi', color: C.sub, align: 'center' });
    text(ctx, 'Start from pure noise; remove a little at a time, guided by the text', w / 2, 600, { font: '20px Med', color: C.dim, align: 'center' });
  });
  // chat
  fade(ctx, stage(lt, S[1] - 0.3, S[2] - 0.1), () => {
    const lt2 = lt - S[1];
    card(ctx, 60, 40, w - 120, 610, { r: 22, fill: '#11172B', stroke: 'rgba(255,255,255,0.12)' });
    circle(ctx, 92, 74, 7, C.red);
    circle(ctx, 114, 74, 7, C.amber);
    circle(ctx, 136, 74, 7, C.green);
    text(ctx, 'November 30, 2022', w / 2, 80, { font: '17px Semi', color: C.dim, align: 'center' });
    line(ctx, 60, 102, w - 60, 102, 'rgba(255,255,255,0.08)', 1);
    const q = 'Explain how you work, in one sentence.';
    ctx.font = '22px Med';
    const qw = ctx.measureText(q).width;
    fade(ctx, prog(lt2, 0.3, 0.8), () => {
      card(ctx, w - 100 - qw - 40, 130, qw + 40, 54, { r: 20, fill: rgba(C.blue, 0.35), stroke: null });
      text(ctx, q, w - 120, 164, { font: '22px Med', color: C.text, align: 'right' });
    });
    const ans = 'I’m a large language model: I predict text one word at a time, and I was fine-tuned with human feedback to follow instructions and be helpful.';
    const shown = typed(ans, prog(lt2, 1.4, E[1] - S[1] + 1.5, (x) => x));
    if (shown.length) {
      const ls = wrap(ctx, shown, 520, '22px Reg');
      card(ctx, 100, 220, 580, ls.length * 34 + 30, { r: 20, fill: 'rgba(255,255,255,0.07)', stroke: null });
      ls.forEach((l, k) => text(ctx, l, 124, 256 + k * 34, { font: '22px Reg', color: C.text }));
      if (shown.length < ans.length && Math.floor(lt * 3) % 2 === 0) {
        ctx.font = '22px Reg';
        circle(ctx, 130 + ctx.measureText(ls[ls.length - 1]).width, 250 + (ls.length - 1) * 34, 6, C.text);
      }
    }
    card(ctx, 100, 576, w - 200, 50, { r: 25, fill: 'rgba(255,255,255,0.05)' });
    text(ctx, 'Message', 128, 608, { font: '19px Med', color: C.dim });
  });
  // growth
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    const lt2 = lt - S[2];
    label(ctx, 'USERS AFTER LAUNCH (ESTIMATES)', 40, 50, { color: P.color });
    const x0 = 120, x1 = 800, y0 = 90, y1 = 580;
    const X = (d) => lerp(x0, x1, d / 90), Y = (u) => lerp(y1, y0, u / 120);
    for (const u of [0, 25, 50, 75, 100]) {
      line(ctx, x0, Y(u), x1, Y(u), 'rgba(255,255,255,0.07)', 1);
      text(ctx, u + 'M', x0 - 12, Y(u) + 6, { font: '17px Med', color: C.dim, align: 'right' });
    }
    for (const [d, s] of [[0, 'launch'], [30, '1 month'], [60, '2 months'], [90, '3 months']]) {
      text(ctx, s, X(d), y1 + 30, { font: '17px Med', color: C.dim, align: 'center' });
    }
    const curve = (d) => (d <= 5 ? d / 5 : d <= 60 ? 1 + 99 * Math.pow((d - 5) / 55, 1.5) : 100 + (d - 60) * 0.5);
    const p = prog(lt2, 0.4, 3.5, (x) => x);
    ctx.strokeStyle = P.color;
    ctx.lineWidth = 5;
    ctx.beginPath();
    for (let d = 0; d <= 65 * p; d += 0.5) {
      if (d === 0) ctx.moveTo(X(d), Y(curve(d)));
      else ctx.lineTo(X(d), Y(curve(d)));
    }
    ctx.stroke();
    fade(ctx, prog(lt2, 0.8, 1.3), () => {
      circle(ctx, X(5), Y(1), 7, C.amber);
      line(ctx, X(5), Y(1) - 8, X(5), Y(24), rgba(C.amber, 0.6), 1.5);
      text(ctx, '1 million in 5 days', X(1), Y(27), { font: '19px Bold', color: C.amber });
    });
    fade(ctx, prog(lt2, 3.2, 3.8), () => {
      glow(ctx, X(60), Y(100), 40, P.color, 0.6);
      circle(ctx, X(60), Y(100), 9, '#fff');
      text(ctx, '~100 million', X(60) - 20, Y(100) - 50, { font: '30px DispBlack', color: C.text, align: 'right' });
      text(ctx, 'in about two months', X(60) - 20, Y(100) - 22, { font: '19px Semi', color: C.sub, align: 'right' });
    });
  });
}

// ------------------------------------------------------------------ 2023-2024 race
function race(ctx, P) {
  const { lt, S, E, w } = P;
  fade(ctx, stage(lt, 0.2, S[1] - 0.1), () => {
    label(ctx, 'FRONTIER MODELS, 2023', 40, 50, { color: P.color });
    const cards = [
      ['GPT-4', 'OpenAI', 'March 2023', C.green, 0],
      ['Claude', 'Anthropic', 'March 2023', C.amber, 1],
      ['Gemini', 'Google DeepMind', 'December 2023', C.blue, 2],
      ['Llama', 'Meta · open weights', 'February 2023', C.violet, 3],
    ];
    const at = [0.6, 2.0, 3.6, 5.2];
    cards.forEach(([n, org, d, col, shape], i) => {
      const a = prog(lt, at[i], at[i] + 0.7, easeOutBack);
      const x = 40 + (i % 2) * 400, y = 80 + Math.floor(i / 2) * 270;
      ctx.save();
      ctx.translate(x + 190, y + 125);
      ctx.scale(Math.max(0.01, a), Math.max(0.01, a));
      ctx.translate(-190, -125);
      card(ctx, 0, 0, 380, 250, { r: 20, fill: rgba(col, 0.1), stroke: rgba(col, 0.6) });
      // abstract mark
      ctx.save();
      ctx.translate(70, 75);
      ctx.rotate(lt * 0.4 * (i % 2 ? -1 : 1));
      ctx.strokeStyle = col;
      ctx.lineWidth = 4;
      for (let k = 0; k < 3 + shape; k++) {
        ctx.rotate(TAU / (3 + shape));
        ctx.beginPath();
        ctx.ellipse(0, 12, 8, 22, 0, 0, TAU);
        ctx.stroke();
      }
      ctx.restore();
      text(ctx, n, 30, 170, { font: '40px DispBlack', color: C.text });
      text(ctx, org, 30, 202, { font: '19px Semi', color: col });
      text(ctx, d, 30, 230, { font: '17px Med', color: C.dim });
      ctx.restore();
    });
  });
  fade(ctx, stage(lt, S[1] - 0.3, S[2] - 0.1), () => {
    const lt2 = lt - S[1];
    label(ctx, 'MULTIMODAL', 40, 50, { color: P.color });
    const cx = w / 2, cy = 360;
    const ins = [['Text', -160, -170, '¶'], ['Images', 160, -170, '▲'], ['Speech', -160, 170, '∿'], ['Documents', 160, 170, '☰']];
    ins.forEach(([s, dx, dy, g], i) => {
      const a = prog(lt2, i * 0.5, i * 0.5 + 0.6);
      fade(ctx, a, () => {
        const x = cx + dx * 1.6, y = cy + dy;
        card(ctx, x - 90, y - 50, 180, 100, { r: 18, fill: 'rgba(255,255,255,0.06)' });
        text(ctx, g, x, y + 4, { font: '38px Sym', color: C.amber, align: 'center' });
        text(ctx, s, x, y + 36, { font: '19px Semi', color: C.text, align: 'center' });
        const ph = (lt2 * 0.6 + i * 0.25) % 1;
        line(ctx, x - dx * 0.35, y - dy * 0.3, cx, cy, 'rgba(255,255,255,0.12)', 2);
        pulse(ctx, x - dx * 0.35, y - dy * 0.3, cx, cy, ph, C.amber, 4);
      });
    });
    glow(ctx, cx, cy, 130, P.color, 0.45);
    circle(ctx, cx, cy, 70, '#151C36', P.color, 4);
    text(ctx, 'model', cx, cy + 8, { font: '24px Bold', color: C.text, align: 'center' });
  });
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    label(ctx, 'REGULATION', 40, 50, { color: P.color });
    const cx = 210, cy = 330, R = 120;
    circle(ctx, cx, cy, 160, '#1D3A8A');
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * TAU - Math.PI / 2;
      const on = prog(lt, S[2] + i * 0.08, S[2] + 0.3 + i * 0.08);
      text(ctx, '★', cx + Math.cos(a) * R, cy + Math.sin(a) * R + 12, { font: '34px Sym', color: '#FFD84A', align: 'center', alpha: on });
    }
    text(ctx, 'EU AI Act', cx, 560, { font: '36px DispBlack', color: C.text, align: 'center' });
    text(ctx, 'adopted 2024', cx, 595, { font: '19px Semi', color: C.sub, align: 'center' });
    const tiers = [['Unacceptable risk', 'banned', C.red], ['High risk', 'strict obligations', C.amber], ['Limited risk', 'transparency', C.blue], ['Minimal risk', 'no new rules', C.green]];
    tiers.forEach(([n, d, col], i) => {
      const a = prog(lt, S[2] + 1 + i * 0.5, S[2] + 1.6 + i * 0.5);
      const tw = 220 + i * 70, x = 615 - tw / 2, y = 150 + i * 105;
      fade(ctx, a, () => {
        card(ctx, x, y, tw, 90, { r: 10, fill: rgba(col, 0.25), stroke: col });
        text(ctx, n, 615, y + 40, { font: '20px Bold', color: C.text, align: 'center' });
        text(ctx, d, 615, y + 66, { font: '16px Med', color: C.sub, align: 'center' });
      });
    });
    text(ctx, 'a risk-based approach', 615, 610, { font: '18px Semi', color: C.dim, align: 'center', alpha: prog(lt, S[2] + 3, S[2] + 4) });
  });
}

// ------------------------------------------------------------------ 2024-2026 reasoning + agents
function agents(ctx, P) {
  const { lt, S, E, w } = P;
  fade(ctx, stage(lt, 0.2, S[1] - 0.1), () => {
    label(ctx, 'A REASONING MODEL THINKS STEP BY STEP', 40, 50, { color: P.color });
    card(ctx, 40, 72, w - 80, 110, { r: 16, fill: 'rgba(255,255,255,0.06)' });
    wrap(ctx, 'A bat and a ball cost $1.10 in total. The bat costs $1.00 more than the ball. How much does the ball cost?', w - 130, '22px Med')
      .forEach((l, k) => text(ctx, l, 64, 112 + k * 32, { font: '22px Med', color: C.text }));
    card(ctx, 40, 204, w - 80, 400, { r: 16, fill: 'rgba(0,0,0,0.25)', stroke: rgba(P.color, 0.4) });
    const dots = '.'.repeat(1 + (Math.floor(lt * 3) % 3));
    text(ctx, 'Thinking' + dots, 64, 242, { font: 'italic 20px Semi', color: P.color });
    const steps = [
      'Intuition says 10¢, but let’s check.',
      'Let the ball cost x. Then the bat costs x + $1.00.',
      'x + (x + 1.00) = 1.10',
      '2x = 0.10, so x = 0.05',
      'Check: $0.05 + $1.05 = $1.10 ✓',
    ];
    steps.forEach((s, i) => {
      const a = prog(lt, 1.6 + i * 1.5, 2.1 + i * 1.5);
      text(ctx, s, 84 - (1 - a) * 20, 296 + i * 50, { font: i === 2 || i === 3 ? '23px Mono' : '22px Reg', color: i === 0 ? C.dim : C.text, alpha: a });
    });
    const fa = prog(lt, 9.4, 10);
    fade(ctx, fa, () => {
      card(ctx, 40, 620, w - 80, 56, { r: 16, fill: rgba(C.green, 0.2), stroke: C.green });
      text(ctx, 'Answer: the ball costs 5 cents.', w / 2, 657, { font: '24px Bold', color: C.text, align: 'center' });
    });
  });
  fade(ctx, stage(lt, S[1] - 0.3, S[2] - 0.1), () => {
    const lt2 = lt - S[1];
    const cx = w / 2, cy = 300;
    const sy = prog(lt2, 0, 0.8, easeOutBack);
    ctx.fillStyle = '#2F4B9A';
    ctx.beginPath();
    ctx.moveTo(cx - 70, 40); ctx.lineTo(cx - 20, 40); ctx.lineTo(cx + 10, cy - 100); ctx.lineTo(cx - 30, cy - 100);
    ctx.fill();
    ctx.fillStyle = '#C8453D';
    ctx.beginPath();
    ctx.moveTo(cx + 70, 40); ctx.lineTo(cx + 20, 40); ctx.lineTo(cx - 10, cy - 100); ctx.lineTo(cx + 30, cy - 100);
    ctx.fill();
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(sy, sy);
    glow(ctx, 0, 0, 220, C.amber, 0.35);
    const g = ctx.createRadialGradient(-30, -30, 10, 0, 0, 130);
    g.addColorStop(0, '#FFF0B8');
    g.addColorStop(0.6, '#E5AE3C');
    g.addColorStop(1, '#9A6A16');
    circle(ctx, 0, 0, 125, g);
    circle(ctx, 0, 0, 104, null, 'rgba(110,70,10,0.55)', 3);
    text(ctx, 'IMO', 0, -6, { font: '58px DispBlack', color: '#5E3F0B', align: 'center' });
    text(ctx, '2025', 0, 44, { font: '34px DispBold', color: '#5E3F0B', align: 'center' });
    ctx.restore();
    text(ctx, 'Gold-medal level', cx, 500, { font: '40px DispBlack', color: C.text, align: 'center', alpha: prog(lt2, 0.6, 1.2) });
    text(ctx, 'International Mathematical Olympiad', cx, 540, { font: '22px Semi', color: C.sub, align: 'center', alpha: prog(lt2, 0.8, 1.4) });
    text(ctx, 'Proofs written in natural language, within the contest time limits', cx, 600, { font: '19px Med', color: C.dim, align: 'center', alpha: prog(lt2, 1.2, 1.8) });
  });
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    const lt2 = lt - S[2];
    label(ctx, 'THE AGENT LOOP', 40, 50, { color: P.color });
    const cx = 250, cy = 320, R = 170;
    const nodes = ['Plan', 'Act', 'Observe', 'Reflect'];
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, TAU);
    ctx.stroke();
    const ang = lt2 * 1.6 - Math.PI / 2;
    const px = cx + Math.cos(ang) * R, py = cy + Math.sin(ang) * R;
    glow(ctx, px, py, 40, C.amber, 0.7);
    circle(ctx, px, py, 7, C.amber);
    nodes.forEach((n, i) => {
      const a = (i / 4) * TAU - Math.PI / 2;
      const x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R;
      const d = Math.abs(((ang - a) % TAU + TAU) % TAU);
      const lit = d < 0.5 || d > TAU - 0.15;
      card(ctx, x - 62, y - 26, 124, 52, { r: 26, fill: lit ? rgba(P.color, 0.5) : '#161D36', stroke: P.color });
      text(ctx, n, x, y + 8, { font: '21px Bold', color: C.text, align: 'center' });
    });
    text(ctx, 'agent', cx, cy + 10, { font: '28px DispBlack', color: P.color, align: 'center' });
    const tools = ['⌨  terminal', '◎  browser', '☰  files', '⚙  tools'];
    tools.forEach((s, i) => {
      const a = prog(lt2, 0.6 + i * 0.4, 1.1 + i * 0.4);
      fade(ctx, a, () => {
        card(ctx, 500, 90 + i * 64, 160, 48, { r: 12, fill: 'rgba(255,255,255,0.06)' });
        text(ctx, s, 520, 121 + i * 64, { font: '19px Sym', color: C.text });
      });
    });
    const term = [
      ['$ run tests', C.text],
      ['  41 passed, 1 failed', C.red],
      ['$ edit parser.py', C.text],
      ['$ run tests', C.text],
      ['  42 passed ✓', C.green],
    ];
    card(ctx, 480, 360, 350, 270, { r: 12, fill: '#05080F', stroke: 'rgba(255,255,255,0.15)' });
    term.forEach(([s, col], i) => {
      text(ctx, s, 500, 400 + i * 44, { font: '19px Mono', color: col, alpha: prog(lt2, 2 + i * 1.3, 2.3 + i * 1.3) });
    });
  });
}

// ------------------------------------------------------------------ Today
const PEOPLE = (() => { const r = rng(77); return Array.from({ length: 24 * 11 }, () => r()); })();

function today(ctx, P) {
  const { lt, S, E, w } = P;
  fade(ctx, stage(lt, 0.2, S[1] - 0.1), () => {
    const cols = 24, rows = 11, cs = 32;
    const ox = (w - cols * cs) / 2 + cs / 2, oy = 120;
    const fill = prog(lt, 0.5, S[1] - 1, (x) => x);
    for (let i = 0; i < cols * rows; i++) {
      const on = PEOPLE[i] < fill * 0.9;
      person(ctx, ox + (i % cols) * cs, oy + Math.floor(i / cols) * cs + 10, 22, on ? rgba(P.color, 0.9) : 'rgba(255,255,255,0.1)');
    }
    text(ctx, 'Hundreds of millions of people', w / 2, 540, { font: '34px DispBlack', color: C.text, align: 'center', alpha: prog(lt, 1, 2) });
    text(ctx, 'use AI every week', w / 2, 580, { font: '24px Semi', color: C.sub, align: 'center', alpha: prog(lt, 1.3, 2.3) });
  });
  fade(ctx, stage(lt, S[1] - 0.3, S[2] - 0.1), () => {
    const lt2 = lt - S[1];
    label(ctx, 'WHY IT FINALLY WORKED', 40, 50, { color: P.color });
    const pillars = [['Algorithms', 'perceptron → backprop → Transformer', C.violet], ['Data', 'the internet, ImageNet, the web’s text', C.teal], ['Compute', 'GPUs and ever-larger clusters', C.amber]];
    pillars.forEach(([n, d, col], i) => {
      const a = prog(lt2, 0.4 + i * 0.7, 1.2 + i * 0.7, easeOut);
      const x = 70 + i * 250, h = 320 * a;
      card(ctx, x, 560 - h, 210, h, { r: 12, fill: rgba(col, 0.22), stroke: col });
      fade(ctx, a, () => {
        text(ctx, n, x + 105, 560 - h + 46, { font: '26px DispBlack', color: C.text, align: 'center' });
        wrap(ctx, d, 180, '17px Med').forEach((l, k) => text(ctx, l, x + 105, 560 - h + 82 + k * 24, { font: '17px Med', color: C.sub, align: 'center' }));
      });
    });
    const ba = prog(lt2, 2.8, 3.6, easeOut);
    fade(ctx, ba, () => {
      card(ctx, 50, 150 - (1 - ba) * 30, 760, 70, { r: 14, fill: rgba(P.color, 0.25), stroke: P.color });
      text(ctx, 'Breakthroughs', w / 2, 196 - (1 - ba) * 30, { font: '30px DispBlack', color: C.text, align: 'center' });
    });
    text(ctx, 'Neural networks: proposed 1958, trainable 1986, unstoppable 2012', w / 2, 630, { font: '19px Semi', color: C.sub, align: 'center', alpha: prog(lt2, 4, 5) });
  });
  fade(ctx, stage(lt, S[2] - 0.3, P.dur + 1), () => {
    const lt2 = lt - S[2];
    label(ctx, 'OPEN QUESTIONS', 40, 50, { color: P.color });
    const cx = w / 2, cy = 350;
    glow(ctx, cx, cy, 160, P.color, 0.35);
    text(ctx, '?', cx, cy + 50, { font: '150px DispBlack', color: P.color, align: 'center', alpha: prog(lt2, 0, 0.6) });
    const qs = [['Safe?', -230, -170], ['Reliable?', 230, -170], ['Aligned with', -230, 170, 'human values?'], ['Benefits', 230, 170, 'shared fairly?']];
    qs.forEach(([a, dx, dy, b], i) => {
      const p = prog(lt2, 0.6 + i * 0.9, 1.2 + i * 0.9, easeOutBack);
      const bob = Math.sin(lt * 1.2 + i) * 6;
      ctx.save();
      ctx.translate(cx + dx, cy + dy + bob);
      ctx.scale(Math.max(0.01, p), Math.max(0.01, p));
      card(ctx, -150, -55, 300, 110, { r: 22, fill: 'rgba(255,255,255,0.07)', stroke: rgba(P.color, 0.6) });
      text(ctx, a, 0, b ? -4 : 12, { font: '28px DispBold', color: C.text, align: 'center' });
      if (b) text(ctx, b, 0, 30, { font: '28px DispBold', color: C.text, align: 'center' });
      ctx.restore();
    });
  });
}

export const VISUALS = {
  intro, outro, turing, dartmouth, perceptron, eliza, winter, expert, winter2, nineties, data, alexnet, gan, alphago,
  transformer, scaling, alphafold, chatgpt, race, agents, today,
};
