import test from 'node:test';
import assert from 'node:assert/strict';
import { DepthCampaign } from '../src/demo/model.js';
import {
  automaticTarget,
  insideArc,
  FIRE_ARC,
} from '../src/demo/engagement.js';
import { unitActivity, updateCondition } from '../src/demo/fatigue.js';
import { WEAPONS, distance } from '../src/game/model.js';

function fixture() {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  for (const u of b.units) {
    u.arrival = 9999;
    u.holdFire = true;
  }
  const own = b.units[0],
    enemy = b.units.find((u) => u.side === 'enemy');
  Object.assign(own, {
    x: 400,
    y: 300,
    facing: 0,
    arrival: 0,
    holdFire: false,
    condition: 80,
    weapon: 'musket',
    target: null,
    attackId: null,
    desiredFacing: null,
  });
  Object.assign(enemy, {
    x: 520,
    y: 300,
    facing: Math.PI,
    arrival: 0,
    visible: true,
    condition: 80,
    target: null,
    attackId: null,
    men: 5000,
    startMen: 5000,
  });
  b.aiClock = -100000;
  b.visibilityClock = -100000;
  b.visibleCells = [];
  model.select([own.id]);
  const advance = (seconds) => {
    for (let i = 0; i < Math.round(seconds * 60); i++)
      model.updateBattle(1 / 60);
  };
  return { model, b, own, enemy, advance };
}

test('idle regiments neither turn nor pursue targets behind them or outside range', () => {
  for (const x of [280, 650]) {
    const { own, enemy, advance } = fixture();
    enemy.x = x;
    advance(3);
    assert.equal(own.facing, 0);
    assert.equal(own.x, 400);
    assert.equal(own.y, 300);
    assert.equal(own.target, null);
    assert.equal(own.ammo, 100);
    assert.equal(own.fireTargetId, null);
  }
});

test('automatic fire selects an enemy already in the arc, even if a closer enemy is behind', () => {
  const { model, b, own, enemy, advance } = fixture();
  const rear = { ...enemy, id: 'rear', x: 330, y: 300 };
  b.units.push(rear);
  assert.equal(automaticTarget(own, rear, b), false);
  advance(0.1);
  assert.equal(own.fireTargetId, enemy.id);
  assert.ok(own.ammo < 100);
  assert.equal(own.facing, 0);
  const nearer = { ...enemy, id: 'nearer', x: 490, y: 325 };
  b.units.push(nearer);
  assert.equal(
    model.combatTarget(own).id,
    enemy.id,
    'keep a valid current opponent',
  );
});

test('the Engage command advances into range but does not overrun an existing firing position', () => {
  const { model, own, enemy, advance } = fixture();
  enemy.x = 630;
  assert.equal(model.engageEnemy(), 1);
  assert.equal(own.attackId, enemy.id);
  assert.ok(own.target);
  advance(5);
  assert.ok(own.x > 400);
  assert.ok(distance(own, enemy) <= WEAPONS[own.weapon].range);
  assert.ok(distance(own, enemy) > WEAPONS[own.weapon].range - 3);
  assert.equal(own.target, null);
  const stopped = { x: own.x, y: own.y, facing: own.facing };
  model.engageEnemy();
  advance(1);
  assert.deepEqual({ x: own.x, y: own.y, facing: own.facing }, stopped);
});

test('explicit engagement turns only into the firing arc, then holds facing as the target moves', () => {
  const { model, own, enemy, advance } = fixture();
  enemy.x = 280;
  model.engageEnemy();
  for (let i = 0; i < 1000 && !own.aimComplete; i++) {
    advance(1 / 60);
    if (own.ammo < 100) assert.ok(insideArc(own, enemy));
  }
  assert.ok(own.aimComplete && insideArc(own, enemy));
  assert.ok(own.facing > Math.PI - FIRE_ARC && own.facing < Math.PI - 0.7);
  assert.equal(own.x, 400);
  const facing = own.facing;
  enemy.y += 20;
  advance(1);
  assert.equal(own.facing, facing);
  enemy.y = 260;
  assert.equal(insideArc(own, enemy), false);
  own.reload = 0;
  const ammo = own.ammo;
  advance(1);
  assert.equal(own.facing, facing);
  assert.equal(own.ammo, ammo);
  model.engageEnemy();
  advance(1);
  assert.notEqual(
    own.facing,
    facing,
    'a new explicit order can reacquire the target',
  );
});

