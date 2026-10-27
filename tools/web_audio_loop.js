// Patches Godot's exported web/index.js so looping music plays seamlessly (run by tools/export_web.sh).
// Godot's web build plays sounds as Web Audio samples, and two things break music loops there:
//  - it loops a sample by waiting for "ended" and starting it again, which leaves a gap
//    -> let the browser loop it (AudioBufferSourceNode.loop);
//  - the buffer it decodes for a tune is a little longer than the tune and its last few tens of ms are the tune's
//    opening again, so each loop plays the opening twice (a stutter)
//    -> end the loop where the opening starts to repeat (loopEnd, found once per buffer).
const fs = require('fs');
const f = process.argv[2] || 'web/index.js';
const anchor = 'this._source.buffer=this.getSample().getAudioBuffer()';
let t = fs.readFileSync(f, 'utf8');
const n = t.split(anchor).length - 1;
if (n !== 2) {
  console.error(`${f}: expected 2 sample sources to patch, found ${n} (Godot's web audio code changed?)`);
  process.exit(1);
}
// seconds where the buffer's opening 50 ms reappear within its last 0.5 s (0 = it doesn't: loop the whole buffer)
function zmxyLoopEnd(b) {
  if (b.zmxyLoopEnd !== undefined) return b.zmxyLoopEnd;
  b.zmxyLoopEnd = 0;
  const d = b.getChannelData(0), sr = b.sampleRate, w = Math.round(sr * 0.05);
  if (d.length < sr * 2) return 0;
  for (let o = d.length - w; o >= d.length - Math.round(sr * 0.5); o--) {
    let same = true;
    for (let i = 0; i < w; i += 4) {
      if (Math.abs(d[o + i] - d[i]) > 1e-4) { same = false; break; }
    }
    if (same) { b.zmxyLoopEnd = o / sr; break; }
  }
  return b.zmxyLoopEnd;
}
const hook = ';if(this.getSample().loopMode==="forward"){this._source.loop=true;' +
  'const le=zmxyLoopEnd(this._source.buffer);if(le>0)this._source.loopEnd=le}';
t = zmxyLoopEnd.toString() + '\n' + t.split(anchor).join(anchor + hook);
fs.writeFileSync(f, t);
console.log('web audio loop patch applied');
