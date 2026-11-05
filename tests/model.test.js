import test from 'node:test';
import assert from 'node:assert/strict';
import {
  Campaign,
  freshState,
  route,
  riverY,
  countMen,
} from '../src/game/model.js';

const memoryStorage = () => {
  const values = new Map();
  return {
    getItem: (key) => values.get(key),
    setItem: (key, value) => values.set(key, value),
  };
};
const play = (m, seconds = 600) => {
  m.state.paused = false;
  for (let i = 0; i < seconds * 10 && m.state.mode === 'battle'; i++)
    m.update(0.1);
};

test('pause freezes the simulation and speed scales campaign time', () => {
  const m = new Campaign();
  m.moveArmy({ x: 560, y: 720 });
  const start = { ...m.state.army },
    hours = m.state.hours;
  m.update(0.1);
  assert.equal(m.state.army.x, start.x);
  assert.equal(m.state.hours, hours);
  m.pause();
  m.speed(4);
  m.update(0.1);
  assert.ok(m.state.army.x > start.x);
  assert.ok(Math.abs(m.state.hours - hours - 0.032) < 0.0001);
});

test('half speed halves campaign time and marching distance', () => {
  const normal = new Campaign(),
    slow = new Campaign();
  for (const m of [normal, slow]) {
    m.moveArmy({ x: 560, y: 720 });
    m.pause();
  }
  slow.speed(0.5);
  const start = { ...slow.state.army },
    hours = slow.state.hours;
  normal.update(0.1);
  slow.update(0.1);
  assert.ok(
    Math.abs((slow.state.hours - hours) * 2 - (normal.state.hours - hours)) <
      1e-10,
  );
  const marched = (m) =>
    Math.hypot(m.state.army.x - start.x, m.state.army.y - start.y);
  assert.ok(Math.abs(marched(slow) * 2 - marched(normal)) < 1e-10);
});

test('half speed slows battle time, formation changes and cooldowns while respecting pause', () => {
  const normal = new Campaign(),
    slow = new Campaign();
  slow.speed(0.5);
  for (const m of [normal, slow]) {
    m.startBattle('e1');
    m.select(['u1']);
    m.formation('square');
    m.state.battle.commanders[0].cooldown = 20;
    m.update(0.1);
    assert.equal(m.state.battle.time, 0);
    m.pause();
    for (let i = 0; i < 10; i++) m.update(0.1);
  }
  assert.equal(slow.state.speed, 0.5);
  assert.ok(
    Math.abs(slow.state.battle.time * 2 - normal.state.battle.time) < 1e-10,
  );
  assert.ok(
    Math.abs(
      slow.state.battle.units[0].formationChange.elapsed * 2 -
        normal.state.battle.units[0].formationChange.elapsed,
    ) < 1e-10,
  );
  assert.ok(Math.abs(slow.state.battle.commanders[0].cooldown - 19.5) < 1e-10);
  slow.pause();
  const before = structuredClone(slow.state.battle);
  slow.update(0.1);
  assert.deepEqual(slow.state.battle, before);
});

test('half speed survives save restoration and rejects unsupported speeds', () => {
  const storage = memoryStorage(),
    m = new Campaign(storage);
  m.state.cash = 4321;
  m.startBattle('e1');
  m.speed(0.5);
  for (const speed of [0, -0.5, NaN, 10]) m.speed(speed);
  assert.equal(m.state.speed, 0.5);
  const restored = new Campaign(storage);
  assert.equal(restored.state.speed, 0.5);
  assert.equal(restored.state.mode, 'battle');
  assert.equal(restored.state.cash, 4321);
  assert.equal(restored.state.paused, true);
});

test('campaign pathfinding crosses the river only at bridges', () => {
  const from = { x: 600, y: 720 },
    points = [from, ...route(from, { x: 600, y: 260 })];
  assert.ok(points.length > 2);
  let riverCrossings = 0;
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1],
      b = points[i];
    for (let t = 0; t <= 1; t += 0.005) {
      const x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t;
      if (Math.abs(y - riverY(x)) < 15) {
        riverCrossings++;
        assert.ok(
          Math.abs(x - 395) < 60 || Math.abs(x - 900) < 60,
          `Illegal crossing at ${x}, ${y}`,
        );
      }
    }
  }
  assert.ok(riverCrossings > 0);
});

test('marching into an enemy automatically opens a paused tactical battle', () => {
  const m = new Campaign();
  m.moveArmy(m.state.enemies[0]);
  m.pause();
  for (let i = 0; i < 1000 && m.state.mode === 'campaign'; i++) m.update(0.1);
  assert.equal(m.state.mode, 'battle');
  assert.equal(m.state.paused, true);
  assert.equal(
    countMen(m.state.battle.units.filter((u) => u.side === 'player')),
    countMen(m.state.units),
  );
});

test('trading obeys inventory, dealer stock, and cash limits', () => {
  const m = new Campaign(),
    cash = m.state.cash;
  assert.equal(m.trade('rifle', 'sell'), false);
  assert.equal(m.state.cash, cash);
  assert.equal(m.trade('rifle', 'buy'), true);
  assert.equal(m.state.cash, cash - 1200);
  assert.equal(m.state.inventory.rifle, 50);
  assert.equal(m.state.market.rifle, 950);
  assert.equal(m.trade('rifle', 'sell'), true);
  assert.equal(m.state.inventory.rifle, 0);
  assert.equal(m.state.cash, cash - 450);
  m.state.cash = 0;
  assert.equal(m.trade('rifle', 'buy'), false);
  assert.equal(m.state.inventory.rifle, 0);
  assert.equal(m.trade('musket', 'bogus'), false);
});

