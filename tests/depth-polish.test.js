import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { cameraMovement } from '../src/demo/cameraMovement.js';
import { gaitCadence, spriteDirection } from '../src/demo/troopAnimation.js';
import {
  terrainSampler,
  spriteGround,
  withBridgeDecks,
  uprightSpriteFrame,
  placeGroundedSprite,
} from '../src/demo/spriteGround.js';
import { landscapeFor, reliefGeometry } from '../src/demo/terrain.js';
import { artillerySpread, artilleryVolley } from '../src/demo/artillery.js';
import { DepthCampaign } from '../src/demo/model.js';
import { Campaign } from '../src/game/model.js';

test('WASD is normalized, zoom-aware, frame-rate independent and stall-bounded', () => {
  const keys = (...codes) => new Set(codes);
  const d = cameraMovement(keys('KeyD'), 1 / 60, 1);
  assert.deepEqual(cameraMovement(keys('KeyW', 'KeyS'), 1 / 60, 1), {
    x: 0,
    y: 0,
  });
  assert.ok(cameraMovement(keys('KeyW'), 1 / 60, 1).y < 0);
  assert.ok(cameraMovement(keys('KeyA'), 1 / 60, 1).x < 0);
  assert.equal(cameraMovement(keys('KeyD'), 1 / 30, 1).x, d.x * 2);
  assert.equal(cameraMovement(keys('KeyD'), 1 / 60, 0.5).x, d.x / 2);
  assert.ok(
    Math.abs(
      cameraMovement(keys('KeyW', 'KeyD'), 1 / 60, 1).x - d.x / Math.sqrt(2),
    ) < 1e-9,
  );
  assert.equal(cameraMovement(keys('KeyD'), 10, 1).x, 24);
});

test('ordinary marching alternates poses every one to two seconds at half speed', () => {
  for (const [type, speed] of [
    [0, 24],
    [1, 30],
    [2, 49],
    [3, 40],
    [6, 35],
    [7, 24],
  ]) {
    const secondsBetweenPoses = 0.5 / (gaitCadence(speed, type) * 0.5);
    assert.ok(secondsBetweenPoses >= 1 && secondsBetweenPoses <= 2);
  }
  assert.equal(spriteDirection(0), 0);
  assert.equal(spriteDirection(Math.PI), 0);
  assert.equal(spriteDirection(-Math.PI / 2), 1);
  assert.equal(spriteDirection(Math.PI / 2), 2);
});

test('sprite ground sampling matches actual rendered triangles on both maps', () => {
  for (const battle of [false, true]) {
    const data = landscapeFor(new DepthCampaign(battle).state);
    for (const relief of [0, 1]) {
      const geometry = reliefGeometry(data, relief);
      const height = terrainSampler(geometry);
      const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
      mesh.updateMatrixWorld();
      const ray = new THREE.Raycaster();
      for (const [x, y] of [
        [230, 195],
        [780, 145],
        [490, 435],
        [1140, -130],
        [260, -190],
        [1370, 910],
      ]) {
        ray.set(new THREE.Vector3(x, 2000, y), new THREE.Vector3(0, -1, 0));
        const hit = ray.intersectObject(mesh)[0];
        assert.ok(Math.abs(height(x, y) - hit.point.y) < 1e-6);
        const support = spriteGround(height, x, y, 43);
        for (const offset of [-43 * 0.22, 0, 43 * 0.22])
          assert.ok(support > height(x + offset, y));
      }
      geometry.dispose();
      mesh.material.dispose();
    }
  }
});

test('troops stand on bridge decks rather than the riverbed underneath', () => {
  const height = withBridgeDecks(
    () => -5,
    [{ x: 720, y: 480, halfX: 49, halfY: 28, height: 6.5 }],
  );
  assert.equal(height(720, 480), 6.5);
  assert.equal(height(600, 480), -5);
  assert.ok(spriteGround(height, 720, 480, 17) > 6.5);
});

