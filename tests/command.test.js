import test from 'node:test';
import assert from 'node:assert/strict';
import { Campaign, countMen } from '../src/game/model.js';
import { soldierPosition } from '../src/game/formations.js';

function battle() {
  const m = new Campaign();
  m.startBattle('e1');
  m.select(['u1']);
  return m;
}
function advance(m, seconds) {
  m.state.paused = false;
  for (let i = 0; i < Math.round(seconds * 10); i++) m.update(0.1);
  m.state.paused = true;
}

test('formation orders take simulation time and soldiers interpolate between layouts', () => {
  const m = battle(),
    unit = m.state.battle.units[0];
  const before = soldierPosition(unit, 9, 100);
  m.formation('square');
  assert.equal(unit.formation, 'line');
  assert.equal(unit.formationChange.to, 'square');
  assert.deepEqual(soldierPosition(unit, 9, 100), before);
  m.update(0.1);
  assert.equal(unit.formationChange.elapsed, 0);
  advance(m, 4);
  assert.equal(unit.formation, 'line');
  assert.ok(unit.formationChange.elapsed > 0);
  assert.notDeepEqual(soldierPosition(unit, 9, 100), before);
  advance(m, 10);
  assert.equal(unit.formation, 'square');
  assert.equal(unit.formationChange, null);
});

test('changing orders queues the next formation without restarting or teleporting ranks', () => {
  const m = battle(),
    u = m.state.battle.units[0];
  m.formation('square');
  advance(m, 3);
  const progress = u.formationChange.elapsed,
    position = soldierPosition(u, 12, 80);
  m.formation('line');
  assert.equal(u.queuedFormation, 'line');
  assert.equal(u.formationChange.elapsed, progress);
  assert.deepEqual(soldierPosition(u, 12, 80), position);
  advance(m, 10);
  assert.equal(u.formation, 'square');
  assert.equal(u.formationChange.to, 'line');
  advance(m, 10);
  assert.equal(u.formation, 'line');
  assert.equal(u.formationChange, null);
});

test('reforming prevents firing and charging and slows an existing march order', () => {
  const m = battle(),
    u = m.state.battle.units[0];
  const target = m.state.battle.units.find((t) => t.side === 'enemy');
  target.x = u.x + 100;
  target.y = u.y;
  m.moveUnits({ x: u.x + 200, y: u.y });
  m.formation('square');
  m.charge();
  assert.equal(u.charging, false);
  const x = u.x;
  advance(m, 1);
  assert.equal(u.shotTime, undefined);
  assert.ok(u.x - x > 0 && u.x - x < 10);
});

test('a nearby drill commander accelerates formation changes only for their own corps', () => {
  const m = battle(),
    u = m.state.battle.units[0];
  const leader = m.state.battle.commanders.find((c) => c.corpsId === u.corpsId);
  leader.x = u.x;
  leader.y = u.y;
  leader.following = false;
  m.formation('square');
  advance(m, 2);
  assert.ok(Math.abs(u.formationChange.elapsed - 2.4) < 0.001);
  leader.x = 1400;
  leader.y = 900;
  advance(m, 1);
  assert.ok(Math.abs(u.formationChange.elapsed - 3.4) < 0.001);
});

test('corps assignments respect four-unit capacity and keep every regiment assigned once', () => {
  const m = new Campaign();
  assert.equal(m.assignCorps('u5', 'c1'), false);
  assert.equal(m.assignCorps('u1', 'c2'), true);
  assert.equal(m.assignCorps('u5', 'c1'), true);
  assert.equal(m.state.units.find((u) => u.id === 'u5').corpsId, 'c1');
  assert.equal(m.assignCorps('u1', 'missing'), false);
  m.recruit();
  assert.equal(m.state.units.at(-1).corpsId, 'c2');
  for (const corps of m.state.corps)
    assert.ok(m.state.units.filter((u) => u.corpsId === corps.id).length <= 4);
  m.startBattle('e1');
  assert.equal(m.assignCorps('u2', 'c2'), false);
  m.selectCorps('c2');
  assert.deepEqual(m.state.selected, ['u1', 'u6']);
});

test('commanders can be moved independently and do not count as fighting regiments', () => {
  const m = battle(),
    before = countMen(m.state.battle.units);
  assert.equal(m.state.battle.commanders.length, 3);
  m.selectCommander('general');
  assert.deepEqual(m.state.selected, []);
  const general = m.state.battle.commanders[0],
    x = general.x;
  m.moveUnits({ x: 300, y: 450 });
  advance(m, 1);
  assert.ok(general.x > x);
  assert.equal(general.following, false);
  assert.equal(countMen(m.state.battle.units), before);
  m.halt();
  assert.equal(general.target, null);
  m.followCommand();
  assert.equal(general.following, true);
});

