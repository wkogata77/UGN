class_name FieldCampaign
extends RefCounted

static var layouts: Dictionary = {}
static var enlarged_layouts: Dictionary = {}
const MAP_VERSION = 4
const MARCH_MODES = {"route": {"pace": 1.4, "fatigue": 0.34}, "normal": {"pace": 1.0, "fatigue": 0.16}, "slow": {"pace": 0.65, "fatigue": 0.045}}

static func march_defaults(state: Dictionary) -> void:
	state.army["marchMode"] = state.army.get("marchMode", "normal")
	for enemy in state.enemies:
		enemy["condition"] = enemy.get("condition", 100.0)
		enemy["marchMode"] = enemy.get("marchMode", "normal")
		enemy["resting"] = enemy.get("resting", false)
		enemy["personality"] = enemy.get("personality", ["aggressive", "cautious", "opportunist"][state.enemies.find(enemy) % 3])
		enemy["intent"] = enemy.get("intent", "Patrolling")
		enemy["lastSighting"] = enemy.get("lastSighting", null)

static func decision(state: Dictionary, terrain, enemy: Dictionary) -> Vector2:
	var distance = FieldData.distance(enemy, state.army)
	var concealed = FieldTerrain.kind(FieldData.pos(state.army), {"forests": terrain.forests}) == "woods"
	var observed = distance < (170 if concealed else 280) and state.immunity <= 0
	if observed: enemy.lastSighting = {"x": state.army.x, "y": state.army.y, "at": state.hours, "strength": FieldData.men(state.units)}
	var sighting = enemy.lastSighting
	if enemy.condition < 24 or (sighting != null and enemy.strength < sighting.strength * 0.55):
		enemy.intent = "Withdrawing to reserve"
		return FieldData.pos(enemy.home)
	if sighting != null and state.hours - sighting.at < 2.0 and state.immunity <= 0:
		var threshold = 0.65 if enemy.personality == "aggressive" else 1.15 if enemy.personality == "cautious" else 0.9
		if enemy.strength >= sighting.strength * threshold:
			enemy.intent = "Intercepting" if observed else "Investigating last report"
			return FieldData.pos(sighting)
	enemy.intent = "Guarding approaches" if enemy.personality == "cautious" else "Patrolling"
	return FieldData.pos(enemy.home) + Vector2(sin(state.hours * 0.65) * 65, cos(state.hours * 0.65) * 50)

static func scale_for(theater: String) -> float:
	return 3.0 if theater in ["italy", "mantua"] else 1.0

static func migrate(state: Dictionary) -> void:
	var version = int(state.get("campaignMapVersion", 1))
	if version >= MAP_VERSION: return
	var original_scale = scale_for(state.get("theater", "danube")) * map_multiplier(version)
	if version < 2 and state.get("theater", "danube") == "italy": original_scale = 1.0
	var factor = scale_for(state.get("theater", "danube")) * map_multiplier(MAP_VERSION) / original_scale
	resize_state(state, factor)
	state["campaignMapVersion"] = MAP_VERSION

static func map_multiplier(version: int) -> float:
	return 4.0 if version >= 4 else 2.0 if version >= 3 else 1.0

static func resize_state(state: Dictionary, factor: float) -> void:
	# Strategic records can alias each other; scale each dictionary exactly once.
	var points: Array = []
	for army in (state.armies if state.get("operation") != null else [state.army]) + state.enemies:
		points.append(army)
		points.append_array(army.path)
		for key in ["home", "intel", "lastSighting", "pendingOrder", "redeployAt"]:
			if army.get(key) != null: points.append(army[key])
	if state.get("operation") != null: points.append_array(state.operation.sites)
	if state.battle != null:
		points.append(state.battle.origin)
		for entry in state.battle.get("campaignForces", []): points.append(entry.origin)
	var changed: Array = []
	for point in points:
		if changed.any(func(other): return is_same(point, other)): continue
		point.x *= factor
		point.y *= factor
		changed.append(point)
	if state.get("operation") != null: FieldOperations.bind_selection(state)

static func layout(theater: String, version: int = MAP_VERSION) -> Dictionary:
	var base = base_layout(theater)
	if version < 3: return base
	var cache_key = theater + ":" + str(version)
	if enlarged_layouts.has(cache_key): return enlarged_layouts[cache_key]
	var factor = map_multiplier(version)
	var result = {"size": base.size * factor, "scale": base.scale * factor, "towns": [], "forests": [], "roads": [], "crossings": []}
	for key in ["towns", "forests"]:
		for original in base[key]:
			var point: Dictionary = original.duplicate(true)
			point.x *= factor
			point.y *= factor
			if key == "forests":
				point.rx *= 2.3 if version >= 4 else 1.35
				point.ry *= 2.3 if version >= 4 else 1.35
			result[key].append(point)
	for road in base.roads: result.roads.append(road.map(func(p): return FieldData.point(FieldData.pos(p) * factor)))
	for crossing in base.crossings: result.crossings.append(crossing * factor)
	if base.has("river"): result["river"] = base.river.map(func(p): return [p[0] * factor, p[1] * factor])
	enlarged_layouts[cache_key] = result
	return result

