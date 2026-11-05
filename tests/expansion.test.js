import test from 'node:test';
import assert from 'node:assert/strict';
import { Campaign, countMen, freshState } from '../src/game/model.js';
import {
  BATTLEFIELDS,
  battleRoute,
  passable,
  lineOfSight,
} from '../src/game/battlefields.js';
import { updateVisibility } from '../src/game/tactics.js';
import {
  commandEfficiency,
  officerReady,
  officerAssignment,
  rankOf,
} from '../src/game/progression.js';

const advance = (m, seconds) => {
  m.state.paused = false;
  for (let i = 0; i < Math.round(seconds * 10); i++) m.update(0.1);
  m.state.paused = true;
};
const isolated = () => {
  const m = new Campaign();
  m.startBattle('e1');
  m.state.battle.aiClock = -100000;
  for (const u of m.state.battle.units.filter((u) => u.side === 'enemy'))
    u.arrival = 100000;
  return m;
};
const pair = () => {
  const m = isolated(),
    b = m.state.battle;
  for (const u of b.units) {
    u.x = 90;
    u.y = 850;
  }
  const player = b.units[0],
    enemy = b.units.find((u) => u.side === 'enemy');
  Object.assign(player, { x: 300, y: 430, facing: 0 });
  Object.assign(enemy, {
    x: 425,
    y: 430,
    arrival: 0,
    holdFire: true,
    reload: 1000,
  });
  updateVisibility(b);
  return { m, b, player, enemy };
};

test('version two campaigns and battles acquire progression without losing existing state', () => {
  const m = new Campaign();
  m.startBattle('e1');
  const old = structuredClone(m.state);
  old.version = 2;
  old.cash = 4123;
  old.battle.time = 35;
  old.battle.units[0].men = 622;
  for (const key of [
    'officers',
    'settings',
    'supply',
    'recon',
    'selectedSupply',
    'orderMode',
  ])
    delete old[key];
  for (const key of [
    'scenario',
    'objective',
    'wagons',
    'playerEdge',
    'visibleCells',
  ])
    delete old.battle[key];
  delete old.inventory.carbine;
  delete old.inventory.howitzer;
  delete old.market.carbine;
  delete old.market.howitzer;
  for (const u of [...old.units, ...old.battle.units])
    for (const key of [
      'skills',
      'condition',
      'ammo',
      'officerId',
      'perk',
      'history',
      'trainedUntil',
      'waypoints',
      'orderQueue',
    ])
      delete u[key];
  const loaded = new Campaign({
    getItem: () => JSON.stringify(old),
    setItem() {},
  });
  assert.equal(loaded.state.version, 3);
  assert.equal(loaded.state.cash, 4123);
  assert.equal(loaded.state.battle.time, 35);
  assert.equal(loaded.state.battle.units[0].men, 622);
  assert.equal(loaded.state.battle.wagons.length, 2);
  assert.equal(loaded.state.units[0].ammo, 100);
  assert.ok(loaded.state.officers.length >= 12);
  assert.ok(
    loaded.state.units.every((u) => u.officerId && u.skills.firearms > 0),
  );
  assert.equal(loaded.state.paused, true);
  advance(loaded, 1);
  assert.ok(loaded.state.battle.time > 35);
});

test('officer hiring and unique assignments enforce treasury, rank, and availability', () => {
  const m = new Campaign(),
    s = m.state,
    officer = s.officers.find((o) => !o.hired);
  assert.equal(m.assignOfficer('c1', officer.id), false);
  const cash = s.cash;
  assert.equal(m.hireOfficer(officer.id), true);
  assert.equal(s.cash, cash - officer.cost);
  assert.equal(m.hireOfficer(officer.id), false);
  assert.equal(m.assignOfficer('c1', officer.id), true);
  assert.equal(officerAssignment(s, officer.id).id, 'c1');
  assert.equal(m.assignOfficer('u1', officer.id), true);
  assert.equal(s.corps[0].officerId, null);
  assert.equal(officerAssignment(s, officer.id).id, 'u1');
  const junior = s.officers.find((o) => o.id === 'officer-u5');
  assert.equal(m.assignOfficer('c2', junior.id), false);
  officer.woundedUntil = s.hours + 8;
  assert.equal(m.assignOfficer('u2', officer.id), false);
  assert.equal(commandEfficiency(s, s.units[0]), 0.7);
  s.hours += 8;
  assert.equal(officerReady(officer, s.hours), true);
  assert.equal(m.assignOfficer('u2', officer.id), true);
  officer.dead = true;
  assert.equal(officerReady(officer, s.hours + 1000), false);
});

