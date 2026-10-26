#!/usr/bin/env node
// Gives scene nodes that still carry generated names (p1_2_3_f5, 2_628_05, OtherMat_v10_245, Part3, lower-case roots,
// Slot116_2) readable PascalCase names, and rewrites every node path that points at them (parent=, NodePath(...) in
// the scene and in its <name>_actions.tres). Nodes whose old name appears in a script / json are left alone (reported).
//   node tools/rename_nodes.js [--dry]
// Naming: root = the scene file in PascalCase (an equipment variant: <Kind><id>, e.g. Wing2); a sprite in a stage =
// <Layer>Piece<n>; a sprite in a UI screen = its picture's name without the screen prefix (Background); any other
// generated name = <Parent>Part<n>.
const fs = require('fs');
const path = require('path');

const GAME = path.join(__dirname, '..', 'game');
const dry = process.argv.includes('--dry');
const SKIP = new Set(['.godot', 'addons', 'tools', 'web_shell']);
const pascal = (s) => s.split(/[^A-Za-z0-9]+/).filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');
const GENERATED = (n) => /_/.test(n) || /^[a-z0-9]/.test(n) || /^Part\d+$/.test(n);

const scenes = [], code = [];
(function walk(d) {
  for (const e of fs.readdirSync(path.join(GAME, d), { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const p = d ? `${d}/${e.name}` : e.name;
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.tscn')) scenes.push(p);
    else if (/\.(gd|json)$/.test(e.name)) code.push(fs.readFileSync(path.join(GAME, p), 'utf8'));
  }
})('');
const codeText = code.join('\n');
const usedInCode = (n) => codeText.includes(`"${n}"`) || codeText.includes(`/${n}"`) || codeText.includes(`"${n}/`) || codeText.includes(`/${n}/`) || codeText.includes(`$${n}`) || codeText.includes(`%${n}`);

// equipment variant scene -> "<Kind><id>" from the EquipSlot that lists it
const variantName = {};
for (const s of scenes) {
  const t = fs.readFileSync(path.join(GAME, s), 'utf8');
  const ext = Object.fromEntries([...t.matchAll(/\[ext_resource[^\]]*path="res:\/\/([^"]+)"[^\]]*id="([^"]+)"\]/g)].map((m) => [m[2], m[1]]));
  for (const m of t.matchAll(/kind = "([a-z_]+)"\nvariants = \{\n([^}]*)\}/g))
    for (const v of m[2].matchAll(/(\d+): ExtResource\("([^"]+)"\)/g)) {
      const f = ext[v[2]];
      if (f && !variantName[f]) variantName[f] = pascal(m[1]) + v[1];
    }
}

