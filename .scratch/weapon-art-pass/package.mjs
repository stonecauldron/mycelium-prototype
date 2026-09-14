import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root = process.cwd();
const dir = path.join(root, '.scratch/weapon-art-pass');
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'generation.json')));
const configs = {
  sword: {pixels: 78, grip: [.5, .83]},
  great_sword: {pixels: 160, grip: [.5, .925], stretch: 1.35},
  great_hammer: {pixels: 163, grip: [.473, .82], file: 'greathammer', stretch: 1.12, outline: 1},
  great_shield: {pixels: 150, grip: [.5, .75]},
  spear: {pixels: 143, grip: [.5, .80]},
  great_spear: {pixels: 192, grip: [.45, .84]},
  bow: {pixels: 94, grip: [.83, .56]},
  great_bow: {pixels: 168, grip: [.82, .5]},
  mace: {pixels: 85, grip: [.5, .79]},
  shield: {pixels: 78, grip: [.5, .50]},
  sickle: {pixels: 82, grip: [.48, .83]},
  warhammer: {pixels: 88, grip: [.5, .77]},
  polehammer: {pixels: 146, grip: [.48, .80]},
  lance: {pixels: 151, grip: [.5, .86]},
  rapier: {pixels: 108, grip: [.5, .86]},
  scythe: {pixels: 156, grip: [.09, .80]},
  crossbow: {pixels: 116, grip: [.12, .77]},
  mortar: {pixels: 112, grip: [.07, .68]},
  giant_horn: {pixels: 168, grip: [.13, .87], file: 'horn'},
  umbrella: {pixels: 190, grip: [.5, .88]},
  sling: {pixels: 70, grip: [.5, .82]},
};
fs.mkdirSync(path.join(dir, 'cutouts'), {recursive: true});
for (const item of manifest.assets) {
  if (process.argv[2] && !process.argv[2].split(',').includes(item.id)) continue;
  const c = configs[item.id];
  if (!c) continue;
  const target = path.join(root, 'assets/weapons', item.id, (c.file || item.id) + '.png');
  const staged = path.join(dir, 'cutouts', item.id + '-packed.png');
  const cutout = path.join(dir, 'cutouts', item.id + '.png');
  const magick = args => execFileSync('/opt/homebrew/bin/magick', args);
  // The generated chroma-key plate becomes true alpha before any resampling.
  magick([item.source, '-alpha', 'on', '-channel', 'A', '-fx', 'r > g+0.08 && b > g+0.08 ? 0 : 1', '+channel', '-trim', '+repage', '-resize', '464x464', cutout]);
  // Extend the dark silhouette by one to two world pixels to match the character stroke.
  const radius = Math.round((c.outline ?? 2) * 464 / c.pixels);
  if (c.stretch) magick([cutout, '-resize', `${c.stretch * 100}%x100%!`, cutout]);
  magick([cutout, '-bordercolor', 'none', '-border', String(radius + 1), '(', '+clone', '-alpha', 'extract', '-morphology', 'Dilate', 'Disk:' + radius, '-background', '#0b0e09', '-alpha', 'shape', ')', '+swap', '-compose', 'Over', '-composite', '-background', 'none', '-gravity', 'center', '-extent', '512x512', staged]);
  fs.renameSync(staged, target);
  const dimensions = magick(['identify', '-format', '%w %h', cutout]).toString().trim().split(' ').map(Number);
  const scale = c.pixels / 464;
  const grip = c.grip.map((f,i) => (512 - dimensions[i]) / 2 + f * dimensions[i]);
  const scenePath = path.join(root, 'assets/weapons', item.id, item.id + '_appearance.tscn');
  let scene = fs.readFileSync(scenePath, 'utf8');
  // The measured grip is now at the mount origin; old visual translations no longer apply.
  scene = scene.replace(/(\[node name="Visual"[^\n]+\]\n)([\s\S]*?)(?=\n\[node|$)/, (_, head, body) => head + body.replace(/^position = .*\n/m, ''));
  scene = scene.replace(/scale = Vector2\([^\n]+\)/, `scale = Vector2(${scale.toFixed(8)}, ${scale.toFixed(8)})`);
  const offset = `offset = Vector2(${(256-grip[0]).toFixed(4)}, ${(256-grip[1]).toFixed(4)})`;
  scene = /offset = Vector2/.test(scene) ? scene.replace(/offset = Vector2\([^\n]+\)/, offset) : scene.trimEnd() + '\n' + offset + '\n';
  fs.writeFileSync(scenePath, scene);
  console.log(item.id, dimensions.join('×'), 'world extent', c.pixels);
}