test('veteran replacements preserve experience and skills while recruits dilute them', () => {
  for (const quality of ['recruits', 'veterans']) {
    const m = new Campaign(),
      u = m.state.units[0];
    u.men = 600;
    u.experience = 3;
    u.skills.firearms = 70;
    const cash = m.state.cash;
    assert.equal(m.replenish(u.id, quality, 100), true);
    assert.equal(u.men, 700);
    assert.equal(m.state.inventory.musket, 300);
    assert.equal(m.state.cash, cash - (quality === 'veterans' ? 600 : 200));
    if (quality === 'veterans') {
      assert.equal(u.experience, 3);
      assert.equal(u.skills.firearms, 70);
    } else {
      assert.ok(u.experience < 3);
      assert.ok(u.skills.firearms < 70);
    }
  }
});

test('training, regiment names, strength limits and one-time distinctions persist', () => {
  const m = new Campaign(),
    u = m.state.units[0],
    skill = u.skills.firearms;
  assert.equal(m.renameRegiment(u.id, '  1st Imperial Line  '), true);
  assert.equal(u.name, '1st Imperial Line');
  assert.equal(m.renameRegiment(u.id, ' '), false);
  assert.equal(m.setUnitSize(u.id, 700), false);
  assert.equal(m.setUnitSize(u.id, 1201), false);
  assert.equal(m.setUnitSize(u.id, 1000), true);
  assert.equal(m.train(u.id, 'firearms'), true);
  assert.equal(u.skills.firearms, skill + 5);
  assert.equal(m.train(u.id, 'firearms'), false);
  assert.equal(m.choosePerk(u.id, 'volley'), false);
  u.experience = 1;
  assert.equal(m.choosePerk(u.id, 'volley'), true);
  assert.equal(m.choosePerk(u.id, 'march'), false);
  const restored = new Campaign({
    getItem: () => JSON.stringify(m.state),
    setItem() {},
  });
  assert.equal(restored.state.units[0].perk, 'volley');
  assert.equal(restored.state.units[0].maxMen, 1000);
  assert.equal(restored.state.units[0].name, u.name);
});

test('battle service records, wounds and automatic officer promotions survive the result', () => {
  const m = isolated(),
    u = m.state.units[0],
    officer = m.state.officers.find((o) => o.id === u.officerId);
  officer.xp = 59;
  Object.assign(m.state.battle.units[0], {
    men: 300,
    kills: 150,
    ammo: 42,
    condition: 61,
  });
  m.finishBattle(true);
  assert.equal(u.history[0].losses, 500);
  assert.equal(u.history[0].kills, 150);
  assert.equal(u.ammo, 42);
  assert.equal(u.condition, 61);
  assert.equal(rankOf(officer), 2);
  assert.equal(officer.wounds, 1);
  assert.equal(officerReady(officer, m.state.hours), false);
});

test('supply purchases charge once and cannot happen during combat', () => {
  const m = new Campaign(),
    s = m.state;
  s.supply = 300;
  s.units[0].ammo = 50;
  assert.equal(m.resupplyCost(), 300);
  const cash = s.cash;
  assert.equal(m.resupply(), true);
  assert.equal(s.cash, cash - 300);
  assert.equal(s.units[0].ammo, 100);
  assert.equal(s.supply, 500);
  assert.equal(m.resupply(), false);
  m.startBattle('e1');
  s.supply = 0;
  assert.equal(m.resupply(), false);
});

