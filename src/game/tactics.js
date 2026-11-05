import { fieldFor, fieldTerrain, lineOfSight } from './battlefields.js';
import { commandEfficiency } from './progression.js';
import { advanceFormation } from './formations.js';

const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const clamp = (v, lo = 0, hi = 100) => Math.max(lo, Math.min(hi, v));
const active = (b, side) =>
  b.units.filter(
    (u) => u.side === side && u.men > 0 && !u.routed && u.arrival <= b.time,
  );

export function updateVisibility(b) {
  const field = fieldFor(b),
    observers = [
      ...active(b, 'player'),
      ...b.commanders.filter((c) => !c.unavailable),
    ];
  for (const unit of b.units)
    unit.visible =
      unit.side === 'player' ||
      (unit.arrival <= b.time &&
        observers.some((from) => lineOfSight(from, unit, field)));
  for (const wagon of b.wagons)
    wagon.visible =
      wagon.side === 'player' ||
      observers.some((from) => lineOfSight(from, wagon, field));
  b.visibleCells = Array.from({ length: 600 }, (_, i) => {
    const p = { x: (i % 30) * 48 + 24, y: Math.floor(i / 30) * 48 + 24 };
    return observers.some((from) => lineOfSight(from, p, field));
  });
}

function setGoal(model, unit, point, facing = null) {
  if (!unit.goal || distance(unit.goal, point) > 45 || !unit.target)
    model.pathUnit(unit, point, facing);
}

function planEnemy(model, weapons) {
  const b = model.state.battle,
    field = fieldFor(b),
    enemies = active(b, 'enemy'),
    players = active(b, 'player');
  const advance = b.playerEdge === 'east' ? 1 : -1;
  for (const [i, unit] of enemies.entries()) {
    const seen = players.filter((p) =>
      enemies.some((observer) => lineOfSight(observer, p, field)),
    );
    const target = seen.sort((a, c) => {
      const score = (p) =>
        distance(unit, p) -
        (unit.kind === 'cavalry' && p.kind === 'artillery' ? 160 : 0) -
        (p.routed ? 70 : 0);
      return score(a) - score(c);
    })[0];
    const wagon = b.wagons.find(
      (w) => w.side === 'enemy' && w.health > 0 && w.stock > 0,
    );
    unit.attackId = target?.id || null;
    if (unit.condition < 18 || (unit.ammo < 12 && wagon))
      unit.recovering = true;
    if (unit.recovering && unit.condition >= 45 && (!wagon || unit.ammo >= 45))
      unit.recovering = false;
    if (unit.recovering) {
      unit.charging = false;
      unit.fallingBack = true;
      setGoal(
        model,
        unit,
        wagon || { x: b.playerEdge === 'west' ? 1300 : 140, y: unit.y },
      );
      continue;
    }
    unit.fallingBack = false;
    if (!target) {
      setGoal(model, unit, {
        x: field.objective.x - advance * (unit.kind === 'artillery' ? 220 : 25),
        y: clamp(field.objective.y + ((i % 3) - 1) * 36, 80, 880),
      });
      continue;
    }
    const d = distance(unit, target),
      range = weapons[unit.weapon].range;
    if (unit.aiRole === 'reserve' && b.time < 40 && d > 220) {
      unit.attackId = null;
      unit.target = null;
      unit.waypoints = [];
      continue;
    }
    if (
      unit.flankTarget === target.id &&
      unit.goal &&
      distance(unit, unit.goal) < 25
    )
      unit.flankReady = true;
    if (
      unit.kind === 'cavalry' &&
      d > 180 &&
      !unit.flankReady &&
      field.river !== true
    ) {
      unit.charging = false;
      unit.flankTarget = target.id;
      setGoal(model, unit, {
        x: target.x - advance * 110,
        y: clamp(target.y + (unit.y < 480 ? -190 : 190), 75, 885),
      });
    } else if (
      unit.kind === 'cavalry' &&
      !unit.dismounted &&
      unit.condition > 30 &&
      d < 190 &&
      target.formation !== 'square'
    ) {
      unit.charging = true;
      setGoal(model, unit, target);
    } else if (unit.ammo < 1 && !wagon && unit.kind !== 'artillery') {
      unit.charging = unit.condition > 30;
      setGoal(model, unit, target);
    } else if (d > range * 0.85 || !clearShot(unit, target, b, field)) {
      unit.charging = false;
      if (
        unit.kind === 'artillery' &&
        !unit.limbered &&
        d > range + 200 &&
        !unit.limberChange
      ) {
        unit.limberChange = 5;
        unit.nextLimber = true;
      }
      setGoal(model, unit, {
        x:
          target.x -
          advance * range * (unit.blocked === 'Obstructed' ? 0.4 : 0.72),
        y: target.y + (i % 2 ? -42 : 42),
      });
    } else {
      unit.charging = false;
      unit.target = null;
      unit.waypoints = [];
      if (unit.kind === 'artillery' && unit.limbered && !unit.limberChange) {
        unit.limberChange = 5;
        unit.nextLimber = false;
      }
    }
  }
}

