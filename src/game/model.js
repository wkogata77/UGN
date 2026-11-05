import PF from 'pathfinding';
import { orderFormation } from './formations.js';
import {
  upgradeArmy,
  upgradeRegiment,
  makeOfficer,
  officerReady,
  rankOf,
  RANKS,
  SKILLS,
  PERKS,
  baseSkills,
} from './progression.js';
import {
  fieldFor,
  fieldTerrain,
  battleRoute,
  initializeBattle,
  lineOfSight,
} from './battlefields.js';
import { updateTactics, updateVisibility } from './tactics.js';

export const WORLD = { width: 1440, height: 960, cell: 24 };
export const SPEEDS = [0.5, 1, 2, 4];
export const WEAPONS = {
  musket: {
    name: 'Charleville 1777',
    kind: 'infantry',
    price: 8,
    resale: 5,
    power: 1,
    range: 156,
    lot: 50,
    description: 'Standard service musket',
  },
  improved: {
    name: 'Charleville AN IX',
    kind: 'infantry',
    price: 14,
    resale: 9,
    power: 1.28,
    range: 175,
    lot: 50,
    description: 'Improved infantry musket',
  },
  rifle: {
    name: 'Versailles rifle',
    kind: 'infantry',
    price: 24,
    resale: 15,
    power: 1.55,
    range: 210,
    lot: 50,
    description: 'Accurate, longer-range fire',
  },
  sabre: {
    name: 'Light cavalry sabre',
    kind: 'cavalry',
    price: 18,
    resale: 11,
    power: 1.1,
    range: 40,
    lot: 20,
    description: 'Cavalry armament',
  },
  cannon: {
    name: '6-pounder field gun',
    kind: 'artillery',
    price: 180,
    resale: 110,
    power: 1.5,
    range: 335,
    lot: 1,
    description: 'Long-range field artillery',
  },
  carbine: {
    name: 'Dragoon carbine',
    kind: 'cavalry',
    price: 22,
    resale: 13,
    power: 0.85,
    range: 125,
    lot: 20,
    description: 'Mounted or dismounted fire',
  },
  howitzer: {
    name: '6-inch howitzer',
    kind: 'artillery',
    price: 260,
    resale: 150,
    power: 1.8,
    range: 280,
    lot: 1,
    description: 'Heavy close-support artillery',
  },
};
export const TOWNS = [
  { name: 'Ulm', x: 222, y: 628, major: true },
  { name: 'Gunzburg', x: 395, y: 570 },
  { name: 'Dillingen', x: 596, y: 470 },
  { name: 'Donauworth', x: 900, y: 407, major: true },
  { name: 'Augsburg', x: 815, y: 770, major: true },
  { name: 'Nordlingen', x: 1110, y: 239 },
];
export const FORESTS = {
  campaign: [
    { x: 210, y: 230, rx: 230, ry: 160 },
    { x: 688, y: 188, rx: 235, ry: 112 },
    { x: 1110, y: 730, rx: 270, ry: 155 },
    { x: 145, y: 864, rx: 140, ry: 100 },
    { x: 1260, y: 430, rx: 170, ry: 75 },
  ],
  battle: [
    { x: 400, y: 208, rx: 255, ry: 130 },
    { x: 970, y: 770, rx: 240, ry: 140 },
    { x: 1310, y: 250, rx: 155, ry: 195 },
  ],
};
export const HILLS = [
  { x: 530, y: 625, rx: 145, ry: 160 },
  { x: 1050, y: 370, rx: 165, ry: 130 },
];
export const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
export const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
export const riverY = (x) => 455 + Math.sin(x / 175) * 46 + x * 0.045;
export const inEllipse = (p, a) =>
  ((p.x - a.x) / a.rx) ** 2 + ((p.y - a.y) / a.ry) ** 2 < 1;
export const terrainAt = (p, mode, battle = null) =>
  mode === 'battle' && battle
    ? fieldTerrain(p, fieldFor(battle))
    : FORESTS[mode].some((f) => inEllipse(p, f))
      ? 'woods'
      : mode === 'battle' && HILLS.some((h) => inEllipse(p, h))
        ? 'hill'
        : 'open';
export const countMen = (units) =>
  Math.round(units.reduce((sum, u) => sum + Math.max(0, u.men), 0));
export const weaponCount = (u, men = u.men) =>
  u.kind === 'artillery' ? Math.ceil(men / 30) : Math.ceil(men);

const grid = new PF.Grid(WORLD.width / WORLD.cell, WORLD.height / WORLD.cell);
for (let x = 0; x < grid.width; x++) {
  for (let y = 0; y < grid.height; y++) {
    const px = x * 24 + 12,
      py = y * 24 + 12;
    if (
      Math.abs(py - riverY(px)) < 26 &&
      Math.abs(px - 395) > 42 &&
      Math.abs(px - 900) > 42
    )
      grid.setWalkableAt(x, y, false);
  }
}
const finder = new PF.AStarFinder({
  allowDiagonal: true,
  dontCrossCorners: true,
});
export function route(from, to) {
  const start = [
    clamp(Math.floor(from.x / 24), 0, 59),
    clamp(Math.floor(from.y / 24), 0, 39),
  ];
  const end = [
    clamp(Math.floor(to.x / 24), 0, 59),
    clamp(Math.floor(to.y / 24), 0, 39),
  ];
  if (!grid.isWalkableAt(...end)) return [];
  const local = grid.clone();
  local.setWalkableAt(...start, true);
  const points = finder.findPath(...start, ...end, local);
  return PF.Util.compressPath(points)
    .slice(1)
    .map(([x, y]) => ({ x: x * 24 + 12, y: y * 24 + 12 }));
}

const regiment = (id, name, kind, men, weapon, commander) => ({
  id,
  name,
  kind,
  men,
  maxMen: men,
  weapon,
  commander,
  experience: 0,
  morale: 100,
  corpsId: id === 'u5' ? 'c2' : 'c1',
});

const initialCommand = () => ({
  general: {
    id: 'general',
    name: 'Napoleon Bonaparte',
    rank: 'Commander-in-chief',
  },
  corps: [
    {
      id: 'c1',
      name: 'I Corps',
      commanderId: 'commander-c1',
      commander: 'Gen. Auguste Morel',
      specialty: 'Drill',
      color: '#96b1bd',
    },
    {
      id: 'c2',
      name: 'II Corps',
      commanderId: 'commander-c2',
      commander: 'Gen. Henri Valette',
      specialty: 'Resolve',
      color: '#c6a887',
    },
  ],
  selectedCommander: null,
});