test('rally affects eligible units in command radius and its cooldown respects pause', () => {
  const m = battle(),
    u = m.state.battle.units[0];
  const leader = m.state.battle.commanders.find((c) => c.corpsId === 'c1');
  leader.x = u.x;
  leader.y = u.y;
  leader.following = false;
  const other = m.state.battle.units.find((u) => u.id === 'u5');
  other.x = u.x;
  other.y = u.y;
  other.morale = 45;
  u.morale = 40;
  assert.equal(m.rally(leader.id), true);
  assert.equal(u.morale, 58);
  assert.equal(other.morale, 45);
  assert.equal(m.rally(leader.id), false);
  m.update(0.1);
  assert.equal(leader.cooldown, 45);
  advance(m, 1);
  assert.ok(leader.cooldown < 45);
});

test('enemy proximity shakes commanders and interrupts their command support', () => {
  const m = battle(),
    u = m.state.battle.units[0],
    leader = m.state.battle.commanders.find((c) => c.corpsId === 'c1');
  leader.x = u.x;
  leader.y = u.y;
  leader.following = false;
  const enemy = m.state.battle.units.find((u) => u.side === 'enemy');
  enemy.x = leader.x + 55;
  enemy.y = leader.y;
  advance(m, 0.2);
  assert.ok(leader.shaken > 0);
  assert.equal(
    m.commandSupport(u).some((c) => c.id === leader.id),
    false,
  );
  assert.equal(m.rally(leader.id), false);
});

test('hold-fire orders suppress ranged volleys', () => {
  const m = battle(),
    u = m.state.battle.units[0],
    enemy = m.state.battle.units.find((u) => u.side === 'enemy');
  enemy.x = u.x + 140;
  enemy.y = u.y;
  m.holdFire();
  advance(m, 0.5);
  assert.equal(u.holdFire, true);
  assert.equal(u.shotTime, undefined);
  m.holdFire();
  advance(m, 0.5);
  assert.equal(u.holdFire, false);
  assert.ok(u.shotTime > 0);
});

test('older ongoing campaign saves upgrade without losing money, troops, or battle progress', () => {
  const m = battle();
  m.state.cash = 9321;
  m.state.battle.time = 23;
  m.state.battle.units[0].men = 711;
  const old = structuredClone(m.state);
  old.version = 1;
  delete old.general;
  delete old.corps;
  delete old.selectedCommander;
  delete old.battle.commanders;
  for (const u of [...old.units, ...old.battle.units]) {
    delete u.corpsId;
    delete u.formationChange;
  }
  const loaded = new Campaign({
    getItem: () => JSON.stringify(old),
    setItem() {},
  });
  assert.equal(loaded.state.version, 3);
  assert.equal(loaded.state.cash, 9321);
  assert.equal(loaded.state.battle.time, 23);
  assert.equal(loaded.state.battle.units[0].men, 711);
  assert.equal(loaded.state.battle.commanders.length, 3);
  assert.equal(loaded.state.paused, true);
  assert.ok(loaded.state.units.every((u) => ['c1', 'c2'].includes(u.corpsId)));
});

test('ongoing formation orders, officer positions, cooldowns and corps assignments survive reload', () => {
  let saved;
  const storage = {
    getItem: () => saved,
    setItem: (_key, value) => {
      saved = value;
    },
  };
  const m = new Campaign(storage);
  m.assignCorps('u1', 'c2');
  m.startBattle('e1');
  m.select(['u1']);
  m.formation('square');
  advance(m, 3);
  m.state.battle.commanders[0].x = 333;
  m.state.battle.commanders[0].cooldown = 21;
  m.save();
  const loaded = new Campaign(storage);
  assert.deepEqual(loaded.state.battle, m.state.battle);
  assert.equal(loaded.state.units[0].corpsId, 'c2');
  assert.equal(loaded.state.paused, true);
});

test('custom trade quantities cannot underflow cash or inventory', () => {
  const m = new Campaign(),
    cash = m.state.cash;
  assert.equal(m.trade('musket', 'buy', -50), false);
  assert.equal(m.trade('musket', 'buy', 0.5), false);
  assert.equal(m.trade('musket', 'buy', NaN), false);
  assert.equal(m.trade('musket', 'buy', 0), false);
  assert.equal(m.state.cash, cash);
  assert.equal(m.trade('improved', 'buy', 400), true);
  assert.equal(m.state.inventory.improved, 400);
  assert.equal(m.state.cash, cash - 5600);
  assert.equal(m.trade('improved', 'sell', 1000), true);
  assert.equal(m.state.inventory.improved, 0);
});