function walk(model, unit, dt, speed) {
  if (!unit.target) return;
  const d = distance(unit, unit.target);
  let step = Math.min(d, dt * speed);
  if (d > 0.1) {
    const bearing = Math.atan2(unit.target.y - unit.y, unit.target.x - unit.x);
    if (!unit.fallingBack) model.turnUnit(unit, bearing, dt);
    step *= model.movementSpeedScale?.(unit, bearing) ?? 1;
    unit.x += ((unit.target.x - unit.x) / d) * step;
    unit.y += ((unit.target.y - unit.y) / d) * step;
  }
  if (d <= step + 1) {
    unit.target = unit.waypoints?.shift() || null;
    if (!unit.target && unit.orderQueue?.length) {
      const order = unit.orderQueue.shift();
      model.pathUnit(unit, order.point, order.facing);
    }
    if (!unit.target) unit.fallingBack = false;
  }
}

function updateWagons(model, dt) {
  const b = model.state.battle;
  for (const wagon of b.wagons) {
    if (wagon.health <= 0) continue;
    const threat = active(b, wagon.side === 'player' ? 'enemy' : 'player').find(
      (u) => distance(u, wagon) < 75,
    );
    if (threat) {
      wagon.health = Math.max(
        0,
        wagon.health - dt * (threat.kind === 'cavalry' ? 9 : 5),
      );
      wagon.underAttack = true;
      if (wagon.health === 0) {
        wagon.stock = 0;
        wagon.target = null;
        model.log(
          `${wagon.side === 'player' ? 'French' : 'Austrian'} supply train destroyed.`,
        );
      }
    } else wagon.underAttack = false;
    walk(model, wagon, dt, 22);
    if (wagon.underAttack || wagon.stock <= 0 || wagon.health <= 0) continue;
    for (const u of active(b, wagon.side)) {
      if (distance(u, wagon) > 145 || u.ammo >= 100 || wagon.stock <= 0)
        continue;
      const amount = Math.min(100 - u.ammo, dt * 4, wagon.stock);
      u.ammo += amount;
      wagon.stock -= amount;
    }
  }
}

export function clearShot(unit, enemy, b, field) {
  if (!lineOfSight(unit, enemy, field, true)) return false;
  const dx = enemy.x - unit.x,
    dy = enemy.y - unit.y,
    length = dx * dx + dy * dy;
  if (!length) return true;
  return !active(b, unit.side).some((other) => {
    if (
      other.id === unit.id ||
      other.parentId === unit.id ||
      unit.parentId === other.id
    )
      return false;
    const t = ((other.x - unit.x) * dx + (other.y - unit.y) * dy) / length;
    return (
      t > 0.15 &&
      t < 0.9 &&
      Math.hypot(other.x - unit.x - t * dx, other.y - unit.y - t * dy) < 18
    );
  });
}