function fieldCommanders(state, units) {
  return [
    {
      id: state.general.id,
      name: state.general.name,
      corpsId: null,
      specialty: 'Army command',
      radius: 220,
      x: 125,
      y: 480,
    },
    ...state.corps.map((corps) => {
      const own = units.filter(
        (u) => u.side === 'player' && u.corpsId === corps.id,
      );
      return {
        id: corps.commanderId,
        name: corps.commander,
        corpsId: corps.id,
        specialty: corps.specialty,
        officerId: corps.officerId,
        unavailable: !officerReady(
          state.officers?.find((o) => o.id === corps.officerId),
          state.hours,
        ),
        radius: 175,
        x: 190,
        y: own.length ? own.reduce((sum, u) => sum + u.y, 0) / own.length : 760,
      };
    }),
  ].map((c) => ({
    ...c,
    target: null,
    following: true,
    cooldown: 0,
    shaken: 0,
    rallyFlash: 0,
    facing: 0,
  }));
}

function upgradeSave(saved) {
  const needsVisibility = saved.version < 3;
  if (saved.version === 1) {
    Object.assign(saved, initialCommand(), { version: 2 });
    saved.units.forEach((unit, i) => {
      unit.corpsId = i < 4 ? 'c1' : 'c2';
    });
    if (saved.battle) {
      for (const unit of saved.battle.units)
        Object.assign(unit, {
          corpsId: saved.units.find((u) => u.id === unit.id)?.corpsId || null,
          formationChange: null,
          queuedFormation: null,
          holdFire: false,
          kills: 0,
        });
      saved.battle.commanders = fieldCommanders(saved, saved.battle.units);
    }
  }
  saved.inventory.carbine ??= 0;
  saved.inventory.howitzer ??= 0;
  saved.market.carbine ??= 800;
  saved.market.howitzer ??= 6;
  upgradeArmy(saved);
  if (saved.battle) {
    initializeBattle(saved.battle);
    if (needsVisibility) updateVisibility(saved.battle);
  }
  return saved;
}
export function freshState() {
  return upgradeArmy({
    version: 2,
    ...initialCommand(),
    mode: 'campaign',
    paused: true,
    speed: 1,
    hours: 6,
    cash: 6800,
    victories: 0,
    army: { x: 280, y: 727, path: [], name: 'Army of the Danube' },
    units: [
      regiment(
        'u1',
        '1st Line Regiment',
        'infantry',
        800,
        'musket',
        'Col. Moreau',
      ),
      regiment(
        'u2',
        '2nd Line Regiment',
        'infantry',
        700,
        'musket',
        'Col. Laurent',
      ),
      regiment(
        'u3',
        '9th Light Infantry',
        'infantry',
        600,
        'musket',
        'Col. Girard',
      ),
      regiment('u4', '4th Hussars', 'cavalry', 240, 'sabre', 'Col. Fournier'),
      regiment(
        'u5',
        '1st Foot Artillery',
        'artillery',
        120,
        'cannon',
        'Cpt. Aubert',
      ),
    ],
    inventory: {
      musket: 400,
      improved: 0,
      rifle: 0,
      sabre: 20,
      cannon: 1,
      carbine: 0,
      howitzer: 0,
    },
    market: {
      musket: 2400,
      improved: 1800,
      rifle: 1000,
      sabre: 500,
      cannon: 12,
      carbine: 800,
      howitzer: 6,
    },
    enemies: [
      {
        id: 'e1',
        name: 'Kienmayer',
        title: 'Advance guard',
        x: 610,
        y: 690,
        strength: 1740,
        reward: 4800,
        path: [],
        home: { x: 660, y: 690 },
        defeated: false,
      },
      {
        id: 'e2',
        name: 'Werneck',
        title: 'Austrian division',
        x: 1070,
        y: 260,
        strength: 2420,
        reward: 6600,
        path: [],
        home: { x: 1070, y: 260 },
        defeated: false,
      },
      {
        id: 'e3',
        name: 'Mack',
        title: 'Main force',
        x: 1230,
        y: 625,
        strength: 3000,
        reward: 8800,
        path: [],
        home: { x: 1230, y: 625 },
        defeated: false,
      },
    ],
    selected: ['u1'],
    battle: null,
    report: null,
    nextId: 6,
    enemyClock: 0,
    immunity: 0,
    log: [
      { text: 'Army assembled south of Ulm.', hours: 6 },
      { text: 'Austrian advance guard sighted near Gunzburg.', hours: 6 },
    ],
  });
}

function validSave(s) {
  if (
    !s ||
    ![1, 2, 3].includes(s.version) ||
    !['campaign', 'battle'].includes(s.mode)
  )
    return false;
  if (
    !Number.isFinite(s.cash) ||
    s.cash < 0 ||
    !Number.isFinite(s.hours) ||
    !SPEEDS.includes(s.speed)
  )
    return false;
  if (
    !Array.isArray(s.units) ||
    !s.units.length ||
    s.units.length > 8 ||
    !Array.isArray(s.enemies) ||
    s.enemies.length !== 3
  )
    return false;
  if (
    !s.army ||
    !Number.isFinite(s.army.x) ||
    !Number.isFinite(s.army.y) ||
    !Array.isArray(s.army.path)
  )
    return false;
  if (
    !s.units.every(
      (u) =>
        WEAPONS[u.weapon]?.kind === u.kind &&
        Number.isFinite(u.men) &&
        u.men >= 0 &&
        u.men <= u.maxMen,
    )
  )
    return false;
  if (
    !Object.keys(WEAPONS).every(
      (k) =>
        (s.version < 3 && ['carbine', 'howitzer'].includes(k)) ||
        (Number.isInteger(s.inventory?.[k]) &&
          s.inventory[k] >= 0 &&
          Number.isInteger(s.market?.[k]) &&
          s.market[k] >= 0),
    )
  )
    return false;
  if (
    s.version >= 2 &&
    (!s.general?.id ||
      !Array.isArray(s.corps) ||
      s.corps.length !== 2 ||
      new Set(s.corps.map((c) => c.id)).size !== 2 ||
      !s.units.every((u) => s.corps.some((c) => c.id === u.corpsId)) ||
      s.corps.some(
        (c) => s.units.filter((u) => u.corpsId === c.id).length > 4,
      ) ||
      (s.mode === 'battle' && !Array.isArray(s.battle?.commanders)))
  )
    return false;
  if (
    s.version === 3 &&
    (!Array.isArray(s.officers) ||
      !s.units.every(
        (u) =>
          u.skills &&
          Object.keys(SKILLS).every(
            (key) =>
              Number.isFinite(u.skills[key]) &&
              u.skills[key] >= 0 &&
              u.skills[key] <= 100,
          ) &&
          Array.isArray(u.history) &&
          Number.isFinite(u.ammo) &&
          u.ammo >= 0 &&
          u.ammo <= 100 &&
          Number.isFinite(u.condition) &&
          u.condition >= 0 &&
          u.condition <= 100,
      ) ||
      !s.officers.length ||
      !s.officers.every(
        (o) =>
          typeof o.name === 'string' &&
          Number.isFinite(o.xp) &&
          o.xp >= 0 &&
          Number.isFinite(o.woundedUntil),
      ) ||
      !Number.isFinite(s.supply) ||
      s.supply < 0 ||
      s.supply > 500 ||
      (s.mode === 'battle' &&
        !['village', 'bridge', 'ridge'].includes(s.battle?.scenario)))
  )
    return false;
  return (
    Array.isArray(s.log) &&
    Array.isArray(s.selected) &&
    (s.mode !== 'battle' ||
      (s.battle &&
        Array.isArray(s.battle.units) &&
        Array.isArray(s.battle.enemyIds)))
  );
}