static func base_layout(theater: String) -> Dictionary:
	if layouts.has(theater): return layouts[theater]
	if theater == "mantua":
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mantua.json"))
		var roads: Array = []
		for road in data.roads:
			roads.append(road.map(func(p): return {"x": p[0], "y": p[1]}))
		layouts[theater] = {"size": Vector2(4320, 2880), "scale": 3.0, "towns": data.towns, "forests": data.forests, "roads": roads, "crossings": data.crossings, "river": data.river}
		return layouts[theater]
	var scale_value = scale_for(theater)
	var data = FieldData.load_data()
	var towns: Array = (data.italyTowns if theater == "italy" else data.towns).duplicate(true)
	if theater == "italy":
		for site in [["Western cantonment", 100, 470], ["Abbey farms", 390, 260], ["San Pietro", 660, 780], ["Old mill", 685, 510], ["Hill market", 880, 155], ["Southern depot", 425, 900], ["East road post", 1300, 600], ["Ferrara road", 1295, 880], ["Upper valley", 240, 100], ["Riverside hamlet", 1180, 525], ["Cavalry post", 1130, 880], ["South road junction", 680, 910]]:
			towns.append({"name": site[0], "x": site[1], "y": site[2], "major": site[0] in ["Southern depot", "East road post", "Hill market"]})
	for town in towns:
		town.x *= scale_value
		town.y *= scale_value
	var forests: Array = data.forests.campaign.duplicate(true)
	for forest in forests:
		forest.x *= scale_value
		forest.y *= scale_value
		forest.rx *= 1.7 if theater == "italy" else 1.0
		forest.ry *= 1.7 if theater == "italy" else 1.0
	if theater == "italy":
		for f in [Vector4(1250, 1120, 230, 120), Vector4(450, 1120, 150, 180), Vector4(1750, 1020, 170, 130), Vector4(3200, 650, 260, 160), Vector4(3880, 470, 230, 160), Vector4(4100, 2240, 140, 230), Vector4(1960, 2040, 210, 150), Vector4(1400, 2450, 190, 130), Vector4(2340, 2690, 220, 100), Vector4(400, 2140, 120, 220), Vector4(3520, 2540, 210, 100), Vector4(2860, 1070, 150, 140)]:
			forests.append({"x": f.x, "y": f.y, "rx": f.z, "ry": f.w})
	var crossings: Array = [395.0 * scale_value, 900.0 * scale_value]
	if theater == "italy": crossings.append_array([420.0, 2040.0, 3780.0])
	crossings.sort()
	var roads: Array = []
	# Two continuous banks and multiple crossings create routes through the full region.
	if theater == "italy":
		for offset in [-190.0, 220.0]:
			var road: Array = []
			for x in range(0, 4321, 120): road.append({"x": x, "y": FieldData.river_y(x / scale_value) * scale_value + offset})
			roads.append(road)
		for x in crossings:
			var y = FieldData.river_y(x / scale_value) * scale_value
			roads.append([{ "x": x, "y": y - 190 }, { "x": x, "y": y + 220 }])
		for town in towns:
			var river = FieldData.river_y(town.x / scale_value) * scale_value
			roads.append([town, {"x": town.x, "y": river + (-190 if town.y < river else 220)}])
		roads.append([towns[0], towns[11], towns[17], towns[16], towns[13]])
		roads.append([towns[14], towns[7], towns[10], towns[5]])
	else:
		roads = [[{"x": -400, "y": 790}, towns[0], towns[1], {"x": 395, "y": FieldData.river_y(395)}, {"x": 470, "y": 320}, towns[3], towns[5]], [towns[0], {"x": 510, "y": 750}, towns[4], {"x": 1300, "y": 950}], [towns[4], {"x": 900, "y": FieldData.river_y(900)}, towns[3]], [towns[1], towns[2], {"x": 900, "y": FieldData.river_y(900)}]]
	layouts[theater] = {"size": Vector2(1440, 960) * scale_value, "scale": scale_value, "towns": towns, "forests": forests, "roads": roads, "crossings": crossings}
	return layouts[theater]