test('right-click attack obeys the same acquisition rules and halt cancels the turn', () => {
  const { model, own, enemy, advance } = fixture();
  enemy.x = 280;
  model.moveUnits(enemy, enemy.id);
  advance(1);
  assert.ok(own.facing > 0 && own.facing < Math.PI / 2);
  assert.equal(own.x, 400);
  model.halt();
  const facing = own.facing;
  advance(2);
  assert.equal(own.facing, facing);
  assert.equal(own.attackId, null);
});

test('no visible target produces no engage order and lost targets do not leave a pursuit running', () => {
  const { model, own, enemy, advance } = fixture();
  enemy.visible = false;
  assert.equal(model.engageEnemy(), 0);
  assert.equal(own.target, null);
  enemy.visible = true;
  enemy.x = 650;
  model.engageEnemy();
  enemy.visible = false;
  advance(0.1);
  assert.equal(own.target, null);
  assert.equal(own.attackId, null);
  assert.equal(own.x, 400);
});

test('engagement respects hold-fire and melee-only orders still close the distance', () => {
  const { model, own, enemy, advance } = fixture();
  own.holdFire = true;
  advance(0.1);
  assert.equal(own.ammo, 100);
  assert.equal(own.fireTargetId, enemy.id);
  model.engageEnemy();
  advance(1);
  assert.ok(own.x > 400);
  assert.equal(own.ammo, 100);
});

test('Engage interrupts a passing march and does not turn toward a target already at the arc edge', () => {
  const { model, own, enemy, advance } = fixture();
  model.moveUnits({ x: 620, y: 300 });
  advance(0.1);
  assert.ok(own.target && own.fireTargetId === enemy.id);
  model.engageEnemy();
  assert.equal(own.target, null);
  const x = own.x,
    facing = own.facing;
  enemy.x = own.x + Math.cos(FIRE_ARC - 0.005) * 120;
  enemy.y = own.y + Math.sin(FIRE_ARC - 0.005) * 120;
  advance(0.1);
  assert.equal(own.x, x);
  assert.equal(own.facing, facing);
});

test('stationary combat drains both participants without recovery between volleys', () => {
  const { own, enemy, advance } = fixture();
  let previousOwn = own.condition,
    previousEnemy = enemy.condition;
  for (let i = 0; i < 400; i++) {
    advance(1 / 60);
    assert.ok(own.condition <= previousOwn);
    assert.ok(enemy.condition <= previousEnemy);
    previousOwn = own.condition;
    previousEnemy = enemy.condition;
  }
  assert.ok(own.condition < 79 && enemy.condition < 79);
  assert.equal(own.x, 400);
  assert.equal(enemy.x, 520);
});

test('fatigue recovery waits for stationary rest after combat; marching never recovers it', () => {
  const { model, own, enemy, advance } = fixture();
  advance(1);
  own.holdFire = true;
  enemy.visible = false;
  const exhausted = own.condition;
  advance(8);
  assert.ok(own.condition > exhausted);
  model.moveUnits({ x: 450, y: 300 });
  const rested = own.condition;
  advance(1);
  assert.ok(own.condition < rested);
  model.halt();
  const stopped = own.condition;
  advance(1);
  assert.equal(
    own.condition,
    stopped,
    'short settling interval before recovery',
  );
  advance(3);
  assert.ok(own.condition > stopped);
});

test('melee is more tiring than ranged combat and reforming or wheeling cannot restore condition', () => {
  const base = {
    x: 0,
    y: 0,
    facing: 0,
    condition: 60,
    skills: { stamina: 30 },
    fightingUntil: 10,
  };
  const shooting = structuredClone(base),
    melee = { ...structuredClone(base), meleeUntil: 10 };
  updateCondition(shooting, unitActivity(shooting), 1, 1);
  updateCondition(melee, unitActivity(melee), 1, 1);
  assert.ok(melee.condition < shooting.condition && shooting.condition < 60);
  for (const action of ['turning', 'reforming']) {
    const unit = { ...structuredClone(base), fightingUntil: 0 },
      before = unitActivity(unit);
    if (action === 'turning') unit.facing = 0.1;
    else unit.formationChange = { elapsed: 1 };
    updateCondition(unit, before, 1, 1);
    assert.ok(unit.condition < 60);
  }
});
