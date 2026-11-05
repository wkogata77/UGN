export const SKILLS = {
  firearms: 'Firearms',
  melee: 'Melee',
  stamina: 'Stamina',
  discipline: 'Discipline',
};
export const PERKS = {
  volley: { name: 'Disciplined volleys', description: '+15% ranged damage' },
  steadfast: { name: 'Steadfast', description: '20% less morale damage' },
  march: { name: 'Campaign veterans', description: '25% less fatigue' },
};
export const RANKS = ['Captain', 'Major', 'Colonel', 'Brigadier', 'General'];
export const RANK_XP = [0, 20, 60, 120, 210];
export const baseSkills = (kind = 'infantry') => ({
  firearms: kind === 'artillery' ? 44 : 32,
  melee: kind === 'cavalry' ? 48 : 30,
  stamina: 42,
  discipline: 38,
});
export const rankOf = (officer) =>
  officer
    ? Math.max(
        0,
        RANK_XP.findLastIndex((xp) => officer.xp >= xp),
      )
    : -1;
export const officerReady = (officer, hours) =>
  !!officer?.hired && !officer.dead && officer.woundedUntil <= hours;
export function officerAssignment(state, id) {
  return (
    [...state.corps, ...state.units].find((u) => u.officerId === id) || null
  );
}
export function commandEfficiency(state, unit) {
  const officer = state.officers.find((o) => o.id === unit.officerId);
  if (!officerReady(officer, state.hours)) return 0.7;
  const rank = rankOf(officer);
  return (
    Math.min(1.12, 0.88 + rank * 0.06) *
    Math.min(1, [250, 600, 1000, 1800, 3000][rank] / Math.max(1, unit.men))
  );
}
export function makeOfficer(id, name, portrait, xp = 60, hired = true) {
  return {
    id,
    name: name.replace(/^(Col\.|Cpt\.|Gen\.)\s*/, ''),
    portrait,
    xp,
    hired,
    specialty: portrait % 2 ? 'Drill' : 'Resolve',
    woundedUntil: 0,
    wounds: 0,
    dead: false,
    cost: xp >= 120 ? 1400 : xp >= 60 ? 900 : 500,
  };
}
export function upgradeRegiment(unit) {
  unit.skills ||= baseSkills(unit.kind);
  unit.perk ??= null;
  unit.history ||= [];
  unit.condition ??= 100;
  unit.ammo ??= 100;
  unit.trainedUntil ??= 0;
}
export function upgradeArmy(state) {
  if (!state.officers) {
    state.officers = [];
    for (const [i, corps] of state.corps.entries()) {
      corps.officerId = `officer-${corps.id}`;
      const officer = makeOfficer(corps.officerId, corps.commander, i + 1, 120);
      officer.specialty = corps.specialty;
      state.officers.push(officer);
    }
    for (const [i, unit] of state.units.entries()) {
      unit.officerId = `officer-${unit.id}`;
      state.officers.push(
        makeOfficer(
          unit.officerId,
          unit.commander,
          i + 3,
          unit.kind === 'artillery' ? 20 : 60,
        ),
      );
    }
    for (const [i, name] of [
      'Charles Delmas',
      'Etienne Beaumont',
      'Louis Renaud',
      'Jean Villiers',
      'Pierre Duval',
    ].entries())
      state.officers.push(
        makeOfficer(
          `reserve-${i}`,
          name,
          i + 9,
          [120, 60, 20, 120, 60][i],
          false,
        ),
      );
  }
  for (const unit of state.units) upgradeRegiment(unit);
  state.settings ||= { sound: true, volume: 0.3 };
  state.army.condition ??= 100;
  state.supply ??= 500;
  state.recon ||= { remaining: 0, cooldown: 0 };
  state.selectedSupply ??= false;
  state.orderMode ||= 'move';
  for (const enemy of state.enemies)
    enemy.intel ||= {
      x: enemy.x,
      y: enemy.y,
      at: state.hours - 12,
      strength: Math.round(enemy.strength / 200) * 200,
    };
  if (state.battle) {
    for (const unit of state.battle.units) {
      const persistent = state.units.find(
        (u) => u.id === (unit.parentId || unit.id),
      );
      unit.officerId ||= persistent?.officerId || null;
      upgradeRegiment(unit);
      unit.waypoints ||= [];
      unit.fallingBack ??= false;
      unit.running ??= false;
      unit.limbered ??= false;
      unit.limberChange ??= 0;
      unit.visible ??= true;
    }
    for (const commander of state.battle.commanders)
      commander.officerId ||=
        state.corps.find((c) => c.id === commander.corpsId)?.officerId || null;
  }
  state.version = 3;
  return state;
}
