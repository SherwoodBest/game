'use strict';

// ---------- setup ----------

const W = 960;
const H = 600;
const HUD_H = 40;
const canvas = document.getElementById('canvas');
const ctx = canvas.getContext('2d');
const $ = (id) => document.getElementById(id);

const COLORS = {
  ground: '#0b1714',
  grid: 'rgba(200, 170, 110, 0.05)',
  lane: '#13241f',
  gold: '#c8aa6e',
  goldBright: '#f0e6d2',
  teal: '#0ac8b9',
  ally: '#3a8eed',
  enemy: '#e84057',
  text: '#f0e6d2',
  muted: '#a09b8c',
  danger: '#ff5a4f',
};

const FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

const store = {
  get(key, fallback) {
    try {
      const v = localStorage.getItem(key);
      return v === null ? fallback : JSON.parse(v);
    } catch {
      return fallback;
    }
  },
  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // Storage unavailable (private mode etc.) — bests just won't persist.
    }
  },
};

const settings = store.get('lolwarmup.settings', { leftClick: false });
const clickName = () => (settings.leftClick ? 'left-click' : 'right-click');

// ---------- helpers ----------

const rand = (a, b) => a + Math.random() * (b - a);
const randInt = (a, b) => Math.floor(rand(a, b + 1));
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
const capitalize = (s) => s[0].toUpperCase() + s.slice(1);
const pct = (a, b) => (b ? `${Math.round((a / b) * 100)}%` : '—');

const mouse = { x: W / 2, y: H / 2 };

let floaters = [];

function floatText(x, y, text, color = COLORS.text, size = 16) {
  floaters.push({ x, y, text, color, size, t: 0 });
}

function updateFloaters(dt) {
  for (const f of floaters) {
    f.t += dt;
    f.y -= 30 * dt;
  }
  floaters = floaters.filter((f) => f.t < 0.9);
}

function drawFloaters() {
  ctx.textAlign = 'center';
  for (const f of floaters) {
    ctx.globalAlpha = 1 - f.t / 0.9;
    ctx.fillStyle = f.color;
    ctx.font = `bold ${f.size}px ${FONT}`;
    ctx.fillText(f.text, f.x, f.y);
  }
  ctx.globalAlpha = 1;
}

function circle(x, y, r, fill, stroke, lineWidth = 2) {
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  if (fill) {
    ctx.fillStyle = fill;
    ctx.fill();
  }
  if (stroke) {
    ctx.strokeStyle = stroke;
    ctx.lineWidth = lineWidth;
    ctx.stroke();
  }
}

function drawGround() {
  ctx.fillStyle = COLORS.ground;
  ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = COLORS.grid;
  ctx.lineWidth = 1;
  ctx.beginPath();
  for (let x = 0; x <= W; x += 40) {
    ctx.moveTo(x + 0.5, 0);
    ctx.lineTo(x + 0.5, H);
  }
  for (let y = 0; y <= H; y += 40) {
    ctx.moveTo(0, y + 0.5);
    ctx.lineTo(W, y + 0.5);
  }
  ctx.stroke();
}

// ---------- drill: target clicks ----------

function createReaction() {
  const LIFE = 1.3;
  let target = null;
  let gap = 0.4;
  let hits = 0;
  let misses = 0;
  let bonus = 0;
  const times = [];

  function spawn() {
    target = { x: rand(70, W - 70), y: rand(HUD_H + 70, H - 70), r: rand(16, 28), age: 0 };
  }

  return {
    update(dt) {
      if (target) {
        target.age += dt;
        if (target.age >= LIFE) {
          misses++;
          floatText(target.x, target.y, 'too slow', COLORS.muted);
          target = null;
          gap = rand(0.15, 0.5);
        }
      } else {
        gap -= dt;
        if (gap <= 0) spawn();
      }
    },

    draw() {
      if (!target) return;
      const left = 1 - target.age / LIFE;
      circle(target.x, target.y, target.r + 34 * left, null, 'rgba(200, 170, 110, 0.5)', 2);
      circle(target.x, target.y, target.r, 'rgba(232, 64, 87, 0.85)', COLORS.goldBright, 2);
      circle(target.x, target.y, 4, COLORS.goldBright);
    },

    click(x, y) {
      if (target && dist(x, y, target.x, target.y) <= target.r + 4) {
        const ms = target.age * 1000;
        times.push(ms);
        hits++;
        bonus += Math.round((1 - target.age / LIFE) * 100);
        floatText(target.x, target.y - target.r - 6, `${Math.round(ms)} ms`, COLORS.teal);
        target = null;
        gap = rand(0.15, 0.5);
      } else {
        misses++;
        floatText(x, y, 'miss', COLORS.danger);
      }
    },

    hud() {
      return `Hits ${hits}   ·   Misses ${misses}`;
    },

    result() {
      const avg = times.length ? times.reduce((a, b) => a + b, 0) / times.length : 0;
      return {
        score: Math.max(0, hits * 100 + bonus - misses * 50),
        rows: [
          ['Hits', hits],
          ['Misses', misses],
          ['Accuracy', pct(hits, hits + misses)],
          ['Average reaction', times.length ? `${Math.round(avg)} ms` : '—'],
        ],
      };
    },
  };
}

