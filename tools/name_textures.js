#!/usr/bin/env node
// Plans readable names for pictures still called after their Flash library id (OtherMat_v10_341.png, 3_1027.png,
// Common_v7_438.png ...): <owner>_<use>.png, where <owner> is the entity / stage / ui folder the picture is in (for a
// shared folder: its first user) and <use> the node or animation track that shows it (Hit1Part3 -> hit1_part3). Same
// folder; duplicates get _2, _3. Pictures nothing references are listed apart (to delete).
//   node tools/name_textures.js <out_pairs.json> <out_unused.txt>
// then: node tools/move_entity.js --list <out_pairs.json>
const fs = require('fs');
const path = require('path');

const GAME = path.join(__dirname, '..', 'game');
const SKIP = new Set(['.godot', 'addons', 'node_modules', 'web_shell', 'tools']);
const UGLY = /^(?:[A-Za-z]+[0-9]*(?:_v\d+)?_|zmxy2_game_|\d+_(?:v\d+_)?|c)\d+(?:_\d+)*$/;
const snake = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').replace(/([A-Za-z])(\d)/g, '$1$2').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '').toLowerCase();
const uglyNode = (n) => UGLY.test(n) || /^p\d+(_\d+)*(_f\d+)?$/.test(n) || /^\d/.test(n) || /^(Art|Part|Sprite|Node|Picture)\d*$/.test(n);

const pngs = [], texts = [];
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.png')) pngs.push(path.relative(GAME, p).replace(/\\/g, '/'));
    else if (/\.(tscn|tres|json|gd)$/.test(e.name)) texts.push(p);
  }
})(GAME);
const T = texts.map((p) => [path.relative(GAME, p).replace(/\\/g, '/'), fs.readFileSync(p, 'utf8').replace(/\r/g, '')]);

