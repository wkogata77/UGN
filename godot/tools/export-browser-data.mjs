import { mkdirSync, writeFileSync, copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import * as icons from 'lucide-react';
import { freshState, WEAPONS, TOWNS, FORESTS, HILLS } from '../../src/game/model.js';
import { BATTLEFIELDS } from '../../src/game/battlefields.js';
import { PERKS, SKILLS, RANKS, RANK_XP } from '../../src/game/progression.js';
import { DEMO_TOWNS } from '../../src/demo/model.js';

const root = fileURLToPath(new URL('../../', import.meta.url));
const destination = join(root, 'godot');
for (const dir of ['data', 'assets', 'assets/icons', 'assets/fonts'])
  mkdirSync(join(destination, dir), { recursive: true });
writeFileSync(join(destination, 'data/browser.json'), JSON.stringify({
  state: freshState(), weapons: WEAPONS, towns: TOWNS, italyTowns: DEMO_TOWNS,
  forests: FORESTS, hills: HILLS, fields: BATTLEFIELDS, perks: PERKS,
  skills: SKILLS, ranks: RANKS, rankXp: RANK_XP,
}, null, 2) + '\n');
for (const name of ['terrain.png', 'trees.png', 'village.png', 'officers.png', 'weapons.png',
  'depth-units-keyed.png', 'depth-unit-actions-keyed.png', 'depth-unit-directions-v2.png'])
  copyFileSync(join(root, 'public/assets', name), join(destination, 'assets', name));
for (const name of ['ArrowLeft', 'ArrowRight', 'ArrowDownToLine', 'ArrowUpFromLine',
  'Award', 'Check', 'ChevronRight', 'Coins', 'Crosshair', 'Flag', 'Footprints',
  'Heart', 'Home', 'Landmark', 'Map', 'Maximize', 'Minus', 'Mountain', 'Pause',
  'Play', 'Plus', 'RotateCcw', 'Save', 'Settings', 'Shield', 'Square', 'Swords',
  'Target', 'Tent', 'Truck', 'UserRound', 'Users', 'Volume2', 'VolumeX', 'Wrench', 'X',
  'Rows3', 'Columns3', 'Gauge', 'Binoculars', 'MousePointer2', 'Star', 'Move', 'Undo2']) {
  writeFileSync(join(destination, 'assets/icons', `${name}.svg`),
    renderToStaticMarkup(React.createElement(icons[name], { width: 24, height: 24, color: '#e6dec5', strokeWidth: 1.5 })));
}
for (const [source, target] of [
  ['@fontsource/inter/files/inter-latin-400-normal.woff2', 'Inter.woff2'],
  ['@fontsource/cormorant-garamond/files/cormorant-garamond-latin-600-normal.woff2', 'Cormorant.woff2'],
  ['@fontsource/inter/LICENSE', 'Inter-LICENSE.txt'],
  ['@fontsource/cormorant-garamond/LICENSE', 'Cormorant-LICENSE.txt'],
  ['lucide-react/LICENSE', '../icons/LICENSE.txt'],
]) copyFileSync(join(root, 'node_modules', source), join(destination, 'assets/fonts', target));
console.log('Exported existing game data, painted assets, fonts, and Lucide icons to godot/.');