let renamed = 0, kept = [];
for (const s of scenes) {
  const file = path.join(GAME, s);
  let t = fs.readFileSync(file, 'utf8');
  const nl = t.includes('\r\n') ? '\r\n' : '\n';
  t = t.replace(/\r\n/g, '\n');
  const nodes = [];
  for (const m of t.matchAll(/^\[node name="([^"]+)"([^\]\n]*)\]$/gm)) {
    const parent = (m[2].match(/ parent="([^"]*)"/) || [])[1];
    const body = t.slice(m.index + m[0].length, t.indexOf('\n[', m.index + m[0].length) >>> 0);
    const tex = (body.match(/\ntexture = ExtResource\("([^"]+)"\)/) || [])[1];
    nodes.push({ name: m[1], parent, tex, instance: /instance=/.test(m[2]) });
  }
  if (!nodes.length) continue;
  const ext = Object.fromEntries([...t.matchAll(/\[ext_resource[^\]]*path="res:\/\/([^"]+)"[^\]]*id="([^"]+)"\]/g)].map((m) => [m[2], m[1]]));
  const base = path.basename(s, '.tscn');
  const kind = s.startsWith('stages/') ? 'stage' : s.startsWith('ui/') ? 'ui' : 'entity';
  // full path of every node (root = ".")
  const full = (n) => (n.parent === undefined ? '.' : n.parent === '.' ? n.name : `${n.parent}/${n.name}`);
  const map = {};   // old full path -> new name of the last segment
  const counters = {}, taken = {};
  for (const n of nodes) { const k = n.parent ?? '#'; (taken[k] ??= new Set()).add(n.name); }
  for (const n of nodes) {
    if (!GENERATED(n.name) || n.instance && n.parent !== undefined) continue;
    if (n.parent !== undefined && usedInCode(n.name)) { kept.push(`${s}: ${n.name}`); continue; }
    let want;
    const parentName = n.parent === undefined ? '' : n.parent === '.' ? pascal(base) : n.parent.split('/').pop();
    if (n.parent === undefined) want = variantName[s] || pascal(base);
    else if (kind === 'stage' && n.tex) want = `${pascal(parentName)}Piece`;
    else if (kind === 'ui' && n.tex && ext[n.tex]) {
      const owner = s.split('/')[1];
      want = pascal(path.basename(ext[n.tex], '.png').replace(new RegExp(`^${owner}_`), '')) || 'Picture';
      if (/^\d/.test(want)) want = 'Picture' + want;
    } else want = `${pascal(parentName)}Part`;
    const k = n.parent ?? '#';
    let name = want;
    if (/(Piece|Part)$/.test(want)) { let i = (counters[k + want] || 0); do { i++; name = want + i; } while (taken[k].has(name)); counters[k + want] = i; }
    else { let i = 1; while (taken[k].has(name) && name !== n.name) name = want + ++i; }
    if (name === n.name) continue;
    taken[k].add(name);
    map[full(n)] = name;
    n.newName = name;
  }
  if (!Object.keys(map).length) continue;
  // old path -> new path, segment by segment (a renamed parent renames its children's paths)
  const fix = (p) => {
    if (p === '.' || p === '') return p;
    const segs = p.split('/'), out = [];
    for (let i = 0; i < segs.length; i++) { const old = segs.slice(0, i + 1).join('/'); out.push(map[old] ?? segs[i]); }
    return out.join('/');
  };
  // node headers
  let idx = 0;
  t = t.replace(/^\[node name="([^"]+)"([^\]\n]*)\]$/gm, (all, name, rest) => {
    const n = nodes[idx++];
    const r = rest.replace(/ parent="([^"]*)"/, (a, p) => ` parent="${fix(p)}"`);
    return `[node name="${n.newName ?? name}"${r}]`;
  });
  // NodePaths: relative to the root, or to the Puppet child (actor scenes animate under it)
  const fixPath = (p) => {
    const [np, prop] = p.split(':');
    const a = fix(np);
    if (a !== np) return a + (prop !== undefined ? ':' + p.slice(np.length + 1) : '');
    const b = fix('Puppet/' + np);
    if (b !== 'Puppet/' + np) return b.slice(7) + (prop !== undefined ? ':' + p.slice(np.length + 1) : '');
    return p;
  };
  const fixText = (x) => x.replace(/NodePath\("([^"]*)"\)/g, (a, p) => `NodePath("${fixPath(p)}")`)
    .replace(/(\[connection [^\]]*?(?:from|to)=")([^"]*)"/g, (a, h, p) => h + fix(p) + '"');
  t = fixText(t);
  renamed += Object.keys(map).length;
  if (!dry) {
    fs.writeFileSync(file, t.replace(/\n/g, nl));
    for (const lib of [s.replace(/\.tscn$/, '_actions.tres')]) {
      const lf = path.join(GAME, lib);
      if (!fs.existsSync(lf)) continue;
      let l = fs.readFileSync(lf, 'utf8');
      const lnl = l.includes('\r\n') ? '\r\n' : '\n';
      fs.writeFileSync(lf, fixText(l.replace(/\r\n/g, '\n')).replace(/\n/g, lnl));
    }
  }
}
console.log(renamed, 'nodes renamed');
if (kept.length) console.log('kept (named in code):\n' + kept.join('\n'));
