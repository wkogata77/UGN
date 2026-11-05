import test from 'node:test';
import assert from 'node:assert/strict';
import {
  formationOffsets,
  formationPoint,
  formationFront,
  formationRange,
} from '../src/demo/formationGeometry.js';
import { soldierPosition } from '../src/game/formations.js';

const unit = (changes = {}) => ({
  x: 500,
  y: 400,
  facing: 0,
  men: 800,
  kind: 'infantry',
  formation: 'line',
  ...changes,
});
const near = (a, b) =>
  assert.ok(Math.abs(a - b) < 1e-8, `${a} differs from ${b}`);
const width = (front) =>
  Math.hypot(front.left.x - front.right.x, front.left.y - front.right.y);

test('range sides start at the front formation edges, not the regiment center', () => {
  const u = unit(),
    result = formationRange(u, 156);
  near(result.front.left.x, 512);
  near(result.front.right.x, 512);
  near(result.front.left.y, 342.5);
  near(result.front.right.y, 457.5);
  assert.deepEqual(result.outline[0], result.front.left);
  assert.deepEqual(result.outline.at(-1), result.front.right);
  assert.ok(!result.outline.some((p) => p.x === u.x && p.y === u.y));
});

test('range flanks track line, column, square, and casualties', () => {
  near(width(formationFront(unit())), 115);
  near(width(formationFront(unit({ formation: 'column' }))), 35);
  near(width(formationFront(unit({ formation: 'square' }))), 59);
  assert.ok(
    width(formationFront(unit({ men: 200 }))) < width(formationFront(unit())),
  );
});

test('range frontage changes gradually with the same interpolated ranks as the sprites', () => {
  const u = unit({
    formationChange: { from: 'line', to: 'column', elapsed: 0, duration: 8 },
  });
  const start = width(formationFront(u));
  u.formationChange.elapsed = 4;
  const middle = width(formationFront(u));
  u.formationChange.elapsed = 8;
  const end = width(formationFront(u));
  assert.ok(start > middle && middle > end);
  near(start, width(formationFront(unit())));
  near(end, width(formationFront(unit({ formation: 'column' }))));
});

test('rotating the regiment rotates its front corners without changing width', () => {
  for (const facing of [Math.PI / 2, Math.PI, -Math.PI / 2, 0.37]) {
    const u = unit({ facing }),
      front = formationFront(u);
    near(width(front), 115);
    const center = {
      x: (front.left.x + front.right.x) / 2,
      y: (front.left.y + front.right.y) / 2,
    };
    near(center.x, u.x + Math.cos(facing) * 12);
    near(center.y, u.y + Math.sin(facing) * 12);
  }
});

test('artillery batteries, cavalry, and loose skirmishers use their rendered frontage', () => {
  near(width(formationFront(unit({ kind: 'artillery', men: 120 }))), 100);
  near(width(formationFront(unit({ kind: 'artillery', men: 30 }))), 25);
  near(width(formationFront(unit({ kind: 'cavalry', men: 240 }))), 64);
  near(width(formationFront(unit({ role: 'skirmishers' }))), 115 * 1.7);
});

test('edge anchoring does not extend maximum range or change the far firing angles', () => {
  const u = unit({ facing: 0.7 }),
    range = 156,
    { arc } = formationRange(u, range);
  for (const p of arc) near(Math.hypot(p.x - u.x, p.y - u.y), range);
  for (const p of [arc[0], arc.at(-1)])
    near(Math.cos(Math.atan2(p.y - u.y, p.x - u.x) - u.facing), 0.45);
  const melee = formationRange(u, 38);
  assert.equal(melee.front, null);
  assert.equal(melee.outline.length, 51);
  near(melee.arc[0].x, melee.arc.at(-1).x);
  near(melee.arc[0].y, melee.arc.at(-1).y);
});

test('shared layout retains the existing sprite count and positions', () => {
  for (const kind of ['infantry', 'cavalry', 'artillery']) {
    for (const formation of ['line', 'column', 'square']) {
      const u = unit({ kind, formation, role: 'skirmishers', facing: 0.43 });
      const count =
        kind === 'artillery'
          ? Math.ceil(u.men / 30)
          : Math.min(100, Math.max(4, Math.ceil(u.men / 9)));
      const offsets = formationOffsets(u);
      assert.equal(offsets.length, count);
      offsets.forEach((p, i) => {
        const old =
          kind === 'artillery'
            ? { x: (i - (count - 1) / 2) * 25, y: 0 }
            : soldierPosition(u, i, count);
        const a = u.facing - Math.PI / 2,
          world = formationPoint(u, p);
        near(world.x, u.x + (old.x * Math.cos(a) - old.y * Math.sin(a)) * 1.7);
        near(world.y, u.y + (old.x * Math.sin(a) + old.y * Math.cos(a)) * 1.7);
      });
    }
  }
});
