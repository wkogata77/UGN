export const FORMATIONS = {
  line: { name: 'Line', seconds: 8 },
  column: { name: 'Column', seconds: 6 },
  square: { name: 'Square', seconds: 12 },
};

export function orderFormation(unit, formation) {
  if (unit.kind !== 'infantry' || unit.routed || !FORMATIONS[formation])
    return false;
  if (unit.formationChange) {
    unit.queuedFormation =
      formation === unit.formationChange.to ? null : formation;
    return true;
  }
  if (unit.formation === formation) return false;
  unit.formationChange = {
    from: unit.formation,
    to: formation,
    elapsed: 0,
    duration:
      FORMATIONS[formation].seconds *
      (1 - Math.min(5, unit.experience || 0) * 0.045) *
      (1 + (100 - unit.morale) / 180),
  };
  unit.charging = false;
  return true;
}

export function advanceFormation(unit, seconds) {
  const change = unit.formationChange;
  if (!change) return;
  change.elapsed = Math.min(change.duration, change.elapsed + seconds);
  if (change.elapsed < change.duration) return;
  unit.formation = change.to;
  unit.formationChange = null;
  const queued = unit.queuedFormation;
  unit.queuedFormation = null;
  if (queued) orderFormation(unit, queued);
}

export function formationPosition(formation, index, count, kind = 'infantry') {
  if (formation === 'square') {
    const edge = index % 4;
    const offset =
      (Math.floor(index / 4) / Math.max(1, Math.ceil(count / 4) - 1) - 0.5) *
      54;
    return {
      x: edge < 2 ? offset : edge === 2 ? -27 : 27,
      y: edge >= 2 ? offset : edge === 0 ? -27 : 27,
    };
  }
  const cols =
    kind === 'cavalry' ? 8 : formation === 'column' ? 7 : Math.ceil(count / 4);
  return {
    x: ((index % cols) - (cols - 1) / 2) * (kind === 'cavalry' ? 8 : 5),
    y: (Math.floor(index / cols) - (Math.ceil(count / cols) - 1) / 2) * 6,
  };
}

export function soldierPosition(unit, index, count) {
  const from = formationPosition(unit.formation, index, count, unit.kind);
  if (!unit.formationChange) return from;
  const change = unit.formationChange;
  const to = formationPosition(change.to, index, count, unit.kind);
  const progress = Math.min(1, change.elapsed / change.duration);
  const t = progress * progress * (3 - 2 * progress);
  return { x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t };
}
