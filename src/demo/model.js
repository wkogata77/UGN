import { Campaign, riverY, WEAPONS, distance, WORLD } from '../game/model.js';
import { fieldFor, passable } from '../game/battlefields.js';
import { clearShot, updateVisibility } from '../game/tactics.js';
import { artilleryVolley } from './artillery.js';
import { turnFormation, movementAlignment } from './turning.js';
import {
  automaticTarget,
  visibleTarget,
  combatTarget,
  engagementFacing,
  clearEngagement,
  insideArc,
} from './engagement.js';
import { unitActivity, combatExertion, updateCondition } from './fatigue.js';
import { FormationMotion } from './formationMotion.js';

export const DEMO_TOWNS = [
  { name: 'Forward depot', x: 222, y: 628, major: true },
  { name: 'San Martino', x: 395, y: 570 },
  { name: 'River post', x: 596, y: 470 },
  { name: 'Valeggio', x: 900, y: 407, major: true },
  { name: 'Supply base', x: 815, y: 770, major: true },
  { name: 'Northern post', x: 1110, y: 239 },
];

// Demo state never reads or writes the normal campaign's storage.
export class DepthCampaign extends Campaign {
  constructor(battle = false) {
    super(null);
    this.soldiers = new FormationMotion();
    this.meleeOnlyOrders = true;
    this.state.speed = 0.5;
    this.state.army.name = 'Army of Italy';
    this.state.enemies[0].x = 700;
    this.state.enemies[0].y = riverY(700) + 65;
    this.state.enemies[0].home = { x: 700, y: riverY(700) + 65 };
    this.state.enemies.forEach((e) => {
      e.intel = { ...e.intel, x: e.x, y: e.y, strength: e.strength };
    });
    this.state.units[3].corpsId = 'c2';
    if (battle) {
      Object.assign(this.state.enemies[1], {
        x: 835,
        y: this.state.enemies[0].y + 95,
        strength: 850,
      });
      this.startBattle('e1');
    }
  }
  save() {
    this.saveFailed = false;
  }
  turnUnit(unit, angle, dt) {
    const time = this.state.battle?.time;
    if (time != null) {
      if (unit.lastTurnAt == null || time - unit.lastTurnAt > dt * 1.5 + 1e-6)
        unit.turnVelocity = 0;
      unit.lastTurnAt = time;
    }
    turnFormation(unit, angle, dt);
  }
  movementSpeedScale(unit, bearing) {
    return movementAlignment(unit, bearing);
  }
  combatTarget(unit) {
    return combatTarget(unit, this.state.battle);
  }
  insideFiringArc(unit, enemy) {
    return insideArc(unit, enemy);
  }
  engagementFacing(unit, enemy) {
    return engagementFacing(unit, enemy);
  }
  attackStopDistance(unit) {
    return unit.charging || unit.holdFire ? 22 : WEAPONS[unit.weapon].range;
  }
  unitActivity(unit) {
    return unitActivity(unit);
  }
  updateUnitCondition(unit, before, dt) {
    updateCondition(unit, before, this.state.battle.time, dt);
  }
  combatExertion(source, target, melee, hit) {
    combatExertion(source, target, this.state.battle.time, melee, hit);
  }
  engageEnemy() {
    const b = this.state.battle;
    let ordered = 0;
    for (const unit of this.selectedUnits()) {
      const current = b.units.find((e) => e.id === unit.fireTargetId);
      if (
        automaticTarget(unit, current, b) &&
        !unit.target &&
        distance(unit, current) <= this.attackStopDistance(unit)
      ) {
        ordered++;
        continue;
      }
      const enemy = automaticTarget(unit, current, b)
        ? current
        : b.units
            .filter((e) => visibleTarget(unit, e, b))
            .sort((a, c) => distance(unit, a) - distance(unit, c))[0];
      if (!enemy) continue;
      unit.charging = false;
      if (
        distance(unit, enemy) > this.attackStopDistance(unit) &&
        !this.pathUnit(unit, enemy)
      )
        continue;
      if (distance(unit, enemy) <= this.attackStopDistance(unit)) {
        unit.target = null;
        unit.waypoints = [];
      }
      clearEngagement(unit);
      unit.attackId = enemy.id;
      unit.desiredFacing = null;
      unit.orderQueue = [];
      unit.fallingBack = false;
      ordered++;
    }
    this.publish(false);
    return ordered;
  }
  moveUnits(point, attackId = null, queue = false, facing = null) {
    if (!this.state.selectedSupply && !this.state.selectedCommander)
      for (const unit of this.selectedUnits())
        if (!queue || !unit.target) clearEngagement(unit);
    super.moveUnits(point, attackId, queue, facing);
  }
  halt() {
    for (const unit of this.selectedUnits()) {
      clearEngagement(unit);
      unit.desiredFacing = null;
      unit.turnVelocity = 0;
    }
    super.halt();
  }
  charge() {
    for (const unit of this.selectedUnits()) clearEngagement(unit);
    super.charge();
  }
  soldierPositions(unit) {
    return this.soldiers.positions(unit, this.state.battle.time);
  }
  updateBattle(dt) {
    const battle = this.state.battle;
    super.updateBattle(dt);
    if (this.state.mode === 'battle' && this.state.battle === battle)
      this.soldiers.advance(battle.units, battle.time);
    else this.soldiers.clear();
  }
  artilleryVolley(source, target, power) {
    const b = this.state.battle;
    source.artilleryShots = (source.artilleryShots || 0) + 1;
    const impacts = artilleryVolley(source, target, source.artilleryShots).map(
      (p, i) => ({
        ...p,
        id: `${source.id}:${source.artilleryShots}:${i}`,
        time: b.time,
        visible: source.side === 'player' || !!source.visible,
      }),
    );
    source.artilleryImpacts = impacts;
    b.artilleryImpacts = [
      ...(b.artilleryImpacts || []).filter((p) => b.time - p.time < 6),
      ...impacts,
    ].slice(-128);
    return (power * impacts.filter((p) => p.hit).length) / impacts.length;
  }
  startBattle(id) {
    if (!super.startBattle(id)) return false;
    const s = this.state;
    const b = s.battle;
    b.scenario = 'bridge';
    b.name = 'The Valeggio Crossing';
    b.playerEdge = 'west';
    b.objective = { player: 0, enemy: 0, owner: null };
    const friendly = b.units.filter((u) => u.side === 'player');
    friendly.forEach((u, i) => {
      u.x = i === 4 ? 380 : i === 3 ? 450 : i === 2 ? 390 : 490;
      u.y = [300, 435, 565, 715, 660][i] ?? 200 + i * 110;
      u.facing = 0;
    });
    b.units
      .filter((u) => u.side === 'enemy')
      .forEach((u, i) => {
        u.x = (i === 1 ? 805 : 880) + Math.floor(i / 5) * 170;
        u.y = 280 + (i % 5) * 112;
        u.facing = Math.PI;
      });
    for (const c of b.commanders) {
      if (c.corpsId) {
        c.hostId = friendly.find((u) => u.corpsId === c.corpsId)?.id;
        c.following = false;
      } else {
        c.x = 350;
        c.y = 470;
        c.following = false;
      }
    }
    b.wagons[0].x = 335;
    b.wagons[0].y = 580;
    this.soldiers.clear();
    this.soldiers.advance(b.units, b.time);
    this.syncHosts();
    updateVisibility(b);
    s.selected = [friendly[0].id];
    s.speed = 0.5;
    this.publish(false);
    return true;
  }
  syncHosts() {
    const b = this.state.battle;
    if (!b) return;
    for (const c of b.commanders.filter((c) => c.hostId)) {
      const host = b.units.find((u) => u.id === c.hostId);
      if (host) {
        c.x = host.x;
        c.y = host.y;
      }
      c.unavailable = c.unavailable || !host || host.men <= 0 || host.routed;
      c.target = null;
      c.waypoints = [];
    }
  }
  updateCommanders(dt) {
    super.updateCommanders(dt);
    this.syncHosts();
  }
  selectCommander(id) {
    const c = this.state.battle?.commanders.find((c) => c.id === id);
    if (c?.hostId) this.select([c.hostId]);
    else super.selectCommander(id);
  }
}

