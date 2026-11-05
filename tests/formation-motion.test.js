import test from 'node:test';
import assert from 'node:assert/strict';
import { FormationMotion } from '../src/demo/formationMotion.js';
import {
  formationOffsets,
  formationPoint,
  formationRange,
} from '../src/demo/formationGeometry.js';
import { DepthCampaign, createFixedClock } from '../src/demo/model.js';

const unit = () => ({
  id: 'line',
  x: 400,
  y: 300,
  facing: 0,
  kind: 'infantry',
  men: 800,
  formation: 'line',
  arrival: 0,
});
const copy = (motion, u, time) => structuredClone(motion.positions(u, time));

test('turning soldiers walk toward slots individually instead of rotating as a rigid block', () => {
  const motion = new FormationMotion(),
    u = unit();
  motion.advance([u], 0);
  for (let i = 1; i <= 120; i++) {
    u.facing = (i / 60) * 0.3;
    motion.advance([u], i / 60);
  }
  const points = motion.positions(u, 2),
    goals = formationOffsets(u).map((p) => formationPoint(u, p));
  const errors = points.map((p, i) =>
    Math.hypot(p.x - goals[i].x, p.y - goals[i].y),
  );
  assert.ok(Math.max(...errors) > 1);
  assert.ok(Math.max(...errors) - Math.min(...errors) > 0.7);
  assert.ok(Math.max(...errors) < 15);
  assert.ok(points.some((p) => Math.abs(p.facing - u.facing) > 0.2));
  for (const p of points) assert.ok(Math.hypot(p.vx, p.vy) <= 52 + 1e-8);
  const range = formationRange(u, 156, points);
  assert.notDeepEqual(range.front, formationRange(u, 156).front);
});

test('soldiers settle back into exact ranks without idle drift', () => {
  const motion = new FormationMotion(),
    u = unit();
  motion.advance([u], 0);
  for (let i = 1; i <= 120; i++) {
    u.x += 0.3;
    u.facing += 0.004;
    motion.advance([u], i / 60);
  }
  for (let i = 121; i <= 900; i++) motion.advance([u], i / 60);
  const points = copy(motion, u, 15),
    offsets = formationOffsets(u);
  for (let i = 0; i < points.length; i++) {
    const goal = formationPoint(u, offsets[i]);
    assert.ok(Math.hypot(points[i].x - goal.x, points[i].y - goal.y) < 0.04);
    assert.equal(points[i].facing, u.facing);
  }
  motion.advance([u], 15.1);
  assert.deepEqual(copy(motion, u, 15.1), points);
});

test('casualties, deployment and removed regiments retain bounded presentation state', () => {
  const motion = new FormationMotion(),
    u = unit();
  motion.advance([u], 0);
  u.men = 270;
  motion.advance([u], 0.1);
  assert.equal(motion.positions(u, 0.1).length, 30);
  u.x = 1000;
  const relocated = motion.positions(u, 0.1);
  assert.ok(relocated.every((p) => p.x > 950));
  motion.advance([], 0.2);
  assert.equal(motion.groups.size, 0);
});

test('soldier motion uses the fixed simulation clock and remains frozen on pause', () => {
  const run = (fps) => {
    const model = new DepthCampaign(true),
      clock = createFixedClock(model),
      u = model.state.battle.units[0];
    model.select([u.id]);
    model.moveUnits({ x: 450, y: 600 });
    model.state.paused = false;
    for (let i = 0; i < fps * 3; i++) clock.advance(1 / fps);
    model.state.paused = true;
    const frozen = structuredClone(model.soldierPositions(u));
    clock.advance(10);
    assert.deepEqual(model.soldierPositions(u), frozen);
    return frozen;
  };
  assert.deepEqual(run(30), run(60));
});
