#!/usr/bin/env node
// Moves files/folders inside game/ and rewrites every res:// path that points at them.
//   node tools/move_entity.js <from> <to> [<from> <to> ...]     (paths relative to game/, files or folders)
// Each file moves with its .import / .uid sidecars (uids stay, so uid references keep working); then every text
// resource / script / config under game/ (not .godot, addons) gets "res://<from>" replaced by "res://<to>".
// Writes keep each file's own line endings. Code that builds paths from parts is not rewritten: grep for it.
const fs = require('fs');
const path = require('path');

const GAME = path.join(__dirname, '..', 'game');
// --list <file.json>: [[from, to], ...] instead of arguments (a long list does not fit a command line)
let args = process.argv.slice(2);
if (args[0] === '--list') args = [].concat(...JSON.parse(fs.readFileSync(args[1], 'utf8')));
if (args.length === 0 || args.length % 2) {
  console.error('usage: node tools/move_entity.js <from> <to> [<from> <to> ...] | --list <pairs.json>');
  process.exit(1);
}
const pairs = [];
for (let i = 0; i < args.length; i += 2) pairs.push([args[i].replace(/\/+$/, ''), args[i + 1].replace(/\/+$/, '')]);

// 1. move
for (const [from, to] of pairs) {
  const src = path.join(GAME, from), dst = path.join(GAME, to);
  // already moved (a run stopped half way): only the paths are left to rewrite
  if (!fs.existsSync(src) && fs.existsSync(dst)) continue;
  if (!fs.existsSync(src)) throw new Error('missing ' + from);
  // a change of case only (Windows: the same file) goes through a temporary name
  const caseOnly = from.toLowerCase() === to.toLowerCase();
  if (fs.existsSync(dst) && !caseOnly) throw new Error('exists ' + to);
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  const step = (a, b) => { if (caseOnly) { fs.renameSync(a, a + '.~mv'); a += '.~mv'; } fs.renameSync(a, b); };
  step(src, dst);
  for (const s of ['.import', '.uid']) if (fs.existsSync(src + s)) step(src + s, dst + s);
  // a folder emptied by the move goes too (git does not keep empty folders)
  let d = path.dirname(src);
  while (d !== GAME && fs.readdirSync(d).length === 0) { fs.rmdirSync(d); d = path.dirname(d); }
  if (pairs.length < 40) console.log('moved', from, '->', to);
}

// 2. rewrite res:// paths: one pass, longest prefix first (a nested move must not be hit by its parent's rule); the old
// prefix must be followed by "/", a quote, space, ")" or the end, never a longer sibling name (wukong vs wukong_hit10)
const rules = new Map(pairs.map(([f, t]) => ['res://' + f, 'res://' + t]));
const esc = (x) => x.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const RE = new RegExp('(' + [...rules.keys()].sort((x, y) => y.length - x.length).map(esc).join('|') + ')(?=[/"\'\\s)]|$)', 'g');
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
    let n = 0;
    const out = s.replace(RE, (m) => { n++; return rules.get(m); });
    if (n) { fs.writeFileSync(p, out); files++; hits += n; }
  }
})(GAME);
console.log('rewrote', hits, 'paths in', files, 'files');
