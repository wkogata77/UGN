import test from 'node:test';
import assert from 'node:assert/strict';
import {
  DepthCampaign,
  createFixedClock,
  legalGround,
  fireStatus,
} from '../src/demo/model.js';
import { landscapeFor } from '../src/demo/terrain.js';
import { fieldFor, elevation, channelX } from '../src/game/battlefields.js';

test('the depth demo is isolated from campaign storage and starts at half speed', () => {
  const model = new DepthCampaign();
  assert.equal(model.storage, null);
  assert.equal(model.state.speed, 0.5);
  model.save();
  assert.equal(model.saveFailed, false);
  assert.equal(model.state.mode, 'campaign');
});

test('the campaign demo can march to its advance guard and enter the crossing battle', () => {
  const model = new DepthCampaign(),
    enemy = model.state.enemies[0];
  assert.ok(legalGround(enemy, model.state));
  model.moveArmy(enemy);
  model.speed(4);
  model.pause();
  for (let i = 0; i < 500 && model.state.mode === 'campaign'; i++)
    model.update(0.1);
  assert.equal(model.state.mode, 'battle');
  assert.equal(model.state.battle.scenario, 'bridge');
  assert.equal(model.state.paused, true);
});

test('the fixed demo clock produces identical battle state at different render rates', () => {
  const a = new DepthCampaign(true),
    b = new DepthCampaign(true);
  a.pause();
  b.pause();
  const first = createFixedClock(a),
    second = createFixedClock(b);
  for (let i = 0; i < 120; i++) first.advance(1 / 60);
  for (let i = 0; i < 60; i++) second.advance(1 / 30);
  assert.deepEqual(a.state.battle, b.state.battle);
  assert.ok(Math.abs(a.state.battle.time - 1) < 1e-8);
});

test('paused time and stalls do not cause a hidden simulation catch-up', () => {
  const model = new DepthCampaign(true),
    clock = createFixedClock(model);
  assert.equal(clock.advance(10), 0);
  assert.equal(model.state.battle.time, 0);
  model.pause();
  assert.equal(clock.advance(10), 6);
  assert.ok(model.state.battle.time < 0.051);
  model.pause();
  clock.advance(10);
  model.pause();
  assert.equal(clock.advance(1 / 60), 1);
});

test('corps command is attached to a host and lost when the host routes', () => {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  const commander = b.commanders.find((c) => c.corpsId === 'c1');
  const host = b.units.find((u) => u.id === commander.hostId);
  assert.ok(host);
  host.x = 460;
  host.y = 390;
  model.updateCommanders(1 / 60);
  assert.equal(commander.x, host.x);
  assert.equal(commander.y, host.y);
  assert.ok(model.commandSupport(host).includes(commander));
  model.selectCommander(commander.id);
  assert.deepEqual(model.state.selected, [host.id]);
  assert.equal(model.state.selectedCommander, null);
  host.routed = true;
  model.updateCommanders(1 / 60);
  assert.equal(commander.unavailable, true);
  assert.ok(!model.commandSupport(host).includes(commander));
  assert.ok(b.commanders.some((c) => !c.hostId && c.id === 'general'));
});

test('battle relief uses the same hills as combat and legal orders respect the bridge', () => {
  const model = new DepthCampaign(true),
    data = landscapeFor(model.state);
  const p = { x: 305, y: 430 };
  assert.equal(
    data.height(p.x, p.y),
    elevation(p, fieldFor(model.state.battle)) * 70,
  );
  assert.equal(legalGround({ x: 720, y: 480 }, model.state), true);
  assert.equal(legalGround({ x: channelX(200), y: 200 }, model.state), false);
  assert.equal(legalGround({ x: -1, y: 480 }, model.state), false);
  model.state.mode = 'campaign';
  assert.ok(landscapeFor(model.state).height(230, 195) > 50);
});

test('range feedback shares the actual friendly-obstruction query', () => {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  const own = b.units.find((u) => u.id === 'u1'),
    other = b.units.find((u) => u.id === 'u2');
  const enemy = b.units.find((u) => u.side === 'enemy');
  Object.assign(own, { x: 440, y: 480, facing: 0 });
  Object.assign(enemy, { x: 550, y: 480, visible: true });
  Object.assign(other, { x: 490, y: 480 });
  assert.equal(fireStatus(own, enemy, b), 'Line of fire blocked');
  other.y = 590;
  assert.equal(fireStatus(own, enemy, b), 'Clear shot');
  enemy.visible = false;
  assert.equal(fireStatus(own, enemy, b), 'No visible target');
});

test('demo regiments deploy clear of the settlement artwork', () => {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  for (const unit of b.units)
    for (const town of fieldFor(b).towns) {
      assert.ok(
        Math.hypot(unit.x - town.x, unit.y - town.y) > 80,
        `${unit.name} spawns inside the hamlet`,
      );
    }
});
