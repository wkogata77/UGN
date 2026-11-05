import { soldierPosition } from '../game/formations.js';

export function formationOffsets(unit) {
  const artillery = unit.kind === 'artillery';
  const count = artillery
    ? Math.ceil(unit.men / 30)
    : Math.min(100, Math.max(4, Math.ceil(unit.men / 9)));
  const spread = unit.role === 'skirmishers' ? 1.7 : 1;
  return Array.from({ length: count }, (_, i) => {
    const p = artillery
      ? { x: (i - (count - 1) / 2) * 25, y: 0 }
      : soldierPosition(unit, i, count);
    return { x: p.x * spread, y: p.y * spread };
  });
}

export function formationPoint(unit, offset) {
  const angle = unit.facing - Math.PI / 2;
  return {
    x: unit.x + offset.x * Math.cos(angle) - offset.y * Math.sin(angle),
    y: unit.y + offset.x * Math.sin(angle) + offset.y * Math.cos(angle),
  };
}

export function formationFront(unit, positions) {
  const angle = unit.facing - Math.PI / 2;
  const offsets = positions
    ? positions.map((p) => ({
        x: (p.x - unit.x) * Math.cos(angle) + (p.y - unit.y) * Math.sin(angle),
        y: -(p.x - unit.x) * Math.sin(angle) + (p.y - unit.y) * Math.cos(angle),
      }))
    : formationOffsets(unit);
  const spread = unit.role === 'skirmishers' ? 1.7 : 1;
  const halfFile =
    (unit.kind === 'artillery' ? 12.5 : unit.kind === 'cavalry' ? 4 : 2.5) *
    spread;
  const halfRank = (unit.kind === 'artillery' ? 6 : 3) * spread;
  // Positive local Y is the front rank; include half a file/rank at the edges.
  const front = Math.max(...offsets.map((p) => p.y), 0) + halfRank;
  return {
    left: formationPoint(unit, {
      x: Math.max(...offsets.map((p) => p.x), 0) + halfFile,
      y: front,
    }),
    right: formationPoint(unit, {
      x: Math.min(...offsets.map((p) => p.x), 0) - halfFile,
      y: front,
    }),
  };
}

export function formationRange(unit, range, positions) {
  const melee = range <= 45;
  const half = melee ? Math.PI : Math.acos(0.45);
  // Keep the far boundary tied to the simulation's center-measured weapon range.
  const arc = Array.from({ length: 51 }, (_, i) => ({
    x: unit.x + Math.cos(unit.facing - half + (i / 50) * half * 2) * range,
    y: unit.y + Math.sin(unit.facing - half + (i / 50) * half * 2) * range,
  }));
  const front = melee ? null : formationFront(unit, positions);
  return {
    arc,
    front,
    outline: front ? [front.left, ...arc, front.right] : arc,
  };
}
