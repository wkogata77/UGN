import { formationOffsets } from './formationGeometry.js';

export function artillerySpread(source, range) {
  const skill = Math.max(0, Math.min(100, source.skills?.firearms ?? 30));
  const fatigue = 100 - Math.max(0, Math.min(100, source.condition ?? 100));
  return (4 + range * 0.055) * (1.25 - skill * 0.006) * (1 + fatigue * 0.004);
}

export function artilleryVolley(source, target, sequence) {
  let seed = sequence >>> 0;
  for (const c of source.id)
    seed = (Math.imul(seed, 31) + c.charCodeAt(0)) >>> 0;
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  const range = Math.hypot(target.x - source.x, target.y - source.y);
  const spread = artillerySpread(source, range);
  const bearing = Math.atan2(target.y - source.y, target.x - source.x);
  const angle = (target.facing ?? 0) - Math.PI / 2;
  const offsets = formationOffsets(target);
  const xs = offsets.map((p) => p.x),
    ys = offsets.map((p) => p.y);
  const count = Math.max(1, Math.min(12, Math.ceil(source.men / 30)));
  const canister = range < 120;
  const margin = canister ? 9 : 5;
  return Array.from({ length: count }, () => {
    // A battery-level spread abstraction, not a historical ballistic simulation.
    const along = (random() + random() - 1) * spread * 2.5;
    const across = (random() + random() - 1) * spread * 1.5;
    const dx = Math.cos(bearing) * along - Math.sin(bearing) * across;
    const dy = Math.sin(bearing) * along + Math.cos(bearing) * across;
    const localX = dx * Math.cos(angle) + dy * Math.sin(angle);
    const localY = -dx * Math.sin(angle) + dy * Math.cos(angle);
    return {
      x: target.x + dx,
      y: target.y + dy,
      hit:
        localX >= Math.min(...xs) - margin &&
        localX <= Math.max(...xs) + margin &&
        localY >= Math.min(...ys) - margin &&
        localY <= Math.max(...ys) + margin,
      kind: canister ? 'canister' : 'roundshot',
    };
  });
}