// ---------- drill: key combos ----------

function createCombo() {
  const KEYS = ['Q', 'W', 'E', 'R', 'D', 'F'];
  let seq = [];
  let pos = 0;
  let combos = 0;
  let correct = 0;
  let errors = 0;
  let shake = 0;

  function next() {
    seq = Array.from({ length: randInt(3, 5) }, () => KEYS[randInt(0, KEYS.length - 1)]);
    pos = 0;
  }
  next();

  return {
    update(dt) {
      shake = Math.max(0, shake - dt);
    },

    draw() {
      const size = 84;
      const gap = 18;
      const total = seq.length * size + (seq.length - 1) * gap;
      const x0 = (W - total) / 2 + (shake > 0 ? Math.sin(shake * 80) * 8 : 0);
      const y0 = H / 2 - size / 2;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      seq.forEach((k, i) => {
        const x = x0 + i * (size + gap);
        const done = i < pos;
        const cur = i === pos;
        ctx.fillStyle = done ? 'rgba(10, 200, 185, 0.2)' : '#0a1428';
        ctx.fillRect(x, y0, size, size);
        ctx.strokeStyle = cur ? COLORS.goldBright : done ? COLORS.teal : COLORS.gold;
        ctx.lineWidth = cur ? 4 : 2;
        ctx.strokeRect(x + 1, y0 + 1, size - 2, size - 2);
        ctx.fillStyle = done ? COLORS.teal : COLORS.text;
        ctx.font = `bold 40px ${FONT}`;
        ctx.fillText(k, x + size / 2, y0 + size / 2 + 2);
      });
      ctx.textBaseline = 'alphabetic';
      ctx.fillStyle = COLORS.muted;
      ctx.font = `16px ${FONT}`;
      ctx.fillText('Type the keys left to right', W / 2, y0 + size + 44);
    },

    key(k) {
      if (!KEYS.includes(k)) return;
      if (k === seq[pos]) {
        correct++;
        pos++;
        if (pos === seq.length) {
          combos++;
          floatText(W / 2, H / 2 - 70, 'combo!', COLORS.teal, 20);
          next();
        }
      } else {
        errors++;
        pos = 0;
        shake = 0.25;
        floatText(W / 2, H / 2 - 70, 'wrong key', COLORS.danger, 20);
      }
    },

    hud() {
      return `Combos ${combos}   ·   Errors ${errors}`;
    },

    result(duration) {
      return {
        score: Math.max(0, correct * 10 + combos * 20 - errors * 25),
        rows: [
          ['Combos', combos],
          ['Correct keys', correct],
          ['Errors', errors],
          ['Keys per second', (correct / duration).toFixed(1)],
        ],
      };
    },
  };
}

// ---------- drill: last hitting ----------

const LAST_HIT_AD = 64;

