import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { MeshBVH, acceleratedRaycast } from 'three-mesh-bvh';
import {
  FrameInvalidation,
  troopDetail,
  uploadInstances,
} from '../src/demo/renderPerformance.js';
import { animatedGeometry } from '../src/demo/troopAnimation.js';
import { landscapeFor, reliefGeometry } from '../src/demo/terrain.js';
import { DepthCampaign } from '../src/demo/model.js';

test('paused frames sleep until invalidated and running frames are never throttled', () => {
  const gate = new FrameInvalidation();
  assert.equal(gate.consume(false), true);
  for (let i = 0; i < 120; i++) assert.equal(gate.consume(false), false);
  gate.invalidate();
  assert.equal(gate.consume(false), true);
  assert.equal(gate.consume(false), false);
  for (let i = 0; i < 120; i++) assert.equal(gate.consume(true), true);
  gate.invalidate();
  assert.equal(gate.consume(false), true);
});

test('small sprites keep an articulated rig with substantially fewer triangles', () => {
  assert.equal(troopDetail(17), 'low');
  assert.equal(troopDetail(35), 'medium');
  assert.equal(troopDetail(70), 'high');
  for (let type = 0; type < 8; type++) {
    for (const [detail, vertices] of [
      ['low', 35],
      ['medium', 77],
      ['high', 187],
    ]) {
      const g = animatedGeometry(type, 0, 12, detail);
      assert.equal(
        g.attributes.position.count,
        type < 2 && detail === 'low' ? 49 : vertices,
      );
      assert.ok(g.index.count / 3 < 480);
      assert.ok(g.attributes.troopRig.array.some((weight) => weight !== 0));
      assert.equal(g.attributes.troopMotion.count, 12);
      g.dispose();
    }
  }
});

test('instance updates upload only the live prefix, not unused capacity', () => {
  const attribute = new THREE.InstancedBufferAttribute(
    new Float32Array(1200 * 4),
    4,
  );
  uploadInstances(attribute, 23);
  assert.deepEqual(attribute.updateRanges, [{ start: 0, count: 92 }]);
  const version = attribute.version;
  uploadInstances(attribute, 0);
  assert.equal(attribute.version, version);
  uploadInstances(attribute, 7);
  assert.deepEqual(attribute.updateRanges, [{ start: 0, count: 28 }]);
});

test('accelerated terrain picking matches native raycasts on campaign and battle relief', () => {
  const nativeRaycast = THREE.Mesh.prototype.raycast;
  for (const battle of [false, true]) {
    const data = landscapeFor(new DepthCampaign(battle).state);
    for (const relief of [0, 1]) {
      const geometry = reliefGeometry(data, relief);
      geometry.boundsTree = new MeshBVH(geometry);
      const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial());
      mesh.updateMatrixWorld();
      const ray = new THREE.Raycaster();
      ray.firstHitOnly = true;
      for (const [x, z] of [
        [-900, -400],
        [0, 0],
        [230, 195],
        [305, 430],
        [720, 480],
        [1440, 960],
        [2300, 1800],
      ]) {
        ray.set(
          new THREE.Vector3(x, 1400, z + 400),
          new THREE.Vector3(0, -1, -0.28).normalize(),
        );
        const expected = [],
          actual = [];
        nativeRaycast.call(mesh, ray, expected);
        acceleratedRaycast.call(mesh, ray, actual);
        expected.sort((a, b) => a.distance - b.distance);
        assert.ok(expected.length && actual.length);
        assert.ok(actual[0].point.distanceTo(expected[0].point) < 1e-7);
      }
      geometry.boundsTree = null;
      geometry.dispose();
      mesh.material.dispose();
    }
  }
  assert.equal(
    THREE.Mesh.prototype.raycast,
    nativeRaycast,
    'do not patch Three.js globally',
  );
});