export class Campaign {
  constructor(storage = null) {
    this.storage = storage;
    this.listeners = new Set();
    this.uiClock = 0;
    this.saveClock = 0;
    this.state = freshState();
    try {
      const saved = JSON.parse(
        storage?.getItem('field-command-save') || 'null',
      );
      if (validSave(saved))
        this.state = { ...upgradeSave(saved), paused: true };
    } catch {
      /* An unavailable or damaged save must not prevent play. */
    }
  }
  subscribe = (fn) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };
  publish(save = true) {
    if (save) this.save();
    for (const fn of this.listeners) fn();
  }
  save() {
    try {
      if (!this.storage) {
        this.saveFailed = true;
        return;
      }
      this.storage.setItem('field-command-save', JSON.stringify(this.state));
      this.saveFailed = false;
    } catch {
      this.saveFailed = true;
    }
  }
  log(text) {
    this.state.log.unshift({ text, hours: this.state.hours });
    this.state.log = this.state.log.slice(0, 20);
  }
  pause() {
    this.state.paused = !this.state.paused;
    if (!this.state.paused && this.state.orderMode === 'deploy')
      this.state.orderMode = 'move';
    this.publish();
  }
  speed(value) {
    if (SPEEDS.includes(value)) {
      this.state.speed = value;
      this.publish();
    }
  }
  reset() {
    this.state = freshState();
    this.publish();
  }
  select(ids) {
    this.state.selected = ids;
    this.state.selectedCommander = null;
    this.state.selectedSupply = false;
    this.state.orderMode = 'move';
    this.publish(false);
  }
  selectCorps(id) {
    const units = this.state.battle?.units || this.state.units;
    this.select(
      units
        .filter((u) => u.corpsId === id && u.men > 0 && !u.routed)
        .map((u) => u.id),
    );
  }
  selectCommander(id) {
    if (
      this.state.mode !== 'battle' ||
      !this.state.battle.commanders.some((c) => c.id === id)
    )
      return;
    this.state.selected = [];
    this.state.selectedCommander = id;
    this.state.selectedSupply = false;
    this.state.orderMode = 'move';
    this.publish(false);
  }
  assignCorps(unitId, corpsId) {
    const s = this.state,
      unit = s.units.find((u) => u.id === unitId);
    if (
      s.mode !== 'campaign' ||
      !unit ||
      !s.corps.some((c) => c.id === corpsId) ||
      unit.corpsId === corpsId ||
      s.units.filter((u) => u.corpsId === corpsId).length >= 4
    )
      return false;
    unit.corpsId = corpsId;
    this.log(
      `${unit.name} transferred to ${s.corps.find((c) => c.id === corpsId).name}.`,
    );
    this.publish();
    return true;
  }
  commandSupport(unit) {
    if (unit.side !== 'player' || !this.state.battle) return [];
    return this.state.battle.commanders.filter(
      (c) =>
        !c.shaken &&
        !c.unavailable &&
        (!c.corpsId || c.corpsId === unit.corpsId) &&
        distance(c, unit) <= c.radius,
    );
  }
  rally(id = this.state.selectedCommander) {
    const s = this.state,
      c = s.battle?.commanders.find((c) => c.id === id);
    if (
      s.mode !== 'battle' ||
      !c ||
      c.cooldown > 0 ||
      c.shaken ||
      c.unavailable
    )
      return false;
    const own = s.battle.units.filter(
      (u) =>
        u.side === 'player' &&
        u.men > 0 &&
        (!c.corpsId || c.corpsId === u.corpsId) &&
        distance(c, u) <= c.radius &&
        u.morale < 100,
    );
    if (!own.length) return false;
    for (const u of own) {
      u.morale = Math.min(100, u.morale + 18);
      if (
        u.routed &&
        u.men > u.startMen * 0.23 &&
        (!this.nearestEnemy(u) || distance(u, this.nearestEnemy(u)) > 90)
      )
        u.routed = false;
    }
    c.cooldown = 45;
    c.rallyFlash = 2;
    this.log(`${c.name} rallied ${own.length} regiments.`);
    this.publish();
    return true;
  }
  followCommand() {
    const c = this.state.battle?.commanders.find(
      (c) => c.id === this.state.selectedCommander,
    );
    if (!c) return;
    c.following = true;
    c.target = null;
    this.publish();
  }
  holdFire() {
    const selected = this.selectedUnits(),
      hold = selected.some((u) => !u.holdFire);
    for (const u of selected) u.holdFire = hold;
    this.publish();
  }
  hireOfficer(id) {
    const s = this.state,
      officer = s.officers.find((o) => o.id === id);
    if (
      s.mode !== 'campaign' ||
      !officer ||
      officer.hired ||
      s.cash < officer.cost
    )
      return false;
    s.cash -= officer.cost;
    officer.hired = true;
    this.log(`${RANKS[rankOf(officer)]} ${officer.name} joined headquarters.`);
    this.publish();
    return true;
  }
  assignOfficer(targetId, officerId) {
    const s = this.state,
      target = [...s.corps, ...s.units].find((u) => u.id === targetId),
      officer = s.officers.find((o) => o.id === officerId);
    if (
      s.mode !== 'campaign' ||
      !target ||
      !officerReady(officer, s.hours) ||
      rankOf(officer) <
        (target.kind ? (target.kind === 'artillery' ? 0 : 1) : 3)
    )
      return false;
    for (const unit of [...s.corps, ...s.units])
      if (unit.officerId === officerId) {
        unit.officerId = null;
        unit.commander = 'Vacant command';
      }
    target.officerId = officerId;
    target.commander = `${RANKS[rankOf(officer)]} ${officer.name}`;
    if (!target.kind) target.specialty = officer.specialty;
    this.log(`${officer.name} assigned to ${target.name}.`);
    this.publish();
    return true;
  }
  renameRegiment(id, name) {
    const u = this.state.units.find((u) => u.id === id),
      clean = name.trim().slice(0, 36);
    if (this.state.mode !== 'campaign' || !u || !clean) return false;
    u.name = clean;
    this.publish();
    return true;
  }
  train(id, skill) {
    const s = this.state,
      u = s.units.find((u) => u.id === id);
    if (
      s.mode !== 'campaign' ||
      !u ||
      !SKILLS[skill] ||
      s.cash < 450 ||
      u.trainedUntil > s.hours ||
      u.skills[skill] >= 100
    )
      return false;
    s.cash -= 450;
    u.skills[skill] = Math.min(100, u.skills[skill] + 5);
    u.experience = Math.min(5, u.experience + 0.15);
    u.condition = Math.max(0, u.condition - 12);
    u.trainedUntil = s.hours + 2;
    this.log(`${u.name} completed ${SKILLS[skill].toLowerCase()} drill.`);
    this.publish();
    return true;
  }
  choosePerk(id, perk) {
    const u = this.state.units.find((u) => u.id === id);
    if (
      this.state.mode !== 'campaign' ||
      !u ||
      u.perk ||
      u.experience < 0.75 ||
      !PERKS[perk]
    )
      return false;
    u.perk = perk;
    this.publish();
    return true;
  }
  setUnitSize(id, size) {
    const u = this.state.units.find((u) => u.id === id),
      cap = u?.kind === 'artillery' ? 240 : u?.kind === 'cavalry' ? 400 : 1200;
    if (
      this.state.mode !== 'campaign' ||
      !u ||
      !Number.isInteger(size) ||
      size < Math.max(u.men, u.kind === 'artillery' ? 30 : 100) ||
      size > cap
    )
      return false;
    u.maxMen = size;
    this.publish();
    return true;
  }
  resupplyCost() {
    return Math.ceil(
      500 -
        this.state.supply +
        this.state.units.reduce((sum, u) => sum + (100 - u.ammo) * 2, 0),
    );
  }
  resupply() {
    const s = this.state,
      cost = this.resupplyCost();
    if (s.mode !== 'campaign' || cost <= 0 || s.cash < cost) return false;
    s.cash -= cost;
    s.supply = 500;
    s.units.forEach((u) => {
      u.ammo = 100;
    });
    this.log('Ammunition and supply train replenished.');
    this.publish();
    return true;
  }
  scout() {
    const s = this.state;
    if (s.mode !== 'campaign' || s.recon.cooldown > 0 || s.cash < 100)
      return false;
    s.cash -= 100;
    s.recon = { remaining: 45, cooldown: 90 };
    this.log('Cavalry patrols dispatched.');
    this.publish();
    return true;
  }
  enemyVisible(enemy) {
    return (
      distance(this.state.army, enemy) <=
      (this.state.recon.remaining > 0 ? 760 : 380)
    );
  }
  selectSupply() {
    if (this.state.mode !== 'battle') return;
    this.state.selected = [];
    this.state.selectedCommander = null;
    this.state.selectedSupply = true;
    this.state.orderMode = 'move';
    this.publish(false);
  }
  setOrderMode(mode) {
    if (!['move', 'frontline', 'deploy'].includes(mode)) return;
    this.state.orderMode = mode;
    this.publish(false);
  }
  pathUnit(unit, point, facing = null) {
    const path = battleRoute(
      unit,
      { x: clamp(point.x, 45, 1395), y: clamp(point.y, 45, 915) },
      fieldFor(this.state.battle),
    );
    if (!path.length) return false;
    unit.target = path.shift();
    unit.waypoints = path;
    unit.goal = { ...point };
    unit.desiredFacing = facing;
    return true;
  }
  frontline(a, b) {
    const units = this.selectedUnits();
    if (!units.length) return;
    const facing = Math.atan2(b.y - a.y, b.x - a.x) - Math.PI / 2;
    units.forEach((u, i) => {
      const t = units.length === 1 ? 0.5 : i / (units.length - 1);
      u.attackId = null;
      u.orderQueue = [];
      this.pathUnit(
        u,
        { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t },
        facing,
      );
    });
    this.state.orderMode = 'move';
    this.publish();
  }
  deploy(point) {
    const b = this.state.battle;
    if (!b || b.time > 0 || !this.state.paused) return false;
    const east = b.playerEdge === 'east';
    if (east ? point.x < 1050 : point.x > 390) return false;
    const units = this.selectedUnits();
    units.forEach((u, i) => {
      u.x = clamp(point.x, east ? 1060 : 65, east ? 1375 : 380);
      u.y = clamp(point.y + (i - (units.length - 1) / 2) * 90, 90, 870);
      u.target = null;
      u.waypoints = [];
      u.attackId = null;
      u.orderQueue = [];
      u.charging = false;
      u.fallingBack = false;
    });
    this.publish();
    return true;
  }
  run() {
    const units = this.selectedUnits(),
      running = units.some((u) => !u.running);
    units.forEach((u) => {
      u.running = running;
    });
    this.publish();
  }
  fallBack() {
    for (const u of this.selectedUnits()) {
      const enemy = this.nearestEnemy(u),
        facing = enemy ? Math.atan2(enemy.y - u.y, enemy.x - u.x) : u.facing;
      u.attackId = null;
      u.charging = false;
      u.fallingBack = true;
      u.orderQueue = [];
      this.pathUnit(
        u,
        { x: u.x - Math.cos(facing) * 100, y: u.y - Math.sin(facing) * 100 },
        facing,
      );
    }
    this.publish();
  }
  limber() {
    for (const u of this.selectedUnits())
      if (u.kind === 'artillery' && !u.limberChange) {
        u.limberChange = 5;
        u.nextLimber = !u.limbered;
      }
    this.publish();
  }
  dismount() {
    for (const u of this.selectedUnits())
      if (u.kind === 'cavalry' && u.weapon === 'carbine') {
        u.dismounted = !u.dismounted;
        u.charging = false;
        u.condition = Math.max(0, u.condition - 3);
      }
    this.publish();
  }
  detachSkirmishers() {
    const b = this.state.battle;
    if (!b) return;
    for (const u of this.selectedUnits()) {
      if (u.parentId) {
        const parent = b.units.find((p) => p.id === u.parentId);
        if (!parent || parent.routed || distance(parent, u) > 90) continue;
        parent.ammo =
          (parent.ammo * parent.men + u.ammo * u.men) / (parent.men + u.men);
        parent.men += u.men;
        parent.kills += u.kills;
        b.units = b.units.filter((p) => p.id !== u.id);
        this.state.selected = [parent.id];
      } else if (
        u.kind === 'infantry' &&
        u.men >= 300 &&
        !u.formationChange &&
        !b.units.some((p) => p.parentId === u.id)
      ) {
        const men = Math.floor(u.men * 0.2);
        u.men -= men;
        const detachment = {
          ...structuredClone(u),
          id: `${u.id}-skirmish`,
          parentId: u.id,
          name: `${u.name.split(' ').slice(0, 2).join(' ')} skirmishers`,
          men,
          startMen: men,
          maxMen: men,
          x: u.x + (b.playerEdge === 'east' ? -40 : 40),
          y: u.y + 25,
          formation: 'line',
          role: 'skirmishers',
          kills: 0,
          target: null,
          attackId: null,
          goal: null,
          waypoints: [],
          orderQueue: [],
        };
        b.units.push(detachment);
        this.state.selected = [detachment.id];
      }
    }
    this.publish();
  }
  setSound(enabled, volume = this.state.settings.volume) {
    this.state.settings.sound = !!enabled;
    this.state.settings.volume = clamp(
      Number.isFinite(volume) ? volume : 0.3,
      0,
      1,
    );
    this.publish();
  }
  moveArmy(point) {
    if (this.state.mode !== 'campaign' || this.state.report) return;
    const path = route(this.state.army, point);
    if (!path.length) return;
    this.state.army.path = path;
    this.log('Marching orders issued.');
    this.publish();
  }
  halt() {
    if (this.state.mode === 'campaign') this.state.army.path = [];
    else if (this.state.selectedSupply) {
      const wagon = this.state.battle.wagons.find((w) => w.side === 'player');
      wagon.target = null;
      wagon.waypoints = [];
    } else if (this.state.selectedCommander) {
      const c = this.state.battle.commanders.find(
        (c) => c.id === this.state.selectedCommander,
      );
      if (c) {
        c.target = null;
        c.following = false;
        c.waypoints = [];
      }
    } else
      for (const u of this.selectedUnits()) {
        u.target = null;
        u.attackId = null;
        u.charging = false;
        u.waypoints = [];
        u.orderQueue = [];
        u.fallingBack = false;
      }
    this.publish();
  }
  selectedUnits() {
    return (this.state.battle?.units || []).filter(
      (u) =>
        u.side === 'player' &&
        u.men > 0 &&
        this.state.selected.includes(u.id) &&
        !u.routed &&
        u.arrival <= this.state.battle.time,
    );
  }
  moveUnits(point, attackId = null, queue = false, facing = null) {
    if (this.state.selectedSupply) {
      const wagon = this.state.battle?.wagons.find((w) => w.side === 'player');
      if (wagon?.health > 0) {
        this.pathUnit(wagon, point);
        this.publish();
      }
      return;
    }
    if (this.state.selectedCommander) {
      const c = this.state.battle?.commanders.find(
        (c) => c.id === this.state.selectedCommander,
      );
      if (c) {
        this.pathUnit(c, point);
        c.following = false;
        this.publish();
      }
      return;
    }
    const units = this.selectedUnits();
    units.forEach((u, i) => {
      const destination = {
        x: clamp(point.x, 45, 1395),
        y: clamp(point.y + (i - (units.length - 1) / 2) * 72, 45, 915),
      };
      if (queue && u.target) {
        u.orderQueue.push({ point: destination, facing });
        return;
      }
      this.pathUnit(u, destination, facing);
      u.orderQueue = [];
      u.attackId = attackId;
      u.charging = false;
      u.fallingBack = false;
    });
    this.publish();
  }
  formation(value) {
    for (const u of this.selectedUnits()) orderFormation(u, value);
    this.publish();
  }
  charge() {
    for (const u of this.selectedUnits()) {
      if (
        u.kind === 'artillery' ||
        u.formationChange ||
        u.condition < 25 ||
        u.dismounted
      )
        continue;
      const enemy = this.nearestEnemy(u);
      if (enemy) {
        u.attackId = enemy.id;
        u.charging = true;
        u.holdFire = false;
        u.target = { x: enemy.x, y: enemy.y };
      }
    }
    this.publish();
  }
  trade(key, direction, quantity = WEAPONS[key]?.lot) {
    const s = this.state,
      w = WEAPONS[key];
    if (
      s.mode !== 'campaign' ||
      !w ||
      !['buy', 'sell'].includes(direction) ||
      !Number.isSafeInteger(quantity) ||
      quantity < 1
    )
      return false;
    const amount =
      direction === 'buy'
        ? Math.min(quantity, s.market[key])
        : Math.min(quantity, s.inventory[key]);
    if (!amount || (direction === 'buy' && s.cash < amount * w.price))
      return false;
    if (direction === 'buy') {
      s.cash -= amount * w.price;
      s.inventory[key] += amount;
      s.market[key] -= amount;
    } else {
      s.cash += amount * w.resale;
      s.inventory[key] -= amount;
      s.market[key] += amount;
    }
    this.publish();
    return true;
  }
  equip(id, key) {
    const s = this.state,
      u = s.units.find((u) => u.id === id),
      w = WEAPONS[key];
    if (
      s.mode !== 'campaign' ||
      !u ||
      !w ||
      w.kind !== u.kind ||
      key === u.weapon ||
      s.inventory[key] < weaponCount(u)
    )
      return false;
    s.inventory[u.weapon] += weaponCount(u);
    s.inventory[key] -= weaponCount(u);
    u.weapon = key;
    this.log(`${u.name} issued ${w.name}.`);
    this.publish();
    return true;
  }
  replenish(id, quality = 'recruits', requested = Infinity) {
    const s = this.state,
      u = s.units.find((u) => u.id === id);
    if (
      s.mode !== 'campaign' ||
      !u ||
      !['recruits', 'veterans'].includes(quality) ||
      requested <= 0 ||
      (requested !== Infinity && !Number.isSafeInteger(requested))
    )
      return false;
    const price = quality === 'veterans' ? 6 : 2;
    const available =
      u.kind === 'artillery'
        ? s.inventory[u.weapon] * 30 + weaponCount(u) * 30 - u.men
        : s.inventory[u.weapon];
    const count = Math.min(
      requested,
      u.maxMen - u.men,
      available,
      Math.floor(s.cash / price),
    );
    if (count <= 0) return false;
    const old = u.men;
    s.inventory[u.weapon] -= weaponCount(u, old + count) - weaponCount(u, old);
    s.cash -= count * price;
    u.men += count;
    if (quality === 'recruits') {
      u.experience *= old / u.men;
      for (const skill of Object.keys(SKILLS))
        u.skills[skill] =
          (u.skills[skill] * old + baseSkills(u.kind)[skill] * count) / u.men;
    }
    this.log(`${count} replacements joined ${u.name}.`);
    this.publish();
    return true;
  }
  recruit(kind = 'infantry') {
    const s = this.state;
    const specification = {
      infantry: {
        men: 400,
        cost: 1200,
        weapon: 'musket',
        name: 'Line Regiment',
      },
      cavalry: { men: 160, cost: 1600, weapon: 'sabre', name: 'Hussars' },
      artillery: {
        men: 90,
        cost: 1500,
        weapon: 'cannon',
        name: 'Foot Artillery',
      },
    }[kind];
    if (
      !specification ||
      s.mode !== 'campaign' ||
      s.units.length >= 8 ||
      s.cash < specification.cost ||
      s.inventory[specification.weapon] <
        (kind === 'artillery' ? specification.men / 30 : specification.men)
    )
      return false;
    s.cash -= specification.cost;
    s.inventory[specification.weapon] -=
      kind === 'artillery' ? specification.men / 30 : specification.men;
    const id = s.nextId++;
    s.units.push(
      regiment(
        `u${id}`,
        `${id}th ${specification.name}`,
        kind,
        specification.men,
        specification.weapon,
        'Col. Delmas',
      ),
    );
    s.units.at(-1).corpsId = s.corps.find(
      (c) => s.units.slice(0, -1).filter((u) => u.corpsId === c.id).length < 4,
    ).id;
    const unit = s.units.at(-1);
    unit.officerId = `officer-${unit.id}`;
    s.officers.push(
      makeOfficer(unit.officerId, 'Antoine Delmas', ((id + 4) % 15) + 1, 20),
    );
    upgradeRegiment(unit);
    this.log(`${unit.name} has joined the army.`);
    this.publish();
    return true;
  }
  march(entity, delta, speed) {
    let remaining = delta * speed;
    while (entity.path.length && remaining > 0) {
      const dest = entity.path[0],
        d = distance(entity, dest);
      if (d <= remaining) {
        entity.x = dest.x;
        entity.y = dest.y;
        entity.path.shift();
        remaining -= d;
      } else {
        entity.x += ((dest.x - entity.x) / d) * remaining;
        entity.y += ((dest.y - entity.y) / d) * remaining;
        break;
      }
    }
  }
  update(realDelta) {
    const s = this.state;
    if (s.paused || s.report) return;
    const delta = Math.min(realDelta, 0.1) * s.speed;
    if (s.mode === 'campaign') this.updateCampaign(delta);
    else this.updateBattle(delta);
    this.uiClock += realDelta;
    this.saveClock += realDelta;
    if (this.uiClock > 0.15) {
      this.uiClock = 0;
      this.publish(false);
    }
    if (this.saveClock > 4) {
      this.saveClock = 0;
      this.save();
    }
  }
  updateCampaign(dt) {
    const s = this.state;
    s.hours += dt * 0.08;
    s.enemyClock += dt;
    s.immunity = Math.max(0, s.immunity - dt);
    s.recon.remaining = Math.max(0, s.recon.remaining - dt);
    s.recon.cooldown = Math.max(0, s.recon.cooldown - dt);
    const moving = s.army.path.length > 0;
    this.march(
      s.army,
      dt,
      (terrainAt(s.army, 'campaign') === 'woods' ? 14 : 24) *
        (0.65 + s.army.condition * 0.0035),
    );
    s.army.condition = clamp(
      s.army.condition + dt * (moving ? -0.16 : 0.65),
      20,
      100,
    );
    for (const unit of s.units)
      unit.condition = clamp(
        unit.condition + dt * (moving ? -0.1 : 0.6),
        20,
        100,
      );
    for (const enemy of s.enemies.filter((e) => !e.defeated)) {
      if (this.enemyVisible(enemy))
        enemy.intel = {
          x: enemy.x,
          y: enemy.y,
          at: s.hours,
          strength:
            Math.round(enemy.strength / (s.recon.remaining ? 50 : 200)) *
            (s.recon.remaining ? 50 : 200),
        };
      if (s.enemyClock > 3) {
        const target =
          distance(enemy, s.army) < 240 && s.immunity === 0
            ? s.army
            : {
                x: enemy.home.x + Math.sin(s.hours * 0.65) * 65,
                y: enemy.home.y + Math.cos(s.hours * 0.65) * 50,
              };
        enemy.path = route(enemy, target);
      }
      this.march(enemy, dt, 10);
      if (
        !s.immunity &&
        countMen(s.units) > 0 &&
        distance(enemy, s.army) < 48
      ) {
        this.startBattle(enemy.id);
        break;
      }
    }
    if (s.enemyClock > 3) s.enemyClock = 0;
  }
  startBattle(enemyId) {
    const s = this.state,
      main = s.enemies.find((e) => e.id === enemyId && !e.defeated);
    if (s.mode !== 'campaign' || !main || s.report || countMen(s.units) === 0)
      return false;
    const involved = [
      main,
      ...s.enemies.filter(
        (e) => e.id !== main.id && !e.defeated && distance(e, main) < 210,
      ),
    ];
    const playerEdge = s.army.x > main.x ? 'east' : 'west';
    const scenario =
      Math.abs(main.y - riverY(main.x)) < 90
        ? 'bridge'
        : main.id === 'e2'
          ? 'ridge'
          : 'village';
    const units = s.units
      .filter((u) => u.men > 0)
      .map((u, i, all) => ({
        ...u,
        side: 'player',
        startMen: u.men,
        x: playerEdge === 'west' ? (scenario === 'ridge' ? 430 : 280) : 1160,
        y:
          480 +
          (i - (all.length - 1) / 2) *
            Math.min(140, 750 / Math.max(1, all.length - 1)),
        target: null,
        attackId: null,
        formation: 'line',
        formationChange: null,
        queuedFormation: null,
        holdFire: false,
        kills: 0,
        morale: 100,
        condition: Math.min(u.condition, s.army.condition),
        ammo: u.ammo,
        skills: { ...u.skills },
        reload: i * 0.3,
        flash: 0,
        routed: false,
        arrival: 0,
        charging: false,
        facing: playerEdge === 'west' ? 0 : Math.PI,
      }));
    for (const [index, army] of involved.entries()) {
      const strengths = [0.3, 0.3, 0.23, 0.11, 0.06];
      strengths.forEach((fraction, i) => {
        const kind = i === 3 ? 'cavalry' : i === 4 ? 'artillery' : 'infantry';
        const men = Math.round(army.strength * fraction);
        units.push({
          id: `${army.id}-${i}`,
          name: [
            'Grenadiers',
            'Line Infantry',
            'Fusiliers',
            'Chevaulegers',
            'Field Battery',
          ][i],
          kind,
          weapon:
            kind === 'infantry'
              ? 'musket'
              : kind === 'cavalry'
                ? 'sabre'
                : 'cannon',
          men,
          maxMen: men,
          startMen: men,
          side: 'enemy',
          x: playerEdge === 'west' ? 1100 + index * 85 : 340 - index * 85,
          y: 200 + i * 140,
          target: null,
          attackId: null,
          formation: 'line',
          formationChange: null,
          queuedFormation: null,
          holdFire: false,
          kills: 0,
          experience: index * 0.1,
          skills: baseSkills(kind),
          condition: 100,
          ammo: 100,
          morale: 100,
          reload: 1 + i * 0.35,
          flash: 0,
          routed: false,
          arrival: index ? 35 + index * 12 : 0,
          charging: false,
          facing: playerEdge === 'west' ? Math.PI : 0,
        });
      });
    }
    s.battle = {
      scenario,
      playerEdge,
      enemyIds: involved.map((e) => e.id),
      name: `Battle of ${TOWNS.reduce((a, b) => (distance(main, a) < distance(main, b) ? a : b)).name}`,
      units,
      commanders: fieldCommanders(s, units),
      time: 0,
      startMen: countMen(s.units),
      enemyStartMen: countMen(units.filter((u) => u.side === 'enemy')),
      origin: { x: s.army.x, y: s.army.y },
      reward: involved.reduce((sum, e) => sum + e.reward, 0),
      officerStart: s.officers.map((o) => ({
        id: o.id,
        rank: rankOf(o),
        woundedUntil: o.woundedUntil,
        dead: o.dead,
      })),
    };
    initializeBattle(s.battle);
    s.battle.wagons[0].stock = s.supply;
    if (playerEdge === 'east')
      for (const commander of s.battle.commanders)
        commander.x = 1440 - commander.x;
    updateVisibility(s.battle);
    s.mode = 'battle';
    s.selectedCommander = null;
    s.selectedSupply = false;
    s.orderMode = 'move';
    s.paused = true;
    s.army.path = [];
    s.selected = units.filter((u) => u.side === 'player').map((u) => u.id);
    this.log(`${main.name}'s army engaged. Deploy your regiments.`);
    this.publish();
    return true;
  }
  nearestEnemy(unit) {
    const b = this.state.battle;
    if (!b) return null;
    return (
      b.units
        .filter(
          (u) =>
            u.side !== unit.side &&
            !u.routed &&
            u.men > 0 &&
            u.arrival <= b.time &&
            (unit.side === 'enemy'
              ? lineOfSight(unit, u, fieldFor(b))
              : u.visible),
        )
        .sort((a, b) => distance(unit, a) - distance(unit, b))[0] || null
    );
  }
  updateCommanders(dt) {
    const b = this.state.battle;
    for (const c of b.commanders) {
      c.unavailable =
        !!c.corpsId &&
        !officerReady(
          this.state.officers.find((o) => o.id === c.officerId),
          this.state.hours,
        );
      c.cooldown = Math.max(0, c.cooldown - dt);
      c.shaken = Math.max(0, c.shaken - dt);
      c.rallyFlash = Math.max(0, c.rallyFlash - dt);
      const threat = b.units.find(
        (u) =>
          u.side === 'enemy' &&
          !u.routed &&
          u.men > 0 &&
          u.arrival <= b.time &&
          distance(c, u) < 85,
      );
      if (threat) {
        c.shaken = 7;
        c.x = clamp(
          c.x + (b.playerEdge === 'east' ? 1 : -1) * dt * 46,
          30,
          1410,
        );
        c.pressure = (c.pressure || 0) + dt;
        if (c.officerId && c.pressure > 15) {
          const officer = this.state.officers.find((o) => o.id === c.officerId);
          if (officer && officer.woundedUntil <= this.state.hours) {
            officer.woundedUntil = this.state.hours + 8;
            officer.wounds++;
            this.log(`${officer.name} wounded under fire.`);
          }
        }
        continue;
      }
      if (c.following) {
        const own = b.units.filter(
          (u) =>
            u.side === 'player' &&
            !u.routed &&
            u.men > 0 &&
            (!c.corpsId || c.corpsId === u.corpsId),
        );
        const destination = own.length
          ? {
              x: Math.max(
                55,
                own.reduce((v, u) => v + u.x, 0) / own.length -
                  (c.corpsId ? 90 : 150) * (b.playerEdge === 'east' ? -1 : 1),
              ),
              y: own.reduce((v, u) => v + u.y, 0) / own.length,
            }
          : null;
        if (
          destination &&
          (!c.goal ||
            distance(c.goal, destination) > 30 ||
            (!c.target && distance(c, destination) > 25))
        )
          this.pathUnit(c, destination);
        if (!destination) {
          c.target = null;
          c.waypoints = [];
        }
      }
      if (c.target) {
        const d = distance(c, c.target);
        if (d > 1) {
          let step = Math.min(d, dt * 40);
          const bearing = Math.atan2(c.target.y - c.y, c.target.x - c.x);
          if (this.movementSpeedScale) {
            this.turnUnit(c, bearing, dt);
            step *= this.movementSpeedScale(c, bearing);
          } else c.facing = bearing;
          c.x += ((c.target.x - c.x) / d) * step;
          c.y += ((c.target.y - c.y) / d) * step;
        } else c.target = c.waypoints?.shift() || null;
      }
    }
  }
  turnUnit(unit, angle, dt) {
    const change = Math.atan2(
      Math.sin(angle - unit.facing),
      Math.cos(angle - unit.facing),
    );
    const rate =
      (unit.kind === 'artillery'
        ? 0.85
        : unit.kind === 'cavalry'
          ? 2.4
          : 1.65) * dt;
    unit.facing += clamp(change, -rate, rate);
  }
  updateBattle(dt) {
    return updateTactics(this, dt, WEAPONS);
  }
  withdraw() {
    if (this.state.mode === 'battle') this.finishBattle(false, true);
  }
  finishBattle(won, retreat = false) {
    const s = this.state,
      b = s.battle;
    if (!b || s.mode !== 'battle') return false;
    for (const unit of s.units) {
      const result = b.units.find((u) => u.id === unit.id);
      if (!result) continue;
      const detachments = b.units.filter((u) => u.parentId === unit.id);
      const survivors =
        result.men + detachments.reduce((sum, u) => sum + u.men, 0);
      const killed =
        result.kills + detachments.reduce((sum, u) => sum + u.kills, 0);
      const lost = Math.max(0, unit.men - survivors);
      unit.men = Math.max(0, Math.floor(survivors));
      unit.morale = 100;
      unit.condition = result.condition;
      unit.ammo = survivors
        ? (result.ammo * result.men +
            detachments.reduce((sum, u) => sum + u.ammo * u.men, 0)) /
          survivors
        : 0;
      unit.skills = { ...result.skills };
      unit.history.unshift({
        battle: b.name,
        won,
        retreat,
        losses: Math.round(lost),
        kills: Math.floor(killed),
        hours: s.hours,
      });
      unit.history = unit.history.slice(0, 12);
      const officer = s.officers.find((o) => o.id === unit.officerId);
      if (officerReady(officer, s.hours)) {
        officer.xp += Math.min(45, b.time / 25 + (won ? 15 : 5));
        if (survivors < result.startMen * 0.12) {
          officer.dead = true;
          this.log(`${officer.name} killed in action.`);
        } else if (
          lost > result.startMen * 0.35 &&
          officer.woundedUntil <= s.hours
        ) {
          officer.woundedUntil = s.hours + 8;
          officer.wounds++;
          this.log(
            `${officer.name} wounded; recovering for eight campaign hours.`,
          );
        }
        unit.commander = `${RANKS[rankOf(officer)]} ${officer.name}`;
      }
      unit.experience = Math.min(5, unit.experience + (won ? 0.8 : 0.25));
    }
    for (const corps of s.corps) {
      const officer = s.officers.find((o) => o.id === corps.officerId);
      if (officerReady(officer, s.hours)) {
        officer.xp += Math.min(35, b.time / 40 + (won ? 12 : 4));
        corps.commander = `${RANKS[rankOf(officer)]} ${officer.name}`;
      }
    }
    s.supply = Math.max(0, b.wagons.find((w) => w.side === 'player').stock);
    s.army.condition = Math.max(
      20,
      s.units.reduce((sum, u) => sum + u.condition, 0) / s.units.length,
    );
    const enemies = s.enemies.filter((e) => b.enemyIds.includes(e.id));
    let loot = 0;
    if (won) {
      s.cash += b.reward;
      s.victories += enemies.length;
      loot = Math.round(b.enemyStartMen * 0.12);
      s.inventory.musket += loot;
      enemies.forEach((e) => {
        e.defeated = true;
        e.path = [];
      });
      this.log(`Victory. ${b.reward.toLocaleString()} francs awarded.`);
    } else {
      enemies.forEach((e) => {
        e.strength = Math.max(
          250,
          countMen(b.units.filter((u) => u.id.startsWith(`${e.id}-`))),
        );
        e.path = [];
      });
      s.army.x = 280;
      s.army.y = 727;
      s.immunity = 18;
      this.log(
        retreat
          ? 'Army withdrawn to the rally point at Ulm.'
          : 'Defeated. Survivors regrouped at Ulm.',
      );
    }
    s.report = {
      won,
      retreat,
      name: b.name,
      casualties: b.startMen - countMen(s.units),
      enemyCasualties:
        b.enemyStartMen - countMen(b.units.filter((u) => u.side === 'enemy')),
      reward: won ? b.reward : 0,
      loot,
      regiments: s.units
        .filter((u) => b.units.some((field) => field.id === u.id))
        .map((u) => ({
          id: u.id,
          name: u.name,
          men: u.men,
          losses: u.history[0].losses,
          kills: u.history[0].kills,
          experience: u.experience,
        })),
      officers: (b.officerStart || []).flatMap((previous) => {
        const officer = s.officers.find((o) => o.id === previous.id);
        if (!officer) return [];
        const events = [];
        if (officer.dead && !previous.dead) events.push('Killed in action');
        else {
          if (officer.woundedUntil > previous.woundedUntil)
            events.push('Wounded');
          if (rankOf(officer) > previous.rank)
            events.push(`Promoted to ${RANKS[rankOf(officer)]}`);
        }
        return events.map((status) => ({ name: officer.name, status }));
      }),
      complete: s.enemies.every((e) => e.defeated),
    };
    s.battle = null;
    s.selectedCommander = null;
    s.selectedSupply = false;
    s.mode = 'campaign';
    s.paused = true;
    s.selected = [s.units[0].id];
    this.publish();
    return true;
  }
  dismissReport() {
    this.state.report = null;
    this.publish();
  }
}