test('campaign scouting reveals recent intelligence and its duration respects pause', () => {
  const m = new Campaign(),
    s = m.state,
    enemy = s.enemies[0];
  enemy.x = s.army.x + 500;
  enemy.y = s.army.y;
  assert.equal(m.enemyVisible(enemy), false);
  assert.equal(m.scout(), true);
  assert.equal(m.enemyVisible(enemy), true);
  assert.equal(m.scout(), false);
  m.update(0.1);
  assert.equal(s.recon.remaining, 45);
  advance(m, 1);
  assert.ok(s.recon.remaining < 45);
  assert.equal(enemy.intel.x, enemy.x);
  assert.equal(enemy.intel.at, s.hours);
  s.army.condition = 60;
  s.units[0].condition = 60;
  m.moveArmy({ x: 360, y: 727 });
  advance(m, 1);
  assert.ok(s.army.condition < 60);
  m.halt();
  advance(m, 2);
  assert.ok(s.army.condition > 60);
});

test('fog respects scouting distance, woodland depth and intervening high ground', () => {
  const field = BATTLEFIELDS.village;
  assert.equal(
    lineOfSight({ x: 100, y: 430 }, { x: 1300, y: 430 }, field),
    false,
  );
  assert.equal(
    lineOfSight({ x: 300, y: 430 }, { x: 425, y: 430 }, field),
    true,
  );
  assert.equal(
    lineOfSight({ x: 180, y: 208 }, { x: 610, y: 208 }, field, true),
    false,
  );
  assert.equal(
    lineOfSight({ x: 330, y: 625 }, { x: 730, y: 625 }, field, true),
    false,
  );
  const m = isolated(),
    b = m.state.battle,
    enemy = b.units.find((u) => u.side === 'enemy');
  enemy.arrival = 0;
  enemy.x = 1350;
  enemy.y = 850;
  updateVisibility(b);
  assert.equal(enemy.visible, false);
  enemy.x = b.units[0].x + 40;
  enemy.y = b.units[0].y;
  updateVisibility(b);
  assert.equal(enemy.visible, true);
  assert.equal(b.visibleCells.length, 600);
  assert.ok(b.visibleCells.some(Boolean) && b.visibleCells.some((v) => !v));
});

test('volleys consume ammunition and zero ammunition suppresses ranged attacks', () => {
  const { m, player, enemy } = pair();
  player.ammo = 10;
  const men = enemy.men;
  advance(m, 1);
  assert.ok(player.ammo < 10 && enemy.men < men);
  player.ammo = 0;
  player.reload = 0;
  const remaining = enemy.men;
  advance(m, 1);
  assert.equal(enemy.men, remaining);
  assert.equal(player.blocked, 'No ammunition');
});

test('friendly lines obstruct shooting and clearing the line restores fire', () => {
  const { m, b, player, enemy } = pair(),
    blocker = b.units[1];
  Object.assign(blocker, { x: 363, y: 430, holdFire: true });
  advance(m, 1);
  assert.equal(player.blocked, 'Obstructed');
  assert.equal(player.ammo, 100);
  blocker.y += 80;
  advance(m, 1);
  assert.ok(player.ammo < 100 && enemy.men < enemy.startMen);
});

test('wagons conserve stores, can be ordered independently and are vulnerable to raids', () => {
  const m = isolated(),
    b = m.state.battle,
    u = b.units[0],
    wagon = b.wagons[0];
  Object.assign(u, { x: wagon.x + 50, y: wagon.y, ammo: 30 });
  wagon.stock = 2;
  advance(m, 1);
  assert.ok(Math.abs(u.ammo - 32) < 0.0001);
  assert.equal(wagon.stock, 0);
  m.selectSupply();
  m.moveUnits({ x: 300, y: 500 });
  assert.ok(wagon.target);
  assert.equal(m.selectedUnits().length, 0);
  m.halt();
  assert.equal(wagon.target, null);
  const enemy = b.units.find((u) => u.side === 'enemy');
  Object.assign(enemy, { arrival: 0, x: wagon.x, y: wagon.y, holdFire: true });
  wagon.health = 1;
  wagon.stock = 10;
  advance(m, 1);
  assert.equal(wagon.health, 0);
  assert.equal(wagon.stock, 0);
});

