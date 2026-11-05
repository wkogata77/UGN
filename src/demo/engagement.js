import { WEAPONS, distance } from '../game/model.js';
import { angleDifference } from './turning.js';
import { clearShot } from '../game/tactics.js';
import { fieldFor } from '../game/battlefields.js';

export const FIRE_ARC = Math.acos(0.45);

export function insideArc(unit, enemy, margin = 0) {
  return (
    WEAPONS[unit.weapon].range <= 45 ||
    Math.abs(
      angleDifference(
        Math.atan2(enemy.y - unit.y, enemy.x - unit.x),
        unit.facing,
      ),
    ) <
      FIRE_ARC - margin
  );
}

export function visibleTarget(unit, enemy, battle) {
  return (
    enemy &&
    enemy.side !== unit.side &&
    enemy.men > 0 &&
    !enemy.routed &&
    enemy.arrival <= battle.time &&
    (unit.side === 'enemy' || enemy.visible)
  );
}

export function automaticTarget(unit, enemy, battle) {
  return (
    visibleTarget(unit, enemy, battle) &&
    distance(unit, enemy) <= WEAPONS[unit.weapon].range &&
    insideArc(unit, enemy) &&
    (distance(unit, enemy) < 45 ||
      clearShot(unit, enemy, battle, fieldFor(battle)))
  );
}

export function combatTarget(unit, battle) {
  const ordered = battle.units.find((e) => e.id === unit.attackId);
  if (visibleTarget(unit, ordered, battle)) {
    if (distance(unit, ordered) > WEAPONS[unit.weapon].range)
      unit.aimComplete = false;
    unit.fireTargetId = ordered.id;
    return ordered;
  }
  if (unit.attackId) {
    unit.attackId = null;
    if (unit.side === 'player') {
      unit.target = null;
      unit.waypoints = [];
    }
  }
  const previous = battle.units.find((e) => e.id === unit.fireTargetId);
  if (automaticTarget(unit, previous, battle)) return previous;
  let nearest = null,
    nearestDistance = Infinity;
  for (const enemy of battle.units) {
    if (!automaticTarget(unit, enemy, battle)) continue;
    const d = distance(unit, enemy);
    if (d < nearestDistance) {
      nearest = enemy;
      nearestDistance = d;
    }
  }
  unit.fireTargetId = nearest?.id || null;
  return nearest;
}

export function engagementFacing(unit, enemy) {
  if (!unit.attackId || !enemy) return unit.desiredFacing ?? null;
  if (distance(unit, enemy) > WEAPONS[unit.weapon].range) return null;
  if (unit.aimOrderId !== unit.attackId) {
    unit.aimOrderId = unit.attackId;
    unit.aimComplete = false;
  }
  if (unit.aimComplete) return null;
  if (insideArc(unit, enemy)) {
    unit.aimComplete = true;
    unit.turnVelocity = 0;
    return null;
  }
  const bearing = Math.atan2(enemy.y - unit.y, enemy.x - unit.x);
  return (
    bearing -
    Math.sign(angleDifference(bearing, unit.facing)) * (FIRE_ARC - 0.06)
  );
}

export function clearEngagement(unit) {
  unit.fireTargetId = null;
  unit.aimOrderId = null;
  unit.aimComplete = false;
}
