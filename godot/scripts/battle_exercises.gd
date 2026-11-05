class_name FieldBattleExercises
extends RefCounted

static var battlefields: Dictionary = {}

static func layout(map_version: int = FieldBattlefield.VERSION) -> Dictionary:
	if battlefields.has(map_version): return battlefields[map_version]
	var battlefield = FieldBattlefield.layout({"scenario": "bridge", "mapVersion": map_version}).duplicate(true)
	var shift = FieldBattlefield.offset_for({"mapVersion": map_version}) - FieldBattlefield.STANDARD_OFFSET
	var outskirts: Array = battlefield.towns.slice(4) if map_version >= 3 else []
	battlefield["authored"] = true
	battlefield.objective.seconds = 240.0
	battlefield.towns = [{"x": 1665.0, "y": 875.0, "major": true}, {"x": 1190.0, "y": 1080.0}, {"x": 570.0, "y": 1200.0}, {"x": 2290.0, "y": 590.0}]
	for town in battlefield.towns:
		town.x += shift.x
		town.y += shift.y
	battlefield.towns.append_array(outskirts)
	battlefield.forests.append_array([{"x": 1890.0 + shift.x, "y": 1110.0 + shift.y, "rx": 92.0, "ry": 72.0, "orchard": true}, {"x": 940.0 + shift.x, "y": 905.0 + shift.y, "rx": 80.0, "ry": 60.0, "orchard": true}])
	battlefields[map_version] = battlefield
	return battlefield

static func create(per_side: int = 12, map_version: int = FieldBattlefield.VERSION) -> FieldModel:
	per_side = 20 if per_side >= 20 else 12
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	var b: Dictionary = m.state.battle
	b["mapVersion"] = map_version
	var shift = FieldBattlefield.offset_for(b) - FieldBattlefield.STANDARD_OFFSET
	var center = Vector2(1440, 960) + shift
	var grand = map_version >= 3
	m.state["exerciseSize"] = per_side
	b["battlePolish"] = true
	b["exerciseSize"] = per_side
	b.name = "The Mincio Battlefield"
	b.units = []
	b.commanders = []
	b.bodies = []
	m.state.units = []
	var corps_template: Dictionary = m.state.corps[0].duplicate(true)
	m.state.corps = []
	var reserve_count = 2 if per_side == 12 else 4
	var line_count = per_side - reserve_count - 4
	for i in ceili(per_side / 4.0):
		var officer = FieldData.officer("exercise-officer-%d" % i, ["Massena", "Augereau", "Serurier", "Joubert", "Vaubois"][i], i + 1, 180.0)
		m.state.officers.append(officer)
		var corps: Dictionary = corps_template.duplicate(true)
		corps.merge({"id": "exercise-corps-%d" % i, "name": ["I", "II", "III", "IV", "V"][i] + " Corps", "commanderId": "exercise-command-%d" % i, "commander": officer.name, "specialty": officer.specialty, "officerId": officer.id}, true)
		m.state.corps.append(corps)
	for side in ["player", "enemy"]:
		var direction = 1.0 if side == "player" else -1.0
		for i in per_side:
			var kind = "infantry" if i < line_count + reserve_count else "cavalry" if i < per_side - 2 else "artillery"
			var reserve = kind == "infantry" and i >= line_count
			var men = float(720 + (i % 3) * 45) if kind == "infantry" else 216.0 if kind == "cavalry" else 120.0
			var p = center + Vector2(-direction * (680 if grand else 290), (i - (line_count - 1) * 0.5) * (160 if grand else 140))
			if reserve: p = center + Vector2(-direction * (1000 if grand else 510), (i - line_count - (reserve_count - 1) * 0.5) * (160 if grand else 125))
			if kind == "cavalry": p = center + Vector2(-direction * (940 if grand else 510), (-950 if grand else -570) if i == per_side - 4 else (950 if grand else 570))
			if kind == "artillery": p = center + Vector2(-direction * (780 if grand else 365), -300 if i == per_side - 2 else 300)
			var corps_id = m.state.corps[i / 4].id if side == "player" else null
			var weapon = ("musket" if side == "player" else "austrian_1784") if kind == "infantry" else ("sabre" if side == "player" else "austrian_carbine") if kind == "cavalry" else ("cannon" if side == "player" else "austrian_6pdr")
			var u = {"id": "exercise-%s-%02d" % [side, i], "name": "%d %s" % [i + 1, "Reserve" if reserve else "Line Regiment" if kind == "infantry" else "Cavalry" if kind == "cavalry" else "Field Battery"], "kind": kind, "side": side, "weapon": weapon, "men": men, "maxMen": men, "startMen": men, "x": p.x, "y": p.y, "corpsId": corps_id, "experience": 0.8, "facing": 0.0 if side == "player" else PI}
			FieldData.regiment_defaults(u)
			u["commander"] = "Col. " + str(i + 1)
			u.skills.discipline = 55.0
			u["aiRole"] = "reserve" if reserve else "battery" if kind == "artillery" else "flank" if kind == "cavalry" else "line"
			if reserve and i == line_count + reserve_count - 1:
				u.arrival = 110.0
				u.x = 90.0 if side == "player" else FieldBattlefield.size_for(b).x - 90
			if side == "player": m.state.units.append(u.duplicate(true))
			b.units.append(u)
	var general = {"id": "exercise-general", "name": "Napoleon Bonaparte", "corpsId": null, "officerId": null, "hostId": null, "specialty": "Drill", "x": 820.0, "y": 960.0, "radius": 200.0, "cooldown": 0.0, "shaken": 0.0, "rallyFlash": 0.0, "following": false, "facing": 0.0, "arrival": 0.0, "unavailable": false, "target": null, "waypoints": []}
	general.x = center.x - (1150 if grand else 620)
	general.y = center.y
	b.commanders.append(general)
	for i in m.state.corps.size():
		var c: Dictionary = general.duplicate(true)
		c.merge({"id": "exercise-command-%d" % i, "name": m.state.officers[-m.state.corps.size() + i].name, "corpsId": m.state.corps[i].id, "officerId": m.state.corps[i].officerId, "hostId": m.state.units[i * 4].id}, true)
		b.commanders.append(c)
	b.startMen = FieldData.men(b.units.filter(func(u): return u.side == "player"))
	b.enemyStartMen = FieldData.men(b.units.filter(func(u): return u.side == "enemy"))
	b.aiClock = 0.0
	b.erase("ai")
	for wagon in b.wagons:
		wagon.x = center.x + (-1 if wagon.side == "player" else 1) * (1250 if grand else 680)
		wagon.y = center.y + 90
		wagon.stock = 2400.0
	m.terrain.configure(m.state)
	# Prepare the immutable obstacle graph during loading, before orders begin.
	for clearance in [1.0, 2.0]: m.terrain.route(Vector2(1250, 810) + shift, Vector2(1700, 1100) + shift, clearance)
	m.formations.groups.clear()
	m.formations.motion.clear()
	for u in b.units: m.formations.reset_roster(u)
	m.prepare_deployment()
	FieldBattleAI.initialize(m)
	m.sync_hosts()
	m.tactics.update_visibility(m)
	m.select([b.units[0].id])
	m.state.paused = true
	m.state.speed = 0.5
	return m