function createLastHit() {
  const CHAMP = { x: 170, y: 330 };
  const WINDUP = 0.22;
  const ATTACK_INTERVAL = 1.0;
  const MISSILE_SPEED = 1500;
  const WAVE_EVERY = 13;
  const TYPES = {
    melee: { maxHp: 420, r: 15, gold: 21 },
    caster: { maxHp: 280, r: 12, gold: 14 },
    cannon: { maxHp: 700, r: 21, gold: 60 },
  };
  const ALLIES = [
    { x: 330, y: 270 },
    { x: 330, y: 390 },
    { x: 380, y: 300 },
    { x: 380, y: 360 },
  ];

  let minions = [];
  let missiles = [];
  let zaps = [];
  let waveTimer = 0.3;
  let wave = 0;
  let allyTimer = 0;
  let cd = 0;
  let windup = null; // { target, t }
  let queued = null;
  let cs = 0;
  let missed = 0;
  let gold = 0;

  function spawnWave() {
    wave++;
    const slots = [
      ['melee', 540, 260], ['melee', 540, 330], ['melee', 540, 400],
      ['caster', 650, 265], ['caster', 650, 330], ['caster', 650, 395],
    ];
    if (wave % 3 === 0) slots.splice(3, 0, ['cannon', 595, 297]);
    slots.forEach(([type, tx, ty], i) => {
      minions.push({
        type,
        ...TYPES[type],
        hp: TYPES[type].maxHp,
        x: W + 40 + i * 28,
        y: ty + rand(-10, 10),
        tx: tx + rand(-10, 10),
        ty: ty + rand(-8, 8),
        arrived: false,
        alive: true,
      });
    });
  }

  // Allies focus the front of the wave like real lane minions, with some spread.
  function allyAttack() {
    const ready = minions.filter((m) => m.alive && m.arrived);
    if (!ready.length) return;
    const order = ['melee', 'cannon', 'caster'];
    const focus = order.map((t) => ready.find((m) => m.type === t)).find(Boolean);
    const target = Math.random() < 0.7 ? focus : ready[randInt(0, ready.length - 1)];
    const from = ALLIES[randInt(0, ALLIES.length - 1)];
    zaps.push({ x1: from.x, y1: from.y, x2: target.x, y2: target.y, t: 0.08 });
    const dmg = rand(22, 40);
    if (target.hp <= dmg) {
      target.alive = false;
      missed++;
      floatText(target.x, target.y - 22, 'missed', COLORS.muted, 13);
    } else {
      target.hp -= dmg;
    }
  }

  function minionAt(x, y) {
    let best = null;
    let bestD = Infinity;
    for (const m of minions) {
      const d = dist(x, y, m.x, m.y);
      if (m.alive && d <= m.r + 6 && d < bestD) {
        best = m;
        bestD = d;
      }
    }
    return best;
  }

  return {
    update(dt) {
      waveTimer -= dt;
      if (waveTimer <= 0) {
        spawnWave();
        waveTimer = WAVE_EVERY;
      }

      for (const m of minions) {
        if (m.arrived) continue;
        const d = dist(m.x, m.y, m.tx, m.ty);
        const step = 150 * dt;
        if (d <= step) {
          m.x = m.tx;
          m.y = m.ty;
          m.arrived = true;
        } else {
          m.x += ((m.tx - m.x) / d) * step;
          m.y += ((m.ty - m.y) / d) * step;
        }
      }

      allyTimer -= dt;
      if (allyTimer <= 0) {
        allyTimer = rand(0.15, 0.27);
        allyAttack();
      }

      cd = Math.max(0, cd - dt);
      if (windup) {
        windup.t += dt;
        if (!windup.target.alive) {
          windup = null;
        } else if (windup.t >= WINDUP) {
          missiles.push({ x: CHAMP.x, y: CHAMP.y, target: windup.target });
          windup = null;
        }
      }
      if (!windup && queued && cd <= 0) {
        if (queued.alive) {
          windup = { target: queued, t: 0 };
          cd = ATTACK_INTERVAL;
        }
        queued = null;
      }

      for (const p of missiles) {
        const t = p.target;
        if (!t.alive) {
          p.done = true;
          continue;
        }
        const d = dist(p.x, p.y, t.x, t.y);
        const step = MISSILE_SPEED * dt;
        if (d > step) {
          p.x += ((t.x - p.x) / d) * step;
          p.y += ((t.y - p.y) / d) * step;
          continue;
        }
        p.done = true;
        if (t.hp <= LAST_HIT_AD) {
          t.alive = false;
          cs++;
          gold += t.gold;
          floatText(t.x, t.y - 22, `+${t.gold}`, COLORS.gold, 18);
        } else {
          t.hp -= LAST_HIT_AD;
        }
      }

      missiles = missiles.filter((p) => !p.done);
      minions = minions.filter((m) => m.alive);
      for (const z of zaps) z.t -= dt;
      zaps = zaps.filter((z) => z.t > 0);
    },

    draw() {
      ctx.fillStyle = COLORS.lane;
      ctx.fillRect(0, 210, W, 240);

      for (const a of ALLIES) circle(a.x, a.y, 13, COLORS.ally, '#9fd0ff', 1.5);

      ctx.strokeStyle = 'rgba(140, 190, 255, 0.8)';
      ctx.lineWidth = 2;
      for (const z of zaps) {
        ctx.beginPath();
        ctx.moveTo(z.x1, z.y1);
        ctx.lineTo(z.x2, z.y2);
        ctx.stroke();
      }

      const hovered = minionAt(mouse.x, mouse.y);
      for (const m of minions) {
        const hover = m === hovered;
        circle(m.x, m.y, m.r, COLORS.enemy, hover ? '#ffd0d0' : '#5a1520', hover ? 3 : 2);
        const bw = m.r * 2 + 16;
        const bx = m.x - bw / 2;
        const by = m.y - m.r - 12;
        ctx.fillStyle = '#000';
        ctx.fillRect(bx - 1, by - 1, bw + 2, 7);
        ctx.fillStyle = '#d13639';
        ctx.fillRect(bx, by, bw * (m.hp / m.maxHp), 5);
      }

      circle(CHAMP.x, CHAMP.y, 20, '#14324a', COLORS.teal, 3);
      if (windup) {
        ctx.beginPath();
        ctx.arc(CHAMP.x, CHAMP.y, 27, -Math.PI / 2, -Math.PI / 2 + (windup.t / WINDUP) * Math.PI * 2);
        ctx.strokeStyle = COLORS.goldBright;
        ctx.lineWidth = 3;
        ctx.stroke();
      }
      ctx.fillStyle = '#000';
      ctx.fillRect(CHAMP.x - 22, CHAMP.y + 28, 44, 5);
      ctx.fillStyle = cd > 0 ? COLORS.muted : COLORS.gold;
      ctx.fillRect(CHAMP.x - 22, CHAMP.y + 28, 44 * (1 - cd / ATTACK_INTERVAL), 5);

      for (const p of missiles) circle(p.x, p.y, 5, COLORS.goldBright);
    },

    click(x, y) {
      const m = minionAt(x, y);
      if (m) {
        if (windup && windup.target === m) return;
        if (windup) {
          // Retargeting mid-windup cancels the current auto.
          windup = null;
          cd = 0;
        }
        queued = m;
      } else {
        queued = null;
        if (windup) {
          windup = null;
          cd = 0;
          floatText(CHAMP.x, CHAMP.y - 34, 'cancelled', COLORS.muted, 13);
        }
      }
    },

    hud() {
      return `CS ${cs}   ·   Missed ${missed}`;
    },

    result() {
      return {
        score: cs,
        rows: [
          ['CS', cs],
          ['Missed', missed],
          ['Last-hit rate', pct(cs, cs + missed)],
          ['Gold', gold],
        ],
      };
    },
  };
}