export function updateTactics(model, dt, weapons) {
  const s = model.state,
    b = s.battle;
  if (!b) return;
  const field = fieldFor(b);
  const activity = model.unitActivity
    ? new Map(b.units.map((u) => [u, model.unitActivity(u)]))
    : null;
  b.time += dt;
  b.visibilityClock += dt;
  b.aiClock += dt;
  if (b.visibilityClock >= 0.6 || !b.visibleCells) {
    b.visibilityClock = 0;
    updateVisibility(b);
  }
  if (b.aiClock >= 2) {
    b.aiClock = 0;
    planEnemy(model, weapons);
  }
  model.updateCommanders(dt);
  updateWagons(model, dt);
  const damage = [];
  for (const u of b.units) {
    u.flash = Math.max(0, u.flash - dt);
    if (u.arrival > b.time || u.men <= 0) continue;
    if (u.routed) {
      u.formationChange = null;
      u.queuedFormation = null;
      const direction =
        (u.side === 'player') === (b.playerEdge === 'west') ? -1 : 1;
      u.x = clamp(u.x + direction * dt * 30, -50, 1490);
      continue;
    }
    const support = model.commandSupport(u),
      terrain = fieldTerrain(u, field);
    advanceFormation(
      u,
      dt * (support.some((c) => c.specialty === 'Drill') ? 1.2 : 1),
    );
    if (u.limberChange > 0) {
      u.limberChange = Math.max(0, u.limberChange - dt);
      if (!u.limberChange) u.limbered = u.nextLimber;
    }
    const fatigue =
      (u.charging ? 1.6 : u.running ? 0.9 : 0.2) *
      (1.15 - u.skills.stamina / 200) *
      (u.perk === 'march' ? 0.75 : 1);
    if (!model.updateUnitCondition)
      u.condition = clamp(u.condition + dt * (u.target ? -fatigue : 0.7));
    if (u.condition < 12) {
      u.running = false;
      u.charging = false;
    }
    u.reload = Math.max(0, u.reload - dt);
    let enemy = model.combatTarget
      ? model.combatTarget(u)
      : b.units.find(
          (e) =>
            e.id === u.attackId &&
            e.men > 0 &&
            !e.routed &&
            e.arrival <= b.time &&
            (u.side === 'enemy' || e.visible),
        ) || model.nearestEnemy(u);
    if (u.side === 'player' && u.attackId && enemy) {
      const d = distance(u, enemy),
        stop = model.attackStopDistance
          ? model.attackStopDistance(u)
          : u.charging || (u.holdFire && model.meleeOnlyOrders)
            ? 22
            : weapons[u.weapon].range * 0.85;
      if (d > stop) setGoal(model, u, enemy);
      else {
        u.target = null;
        u.waypoints = [];
      }
    }
    const moving = !!u.target;
    if (moving) {
      let speed =
        u.kind === 'cavalry'
          ? u.dismounted
            ? 25
            : 49
          : u.kind === 'artillery'
            ? u.limbered
              ? 34
              : 9
            : 24;
      speed *=
        u.formation === 'column' ? 1.45 : u.formation === 'square' ? 0.35 : 1;
      speed *= terrain === 'woods' ? 0.58 : 1;
      speed *= 0.55 + u.condition * 0.0045;
      if (u.formationChange) speed *= 0.3;
      if (u.limberChange) speed *= 0.15;
      if (u.charging || u.running) speed *= 1.45;
      if (u.fallingBack) speed *= 0.65;
      if (u.role === 'skirmishers') speed *= 1.15;
      walk(model, u, dt, speed);
      u.skills.stamina = Math.min(100, u.skills.stamina + dt * 0.008);
    }
    // A final waypoint may be consumed this tick. Do not turn twice in one step.
    const canFace = !moving || u.fallingBack;
    if (canFace && model.engagementFacing) {
      const facing = model.engagementFacing(u, enemy);
      if (facing != null) model.turnUnit(u, facing, dt);
    } else if (canFace && u.desiredFacing != null)
      model.turnUnit(u, u.desiredFacing, dt);
    else if (canFace && enemy)
      model.turnUnit(u, Math.atan2(enemy.y - u.y, enemy.x - u.x), dt);
    u.blocked = u.formationChange
      ? 'Reforming'
      : u.limberChange
        ? 'Preparing guns'
        : u.limbered
          ? 'Limbered'
          : u.ammo < 1 && u.kind !== 'cavalry'
            ? 'No ammunition'
            : '';
    if (!enemy) continue;
    const d = distance(u, enemy),
      melee = d < 45,
      range = weapons[u.weapon].range;
    const visible =
      u.side === 'player'
        ? enemy.visible
        : active(b, 'enemy').some((observer) =>
            lineOfSight(observer, enemy, field),
          );
    const unobstructed = melee || clearShot(u, enemy, b, field);
    if (d <= range && !unobstructed && !u.blocked) u.blocked = 'Obstructed';
    if (u.role === 'skirmishers' && !u.attackId && !u.target && d < 90) {
      const angle = Math.atan2(u.y - enemy.y, u.x - enemy.x);
      u.fallingBack = true;
      model.pathUnit(
        u,
        { x: u.x + Math.cos(angle) * 65, y: u.y + Math.sin(angle) * 65 },
        angle + Math.PI,
      );
    }
    const bearing = Math.atan2(enemy.y - u.y, enemy.x - u.x);
    if (
      !visible ||
      d > range ||
      !unobstructed ||
      u.formationChange ||
      u.limbered ||
      u.limberChange ||
      u.reload > 0 ||
      (model.insideFiringArc && !model.insideFiringArc(u, enemy)) ||
      (!melee &&
        (u.ammo < 1 ||
          u.holdFire ||
          Math.cos(bearing - u.facing) <= 0.45 ||
          (u.target && !u.fallingBack && u.kind !== 'cavalry')))
    )
      continue;
    let power =
      (u.kind === 'artillery' ? u.men * 0.24 : u.men * 0.045) *
      weapons[u.weapon].power *
      (1 + u.experience * 0.12);
    power *= 0.85 + (melee ? u.skills.melee : u.skills.firearms) / 200;
    if (u.side === 'player') power *= commandEfficiency(s, u);
    if (u.kind === 'cavalry' && melee && !u.dismounted) power *= 2.1;
    if (u.formation === 'column' && !melee) power *= 0.4;
    if (u.formation === 'square' && !melee) power *= 0.55;
    if (u.charging && melee) power *= 1.6;
    if (u.kind === 'artillery') power *= d < 120 ? 1.8 : d < 220 ? 1.15 : 0.8;
    if (u.fallingBack && !melee) power *= 0.55;
    if (u.perk === 'volley' && !melee) power *= 1.15;
    if (
      enemy.formation === 'square' &&
      !enemy.formationChange &&
      u.kind === 'cavalry' &&
      !u.dismounted
    )
      power *= 0.2;
    if (enemy.formationChange) power *= 1.18;
    if (enemy.role === 'skirmishers' || enemy.dismounted)
      power *= melee ? 1.2 : 0.7;
    if (fieldTerrain(enemy, field) === 'woods') power *= melee ? 0.85 : 0.55;
    if (terrain === 'hill') power *= 1.18;
    const flanked =
      Math.cos(Math.atan2(u.y - enemy.y, u.x - enemy.x) - enemy.facing) < -0.3;
    if (flanked) power *= 1.4;
    power *=
      (u.morale / 100) *
      (0.65 + u.condition * 0.0035) *
      (u.side === 'enemy' ? 0.85 : 1);
    if (u.kind === 'artillery' && !melee && model.artilleryVolley)
      power = model.artilleryVolley(u, enemy, power);
    damage.push({
      source: u,
      enemy,
      power,
      morale:
        (power / enemy.startMen) *
        100 *
        (flanked ? 2.5 : 1.4) *
        (model.commandSupport(enemy).length ? 0.88 : 1) *
        (enemy.perk === 'steadfast' ? 0.8 : 1) *
        (1.15 - enemy.skills.discipline / 250),
      flanked,
    });
    u.reload =
      (u.kind === 'artillery' ? 4.2 : melee ? 1.6 : 2.8) *
      (1.15 - u.skills.firearms / 300);
    u.flash = 0.45;
    u.shotTime = b.time;
    u.shotKind = melee ? 'melee' : u.kind === 'artillery' ? 'cannon' : 'musket';
    u.firedAt = { x: enemy.x, y: enemy.y };
    if (model.combatExertion) model.combatExertion(u, enemy, melee, power > 0);
    else u.condition = Math.max(0, u.condition - (melee ? 0.9 : 0.2));
    if (!melee) u.ammo = Math.max(0, u.ammo - (u.kind === 'artillery' ? 6 : 3));
    u.skills[melee ? 'melee' : 'firearms'] = Math.min(
      100,
      u.skills[melee ? 'melee' : 'firearms'] + 0.08,
    );
  }
  // Resolve simultaneous volleys before morale checks or victory decisions.
  for (const { source, enemy, power, morale, flanked } of damage) {
    source.kills = (source.kills || 0) + Math.min(enemy.men, power);
    enemy.men = Math.max(0, enemy.men - power);
    enemy.morale = Math.max(0, enemy.morale - morale);
    enemy.lastHit = b.time;
    enemy.flankedUntil = flanked ? b.time + 3 : enemy.flankedUntil;
    enemy.skills.discipline = Math.min(100, enemy.skills.discipline + 0.03);
  }
  for (const u of b.units) {
    if (u.men > 0 && u.arrival <= b.time && model.updateUnitCondition)
      model.updateUnitCondition(u, activity.get(u), dt);
    if (u.routed || u.men <= 0 || u.arrival > b.time) continue;
    const support = model.commandSupport(u);
    if (support.length)
      u.morale = Math.min(
        100,
        u.morale +
          dt * (support.some((c) => c.specialty === 'Resolve') ? 0.38 : 0.2),
      );
    if (u.morale < 20 || u.men < u.startMen * 0.23) {
      u.routed = true;
      u.target = null;
    }
  }
  const fighting = (side) =>
    b.units.some((u) => u.side === side && !u.routed && u.men > 0);
  if (!fighting('player')) {
    model.finishBattle(false);
    return;
  }
  if (!fighting('enemy')) {
    model.finishBattle(true);
    return;
  }
  const objective = field.objective;
  const strength = (side) =>
    active(b, side)
      .filter((u) => distance(u, objective) <= objective.radius)
      .reduce((sum, u) => sum + u.men, 0);
  const french = strength('player'),
    austrian = strength('enemy');
  b.objective.owner =
    french > 0 && austrian === 0
      ? 'player'
      : austrian > 0 && french === 0
        ? 'enemy'
        : null;
  if (b.objective.owner) b.objective[b.objective.owner] += dt;
  if (b.objective.player >= objective.seconds) model.finishBattle(true);
  else if (
    b.objective.enemy >= (field.type === 'defend' ? 50 : objective.seconds + 60)
  )
    model.finishBattle(false);
}