test('double time costs condition, resting restores it and fallback preserves facing', () => {
  const m = isolated(),
    u = m.state.battle.units[0];
  Object.assign(u, { x: 300, y: 430, facing: 0, condition: 70 });
  m.select([u.id]);
  m.run();
  m.moveUnits({ x: 650, y: 430 });
  advance(m, 2);
  assert.ok(u.condition < 69);
  m.halt();
  advance(m, 3);
  assert.ok(u.condition > 70);
  const x = u.x;
  m.fallBack();
  advance(m, 1);
  assert.ok(u.x < x);
  assert.ok(Math.abs(u.facing) < 0.01);
});

test('frontlines carry final facing and queued waypoints execute in order', () => {
  const m = isolated(),
    [a, b] = m.state.battle.units;
  m.select([a.id, b.id]);
  m.frontline({ x: 400, y: 400 }, { x: 400, y: 600 });
  assert.deepEqual(a.target, { x: 400, y: 400 });
  assert.deepEqual(b.target, { x: 400, y: 600 });
  assert.equal(a.desiredFacing, 0);
  Object.assign(a, { x: 300, y: 430 });
  m.select([a.id]);
  m.moveUnits({ x: 330, y: 430 });
  m.moveUnits({ x: 370, y: 430 }, null, true, Math.PI / 2);
  assert.equal(a.orderQueue.length, 1);
  advance(m, 6);
  assert.equal(a.orderQueue.length, 0);
  assert.equal(a.target, null);
  assert.ok(Math.abs(a.x - 370) < 1 && Math.abs(a.facing - Math.PI / 2) < 0.01);
});

test('deployment stays on the friendly side and ends when time resumes', () => {
  const m = isolated(),
    u = m.state.battle.units[0];
  m.select([u.id]);
  assert.equal(m.deploy({ x: 800, y: 430 }), false);
  assert.equal(m.deploy({ x: 350, y: 430 }), true);
  assert.equal(u.x, 350);
  m.setOrderMode('deploy');
  m.pause();
  assert.equal(m.state.orderMode, 'move');
  m.update(0.1);
  m.pause();
  assert.equal(m.deploy({ x: 300, y: 430 }), false);
});

test('bridge routes cross only the bridge, including commander following paths', () => {
  const field = BATTLEFIELDS.bridge;
  for (const [from, to] of [
    [
      { x: 300, y: 200 },
      { x: 1100, y: 750 },
    ],
    [
      { x: 1100, y: 200 },
      { x: 300, y: 750 },
    ],
  ]) {
    const route = battleRoute(from, to, field);
    assert.ok(route.length > 2);
    let prev = from;
    for (const p of route) {
      for (let t = 0; t <= 1; t += 0.01)
        assert.ok(
          passable(
            { x: prev.x + (p.x - prev.x) * t, y: prev.y + (p.y - prev.y) * t },
            field,
          ),
        );
      prev = p;
    }
    assert.deepEqual(route.at(-1), to);
  }
  const m = isolated(),
    b = m.state.battle;
  b.scenario = 'bridge';
  for (const u of b.units.filter((u) => u.side === 'player'))
    Object.assign(u, { x: 1150, y: 300 });
  const c = b.commanders[0];
  Object.assign(c, { x: 300, y: 300 });
  for (let i = 0; i < 400; i++) {
    m.updateCommanders(0.1);
    assert.ok(passable(c, field));
  }
  assert.ok(c.x > 900);
});

