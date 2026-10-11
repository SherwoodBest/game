// Builds the web player under build/web/: the film cut into parts at chapter
// boundaries (each part stays under the artifact host's 15 MB file limit), a
// poster frame, and index.html with the chapter data filled in.
//
//   node web/build.mjs          render the parts from source frames, then the page
//   node web/build.mjs --page   rebuild only index.html
//   node web/build.mjs --test   also write test.html with low-res WebM parts, for
//                               headless Chromium, which cannot decode H.264
//
// Needs build/timeline.json and build/mix.wav from ./build.sh.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const OUT = path.join(ROOT, 'build/web');
const FPS = 30;
// Each part starts at one of these scenes; parts run about 80-110 seconds.
const SPLIT_AT = ['symbolic', 'nineties', 'alphago', 'alphafold', 'agents'];
const MAX_BYTES = 15 * 1000 * 1000;

const script = JSON.parse(fs.readFileSync(path.join(ROOT, 'script.json'), 'utf8'));
const timeline = JSON.parse(fs.readFileSync(path.join(ROOT, 'build/timeline.json'), 'utf8'));
const eras = Object.fromEntries(script.eras.map((e) => [e.id, e]));
const sceneStart = (id) => timeline.scenes.find((s) => s.id === id).start;

const totalFrames = Math.ceil(timeline.duration * FPS);
const bounds = [0, ...SPLIT_AT.map((id) => Math.round(sceneStart(id) * FPS)), totalFrames];
const parts = bounds.slice(0, -1).map((from, k) => ({
  n: k + 1, from, to: bounds[k + 1], start: from / FPS, duration: (bounds[k + 1] - from) / FPS,
}));

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'ignore', 'inherit'] });
    p.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))));
  });
}

async function pool(tasks, n) {
  const queue = tasks.slice();
  await Promise.all(Array.from({ length: n }, async () => {
    while (queue.length) await queue.shift()();
  }));
}

async function renderParts() {
  fs.mkdirSync(path.join(OUT, 'media'), { recursive: true });
  await pool(parts.map((p) => async () => {
    const video = path.join(OUT, `video-${p.n}.mp4`);
    await run('node', [path.join(ROOT, 'render.mjs'), '--from', String(p.from), '--to', String(p.to), '--out', video]);
    await run('ffmpeg', [
      '-y', '-loglevel', 'error', '-i', video,
      '-ss', p.start.toFixed(6), '-t', p.duration.toFixed(6), '-i', path.join(ROOT, 'build/mix.wav'),
      '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '160k',
      '-shortest', '-movflags', '+faststart', path.join(OUT, `media/part-${p.n}.mp4`),
    ]);
    fs.rmSync(video);
    console.log(`part ${p.n}: ${p.start.toFixed(2)}s +${p.duration.toFixed(2)}s`);
  }), Math.max(1, Math.min(parts.length, os.cpus().length)));

  const still = path.join(OUT, 'stills');
  await run('node', [path.join(ROOT, 'render.mjs'), '--stills', '5', '--dir', still]);
  const png = path.join(still, fs.readdirSync(still).find((f) => f.endsWith('.png')));
  await run('ffmpeg', ['-y', '-loglevel', 'error', '-i', png, '-vf', 'scale=1280:-2', '-q:v', '3', path.join(OUT, 'media/poster.jpg')]);
  fs.rmSync(still, { recursive: true });
}

async function testParts() {
  fs.mkdirSync(path.join(OUT, 'test'), { recursive: true });
  await pool(parts.map((p) => () => run('ffmpeg', [
    '-y', '-loglevel', 'error', '-i', path.join(OUT, `media/part-${p.n}.mp4`),
    '-vf', 'scale=480:-2', '-r', '15', '-c:v', 'libvpx-vp9', '-deadline', 'realtime', '-cpu-used', '8', '-b:v', '150k',
    '-c:a', 'libopus', '-b:a', '48k', path.join(OUT, `test/part-${p.n}.webm`),
  ])), Math.max(1, os.cpus().length));
}

const fmt = (t) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function chapters() {
  return script.scenes.map((s) => {
    const era = s.era ? eras[s.era] : null;
    const intro = s.id === 'intro', outro = s.id === 'outro';
    return {
      id: s.id,
      t: sceneStart(s.id),
      label: intro ? 'Opening' : outro ? 'Closing' : s.yearLabel,
      title: intro ? 'Can machines think?' : outro ? 'What will we choose to do?' : s.title,
      era: era ? era.label : '',
      color: era ? era.color : '#9AA5C4',
    };
  });
}

function page({ ext, mediaDir }) {
  const ch = chapters();
  const film = {
    duration: totalFrames / FPS,
    parts: parts.map((p) => ({ src: `${mediaDir}/part-${p.n}.${ext}`, start: p.start, duration: p.duration })),
    chapters: ch,
  };
  const rows = ch.map((c, i) => {
    const end = i + 1 < ch.length ? ch[i + 1].t : film.duration;
    return `      <li><button class="chapter" type="button" id="ch-${c.id}" data-t="${c.t.toFixed(3)}" style="--era: ${c.color}">` +
      `<span class="ch-time">${fmt(c.t)}</span><span class="ch-label">${esc(c.label)}</span>` +
      `<span class="ch-title">${esc(c.title)}</span><span class="ch-len">${fmt(end - c.t)}</span></button></li>`;
  }).join('\n');
  const segs = ch.map((c, i) => {
    const end = i + 1 < ch.length ? ch[i + 1].t : film.duration;
    return `<i style="flex-grow: ${(end - c.t).toFixed(3)}; --era: ${c.color}"></i>`;
  }).join('');
  return fs.readFileSync(path.join(HERE, 'player.html'), 'utf8')
    .replace('__RUNTIME__', fmt(film.duration))
    .replace('__COUNT__', String(ch.length))
    .replace('__POSTER__', `${mediaDir === 'test' ? 'media' : mediaDir}/poster.jpg`)
    .replace('__SEGMENTS__', segs).replace('__SEGMENTS__', segs)
    .replace('__CHAPTERS__', rows)
    .replace('__DURATION__', fmt(film.duration))
    .replace('__FILM__', JSON.stringify(film));
}

// The artifact host wraps the page in this skeleton at publish time; the local
// test page needs the same wrapper.
const SKELETON = (body) => '<!doctype html><html><head><meta charset="utf-8">' +
  '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>' + body + '</body></html>';

const args = process.argv.slice(2);
if (!args.includes('--page')) await renderParts();
if (args.includes('--test')) await testParts();
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'index.html'), page({ ext: 'mp4', mediaDir: 'media' }));
if (args.includes('--test')) fs.writeFileSync(path.join(OUT, 'test.html'), SKELETON(page({ ext: 'webm', mediaDir: 'test' })));

let total = 0;
for (const p of parts) {
  const f = path.join(OUT, `media/part-${p.n}.mp4`);
  if (!fs.existsSync(f)) continue;
  const size = fs.statSync(f).size;
  total += size;
  console.log(`media/part-${p.n}.mp4  ${(size / 1e6).toFixed(1)} MB${size > MAX_BYTES ? '  OVER LIMIT' : ''}`);
}
console.log(`parts total ${(total / 1e6).toFixed(1)} MB; wrote ${path.relative(ROOT, OUT)}/index.html`);
