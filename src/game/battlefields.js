import PF from 'pathfinding';
import { upgradeRegiment } from './progression.js';

export const BATTLEFIELDS = {
  village: {
    name: 'Saint Martin',
    subtitle: 'Village engagement',
    type: 'capture',
    objective: { x: 724, y: 430, radius: 110, seconds: 150 },
    forests: [
      { x: 400, y: 208, rx: 255, ry: 130 },
      { x: 970, y: 770, rx: 240, ry: 140 },
      { x: 1310, y: 250, rx: 155, ry: 195 },
    ],
    hills: [
      { x: 530, y: 625, rx: 145, ry: 160 },
      { x: 1050, y: 370, rx: 165, ry: 130 },
    ],
    towns: [{ x: 724, y: 397 }],
    roads: [
      [
        { x: -560, y: 692 },
        { x: 370, y: 478 },
        { x: 680, y: 430 },
        { x: 910, y: 480 },
        { x: 2000, y: 633 },
      ],
      [
        { x: 650, y: -560 },
        { x: 715, y: 330 },
        { x: 680, y: 430 },
        { x: 814, y: 1520 },
      ],
    ],
  },
  bridge: {
    name: 'Danube crossing',
    subtitle: 'Bridge assault',
    type: 'capture',
    objective: { x: 745, y: 485, radius: 95, seconds: 120 },
    forests: [
      { x: 295, y: 155, rx: 220, ry: 110 },
      { x: 1080, y: 205, rx: 260, ry: 130 },
      { x: 1165, y: 810, rx: 230, ry: 125 },
      { x: 355, y: 795, rx: 160, ry: 110 },
    ],
    hills: [
      { x: 1100, y: 580, rx: 185, ry: 130 },
      { x: 305, y: 430, rx: 130, ry: 150 },
    ],
    towns: [
      { x: 915, y: 405 },
      { x: 485, y: 560 },
    ],
    river: true,
    roads: [
      [
        { x: -560, y: 620 },
        { x: 470, y: 520 },
        { x: 710, y: 480 },
        { x: 870, y: 480 },
        { x: 2000, y: 305 },
      ],
    ],
  },
  ridge: {
    name: 'Nordlingen heights',
    subtitle: 'Defensive action',
    type: 'defend',
    objective: { x: 540, y: 480, radius: 130, seconds: 210 },
    forests: [
      { x: 215, y: 180, rx: 220, ry: 105 },
      { x: 1020, y: 155, rx: 250, ry: 115 },
      { x: 1100, y: 760, rx: 245, ry: 170 },
    ],
    hills: [
      { x: 545, y: 480, rx: 195, ry: 245 },
      { x: 800, y: 740, rx: 140, ry: 95 },
    ],
    towns: [{ x: 325, y: 725 }],
    roads: [
      [
        { x: -560, y: 1100 },
        { x: 330, y: 750 },
        { x: 560, y: 500 },
        { x: 1070, y: 425 },
        { x: 2000, y: 530 },
      ],
    ],
  },
};
export const fieldFor = (battle) => BATTLEFIELDS[battle?.scenario || 'village'];
const ellipse = (p, e) => ((p.x - e.x) / e.rx) ** 2 + ((p.y - e.y) / e.ry) ** 2;
export const fieldTerrain = (p, field) =>
  field.forests.some((e) => ellipse(p, e) < 1)
    ? 'woods'
    : field.hills.some((e) => ellipse(p, e) < 1)
      ? 'hill'
      : 'open';
export const elevation = (p, field) =>
  Math.max(0, ...field.hills.map((h) => 1 - ellipse(p, h)));
export const channelX = (y) => 720 + Math.sin((y - 480) / 190) * 35;
export const passable = (p, field) =>
  !field.river ||
  Math.abs(p.x - channelX(p.y)) > 31 ||
  Math.abs(p.y - 480) < 36;