// ---------- drill: skillshot dodging ----------

function createDodge(duration) {
  const P_R = 16;
  const SPEED = 330;
  const FLASH_DIST = 150;
  const FLASH_CD = 12;
  const TELEGRAPH = 0.45;
  const p = { x: W / 2, y: H / 2 + 20, tx: W / 2, ty: H / 2 + 20, vx: 0, vy: 0 };
  let shots = [];
  let zones = [];
  let marker = null;
  let elapsed = 0;
  let spawnTimer = 1;
  let invuln = 0;
  let flashCd = 0;
  let hits = 0;
  let dodged = 0;
  let flashes = 0;

  function spawnShot() {
    const side = randInt(0, 3);
    const ox = side === 1 ? W + 20 : side === 3 ? -20 : rand(0, W);
    const oy = side === 0 ? -20 : side === 2 ? H + 20 : rand(HUD_H, H);
    // Some shots lead your movement, so you have to change direction, not just keep walking.
    const lead = rand(0, 0.45);
    const ang = Math.atan2(p.y + p.vy * lead - oy, p.x + p.vx * lead - ox);
    shots.push({
      ox, oy, x: ox, y: oy,
      dx: Math.cos(ang), dy: Math.sin(ang),
      r: rand(13, 24), speed: rand(620, 900),
      delay: TELEGRAPH, touched: false,
    });
  }

  function spawnZone() {
    zones.push({
      x: clamp(p.x + p.vx * 0.4 + rand(-20, 20), 40, W - 40),
      y: clamp(p.y + p.vy * 0.4 + rand(-20, 20), HUD_H + 40, H - 40),
      r: rand(60, 85),
      delay: 0.75,
      t: 0,
    });
  }

  function hit() {
    hits++;
    invuln = 0.6;
    floatText(p.x, p.y - 28, 'hit!', COLORS.danger, 18);
  }

  return {
    update(dt) {
      elapsed += dt;
      invuln = Math.max(0, invuln - dt);
      flashCd = Math.max(0, flashCd - dt);
      if (marker) marker.t += dt;

      const d = dist(p.x, p.y, p.tx, p.ty);
      if (d > 1) {
        const ux = (p.tx - p.x) / d;
        const uy = (p.ty - p.y) / d;
        const step = Math.min(d, SPEED * dt);
        p.x += ux * step;
        p.y += uy * step;
        p.vx = ux * SPEED;
        p.vy = uy * SPEED;
      } else {
        p.vx = 0;
        p.vy = 0;
      }

      spawnTimer -= dt;
      if (spawnTimer <= 0) {
        if (elapsed > 8 && Math.random() < 0.25) spawnZone();
        else spawnShot();
        spawnTimer = 1.1 - 0.65 * clamp(elapsed / duration, 0, 1);
      }

      for (const s of shots) {
        if (s.delay > 0) {
          s.delay -= dt;
          continue;
        }
        s.x += s.dx * s.speed * dt;
        s.y += s.dy * s.speed * dt;
        if (!s.touched && dist(s.x, s.y, p.x, p.y) < s.r + P_R) {
          s.touched = true;
          if (invuln <= 0) hit();
        }
        if (s.x < -60 || s.x > W + 60 || s.y < -60 || s.y > H + 60) {
          s.done = true;
          if (!s.touched) dodged++;
        }
      }
      shots = shots.filter((s) => !s.done);

      for (const z of zones) {
        z.t += dt;
        if (!z.fired && z.t >= z.delay) {
          z.fired = true;
          if (dist(z.x, z.y, p.x, p.y) < z.r + P_R * 0.5) {
            if (invuln <= 0) hit();
          } else {
            dodged++;
          }
        }
      }
      zones = zones.filter((z) => z.t < z.delay + 0.15);
    },

    draw() {
      for (const z of zones) {
        if (z.fired) {
          circle(z.x, z.y, z.r, 'rgba(255, 140, 80, 0.55)');
          continue;
        }
        circle(z.x, z.y, z.r, 'rgba(255, 90, 79, 0.12)', 'rgba(255, 90, 79, 0.7)', 2);
        circle(z.x, z.y, z.r * (z.t / z.delay), 'rgba(255, 90, 79, 0.25)');
      }

      for (const s of shots) {
        if (s.delay > 0) {
          ctx.save();
          ctx.translate(s.ox, s.oy);
          ctx.rotate(Math.atan2(s.dy, s.dx));
          ctx.fillStyle = 'rgba(255, 90, 79, 0.16)';
          ctx.fillRect(0, -s.r, 1400, s.r * 2);
          ctx.strokeStyle = 'rgba(255, 90, 79, 0.45)';
          ctx.lineWidth = 1;
          ctx.strokeRect(0, -s.r, 1400, s.r * 2);
          ctx.restore();
        } else {
          circle(s.x - s.dx * s.r, s.y - s.dy * s.r, s.r * 0.7, 'rgba(255, 138, 61, 0.35)');
          circle(s.x, s.y, s.r, '#ff8a3d', '#ffd2a8', 2);
        }
      }

      if (marker && marker.t < 0.4) {
        circle(marker.x, marker.y, 12 * (1 - marker.t / 0.4) + 3, null, '#5cff9d', 2);
      }

      ctx.globalAlpha = invuln > 0 && Math.floor(invuln * 20) % 2 === 0 ? 0.35 : 1;
      circle(p.x, p.y, P_R, '#14324a', COLORS.teal, 3);
      ctx.globalAlpha = 1;
    },

    click(x, y) {
      p.tx = clamp(x, P_R, W - P_R);
      p.ty = clamp(y, P_R, H - P_R);
      marker = { x, y, t: 0 };
    },

    key(k) {
      if ((k !== 'F' && k !== 'D') || flashCd > 0) return;
      const d = dist(p.x, p.y, mouse.x, mouse.y);
      if (d < 1) return;
      const jump = Math.min(FLASH_DIST, d);
      p.x = clamp(p.x + ((mouse.x - p.x) / d) * jump, P_R, W - P_R);
      p.y = clamp(p.y + ((mouse.y - p.y) / d) * jump, P_R, H - P_R);
      p.tx = p.x;
      p.ty = p.y;
      flashCd = FLASH_CD;
      flashes++;
      floatText(p.x, p.y - 26, 'flash', '#ffe066', 14);
    },

    hud() {
      const flash = flashCd > 0 ? `${Math.ceil(flashCd)}s` : 'ready';
      return `Hits ${hits}   ·   Dodged ${dodged}   ·   Flash ${flash}`;
    },

    result() {
      return {
        score: hits,
        rows: [
          ['Hits taken', hits],
          ['Dodged', dodged],
          ['Dodge rate', pct(dodged, dodged + hits)],
          ['Flashes used', flashes],
        ],
      };
    },
  };
}