test('equipping returns old weapons and requires enough compatible reserve arms', () => {
  const m = new Campaign();
  assert.equal(m.equip('u1', 'rifle'), false);
  m.state.inventory.improved = 800;
  assert.equal(m.equip('u1', 'improved'), true);
  assert.equal(m.state.inventory.improved, 0);
  assert.equal(m.state.inventory.musket, 1200);
  assert.equal(m.state.units[0].weapon, 'improved');
  assert.equal(m.equip('u1', 'sabre'), false);
});

test('replenishment spends money and weapons and dilutes experience', () => {
  const m = new Campaign(),
    unit = m.state.units[0];
  unit.men = 600;
  unit.experience = 2;
  m.state.inventory.musket = 150;
  assert.equal(m.replenish(unit.id), true);
  assert.equal(unit.men, 750);
  assert.equal(m.state.inventory.musket, 0);
  assert.equal(m.state.cash, 6500);
  assert.equal(unit.experience, 1.6);
  assert.equal(m.replenish(unit.id), false);
});

test('artillery replacements consume complete guns without creating negative reserves', () => {
  const m = new Campaign(),
    u = m.state.units[4];
  u.men = 61;
  m.state.inventory.cannon = 0;
  assert.equal(m.replenish(u.id), true);
  assert.equal(u.men, 90);
  assert.equal(m.state.inventory.cannon, 0);
  assert.equal(m.replenish(u.id), false);
  m.state.inventory.cannon = 1;
  assert.equal(m.replenish(u.id), true);
  assert.equal(u.men, 120);
  assert.equal(m.state.inventory.cannon, 0);
});

test('recruitment consumes reserves and respects the army size limit', () => {
  const m = new Campaign();
  assert.equal(m.recruit(), true);
  assert.equal(m.state.units.length, 6);
  assert.equal(m.state.inventory.musket, 0);
  assert.equal(m.recruit(), false);
  m.state.cash = 20000;
  m.state.inventory.musket = 4000;
  m.recruit();
  m.recruit();
  assert.equal(m.state.units.length, 8);
  assert.equal(m.recruit(), false);
});

test('a completed battle persists losses and pays its reward once', () => {
  const m = new Campaign(),
    original = countMen(m.state.units),
    cash = m.state.cash;
  m.startBattle('e1');
  assert.equal(m.trade('musket', 'buy'), false);
  play(m);
  assert.equal(m.state.mode, 'campaign');
  assert.equal(m.state.report.won, true);
  assert.ok(countMen(m.state.units) < original);
  assert.equal(m.state.cash, cash + 4800);
  assert.equal(m.state.enemies[0].defeated, true);
  assert.equal(m.finishBattle(true), false);
  assert.equal(m.state.cash, cash + 4800);
  m.dismissReport();
  assert.equal(m.startBattle('e1'), false);
});

test('nearby armies reinforce the same battle and pending reinforcements prevent an early victory', () => {
  const m = new Campaign();
  m.state.enemies[1].x = m.state.enemies[0].x + 120;
  m.state.enemies[1].y = m.state.enemies[0].y;
  m.startBattle('e1');
  assert.deepEqual(m.state.battle.enemyIds, ['e1', 'e2']);
  assert.ok(
    m.state.battle.units.some((u) => u.side === 'enemy' && u.arrival > 0),
  );
  for (const u of m.state.battle.units.filter(
    (u) => u.side === 'enemy' && u.arrival === 0,
  ))
    u.routed = true;
  m.state.paused = false;
  m.update(0.1);
  assert.equal(m.state.mode, 'battle');
});

test('retreat preserves casualties and does not pay a victory reward', () => {
  const m = new Campaign(),
    cash = m.state.cash;
  m.startBattle('e1');
  m.state.battle.units[0].men -= 123;
  m.withdraw();
  assert.equal(m.state.mode, 'campaign');
  assert.equal(m.state.units[0].men, 677);
  assert.equal(m.state.cash, cash);
  assert.equal(m.state.report.reward, 0);
  assert.equal(m.state.enemies[0].defeated, false);
  assert.deepEqual([m.state.army.x, m.state.army.y], [280, 727]);
});

test('save and reload restore an ongoing battle paused without clearing its losses', () => {
  const storage = memoryStorage(),
    m = new Campaign(storage);
  m.startBattle('e1');
  m.state.paused = false;
  m.state.battle.units[0].men -= 81;
  m.save();
  const loaded = new Campaign(storage);
  assert.equal(loaded.state.mode, 'battle');
  assert.equal(loaded.state.paused, true);
  assert.equal(loaded.state.battle.units[0].men, 719);
});

test('damaged saves and unavailable storage do not stop a new game', () => {
  for (const raw of [
    'broken-json',
    '{"version":1}',
    JSON.stringify({ ...freshState(), cash: -1 }),
  ]) {
    const m = new Campaign({ getItem: () => raw, setItem: () => {} });
    assert.equal(m.state.cash, 6800);
    assert.equal(m.state.mode, 'campaign');
  }
  const m = new Campaign({
    getItem: () => {
      throw Error('blocked');
    },
    setItem: () => {
      throw Error('quota');
    },
  });
  m.pause();
  assert.equal(m.saveFailed, true);
  assert.equal(m.state.paused, false);
});
