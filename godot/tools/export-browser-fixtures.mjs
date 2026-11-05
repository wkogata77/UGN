import fs from 'node:fs/promises';
import { Campaign } from '../../src/game/model.js';

const folder = new URL('../tests/fixtures/', import.meta.url);
await fs.mkdir(folder, { recursive: true });
const write = (name, state) => fs.writeFile(new URL(`${name}.json`, folder), JSON.stringify(state));
const campaign = new Campaign();
await write('browser-campaign', campaign.state);
campaign.startBattle('e1');
campaign.select(['u1']);
campaign.formation('column');
campaign.moveUnits({ x: 500, y: 450 });
campaign.pause();
for (let i = 0; i < 30; i++) campaign.update(0.1);
await write('browser-battle', campaign.state);
campaign.finishBattle(true);
await write('browser-report', campaign.state);
console.log('Exported real browser campaign, battle, and report fixtures.');