test('sprites stand vertically on hills while retaining their projected size', () => {
  const camera = new THREE.OrthographicCamera(-100, 100, 100, -100, 1, 6000);
  camera.position.set(0, 1250, 720);
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld();
  const frame = uprightSpriteFrame(camera.quaternion);
  const object = new THREE.Object3D();
  for (const size of [17, 22, 23, 31, 39, 43]) {
    for (const mirror of [-1, 1]) {
      const terrain = (x, y) => x * 0.8 - y;
      placeGroundedSprite(object, frame, terrain, 50, 30, size, mirror);
      const bottom = new THREE.Vector3(0, -0.5, 0).applyMatrix4(object.matrix);
      const top = new THREE.Vector3(0, 0.5, 0).applyMatrix4(object.matrix);
      assert.equal(top.x, bottom.x);
      assert.equal(top.z, bottom.z, 'sprite must not lean uphill');
      const projectedHeight =
        bottom.clone().project(camera).y - top.clone().project(camera).y;
      assert.ok(Math.abs(Math.abs(projectedHeight) - size / 100) < 1e-9);
      for (const x of [-0.48, -0.24, 0, 0.24, 0.48]) {
        const foot = new THREE.Vector3(x, -0.5, 0).applyMatrix4(object.matrix);
        assert.ok(foot.y > terrain(foot.x, foot.z));
      }
    }
  }
});

test('artillery spread produces reproducible hits and misses with skill and fatigue effects', () => {
  const source = {
    id: 'gun',
    x: 0,
    y: 0,
    men: 120,
    skills: { firearms: 30 },
    condition: 100,
  };
  const target = {
    x: 350,
    y: 0,
    men: 800,
    kind: 'infantry',
    formation: 'line',
    facing: Math.PI,
  };
  assert.deepEqual(
    artilleryVolley(source, target, 7),
    artilleryVolley(source, target, 7),
  );
  assert.notDeepEqual(
    artilleryVolley(source, target, 7),
    artilleryVolley(source, target, 8),
  );
  const shots = Array.from({ length: 100 }, (_, i) =>
    artilleryVolley(source, target, i),
  ).flat();
  assert.ok(shots.some((p) => p.hit) && shots.some((p) => !p.hit));
  assert.ok(artillerySpread(source, 350) > artillerySpread(source, 100));
  assert.ok(
    artillerySpread(source, 350) >
      artillerySpread({ ...source, skills: { firearms: 90 } }, 350),
  );
  assert.ok(
    artillerySpread(source, 350) <
      artillerySpread({ ...source, condition: 20 }, 350),
  );
});

test('demo artillery damage follows its recorded impacts and does not change original campaign policy', () => {
  const model = new DepthCampaign(true);
  const source = model.state.battle.units.find((u) => u.kind === 'artillery');
  const target = model.state.battle.units.find((u) => u.side !== source.side);
  const damage = model.artilleryVolley(source, target, 100);
  assert.equal(
    damage,
    (100 * source.artilleryImpacts.filter((p) => p.hit).length) /
      source.artilleryImpacts.length,
  );
  assert.deepEqual(
    model.state.battle.artilleryImpacts,
    source.artilleryImpacts,
  );
  for (let i = 0; i < 100; i++) model.artilleryVolley(source, target, 100);
  assert.ok(model.state.battle.artilleryImpacts.length <= 128);
  assert.equal(typeof new Campaign(null).artilleryVolley, 'undefined');
});

test('melee-only attack orders close the distance instead of stopping at musket range', () => {
  const model = new DepthCampaign(true),
    b = model.state.battle;
  const own = b.units.find((u) => u.id === 'u1');
  const target = b.units.find((u) => u.side === 'enemy');
  Object.assign(own, { x: 520, y: 340, facing: 0 });
  Object.assign(target, { x: 620, y: 340, visible: true });
  model.select([own.id]);
  model.holdFire();
  model.moveUnits(target, target.id);
  model.state.paused = false;
  model.update(0.1);
  assert.ok(own.x > 520 && own.target);
  assert.ok(own.holdFire && !own.shotKind);
});