const grids = new Map();
export function battleRoute(from, to, field) {
  if (!field.river) return [{ x: to.x, y: to.y }];
  if (!grids.has(field.name)) {
    const grid = new PF.Grid(60, 40);
    for (let x = 0; x < 60; x++)
      for (let y = 0; y < 40; y++)
        grid.setWalkableAt(
          x,
          y,
          Math.abs(x * 24 + 12 - channelX(y * 24 + 12)) > 48 ||
            Math.abs(y * 24 + 12 - 480) < 19,
        );
    grids.set(field.name, grid);
  }
  const grid = grids.get(field.name).clone();
  const cell = (v, max) => Math.max(0, Math.min(max, Math.floor(v / 24)));
  const sx = cell(from.x, 59),
    sy = cell(from.y, 39),
    ex = cell(to.x, 59),
    ey = cell(to.y, 39);
  if (!grid.isWalkableAt(ex, ey) || !passable(to, field)) return [];
  if (sx === ex && sy === ey) return [{ ...to }];
  grid.setWalkableAt(sx, sy, true);
  const path = PF.Util.compressPath(
    new PF.AStarFinder({
      allowDiagonal: true,
      dontCrossCorners: true,
    }).findPath(sx, sy, ex, ey, grid),
  )
    .slice(1)
    .map(([x, y]) => ({ x: x * 24 + 12, y: y * 24 + 12 }));
  if (path.length) path.push({ ...to });
  return path;
}

export function lineOfSight(a, b, field, shooting = false) {
  const d = Math.hypot(a.x - b.x, a.y - b.y);
  if (d < 65) return true;
  if (
    !shooting &&
    d > (a.kind === 'cavalry' || fieldTerrain(a, field) === 'hill' ? 540 : 410)
  )
    return false;
  if (!shooting && fieldTerrain(b, field) === 'woods' && d > 230) return false;
  const points = PF.Util.interpolate(
    Math.round(a.x / 24),
    Math.round(a.y / 24),
    Math.round(b.x / 24),
    Math.round(b.y / 24),
  );
  const ah = elevation(a, field) + 0.32,
    bh = elevation(b, field) + 0.32;
  let woods = 0;
  for (let i = 1; i < points.length - 1; i++) {
    const p = { x: points[i][0] * 24, y: points[i][1] * 24 };
    if (fieldTerrain(p, field) === 'woods') woods += 24;
    if (
      woods > (shooting ? 150 : 180) ||
      elevation(p, field) > ah + ((bh - ah) * i) / (points.length - 1) + 0.08
    )
      return false;
  }
  return true;
}

export function initializeBattle(battle) {
  battle.scenario ||= 'village';
  battle.playerEdge ||= 'west';
  battle.objective ||= { player: 0, enemy: 0, owner: null };
  battle.visibilityClock ??= 0;
  battle.aiClock ??= 0;
  battle.wagons ||= [
    {
      id: 'supply-player',
      side: 'player',
      x: battle.playerEdge === 'west' ? 145 : 1295,
      y: 565,
      stock: 500,
      health: 100,
      target: null,
      waypoints: [],
    },
    {
      id: 'supply-enemy',
      side: 'enemy',
      x: battle.playerEdge === 'west' ? 1300 : 140,
      y: 485,
      stock: 700,
      health: 100,
      target: null,
      waypoints: [],
    },
  ];
  for (const unit of battle.units) {
    upgradeRegiment(unit);
    unit.officerId ??= null;
    unit.waypoints ||= [];
    unit.orderQueue ||= [];
    unit.running ??= false;
    unit.fallingBack ??= false;
    unit.limbered ??= false;
    unit.limberChange ??= 0;
    unit.visible ??= unit.side === 'player';
    unit.aiRole ||=
      unit.kind === 'cavalry'
        ? 'flank'
        : unit.kind === 'artillery'
          ? 'battery'
          : unit.id.endsWith('-2')
            ? 'reserve'
            : 'line';
  }
  for (const commander of battle.commanders) commander.officerId ??= null;
}