// ---------- drill catalog ----------

const DRILLS = [
  {
    id: 'reaction',
    name: 'Target Clicks',
    duration: 30,
    create: createReaction,
    metric: { label: 'score', better: 'high' },
    blurb: 'Snap to targets before they expire.',
    howto: () => [
      'Targets appear one at a time. The outer ring shows how long you have left.',
      `Hit them with ${clickName()}, the same button you use to move and attack.`,
      'Faster hits score more. Misses and expired targets cost points.',
    ],
  },
  {
    id: 'combo',
    name: 'Key Combos',
    duration: 30,
    create: createCombo,
    metric: { label: 'score', better: 'high' },
    blurb: 'Warm up your ability fingers on Q W E R D F.',
    howto: () => [
      'A sequence of ability and summoner keys appears in the middle of the screen.',
      'Type them left to right as fast as you can.',
      'A wrong key resets the current sequence, so accuracy beats mashing.',
    ],
  },
  {
    id: 'lasthit',
    name: 'Last Hitting',
    duration: 60,
    create: createLastHit,
    metric: { label: 'CS', better: 'high' },
    blurb: 'Time your autos to land the killing blow.',
    howto: () => [
      'Your minions (blue) are fighting the enemy wave (red).',
      `${capitalize(clickName())} an enemy minion to auto-attack it. Your attack deals ${LAST_HIT_AD} damage.`,
      'Each auto has a short windup plus missile travel time, so lead the kill.',
      'Only killing blows count as CS. One click is one attack, and clicking the ground cancels a windup.',
    ],
  },
  {
    id: 'dodge',
    name: 'Skillshot Dodging',
    duration: 45,
    create: createDodge,
    metric: { label: 'hits taken', better: 'low' },
    blurb: 'Click to move and sidestep incoming skillshots.',
    howto: () => [
      `${capitalize(clickName())} to move.`,
      'Red lanes and circles show where skillshots are about to land. Some shots aim where you are heading.',
      'Press F (or D) to Flash toward your cursor. It has a 12s cooldown.',
      'Shots speed up as the drill goes on.',
    ],
  },
];