test('detachments conserve men and ammunition when recalled or returned from battle', () => {
  for (const rejoin of [true, false]) {
    const m = isolated(),
      b = m.state.battle,
      parent = b.units[0],
      total = countMen(b.units.filter((u) => u.side === 'player'));
    m.select([parent.id]);
    m.detachSkirmishers();
    const child = b.units.find((u) => u.parentId === parent.id);
    assert.equal(countMen(b.units.filter((u) => u.side === 'player')), total);
    parent.ammo = 40;
    child.ammo = 90;
    child.men -= 10;
    child.kills = 12;
    if (rejoin) {
      m.detachSkirmishers();
      assert.equal(
        b.units.some((u) => u.parentId),
        false,
      );
    }
    m.finishBattle(true);
    assert.equal(m.state.units[0].men, 790);
    assert.ok(
      Math.abs(m.state.units[0].ammo - (640 * 40 + 150 * 90) / 790) < 0.001,
    );
    assert.equal(m.state.units[0].history[0].kills, 12);
  }
});

test('artillery limbering takes time, prevents firing and carbine cavalry can dismount', () => {
  const m = isolated(),
    gun = m.state.battle.units.find((u) => u.kind === 'artillery');
  m.select([gun.id]);
  m.limber();
  assert.equal(gun.limbered, false);
  m.update(0.1);
  assert.equal(gun.limberChange, 5);
  advance(m, 5.1);
  assert.equal(gun.limbered, true);
  m.limber();
  advance(m, 5.1);
  assert.equal(gun.limbered, false);
  const cav = m.state.battle.units.find((u) => u.kind === 'cavalry');
  m.select([cav.id]);
  m.dismount();
  assert.ok(!cav.dismounted);
  cav.weapon = 'carbine';
  m.dismount();
  assert.equal(cav.dismounted, true);
  m.charge();
  assert.equal(cav.charging, false);
});

test('an enemy without a sighted target occupies the objective instead of stalling outside it', () => {
  const m = isolated(),
    b = m.state.battle,
    enemy = b.units.find((u) => u.side === 'enemy');
  b.aiClock = 0;
  enemy.arrival = 0;
  Object.assign(enemy, { x: 1000, y: 430 });
  for (const u of b.units.filter((u) => u.side === 'player'))
    Object.assign(u, { x: 70, y: 850 });
  for (const c of b.commanders) {
    c.following = false;
    c.x = 70;
    c.y = 850;
  }
  advance(m, 260);
  assert.equal(m.state.mode, 'campaign');
  assert.equal(m.state.report.won, false);
});

test('contested objectives do not progress and occupation wins a battle', () => {
  const m = isolated(),
    b = m.state.battle,
    objective = BATTLEFIELDS.village.objective;
  Object.assign(b.units[0], { x: objective.x, y: objective.y, holdFire: true });
  const enemy = b.units.find((u) => u.side === 'enemy');
  Object.assign(enemy, {
    x: objective.x + 75,
    y: objective.y,
    arrival: 0,
    holdFire: true,
  });
  advance(m, 1);
  assert.equal(b.objective.player, 0);
  enemy.arrival = 100000;
  advance(m, 151);
  assert.equal(m.state.report.won, true);
});

test('sound settings are bounded and survive a save restoration', () => {
  const m = new Campaign();
  m.setSound(false, 2);
  assert.equal(m.state.settings.volume, 1);
  m.setSound(true, -1);
  assert.equal(m.state.settings.volume, 0);
  const restored = new Campaign({
    getItem: () => JSON.stringify(m.state),
    setItem() {},
  });
  assert.deepEqual(restored.state.settings, { sound: true, volume: 0 });
  assert.equal(freshState().version, 3);
});

test('an unopposed result has no phantom losses and unavailable officers cannot be injured again', () => {
  const m = new Campaign(),
    officer = m.state.officers.find((o) => o.id === 'officer-u1');
  officer.woundedUntil = m.state.hours + 8;
  const xp = officer.xp;
  m.startBattle('e1');
  m.finishBattle(true);
  assert.equal(m.state.report.enemyCasualties, 0);
  assert.equal(m.state.report.casualties, 0);
  assert.equal(m.state.report.regiments.length, 5);
  assert.equal(officer.xp, xp);
  assert.equal(officer.dead, false);
});
