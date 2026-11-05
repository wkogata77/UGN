import { formationOffsets } from './formationGeometry.js';

export const angleDifference = (target, facing) =>
  Math.atan2(Math.sin(target - facing), Math.cos(target - facing));

const footprints = new WeakMap();

export function turningRate(unit) {
  if (unit.stock != null || unit.kind === 'wagon') return 0.32;
  if (unit.radius != null || unit.kind === 'general') return 0.75;
  const key = `${unit.kind}:${unit.men}:${unit.role}:${unit.formation}:${unit.formationChange?.to}`;
  let footprint = footprints.get(unit);
  if (footprint?.key !== key) {
    const radius = (formation) =>
      Math.max(
        12,
        ...formationOffsets({ ...unit, formation, formationChange: null }).map(
          (p) => Math.hypot(p.x, p.y),
        ),
      );
    footprint = {
      key,
      radius: Math.max(
        radius(unit.formation),
        radius(unit.formationChange?.to || unit.formation),
      ),
    };
    footprints.set(unit, footprint);
  }
  const mounted = unit.kind === 'cavalry' && !unit.dismounted;
  const guns = unit.kind === 'artillery';
  const march = mounted ? 29 : guns ? (unit.limbered ? 16 : 9) : 17;
  const condition =
    0.7 + Math.max(0, Math.min(100, unit.condition ?? 100)) * 0.003;
  // Outer files wheel at marching pace instead of orbiting the center at a sprint.
  return (
    Math.min(mounted ? 0.65 : guns ? 0.28 : 0.42, march / footprint.radius) *
    condition
  );
}

export function turnFormation(unit, angle, dt) {
  if (!(dt > 0) || !Number.isFinite(angle)) return;
  unit.facing = Number.isFinite(unit.facing) ? unit.facing : 0;
  const error = angleDifference(angle, unit.facing);
  const limit = turningRate(unit);
  const acceleration = limit * 2.5;
  const desired = Math.sign(error) * Math.min(limit, Math.abs(error) * 2);
  let velocity = unit.turnVelocity || 0;
  velocity += Math.max(
    -acceleration * dt,
    Math.min(acceleration * dt, desired - velocity),
  );
  const step = velocity * dt;
  if (
    Math.abs(error) < 0.0001 ||
    (Math.sign(step) === Math.sign(error) && Math.abs(step) >= Math.abs(error))
  ) {
    unit.facing += error;
    unit.turnVelocity = 0;
  } else {
    unit.facing += step;
    unit.turnVelocity = velocity;
  }
}

export function movementAlignment(unit, bearing) {
  if (unit.fallingBack) return 1;
  const alignment = Math.max(
    0,
    Math.cos(angleDifference(bearing, unit.facing || 0)),
  );
  return alignment * alignment;
}