export function legalGround(point, state) {
  if (point && state.mode === 'campaign') {
    const x = Math.floor(point.x / 24) * 24 + 12,
      y = Math.floor(point.y / 24) * 24 + 12;
    if (
      Math.abs(y - riverY(x)) < 26 &&
      Math.abs(x - 395) > 42 &&
      Math.abs(x - 900) > 42
    )
      return false;
  }
  return (
    point &&
    point.x >= 0 &&
    point.y >= 0 &&
    point.x <= WORLD.width &&
    point.y <= WORLD.height &&
    (state.mode !== 'battle' || passable(point, fieldFor(state.battle)))
  );
}

export function fireStatus(unit, target, battle) {
  if (
    !unit ||
    !target?.visible ||
    target.men <= 0 ||
    target.arrival > battle.time
  )
    return 'No visible target';
  const d = distance(unit, target);
  if (d > WEAPONS[unit.weapon].range) return 'Advance to range';
  if (d >= 45 && !clearShot(unit, target, battle, fieldFor(battle)))
    return 'Line of fire blocked';
  if (unit.formationChange) return 'Reforming';
  if (unit.limbered || unit.limberChange) return 'Guns not deployed';
  if (d >= 45 && unit.ammo < 1) return 'No ammunition';
  if (d >= 45 && unit.holdFire) return 'Holding fire';
  if (
    d >= 45 &&
    Math.cos(Math.atan2(target.y - unit.y, target.x - unit.x) - unit.facing) <=
      0.45
  )
    return unit.attackId === target.id && !unit.aimComplete
      ? 'Turning to target'
      : 'Outside firing arc';
  return 'Clear shot';
}

export function createFixedClock(model) {
  const step = 1 / 60;
  let accumulator = 0;
  return {
    advance(seconds) {
      if (model.state.paused || model.state.report) {
        accumulator = 0;
        return 0;
      }
      accumulator += Math.max(0, Math.min(seconds, 0.1));
      let ticks = 0;
      while (accumulator + 1e-10 >= step && ticks < 6) {
        model.update(step);
        accumulator -= step;
        ticks++;
        if (model.state.paused || model.state.report) {
          accumulator = 0;
          break;
        }
      }
      return ticks;
    },
    reset() {
      accumulator = 0;
    },
  };
}
