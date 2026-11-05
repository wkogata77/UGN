import test from 'node:test';
import assert from 'node:assert/strict';
import {
  angleDifference,
  turningRate,
  turnFormation,
  movementAlignment,
} from '../src/demo/turning.js';
import { DepthCampaign, createFixedClock } from '../src/demo/model.js';
import { Campaign } from '../src/game/model.js';
import { spriteDirection, TroopAnimator } from '../src/demo/troopAnimation.js';

const regiment = (overrides = {}) => ({
  kind: 'infantry',
  men: 800,
  formation: 'line',
  condition: 100,
  facing: 0,
  ...overrides,
});

test('wide formations wheel more slowly and fatigue reduces their turn rate', () => {
  const wide = regiment(),
    small = regiment({ men: 120 });
  assert.ok(turningRate(wide) < turningRate(small));
  assert.ok(turningRate(wide) < 0.42);
  assert.ok(turningRate(regiment({ condition: 0 })) < turningRate(wide));
  assert.ok(
    turningRate(regiment({ kind: 'cavalry', men: 240 })) > turningRate(wide),
  );
  assert.ok(
    turningRate(regiment({ kind: 'artillery', men: 120 })) < turningRate(wide),
  );
});

test('turns accelerate and ease into headings without overshooting or wrapping the long way', () => {
  const unit = regiment(),
    dt = 1 / 60,
    rates = [];
  for (let i = 0; i < 900; i++) {
    const before = unit.facing;
    turnFormation(unit, Math.PI / 2, dt);
    assert.ok(unit.facing >= before && unit.facing <= Math.PI / 2);
    rates.push((unit.facing - before) / dt);
  }
  assert.equal(unit.facing, Math.PI / 2);
  assert.ok(rates[0] < rates[20] && rates[20] < turningRate(unit) + 1e-10);
  assert.ok(Math.max(...rates) <= turningRate(unit) + 1e-10);
  const crossing = regiment({ facing: Math.PI - 0.05 });
  turnFormation(crossing, -Math.PI + 0.05, dt);
  assert.ok(crossing.facing > Math.PI - 0.05);
  const paused = { ...unit };
  turnFormation(unit, -Math.PI, 0);
  assert.deepEqual(unit, paused);
});

test('quarter turns take several simulation seconds and reverse orders brake smoothly', () => {
  const unit = regiment();
  let elapsed = 0;
  while (
    Math.abs(angleDifference(Math.PI / 2, unit.facing)) > 0.01 &&
    elapsed < 15
  ) {
    turnFormation(unit, Math.PI / 2, 1 / 60);
    elapsed += 1 / 60;
  }
  assert.ok(elapsed > 5 && elapsed < 10);
  unit.facing = 0;
  unit.turnVelocity = turningRate(unit);
  turnFormation(unit, -Math.PI / 2, 1 / 60);
  assert.ok(
    unit.turnVelocity > 0,
    'reversing orders must not instantly reverse angular velocity',
  );
  for (let i = 0; i < 60; i++) turnFormation(unit, -Math.PI / 2, 1 / 60);
  assert.ok(unit.turnVelocity < 0);
});

test('movement waits for major turns, but a deliberate fallback remains backwards', () => {
  assert.equal(movementAlignment(regiment(), Math.PI), 0);
  assert.ok(movementAlignment(regiment(), Math.PI / 2) < 1e-12);
  assert.ok(Math.abs(movementAlignment(regiment(), Math.PI / 4) - 0.5) < 1e-10);
  assert.equal(movementAlignment(regiment(), 0), 1);
  assert.equal(movementAlignment(regiment({ fallingBack: true }), Math.PI), 1);
});

test('battle movement uses smooth turns for regiments, supply and the general', () => {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  for (const unit of b.units) {
    unit.arrival = 9999;
    unit.holdFire = true;
  }
  const unit = b.units.find((u) => u.side === 'player');
  const wagon = b.wagons[0],
    general = b.commanders.find((c) => !c.hostId);
  Object.assign(unit, { x: 280, y: 320, arrival: 0, facing: 0 });
  Object.assign(wagon, { x: 280, y: 440, facing: 0 });
  Object.assign(general, { x: 280, y: 560, facing: 0, following: false });
  for (const u of [unit, wagon, general]) {
    u.target = { x: u.x - 80, y: u.y };
    u.waypoints = [];
  }
  model.state.paused = false;
  for (let i = 0; i < 60; i++) model.update(1 / 60);
  for (const u of [unit, wagon, general]) {
    assert.equal(u.x, 280, 'must not slide backwards before turning');
    assert.ok(u.facing > 0 && u.facing < 0.5);
  }
  assert.equal(typeof new Campaign(null).movementSpeedScale, 'undefined');
});

test('turning and movement are identical at different display rates and freeze on pause', () => {
  const run = (fps) => {
    const model = new DepthCampaign(true),
      clock = createFixedClock(model);
    model.select([model.state.battle.units[0].id]);
    model.moveUnits({ x: 480, y: 600 });
    model.pause();
    for (let i = 0; i < fps * 3; i++) clock.advance(1 / fps);
    model.pause();
    const frozen = structuredClone(model.state.battle);
    clock.advance(1);
    assert.deepEqual(model.state.battle, frozen);
    return frozen;
  };
  assert.deepEqual(run(30), run(60));
});

test('a new turn after standing idle starts from rest rather than stale angular velocity', () => {
  const model = new DepthCampaign(true),
    unit = model.state.battle.units[0];
  for (let i = 0; i < 60; i++) {
    model.state.battle.time += 1 / 60;
    model.turnUnit(unit, Math.PI, 1 / 60);
  }
  const speed = unit.turnVelocity;
  model.state.battle.time += 3;
  model.turnUnit(unit, Math.PI, 1 / 60);
  assert.ok(unit.turnVelocity > 0 && unit.turnVelocity < speed * 0.1);
});

test('sprite headings do not chatter at diagonal boundaries and campaign bends are rate limited', () => {
  let view = 0;
  for (const vertical of [0.71, 0.73, 0.72, 0.74, 0.71]) {
    view = spriteDirection(Math.asin(vertical), view);
    assert.equal(view, 0);
  }
  view = spriteDirection(Math.asin(0.8), view);
  assert.equal(view, 2);
  for (const vertical of [0.72, 0.7, 0.74, 0.68]) {
    view = spriteDirection(Math.asin(vertical), view);
    assert.equal(view, 2);
  }
  assert.equal(spriteDirection(Math.asin(0.6), view), 0);
  const animation = new TroopAnimator();
  animation.sample('army:0', 0, 0, 0, 0);
  animation.sample('army:0', 1, 0, 0.05, 0);
  const bent = animation.sample('army:0', 1, 1, 0.1, 0);
  assert.ok(bent.facing > 0 && bent.facing <= 0.05 * 0.75 + 1e-10);
});
