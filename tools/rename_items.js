#!/usr/bin/env node
// One-off: item ids from pinyin initials to full pinyin (map file: old id -> new id), item pictures to
// assets/items/<id>_fall.png (drop picture) or <id>_icon.png (only the original framed picture exists).
//   node tools/rename_items.js <map.json>
// Rewrites quoted ids ("x" / &"x") in game data, scripts and checks; renames treasure scripts / scenes keyed by id.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const GAME = path.join(ROOT, 'game');
const map = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const lsLF = (f) => { const s = fs.readFileSync(f, 'utf8'); return [s.replace(/\r\n/g, '\n'), s.includes('\r\n')]; };
const save = (f, s, crlf) => fs.writeFileSync(f, crlf ? s.replace(/\n/g, '\r\n') : s);
const move = (a, b) => execFileSync('node', [path.join(ROOT, 'tools/move_entity.js'), ...[].concat(...a.map((x, i) => [x, b[i]]))], { stdio: 'inherit' });

// ---- 1. pictures: each item's icon / ground_icon in the catalogue
const EQ = path.join(GAME, 'data/equipment.tres');
let [eq, eqCrlf] = lsLF(EQ);
const ext = {};
for (const m of eq.matchAll(/\[ext_resource type="Texture2D" path="res:\/\/([^"]+)" id="([^"]+)"\]/g)) ext[m[2]] = m[1];
const moves = [[], []], drop = new Set();
const blocks = eq.split('\n[sub_resource');
for (let i = 1; i < blocks.length; i++) {
  let b = blocks[i];
  const id = (b.match(/\nid = &"([^"]+)"/) || [])[1];
  if (!id) continue;
  const icon = (b.match(/\nicon = ExtResource\("([^"]+)"\)/) || [])[1];
  const ground = (b.match(/\nground_icon = ExtResource\("([^"]+)"\)/) || [])[1];
  const nid = map[id];
  if (ground && icon && ext[ground] !== ext[icon]) {
    // a drop picture of its own: the framed original goes (nothing else uses it)
    moves[0].push(ext[ground]); moves[1].push(`assets/items/${nid}_fall.png`);
    drop.add(ext[icon]);
    b = b.replace(/\nicon = ExtResource\("[^"]+"\)/, '').replace(/\nground_icon = /, '\nicon = ');
  } else if (icon) {
    moves[0].push(ext[icon]); moves[1].push(`assets/items/${nid}_icon.png`);
    b = b.replace(/\nground_icon = ExtResource\("[^"]+"\)/, '').replace(/(\nicon = ExtResource\("[^"]+"\))/, '$1\nframed = true');
  }
  blocks[i] = b;
}
eq = blocks.join('\n[sub_resource');
// the dropped framed pictures' ext_resource lines
for (const [rid, p] of Object.entries(ext)) {
  if (drop.has(p) && !moves[0].includes(p)) eq = eq.replace(new RegExp(`\\[ext_resource type="Texture2D" path="res://${p.replace(/[.]/g, '\\.')}" id="${rid}"\\]\\n`), '');
}
save(EQ, eq, eqCrlf);
const TRASH = path.join(ROOT, 'tools/dl/trash_items');
fs.mkdirSync(TRASH, { recursive: true });
for (const p of drop) {
  if (moves[0].includes(p)) continue;
  for (const s of ['', '.import']) if (fs.existsSync(path.join(GAME, p + s))) fs.renameSync(path.join(GAME, p + s), path.join(TRASH, path.basename(p) + s));
}
move(moves[0], moves[1]);

// ---- 2. scripts / scenes named by treasure id
const tre = [[], []];
for (const f of fs.readdirSync(path.join(GAME, 'src/actors/treasures'))) {
  const m = f.match(/^treasure_([a-z0-9]+)\.gd$/);
  if (m && map[m[1]]) { tre[0].push(`src/actors/treasures/${f}`); tre[1].push(`src/actors/treasures/treasure_${map[m[1]]}.gd`); }
}
for (const d of fs.readdirSync(path.join(GAME, 'scenes/actors'))) {
  const m = d.match(/^fabao_([a-z0-9]+)$/);
  if (!m || !map[m[1]]) continue;
  const n = `fabao_${map[m[1]]}`;
  for (const f of fs.readdirSync(path.join(GAME, 'scenes/actors', d))) {
    if (f.endsWith('.uid') || f.endsWith('.import')) continue;
    tre[0].push(`scenes/actors/${d}/${f}`); tre[1].push(`scenes/actors/${n}/${f.replace(d, n)}`);
  }
  if (fs.existsSync(path.join(GAME, 'assets/puppets', d))) { tre[0].push(`assets/puppets/${d}`); tre[1].push(`assets/puppets/${n}`); }
}
if (tre[0].length) move(tre[0], tre[1]);

// ---- 3. quoted ids everywhere
const ids = Object.keys(map).sort((a, b) => b.length - a.length);
const re = new RegExp(`(&?)"(${ids.join('|')})"`, 'g');
const SKIP = new Set(['.godot', 'addons', 'node_modules', 'web_shell']);
const FILES = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.(gd|tres|tscn|json)$/.test(e.name)) FILES.push(p);
  }
})(GAME);
let n = 0;
for (const f of FILES) {
  const rel = path.relative(GAME, f).replace(/\\/g, '/');
  if (rel === 'src/actors/monster.gd' || rel.startsWith('tools/audit')) continue;   // {"t": 0.0} is a timer, not 贪
  let [s, crlf] = lsLF(f);
  let k = 0;
  let out = s.replace(re, (all, amp, id) => {
    // the bare one-letter ids (贪嗔痴 t / c / ch) only where they are item lists or catalogue keys
    if (id.length <= 2 && !/equipment\.tres$|monster_63\.tres$|item_tip\.gd$|forge_check\.gd$/.test(rel)) return all;
    k++; return `${amp}"${map[id]}"`;
  });
  // fabao_<id> puppet names built from the treasure id
  out = out.replace(/"fabao_([a-z0-9]+)"/g, (all, id) => map[id] ? (k++, `"fabao_${map[id]}"`) : all);
  if (k) { save(f, out, crlf); n += k; console.log(k, rel); }
}
console.log('ids rewritten:', n);
