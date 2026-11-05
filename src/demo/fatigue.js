import { angleDifference } from './turning.js';

export function unitActivity(unit) {
  return {
    x: unit.x,
    y: unit.y,
    facing: unit.facing,
    working: !!unit.formationChange || unit.limberChange > 0,
  };
}

export function combatExertion(source, target, time, melee, hit) {
  const until = time + source.reload + 0.5;
  source.fightingUntil = Math.max(source.fightingUntil || 0, until);
  if (melee) source.meleeUntil = Math.max(source.meleeUntil || 0, until);
  if (hit) {
    target.fightingUntil = Math.max(target.fightingUntil || 0, until);
    if (melee) target.meleeUntil = Math.max(target.meleeUntil || 0, until);
  }
}

export function updateCondition(unit, before, time, dt) {
  if (!before || !(dt > 0)) return;
  const moving = Math.hypot(unit.x - before.x, unit.y - before.y) > 0.0001;
  const turning =
    Math.abs(angleDifference(unit.facing, before.facing)) > 0.0001;
  const working =
    before.working || !!unit.formationChange || unit.limberChange > 0;
  const fighting = (unit.fightingUntil || 0) > time;
  const melee = (unit.meleeUntil || 0) > time;
  if (moving || turning || working || fighting) unit.restAfter = time + 2;
  const stamina = 1.15 - (unit.skills?.stamina ?? 30) / 200;
  const march = moving
    ? unit.charging
      ? 1.6
      : unit.running || unit.routed
        ? 0.9
        : 0.2
    : 0;
  const exertion =
    march * (unit.perk === 'march' ? 0.75 : 1) +
    (melee ? 1.4 : fighting ? 0.4 : 0) +
    (working ? 0.3 : turning ? 0.16 : 0);
  const recovery = !exertion && time >= (unit.restAfter || 0) ? 0.7 : 0;
  unit.condition = Math.max(
    0,
    Math.min(100, unit.condition + dt * (recovery - exertion * stamina)),
  );
  if (unit.condition < 12) {
    unit.running = false;
    unit.charging = false;
  }
}