const drillById = (id) => DRILLS.find((d) => d.id === id);
const pbKey = (id) => `lolwarmup.pb.${id}`;

// ---------- flow ----------

let current = null; // { meta, drill, elapsed, countdown }
let routine = null; // { index, results: [{ meta, res, newPb }] }
let pendingId = null;

function show(id) {
  for (const o of ['menu', 'intro', 'results']) $(o).hidden = o !== id;
}

function renderMenu() {
  const total = DRILLS.reduce((s, d) => s + d.duration, 0);
  $('routine-len').textContent = `(~${Math.round(total / 60 * 2) / 2} min)`;
  $('drill-list').innerHTML = DRILLS.map((d) => {
    const pb = store.get(pbKey(d.id), null);
    return `<button class="drill-card" data-id="${d.id}">
      <strong>${d.name}</strong>
      <span class="desc">${d.blurb}</span>
      <span class="meta">${d.duration}s · Best ${d.metric.label}: ${pb ?? '—'}</span>
    </button>`;
  }).join('');
  $('left-click').checked = settings.leftClick;
  show('menu');
}

function showIntro(id) {
  const meta = drillById(id);
  pendingId = id;
  $('intro-step').textContent = routine
    ? `Drill ${routine.index + 1} of ${DRILLS.length} · ${meta.duration}s`
    : `${meta.duration}s`;
  $('intro-title').textContent = meta.name;
  $('intro-howto').innerHTML = meta.howto().map((line) => `<li>${line}</li>`).join('');
  show('intro');
}

