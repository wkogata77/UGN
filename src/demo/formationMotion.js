import { formationOffsets, formationPoint } from './formationGeometry.js';
import { angleDifference } from './turning.js';

const cellKey = (x, y) => (x << 16) ^ (y & 65535);
const layoutKey = (u) =>
  `${u.kind}:${Math.ceil(u.men / 9)}:${u.role}:${u.formation}:${u.formationChange?.to}:${u.formationChange?.elapsed}:${u.dismounted}`;

// Presentation only. Regimental combat, pathfinding, and casualties remain authoritative.
export class FormationMotion {
  constructor() {
    this.groups = new Map();
  }
  clear() {
    this.groups.clear();
  }
  reset(unit, time) {
    const soldiers = formationOffsets(unit).map((offset, i) => ({
      ...formationPoint(unit, offset),
      vx: 0,
      vy: 0,
      facing: unit.facing,
      response: 3.8 + ((i * 37 + 13) % 101) / 50,
    }));
    const group = {
      unit,
      time,
      soldiers,
      x: unit.x,
      y: unit.y,
      facing: unit.facing,
      key: layoutKey(unit),
      settled: true,
      grid: new Map(),
    };
    this.groups.set(unit.id, group);
    return group;
  }
  positions(unit, time) {
    let group = this.groups.get(unit.id);
    const changed =
      group &&
      (group.x !== unit.x ||
        group.y !== unit.y ||
        group.facing !== unit.facing ||
        group.key !== layoutKey(unit));
    if (
      !group ||
      group.unit !== unit ||
      time < group.time ||
      (time === group.time && changed)
    )
      group = this.reset(unit, time);
    else if (time > group.time) group = this.step(unit, time);
    return group.soldiers;
  }
  advance(units, time) {
    const present = new Set();
    for (const unit of units) {
      if (unit.men <= 0 || unit.arrival > time) continue;
      present.add(unit.id);
      this.step(unit, time);
    }
    for (const id of this.groups.keys())
      if (!present.has(id)) this.groups.delete(id);
  }
  step(unit, time) {
    let group = this.groups.get(unit.id);
    if (!group || group.unit !== unit || time < group.time)
      return this.reset(unit, time);
    const dt = time - group.time;
    if (!(dt > 0)) return group;
    if (
      dt > 0.3 ||
      Math.hypot(unit.x - group.x, unit.y - group.y) > dt * 160 + 30
    )
      return this.reset(unit, time);
    const key = layoutKey(unit);
    if (
      group.settled &&
      group.x === unit.x &&
      group.y === unit.y &&
      group.facing === unit.facing &&
      group.key === key
    ) {
      group.time = time;
      return group;
    }
    const offsets = formationOffsets(unit);
    group.soldiers.length = Math.min(group.soldiers.length, offsets.length);
    for (let i = group.soldiers.length; i < offsets.length; i++)
      group.soldiers.push({
        ...formationPoint(unit, offsets[i]),
        vx: 0,
        vy: 0,
        facing: unit.facing,
        response: 3.8 + ((i * 37 + 13) % 101) / 50,
      });
    const mounted = unit.kind === 'cavalry' && !unit.dismounted;
    const gun = unit.kind === 'artillery';
    const maxSpeed = mounted ? 80 : gun ? (unit.limbered ? 62 : 25) : 52;
    const spacing = mounted ? 4.8 : gun ? 9 : 3.2;
    const cosine = Math.cos(unit.facing - Math.PI / 2),
      sine = Math.sin(unit.facing - Math.PI / 2);
    const steps = Math.ceil(dt / (1 / 60)),
      step = dt / steps;
    for (let tick = 0; tick < steps; tick++) {
      group.grid.clear();
      for (const p of group.soldiers) {
        const cell = cellKey(Math.floor(p.x / 10), Math.floor(p.y / 10));
        if (!group.grid.has(cell)) group.grid.set(cell, []);
        group.grid.get(cell).push(p);
      }
      for (let i = 0; i < group.soldiers.length; i++) {
        const p = group.soldiers[i],
          offset = offsets[i];
        p.goalX = unit.x + offset.x * cosine - offset.y * sine;
        p.goalY = unit.y + offset.x * sine + offset.y * cosine;
        const dx = p.goalX - p.x,
          dy = p.goalY - p.y,
          d = Math.hypot(dx, dy);
        const response = p.response * (mounted ? 1.15 : 1);
        const speed = Math.min(maxSpeed, d * response);
        let wantX = d > 0 ? (dx / d) * speed : 0,
          wantY = d > 0 ? (dy / d) * speed : 0;
        const gx = Math.floor(p.x / 10),
          gy = Math.floor(p.y / 10);
        for (let x = gx - 1; x <= gx + 1; x++)
          for (let y = gy - 1; y <= gy + 1; y++)
            for (const other of group.grid.get(cellKey(x, y)) || []) {
              if (other === p) continue;
              const ox = p.x - other.x,
                oy = p.y - other.y,
                gap = Math.hypot(ox, oy);
              if (gap > 0.001 && gap < spacing) {
                const push = ((spacing - gap) / spacing) * 12;
                wantX += (ox / gap) * push;
                wantY += (oy / gap) * push;
              }
            }
        const changeX = wantX - p.vx,
          changeY = wantY - p.vy;
        const change = Math.hypot(changeX, changeY);
        const blend = Math.min(
          1,
          (maxSpeed * 3 * step) / Math.max(0.0001, change),
          1 - Math.exp(-step * 12),
        );
        p.vx += changeX * blend;
        p.vy += changeY * blend;
        const velocity = Math.hypot(p.vx, p.vy);
        if (velocity > maxSpeed) {
          p.vx *= maxSpeed / velocity;
          p.vy *= maxSpeed / velocity;
        }
      }
      group.settled = true;
      for (const p of group.soldiers) {
        p.x += p.vx * step;
        p.y += p.vy * step;
        const d = Math.hypot(p.goalX - p.x, p.goalY - p.y),
          speed = Math.hypot(p.vx, p.vy);
        if (d < 0.035 && speed < 0.15) {
          p.x = p.goalX;
          p.y = p.goalY;
          p.vx = 0;
          p.vy = 0;
        }
        const heading =
          speed > 2 && d > 0.12 && !unit.fallingBack
            ? Math.atan2(p.vy, p.vx)
            : unit.facing;
        const error = angleDifference(heading, p.facing);
        p.facing += Math.max(-step * 3, Math.min(step * 3, error));
        if (d >= 0.035 || speed >= 0.15 || Math.abs(error) > 0.002)
          group.settled = false;
      }
    }
    Object.assign(group, {
      x: unit.x,
      y: unit.y,
      facing: unit.facing,
      key,
      time,
    });
    return group;
  }
}
