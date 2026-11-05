import * as THREE from 'three';

const WORLD_UP = new THREE.Vector3(0, 1, 0);
const SUPPORT_OFFSETS = [-0.48, -0.24, 0.24, 0.48];

export function terrainSampler(geometry) {
  const {
    widthSegments: columns,
    heightSegments: rows,
    width,
    height,
  } = geometry.parameters;
  const positions = geometry.attributes.position;
  const left = positions.getX(0),
    top = positions.getZ(0);
  // Match the rendered triangles, not the continuous height function between them.
  return (x, y) => {
    const gx = Math.max(0, Math.min(columns, ((x - left) / width) * columns));
    const gy = Math.max(0, Math.min(rows, ((y - top) / height) * rows));
    const col = Math.min(columns - 1, Math.floor(gx));
    const row = Math.min(rows - 1, Math.floor(gy));
    const i = row * (columns + 1) + col;
    const fx =
      (Math.max(left, Math.min(left + width, x)) - positions.getX(i)) /
      (positions.getX(i + 1) - positions.getX(i));
    const fy =
      (Math.max(top, Math.min(top + height, y)) - positions.getZ(i)) /
      (positions.getZ(i + columns + 1) - positions.getZ(i));
    const a = positions.getY(i),
      b = positions.getY(i + 1);
    const c = positions.getY(i + columns + 1),
      d = positions.getY(i + columns + 2);
    return fx + fy <= 1
      ? a + (b - a) * fx + (c - a) * fy
      : d + (c - d) * (1 - fx) + (b - d) * (1 - fy);
  };
}

export function spriteGround(height, x, y, size, right = { x: 1, z: 0 }) {
  // Include wheels, hooves, and the widest animated stride, not just the center.
  let support = height(x, y);
  for (const offset of SUPPORT_OFFSETS)
    support = Math.max(
      support,
      height(x + right.x * size * offset, y + right.z * size * offset),
    );
  return support + 0.8;
}

export function uprightSpriteFrame(cameraQuaternion) {
  const right = new THREE.Vector3(1, 0, 0).applyQuaternion(cameraQuaternion);
  right.y = 0;
  right.normalize();
  const normal = new THREE.Vector3().crossVectors(right, WORLD_UP);
  const rotation = new THREE.Quaternion().setFromRotationMatrix(
    new THREE.Matrix4().makeBasis(right, WORLD_UP, normal),
  );
  const screenUp = WORLD_UP.clone().applyQuaternion(cameraQuaternion);
  return { right, rotation, heightScale: 1 / Math.max(0.1, screenUp.y) };
}

export function placeGroundedSprite(
  object,
  frame,
  height,
  x,
  y,
  size,
  mirror = 1,
) {
  const support = spriteGround(height, x, y, size, frame.right);
  const worldHeight = size * frame.heightScale;
  // Keep the painted size, but stand vertically instead of leaning into hills.
  object.position.set(x, support + worldHeight * 0.5, y);
  object.quaternion.copy(frame.rotation);
  object.scale.set(mirror * size, worldHeight, 1);
  object.updateMatrix();
}

export function withBridgeDecks(terrain, decks) {
  return (x, y) => {
    let height = terrain(x, y);
    for (const deck of decks)
      if (
        Math.abs(x - deck.x) <= deck.halfX &&
        Math.abs(y - deck.y) <= deck.halfY
      )
        height = Math.max(height, deck.height);
    return height;
  };
}