function begin(id) {
  const meta = drillById(id);
  floaters = [];
  current = { meta, drill: meta.create(meta.duration), elapsed: 0, countdown: 3 };
  show(null);
}

function abort() {
  current = null;
  routine = null;
  renderMenu();
}

function finishDrill() {
  const { meta, drill } = current;
  const res = drill.result(meta.duration);
  const prev = store.get(pbKey(meta.id), null);
  const newPb = prev === null || (meta.metric.better === 'high' ? res.score > prev : res.score < prev);
  if (newPb) store.set(pbKey(meta.id), res.score);
  current = null;
  if (routine) routine.results.push({ meta, res, newPb });
  showResults(meta, res, newPb, prev);
}

function showResults(meta, res, newPb, prev) {
  const pbLine = newPb
    ? `<p class="pb new">${prev === null ? 'First run, personal best set' : `New personal best! (was ${prev})`}</p>`
    : `<p class="pb">Personal best: ${prev}</p>`;
  const rows = res.rows.map(([k, v]) => `<tr><td>${k}</td><td>${v}</td></tr>`).join('');

  let buttons;
  if (routine && routine.index < DRILLS.length - 1) {
    buttons = `<button class="primary" data-action="next">Next: ${DRILLS[routine.index + 1].name}</button>
      <button data-action="menu">Quit routine</button>`;
  } else if (routine) {
    buttons = `<button class="primary" data-action="summary">See routine summary</button>`;
  } else {
    buttons = `<button class="primary" data-action="retry">Retry</button>
      <button data-action="menu">Menu</button>`;
  }

  $('results-body').innerHTML = `
    <p class="step">${meta.name} · ${meta.metric.label}</p>
    <div class="headline">${res.score}</div>
    ${pbLine}
    <table>${rows}</table>
    <div class="buttons">${buttons}</div>`;
  show('results');
}

function showSummary() {
  const rows = routine.results.map(({ meta, res, newPb }) =>
    `<tr><td>${meta.name}</td><td>${capitalize(meta.metric.label)}: ${res.score}${newPb ? '<span class="tag">PB</span>' : ''}</td></tr>`
  ).join('');
  $('results-body').innerHTML = `
    <h2>Warm-up complete</h2>
    <p class="pb">You're warmed up. Good luck in queue.</p>
    <table>${rows}</table>
    <div class="buttons">
      <button class="primary" data-action="again">Run routine again</button>
      <button data-action="menu">Menu</button>
    </div>`;
  routine = null;
  show('results');
}

function startRoutine() {
  routine = { index: 0, results: [] };
  showIntro(DRILLS[0].id);
}

// ---------- input ----------

$('routine-btn').addEventListener('click', startRoutine);

$('drill-list').addEventListener('click', (e) => {
  const card = e.target.closest('[data-id]');
  if (!card) return;
  routine = null;
  showIntro(card.dataset.id);
});