// the folder that owns a picture
function ownerOf(png) {
  let m;
  if ((m = png.match(/^entities\/[a-z]+\/[^/]+\/effects\/([^/]+)\//))) return m[1];
  if ((m = png.match(/^entities\/[a-z]+\/([^/]+)\/(?:bag_[a-z]+)\//)) && png.includes('/bag_')) return png.match(/\/(bag_[a-z]+)\//)[1];
  if ((m = png.match(/^entities\/[a-z]+\/([^/]+)\//))) return m[1];
  if ((m = png.match(/^stages\/(sl\d+)\//))) return m[1];
  if ((m = png.match(/^ui\/([^/]+)\//)) && m[1] !== 'shared') return m[1];
  return null;   // shared folders: named after the first user
}
function ownerOfFile(f) {
  let m;
  if ((m = f.match(/^entities\/[a-z]+\/[^/]+\/effects\/([^/]+)\//))) return m[1];
  if ((m = f.match(/\/(bag_[a-z]+)\//))) return m[1];
  if ((m = f.match(/^entities\/[a-z]+\/([^/]+)\//))) return m[1];
  if ((m = f.match(/^stages\/([^/]+)\//))) return m[1];
  if ((m = f.match(/^ui\/([^/]+)\//))) return m[1];
  return path.basename(f).replace(/\.[a-z]+$/, '');
}

// what shows the resource `id` in a scene / resource text: node names or animation track nodes
function usesIn(text, id, kind, depth = 0) {
  const out = [];
  const ref = kind === 'ext' ? `ExtResource("${id}")` : `SubResource("${id}")`;
  let i = text.indexOf(ref);
  while (i >= 0) {
    const head = text.lastIndexOf('\n[', i);
    const line = text.slice(head + 1, text.indexOf('\n', head + 1));
    let m;
    if ((m = line.match(/^\[node name="([^"]+)"(?:[^\]]*parent="([^"]*)")?/))) {
      const chain = [m[1], ...(m[2] || '').split('/').reverse()].filter((x) => x && x !== '.');
      const good = chain.find((n) => !uglyNode(n));
      const idx = chain.indexOf(good);
      out.push(good ? (idx > 0 ? `${good}_${snake(chain[0]).replace(/^.*?(\d+)$/, '$1')}` : good) : null);
    } else if ((m = line.match(/^\[sub_resource type="([^"]+)" id="([^"]+)"\]/))) {
      if (m[1] === 'Animation') {
        const seg = text.slice(head, i);
        const tp = [...seg.matchAll(/tracks\/\d+\/path = NodePath\("([^":]+)/g)].pop();
        if (tp) { const parts = tp[1].split('/').reverse(); out.push(parts.find((n) => !uglyNode(n)) || null); }
      } else if (depth < 3) out.push(...usesIn(text, m[2], 'sub', depth + 1));
    } else if (line.startsWith('[resource]')) {
      const tp = [...text.slice(head, i).matchAll(/tracks\/\d+\/path = NodePath\("([^":]+)/g)].pop();
      if (tp) { const parts = tp[1].split('/').reverse(); out.push(parts.find((n) => !uglyNode(n)) || null); }
    }
    i = text.indexOf(ref, i + ref.length);
  }
  return out;
}

const pairs = [], unused = [], taken = new Map();
const NAMED = { 'assets/shared/mixed/zmxy2_game_353.png': 'fly_floor', 'ui/shared/OtherMat_v10_341.png': 'tab_menu_background' };   // no user that names it
for (const png of pngs.sort()) {
  const base = path.basename(png, '.png');
  if (!UGLY.test(base)) continue;
  const res = 'res://' + png;
  const uidLine = fs.existsSync(path.join(GAME, png + '.import')) ? (fs.readFileSync(path.join(GAME, png + '.import'), 'utf8').match(/uid="(uid:\/\/[a-z0-9]+)"/) || [])[1] : null;
  const users = [];
  for (const [f, s] of T) {
    if (!s.includes(res) && !(uidLine && s.includes(uidLine))) continue;
    const ext = [...s.matchAll(/\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]/g)].filter((m) => m[1] === res).map((m) => m[2]);
    let uses = [];
    for (const id of ext) uses.push(...usesIn(s, id, 'ext'));
    if (!ext.length) uses.push(null);   // a plain path in code / json
    users.push({ f, uses: uses.filter(Boolean) });
  }
  if (!users.length) { unused.push(png); continue; }
  if (NAMED[png]) { pairs.push([png, `${path.dirname(png)}/${NAMED[png]}.png`]); continue; }
  const owner = ownerOf(png) || ownerOfFile(users[0].f);
  const use = (users.flatMap((u) => u.uses)[0] || '').replace(/(?<=[A-Za-z])d{3,}$/, '') || null;   // Background245 -> Background
  // an animation frame of a one-picture effect has no node name of its own: <owner>_frame, numbered
  const anim = users.some((u) => u.f.startsWith('entities/') && /(_actions\.tres|\.tscn)$/.test(u.f));
  // no node name to go by: a full-screen picture is the background, the rest numbered pieces of the owner
  const buf = fs.readFileSync(path.join(GAME, png));
  const big = buf.readUInt32BE(16) * buf.readUInt32BE(20) >= 1400 * 800;
  const fallback = anim ? 'frame' : big ? 'background' : owner === 'cartoon' ? 'page' : 'piece';
  let name = snake(use ? `${owner}_${snake(use).startsWith(owner + '_') ? snake(use).slice(owner.length + 1) : snake(use)}` : `${owner}_${fallback}`);
  name = name.replace(/_+/g, '_');
  const dir = path.dirname(png);
  let n = name, k = 1;
  const key = (x) => `${dir}/${x}`;
  while (taken.has(key(n)) || (fs.existsSync(path.join(GAME, dir, n + '.png')) && !pngs.includes(`${dir}/${n}.png`))) n = `${name}_${++k}`;
  taken.set(key(n), png);
  pairs.push([png, `${dir}/${n}.png`]);
}
fs.writeFileSync(process.argv[2], JSON.stringify(pairs));
fs.writeFileSync(process.argv[3], unused.join('\n'));
console.log(pairs.length, 'renames,', unused.length, 'unused');
