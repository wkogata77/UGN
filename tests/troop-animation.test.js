import test from 'node:test';
import assert from 'node:assert/strict';
import {
  TroopAnimator,
  animationTime,
  combatPose,
  rigWeights,
  animatedGeometry,
} from '../src/demo/troopAnimation.js';
import { DepthCampaign, createFixedClock } from '../src/demo/model.js';

test('gaits follow displacement, not outstanding orders, and settle after halting', () => {
  const animation = new TroopAnimator();
  const sample = (x, time) => ({ ...animation.sample('u1:0', x, 0, time, 0) });
  const rest = sample(0, 0);
  assert.equal(sample(0, 0.2).amount, 0);
  const moving = sample(4, 0.4);
  assert.ok(moving.amount > 0.9);
  assert.notEqual(moving.phase, rest.phase);
  assert.deepEqual(
    sample(4, 0.4),
    moving,
    'rendering without a simulation step must freeze the pose',
  );
  const stopped = sample(4, 0.8);
  assert.ok(stopped.amount < 0.001);
  assert.equal(stopped.phase, moving.phase);
  assert.ok(
    sample(800, 0.9).amount < 0.001,
    'deployment must not trigger a sprint',
  );
});

test('soldiers reform independently and hidden or removed tracks are released', () => {
  const animation = new TroopAnimator();
  animation.begin();
  const a = { ...animation.sample('u1:0', 0, 0, 0, 0, 0) };
  const b = { ...animation.sample('u1:1', 10, 0, 0, 0, 1) };
  assert.notEqual(a.phase, b.phase);
  animation.end();
  animation.begin();
  assert.ok(animation.sample('u1:0', 2, 0, 0.2, 0).amount > 0);
  assert.equal(animation.sample('u1:1', 10, 0, 0.2, 0).amount, 0);
  animation.end();
  animation.begin();
  animation.sample('u1:0', 2, 0, 0.3, 0);
  animation.end();
  assert.equal(animation.tracks.size, 1);
  animation.clear();
  assert.equal(animation.tracks.size, 0);
});

test('walking phase is independent of render rate for the same traveled distance', () => {
  const run = (fps) => {
    const a = new TroopAnimator();
    for (let i = 0; i <= fps; i++)
      a.sample('u1:0', (i / fps) * 24, 0, i / fps, 0);
    return a.tracks.get('u1:0');
  };
  const a = run(30),
    b = run(60);
  assert.ok(Math.abs(a.phase - b.phase) < 1e-10);
  assert.ok(Math.abs(a.amount - b.amount) < 1e-10);
});

test('campaign and battle animation clocks use simulation seconds at half speed', () => {
  for (const battle of [false, true]) {
    const model = new DepthCampaign(battle),
      clock = createFixedClock(model);
    assert.equal(animationTime(model.state), 0);
    model.pause();
    for (let i = 0; i < 60; i++) clock.advance(1 / 60);
    assert.ok(Math.abs(animationTime(model.state) - 0.5) < 1e-8);
    model.pause();
    const frozen = animationTime(model.state);
    clock.advance(0.1);
    assert.equal(animationTime(model.state), frozen);
  }
});

test('each armed sprite reacts only to actual combat events and has a reload cycle', () => {
  for (let type = 0; type < 6; type++) {
    const unit = {
      shotTime: 10,
      shotKind: type >= 4 ? 'cannon' : 'musket',
      reload: 2,
    };
    assert.equal(combatPose({}, 10.05, 0, type).flash, 0);
    assert.equal(combatPose(unit, 9, 0, type).flash, 0);
    const shot = combatPose(unit, 10.06, 0, type);
    assert.ok(shot.flash > 0.9);
    assert.ok(shot.recoil > 0.9);
    assert.equal(shot.pose, type < 4 ? 1 : 0);
    const reload = combatPose(unit, 11, 0, type);
    assert.equal(reload.pose, type < 4 ? 2 : 0);
    assert.notEqual(reload.work, 0);
    assert.equal(reload.flash, 0);
    assert.equal(combatPose(unit, 20, 0, type).pose, 0);
    assert.equal(
      combatPose({ ...unit, routed: true }, 10.06, 0, type).flash,
      0,
    );
    assert.equal(combatPose({ ...unit, reload: 0 }, 11, 0, type).work, 0);
  }
});

test('volleys are staggered, melee has no gun flash, and support units never shoot', () => {
  const unit = { shotTime: 0, shotKind: 'musket', reload: 2 };
  assert.notEqual(
    combatPose(unit, 0.06, 0, 0).flash,
    combatPose(unit, 0.06, 1, 0).flash,
  );
  for (const type of [0, 1, 2, 3, 4, 5]) {
    const melee = combatPose({ ...unit, shotKind: 'melee' }, 0.2, 0, type);
    assert.ok(melee.melee > 0);
    assert.equal(melee.flash, 0);
    assert.equal(melee.smoke, 0);
    assert.equal(melee.pose, 0);
  }
  for (const type of [6, 7])
    assert.equal(combatPose(unit, 0.06, 0, type).flash, 0);
});

test('sprite rigs articulate feet separately while retaining stable heads and bounded weights', () => {
  for (const type of [0, 1, 2, 3, 6, 7]) {
    assert.equal(rigWeights(type, 0.4, 0.2)[1], 0);
    assert.ok(rigWeights(type, 0.3, 0.9)[1] > 0.8);
  }
  assert.ok(rigWeights(0, 0.24, 0.85)[0] > 0);
  assert.ok(rigWeights(0, 0.52, 0.85)[0] < 0);
  for (let type = 0; type < 8; type++) {
    const g = animatedGeometry(type, 0, 100);
    assert.ok(g.attributes.position.count > 100);
    assert.equal(g.attributes.troopMotion.count, 100);
    for (const weight of g.attributes.troopRig.array)
      assert.ok(Number.isFinite(weight) && Math.abs(weight) <= 1.01);
    g.dispose();
  }
});