$('left-click').addEventListener('change', (e) => {
  settings.leftClick = e.target.checked;
  store.set('lolwarmup.settings', settings);
});

$('intro-start').addEventListener('click', () => begin(pendingId));
$('intro-back').addEventListener('click', abort);

$('results').addEventListener('click', (e) => {
  const action = e.target.closest('[data-action]')?.dataset.action;
  if (action === 'next') {
    routine.index++;
    showIntro(DRILLS[routine.index].id);
  } else if (action === 'retry') {
    showIntro(pendingId);
  } else if (action === 'summary') {
    showSummary();
  } else if (action === 'again') {
    startRoutine();
  } else if (action === 'menu') {
    abort();
  }
});

function toCanvas(e) {
  const r = canvas.getBoundingClientRect();
  return { x: ((e.clientX - r.left) * W) / r.width, y: ((e.clientY - r.top) * H) / r.height };
}

canvas.addEventListener('mousemove', (e) => {
  const p = toCanvas(e);
  mouse.x = p.x;
  mouse.y = p.y;
});

canvas.addEventListener('mousedown', (e) => {
  if (!current || current.countdown > 0) return;
  const p = toCanvas(e);
  mouse.x = p.x;
  mouse.y = p.y;
  const primary = settings.leftClick ? e.button === 0 : e.button === 2;
  if (primary) current.drill.click(p.x, p.y);
  else if (e.button === 0 || e.button === 2) floatText(p.x, p.y, `use ${clickName()}`, COLORS.muted, 13);
});

canvas.addEventListener('contextmenu', (e) => e.preventDefault());

window.addEventListener('keydown', (e) => {
  if (current) {
    if (e.key === 'Escape') {
      abort();
      return;
    }
    if (e.key.length !== 1) return;
    const k = e.key.toUpperCase();
    if ('QWERDF'.includes(k)) e.preventDefault();
    if (current.countdown <= 0 && !e.repeat && current.drill.key) current.drill.key(k);
    return;
  }
  if (!$('intro').hidden && (e.key === ' ' || e.key === 'Enter')) {
    e.preventDefault();
    begin(pendingId);
  }
});

// ---------- main loop ----------

function drawHud() {
  const { meta, drill, elapsed } = current;
  ctx.fillStyle = 'rgba(1, 10, 19, 0.85)';
  ctx.fillRect(0, 0, W, HUD_H);
  ctx.fillStyle = COLORS.gold;
  ctx.fillRect(0, HUD_H - 3, W * Math.min(1, elapsed / meta.duration), 3);

  ctx.textBaseline = 'middle';
  ctx.font = `bold 16px ${FONT}`;
  ctx.textAlign = 'left';
  ctx.fillStyle = COLORS.gold;
  ctx.fillText(meta.name.toUpperCase(), 16, HUD_H / 2);
  ctx.textAlign = 'center';
  ctx.fillStyle = COLORS.text;
  ctx.font = `15px ${FONT}`;
  ctx.fillText(drill.hud(), W / 2, HUD_H / 2);
  ctx.textAlign = 'right';
  ctx.font = `bold 16px ${FONT}`;
  ctx.fillText(`${Math.max(0, Math.ceil(meta.duration - elapsed))}s`, W - 16, HUD_H / 2);
  ctx.textBaseline = 'alphabetic';
}

function drawCountdown() {
  ctx.fillStyle = 'rgba(1, 10, 19, 0.55)';
  ctx.fillRect(0, HUD_H, W, H - HUD_H);
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = COLORS.goldBright;
  ctx.font = `bold 120px ${FONT}`;
  ctx.fillText(String(Math.ceil(current.countdown)), W / 2, H / 2);
  ctx.textBaseline = 'alphabetic';
}

let last = performance.now();

function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  drawGround();

  if (current) {
    if (current.countdown > 0) {
      current.countdown -= dt;
    } else {
      current.elapsed += dt;
      current.drill.update(dt);
      updateFloaters(dt);
    }
    current.drill.draw();
    drawFloaters();
    drawHud();
    if (current.countdown > 0) drawCountdown();
    else if (current.elapsed >= current.meta.duration) finishDrill();
  }

  requestAnimationFrame(frame);
}

renderMenu();
requestAnimationFrame(frame);
