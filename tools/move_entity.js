#!/usr/bin/env node
// Moves files/folders inside game/ and rewrites every res:// path that points at them.
//   node tools/move_entity.js <from> <to> [<from> <to> ...]     (paths relative to game/, files or folders)
// Each file moves with its .import / .uid sidecars (uids stay, so uid references keep working); then every text
// resource / script / config under game/ (not .godot, addons) gets "res://<from>" replaced by "res://<to>".
// Writes keep each file's own line endings. Code that builds paths from parts is not rewritten: grep for it.
const fs = require('fs');
const path = require('path');

const GAME = path.join(__dirname, '..', 'game');
const args = process.argv.slice(2);
if (args.length === 0 || args.length % 2) {
  console.error('usage: node tools/move_entity.js <from> <to> [<from> <to> ...]');
  process.exit(1);
}
const pairs = [];
for (let i = 0; i < args.length; i += 2) pairs.push([args[i].replace(/\/+$/, ''), args[i + 1].replace(/\/+$/, '')]);

// 1. move
for (const [from, to] of pairs) {
  const src = path.join(GAME, from), dst = path.join(GAME, to);
  if (!fs.existsSync(src)) throw new Error('missing ' + from);
  if (fs.existsSync(dst)) throw new Error('exists ' + to);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.renameSync(src, dst);
  for (const s of ['.import', '.uid']) if (fs.existsSync(src + s)) fs.renameSync(src + s, dst + s);
  // a folder emptied by the move goes too (git does not keep empty folders)
  let d = path.dirname(src);
  while (d !== GAME && fs.readdirSync(d).length === 0) { fs.rmdirSync(d); d = path.dirname(d); }
  console.log('moved', from, '->', to);
}

// 2. rewrite res:// paths (longest first: a nested move must not be hit by its parent's rule)
const rules = pairs.map(([f, t]) => ['res://' + f, 'res://' + t]).sort((a, b) => b[0].length - a[0].length);
const EXT = new Set(['.tscn', '.tres', '.gd', '.gdshader', '.import', '.json', '.cfg', '.godot', '.md']);
const SKIP = new Set(['.godot', 'addons']);
let files = 0, hits = 0;
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { walk(p); continue; }
    if (!EXT.has(path.extname(e.name))) continue;
    const s = fs.readFileSync(p, 'utf8');
    if (!s.includes('res://')) continue;
    let out = s, n = 0;
    for (const [f, t] of rules) {
      // the old prefix followed by "/" , a quote or the end of the path: never a longer sibling name (wukong_hit10)
      const re = new RegExp(f.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(?=[/"\'\\s)]|$)', 'g');
      out = out.replace(re, () => { n++; return t; });
    }
    if (n) { fs.writeFileSync(p, out); files++; hits += n; }
  }
})(GAME);
console.log('rewrote', hits, 'paths in', files, 'files');
