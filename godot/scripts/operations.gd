class_name FieldOperations
extends RefCounted

const NEUTRAL_MORALE = 60.0
const HOURS_PER_SECOND = 0.08
const REINFORCEMENT_SECONDS_PER_HOUR = 120.0
const MAX_REINFORCEMENT_HOURS = 2.5
const MERGE_DISTANCE = 100.0
const FORCE_SPACING = 90.0
const RECOVERY_PACE = 0.7
const PURSUIT_PAUSE_SECONDS = 2.0

static func enabled(s: Dictionary) -> bool:
	return s.get("operation") != null

static func initialize(s: Dictionary) -> void:
	s.theater = "mantua"
	s.campaignMapVersion = 2
	s.hours = 6.0
	s.army.merge({"id": "army", "side": "player", "name": "Army of Italy", "commander": s.general.name, "x": 700.0, "y": 820.0, "morale": NEUTRAL_MORALE, "supply": s.supply, "path": [], "attackId": null, "retreatUntil": 0.0, "scoutUntil": 0.0, "scoutReady": 0.0, "defeated": false, "intent": "Holding", "home": {"x": 700.0, "y": 820.0}}, true)
	s["armies"] = [s.army]
	s.army["officerId"] = "army-general"
	s.army["specialty"] = "Army command"
	s.officers.append(FieldData.officer("army-general", s.general.name, 0, 240.0))
	s["armySelection"] = ["army"]
	s["selectedArmyId"] = "army"
	s["enemyUnits"] = []
	s["operation"] = {"version": 1, "nextForce": 2, "nextCorps": 3, "reserveSupply": 0.0, "hold": 0.0, "status": "active", "sites": [], "aiIndex": 0}
	for town in FieldCampaign.layout("mantua", 2).towns:
		var site = town.duplicate(true)
		site.merge({"progress": 0.0, "capturing": "", "contested": false, "rewarded": site.owner == "player"}, true)
		s.operation.sites.append(site)
	for u in s.units:
		FieldData.regiment_defaults(u)
		u["armyId"] = "army"
	for c in s.corps: c["armyId"] = "army"
	var specs = [["Advance column", "Lipthay", 2480.0, 920.0, 1500.0], ["Relief column", "Wurmser", 3440.0, 620.0, 1900.0], ["Mantua reserve", "Garrison command", 2880.0, 2210.0, 1250.0]]
	for i in s.enemies.size():
		var e: Dictionary = s.enemies[i]
		var spec: Array = specs[i]
		e.merge({"name": spec[0], "commander": spec[1], "side": "enemy", "x": spec[2], "y": spec[3], "strength": spec[4], "morale": NEUTRAL_MORALE, "supply": 400.0, "condition": 100.0, "path": [], "attackId": null, "retreatUntil": 0.0, "scoutUntil": 0.0, "scoutReady": 0.0, "defeated": false, "home": {"x": spec[2], "y": spec[3]}}, true)
		e.intel = {"x": e.x, "y": e.y, "at": s.hours, "strength": roundf(e.strength / 200) * 200}
		for j in 5:
			var kind = "cavalry" if j == 3 else "artillery" if j == 4 else "infantry"
			var count = roundf(e.strength * [0.30, 0.30, 0.23, 0.11, 0.06][j])
			var u = {"id": e.id + "-" + str(j), "armyId": e.id, "name": ["Grenadiers", "Line Infantry", "Fusiliers", "Chevaulegers", "Field Battery"][j], "kind": kind, "weapon": FieldArsenal.enemy_issue(j, i), "men": count, "maxMen": count, "commander": e.commander, "aiRole": "flank" if j == 3 else "battery" if j == 4 else "reserve" if j == 2 else "line"}
			FieldData.regiment_defaults(u)
			s.enemyUnits.append(u)
	s.log = [{"text": "Army of Italy assembled at Castiglione. Secure Valeggio and Mantua while retaining a supply depot.", "hours": s.hours}]
	FieldCampaign.migrate(s)

static func roster(s: Dictionary, army: Dictionary) -> Array:
	return (s.units if army.side == "player" else s.enemyUnits).filter(func(u): return u.armyId == army.id)

static func force(s: Dictionary, id: String) -> Dictionary:
	for a in s.armies + s.enemies:
		if a.id == id: return a
	return {}

static func selected(s: Dictionary) -> Array:
	return s.armies.filter(func(a): return a.id in s.armySelection and not a.defeated)

static func bind_selection(s: Dictionary) -> void:
	for army in s.armies:
		army["officerId"] = army.get("officerId")
		army["specialty"] = army.get("specialty", "Army command")
	s.army = force(s, s.selectedArmyId)
	s.supply = minf(500, s.army.supply)

static func select(model, ids: Array) -> bool:
	var s: Dictionary = model.state
	var valid_ids: Array = []
	for id in ids:
		if id is String and s.armies.any(func(a): return a.id == id and not a.defeated) and not id in valid_ids: valid_ids.append(id)
	if s.mode != "campaign" or valid_ids.is_empty(): return false
	s.armySelection = valid_ids
	s.selectedArmyId = valid_ids[0]
	bind_selection(s)
	model.publish(false)
	return true

static func morale_factor(morale: float) -> float:
	return clampf(1.0 + (NEUTRAL_MORALE - morale) * 0.006, 0.76, 1.36)

static func morale_name(morale: float) -> String:
	return "Elated" if morale >= 80 else "Confident" if morale >= 68 else "Steady" if morale >= 48 else "Shaken" if morale >= 30 else "Demoralized"

static func can_admin(s: Dictionary, a: Dictionary) -> bool:
	return s.mode == "campaign" and s.report == null and not a.defeated and a.path.is_empty() and a.get("pendingOrder") == null and a.retreatUntil <= s.hours

static func regroup_time(s: Dictionary, a: Dictionary) -> String:
	var minutes = ceili(maxf(0, a.retreatUntil - s.hours) * 60)
	return "%dh %02dm" % [minutes / 60, minutes % 60]

static func forced_retreat(s: Dictionary, a: Dictionary) -> bool:
	return a.retreatUntil > s.hours and not a.path.is_empty() and a.get("withdrawing", a.intent == "Withdrawing")

static func pursuit_paused(s: Dictionary, a: Dictionary) -> bool:
	return a.get("pursuitUntil", 0.0) > s.hours

static func recovery_pace(s: Dictionary, a: Dictionary) -> float:
	return RECOVERY_PACE if a.retreatUntil > s.hours else 1.0

static func split(model, ids: Array, name: String = "") -> bool:
	var s: Dictionary = model.state
	var a: Dictionary = s.army
	var members = roster(s, a)
	var moving = members.filter(func(u): return u.id in ids and u.men > 0)
	if not can_admin(s, a) or s.armies.size() >= 4 or moving.is_empty() or moving.size() != ids.size() or members.filter(func(u): return u.men > 0).size() <= moving.size(): return false
	var n = int(s.operation.nextForce)
	var detached = a.duplicate(true)
	detached.merge({"id": "army-" + str(n), "name": name.strip_edges().left(32) if not name.strip_edges().is_empty() else "Detachment " + str(n), "commander": "Acting " + moving[0].commander, "officerId": null, "path": [], "attackId": null, "intent": "Holding"}, true)
	var share = float(FieldData.men(moving)) / maxf(1, FieldData.men(members))
	detached.supply = a.supply * share
	a.supply -= detached.supply
	# Nearby offsets are cosmetic; a split never teleports troops across an obstacle.
	for offset in [Vector2(FORCE_SPACING, 0), Vector2(-FORCE_SPACING, 0), Vector2(0, FORCE_SPACING), Vector2(0, -FORCE_SPACING)]:
		var p = FieldData.pos(a) + offset
		if model.terrain.direct_route(FieldData.pos(a), p):
			detached.x = p.x
			detached.y = p.y
			break
	for corps in s.corps.duplicate():
		var part = moving.filter(func(u): return u.corpsId == corps.id)
		if part.is_empty(): continue
		var entire = not members.any(func(u): return u.corpsId == corps.id and not u.id in ids)
		var staff: Dictionary = corps if entire else corps.duplicate(true)
		if not entire:
			staff.id = "c" + str(int(s.operation.nextCorps))
			staff.commanderId = "commander-" + staff.id
			staff.name = "Detachment Corps " + str(int(s.operation.nextCorps))
			staff.officerId = null
			staff.commander = "Vacant command"
			s.operation.nextCorps += 1
			s.corps.append(staff)
		staff.armyId = detached.id
		for u in part:
			u.armyId = detached.id
			u.corpsId = staff.id
	s.armies.append(detached)
	s.operation.nextForce += 1
	model.log_event(detached.name + " detached from " + a.name + ".")
	select(model, [detached.id])
	model.publish()
	return true

static func can_merge(model, source: Dictionary, target: Dictionary) -> bool:
	var s: Dictionary = model.state
	return not source.is_empty() and not target.is_empty() and source.id != target.id and source.side == "player" and target.side == "player" and can_admin(s, source) and can_admin(s, target) and FieldData.distance(source, target) <= MERGE_DISTANCE and model.terrain.direct_route(FieldData.pos(source), FieldData.pos(target)) and roster(s, source).size() + roster(s, target).size() <= 8

static func merge(model, target_id: String) -> bool:
	var s: Dictionary = model.state
	var source: Dictionary = s.army
	var target = force(s, target_id)
	if not can_merge(model, source, target): return false
	var units = roster(s, source)
	var a = float(FieldData.men(units))
	var b = float(FieldData.men(roster(s, target)))
	for key in ["morale", "condition"]: target[key] = (source[key] * a + target[key] * b) / maxf(1, a + b)
	var supply: float = source.supply + target.supply
	target.supply = minf(500, supply)
	s.operation.reserveSupply += maxf(0, supply - 500)
	target.scoutUntil = maxf(source.scoutUntil, target.scoutUntil)
	target.scoutReady = maxf(source.scoutReady, target.scoutReady)
	var corps = s.corps.filter(func(c): return c.armyId == target.id)
	for u in units:
		var available = corps.filter(func(c): return s.units.filter(func(p): return p.corpsId == c.id).size() < 4)
		if available.is_empty():
			var c = model.find_id(s.corps, u.corpsId)
			c.armyId = target.id
			corps.append(c)
			available = [c]
		u.corpsId = available[0].id
		u.armyId = target.id
	s.corps = s.corps.filter(func(c): return s.units.any(func(u): return u.corpsId == c.id))
	s.armies.erase(source)
	model.log_event(source.name + " merged into " + target.name + ".")
	select(model, [target.id])
	model.publish()
	return true

static func at_depot(s: Dictionary, a: Dictionary) -> bool:
	return s.operation.sites.any(func(site): return site.kind in ["depot", "fort"] and site.owner == a.side and not site.contested and FieldData.distance(site, a) <= 160 * FieldCampaign.map_multiplier(s.get("campaignMapVersion", 2)))

static func visible(s: Dictionary, observer: Dictionary, target: Dictionary) -> bool:
	var concealed = FieldTerrain.kind(FieldData.pos(target), FieldCampaign.layout(s.theater, s.get("campaignMapVersion", 2))) == "woods"
	return FieldData.distance(observer, target) <= (700.0 if observer.scoutUntil > s.hours else 250.0 if concealed else 430.0)

static func pace(terrain, a: Dictionary, p: Vector2) -> float:
	var woods = FieldTerrain.kind(p, {"forests": terrain.forests}) == "woods"
	var road = terrain.near_road(p, 18)
	return 24.0 * FieldCampaign.MARCH_MODES[a.marchMode].pace * (0.65 + a.condition * 0.0035) * (1.15 if road else 0.60 if woods else 0.85)

static func travel_hours(terrain, a: Dictionary, path: Array, pace_factor: float = 1.0) -> float:
	var previous = FieldData.pos(a)
	var seconds = 0.0
	for point in path:
		var p = FieldData.pos(point)
		var count = maxi(1, ceili(previous.distance_to(p) / 80.0))
		for i in count:
			var sample = previous.lerp(p, (i + 0.5) / count)
			seconds += previous.distance_to(p) / count / maxf(1, pace(terrain, a, sample) * pace_factor * terrain.movement_factor(sample, sample + (p - previous).normalized() * 12))
		previous = p
	return seconds * HOURS_PER_SECOND

static func route(terrain, a: Dictionary, destination: Vector2) -> Array:
	var direct = terrain.route(FieldData.pos(a), destination)
	if direct.is_empty(): return []
	# Existing AStar2D supplies weighted road routing; the terrain path remains the fallback.
	var graph = AStar2D.new()
	var lookup: Dictionary = {}
	for road in terrain.roads:
		var last = -1
		for point in road:
			var p = FieldData.pos(point)
			if not lookup.has(p):
				lookup[p] = graph.get_point_count()
				graph.add_point(lookup[p], p)
			var id: int = lookup[p]
			if last >= 0 and terrain.direct_route(graph.get_point_position(last), p): graph.connect_points(last, id)
			last = id
	var start = graph.get_point_count()
	graph.add_point(start, FieldData.pos(a))
	var end = start + 1
	graph.add_point(end, destination)
	for id in [start, end]:
		var neighbors = Array(range(start))
		neighbors.sort_custom(func(x, y): return graph.get_point_position(x).distance_squared_to(graph.get_point_position(id)) < graph.get_point_position(y).distance_squared_to(graph.get_point_position(id)))
		var linked = 0
		for other in neighbors:
			if terrain.direct_route(graph.get_point_position(id), graph.get_point_position(other)):
				graph.connect_points(id, other)
				linked += 1
				if linked == 3: break
	var path: Array = []
	for point in graph.get_point_path(start, end).slice(1): path.append(FieldData.point(point))
	return path if not path.is_empty() and travel_hours(terrain, a, path) < travel_hours(terrain, a, direct) else direct

static func move(model, destination: Vector2, enemy_id = null) -> bool:
	var s: Dictionary = model.state
	if s.mode != "campaign" or s.report != null: return false
	var orders: Array = []
	var armies = selected(s)
	for i in armies.size():
		var a: Dictionary = armies[i]
		var p = destination + (Vector2(0, i * FORCE_SPACING) if enemy_id == null else Vector2.ZERO)
		var path = route(model.terrain, a, p)
		if path.is_empty(): continue
		orders.append({"army": a, "path": path, "destination": p})
	for order in orders:
		if forced_retreat(s, order.army) or pursuit_paused(s, order.army):
			order.army["pendingOrder"] = {"x": order.destination.x, "y": order.destination.y, "attackId": enemy_id}
			continue
		order.army.erase("pendingOrder")
		order.army["withdrawing"] = false
		order.army.path = order.path
		order.army.attackId = enemy_id
		order.army.intent = "Intercepting" if enemy_id != null else "Marching"
	if orders.is_empty(): return false
	model.sound_requested.emit("order", destination.x)
	model.publish()
	return true

static func start_pending_order(model, a: Dictionary) -> void:
	var pending = a.get("pendingOrder")
	if pending == null or forced_retreat(model.state, a) or pursuit_paused(model.state, a): return
	a.erase("pendingOrder")
	a["withdrawing"] = false
	var destination = FieldData.pos(pending)
	var target = force(model.state, pending.attackId) if pending.attackId != null else {}
	var attack = not target.is_empty() and not target.defeated and model.enemy_visible(target)
	if attack: destination = FieldData.pos(target)
	# Replan from the end of the retreat; never follow a hidden enemy's current position.
	var path = route(model.terrain, a, destination)
	if path.is_empty():
		model.log_event(a.name + ": queued order cancelled; no route to destination.")
		return
	a.path = path
	a.attackId = target.id if attack else null
	a.intent = "Intercepting" if attack else "Marching"
	model.log_event(a.name + ": queued march started.")

static func decide(model, a: Dictionary) -> void:
	var s: Dictionary = model.state
	if forced_retreat(s, a) or pursuit_paused(s, a): return
	var seen = s.armies.filter(func(p): return not p.defeated and visible(s, a, p))
	seen.sort_custom(func(x, y): return FieldData.distance(a, x) < FieldData.distance(a, y))
	if not seen.is_empty():
		var target: Dictionary = seen[0]
		a.lastSighting = {"x": target.x, "y": target.y, "at": s.hours, "strength": float(FieldData.men(roster(s, target)))}
	var destination = FieldData.pos(a)
	var bases = s.operation.sites.filter(func(site): return site.kind in ["depot", "fort"] and site.owner == "enemy")
	bases.sort_custom(func(x, y): return FieldData.distance(x, a) < FieldData.distance(y, a))
	var base = FieldData.pos(bases[0]) if not bases.is_empty() else FieldData.pos(a.home)
	if (a.retreatUntil > s.hours and a.morale < 48) or a.condition < 25 or a.morale < 30 or a.supply < 50:
		a.intent = "Recovering at depot"
		destination = base
	elif a.lastSighting != null and s.hours - a.lastSighting.at < 2:
		var support = 0.0
		for ally in s.enemies:
			if not ally.defeated and FieldData.distance(ally, a) < 650: support += ally.strength
		var threshold = 0.85 if a.personality == "aggressive" else 1.35 if a.personality == "cautious" else 1.05
		if a.lastSighting.strength * threshold <= a.strength:
			destination = FieldData.pos(a.lastSighting)
			a.intent = "Intercepting" if not seen.is_empty() else "Investigating last report"
		elif support > a.lastSighting.strength * 1.15:
			var allies = s.enemies.filter(func(e): return e.id != a.id and not e.defeated and FieldData.distance(e, a) < 650)
			destination = FieldData.pos(allies[0]) if not allies.is_empty() else base
			a.intent = "Concentrating forces"
		else:
			destination = base
			a.intent = "Avoiding superior force"
	else:
		var sites = s.operation.sites.duplicate()
		sites.sort_custom(func(x, y): return objective_score(x, a) < objective_score(y, a))
		if not sites.is_empty(): destination = FieldData.pos(sites[0])
		a.intent = "Guarding approaches" if a.personality == "cautious" else "Securing objectives"
	if FieldData.pos(a).distance_to(destination) < 35:
		a.path = []
	else:
		a.path = route(model.terrain, a, destination)
	a.marchMode = "slow" if a.condition < 45 else "route" if a.intent == "Intercepting" else "normal"

static func objective_score(site: Dictionary, a: Dictionary) -> float:
	return FieldData.distance(site, a) + (-950 if site.contested and site.owner == a.side else 0) + (-600 if site.owner != a.side and a.personality != "cautious" else 1000 if site.owner == a.side and a.personality != "cautious" and not site.contested else 0) + (-400 if site.kind in ["depot", "fort"] else 0)

static func update(model, dt: float) -> void:
	var s: Dictionary = model.state
	var hours = dt * HOURS_PER_SECOND
	s.hours += hours
	s.enemyClock += dt
	model.pursuit_clock += dt
	var repath = model.pursuit_clock >= 2.0
	if repath: model.pursuit_clock = 0
	if s.enemyClock >= 2.0:
		s.enemyClock = 0
		var index = int(s.operation.aiIndex) % s.enemies.size()
		s.operation.aiIndex = (index + 1) % s.enemies.size()
		if not s.enemies[index].defeated: decide(model, s.enemies[index])
	for a in s.armies + s.enemies:
		if a.defeated: continue
		if a.path.is_empty() or a.retreatUntil <= s.hours: a["withdrawing"] = false
		if a.side == "player": start_pending_order(model, a)
		if a.side == "player" and a.attackId != null and repath:
			var target = force(s, a.attackId)
			if target.is_empty() or target.defeated or not model.enemy_visible(target): a.attackId = null
			else: a.path = route(model.terrain, a, FieldData.pos(target))
		var before = FieldData.pos(a)
		a.resting = a.condition < 55 if a.get("resting", false) else a.condition < 8
		if not a.resting and not pursuit_paused(s, a): model.march(a, dt, pace(model.terrain, a, before) * recovery_pace(s, a))
		var moving = before.distance_to(FieldData.pos(a)) > 0.0001
		var fatigue: float = FieldCampaign.MARCH_MODES[a.marchMode].fatigue
		a.condition = clampf(a.condition + dt * (-fatigue if moving else 0.45), 0, 100)
		var depot = not moving and at_depot(s, a)
		a.supply = clampf(a.supply + hours * (35.0 if depot else -5.0 - FieldData.men(roster(s, a)) * 0.001), 0, 500)
		if depot and a.morale < NEUTRAL_MORALE: a.morale = minf(NEUTRAL_MORALE, a.morale + hours * 2)
		elif a.morale > NEUTRAL_MORALE: a.morale = maxf(NEUTRAL_MORALE, a.morale - hours * 0.5)
		if a.supply <= 0:
			a.morale = maxf(0, a.morale - hours * 2)
			a.condition = maxf(0, a.condition - hours * 2)
		for u in roster(s, a):
			u.condition = clampf(u.condition + dt * (-fatigue if moving else 0.45), 0, 100)
			if depot: u.ammo = minf(100, u.ammo + hours * 4)
		if a.path.is_empty() and a.side == "player": a.intent = "Regrouping" if a.retreatUntil > s.hours else "Holding"
		if a.side == "enemy":
			a.strength = FieldData.men(roster(s, a))
			if model.enemy_visible(a): a.intel = {"x": a.x, "y": a.y, "at": s.hours, "strength": roundf(a.strength / 100) * 100}
	update_sites(model, hours)
	bind_selection(s)
	for a in s.armies:
		if a.defeated or a.retreatUntil > s.hours or FieldData.men(roster(s, a)) <= 0: continue
		for enemy in s.enemies:
			if enemy.defeated or enemy.retreatUntil > s.hours: continue
			if FieldData.distance(a, enemy) < 70 and model.terrain.direct_route(FieldData.pos(a), FieldData.pos(enemy)):
				select(model, [a.id])
				model.start_battle(enemy.id)
				return

static func update_sites(model, hours: float) -> void:
	var s: Dictionary = model.state
	for site in s.operation.sites:
		var nearby = (s.armies + s.enemies).filter(func(a): return not a.defeated and a.retreatUntil <= s.hours and FieldData.distance(a, site) < 140 * FieldCampaign.map_multiplier(s.get("campaignMapVersion", 2)) and model.terrain.direct_route(FieldData.pos(a), FieldData.pos(site)))
		var player = nearby.any(func(a): return a.side == "player")
		var enemy = nearby.any(func(a): return a.side == "enemy")
		site.contested = player and enemy
		var side = "player" if player and not enemy else "enemy" if enemy and not player else ""
		var occupiers = nearby.filter(func(a): return a.path.is_empty() and a.condition >= 15)
		var men = 0
		for a in occupiers: men += FieldData.men(roster(s, a))
		if side.is_empty() or side == site.owner or men < (600 if site.kind == "fort" else 100):
			site.progress = maxf(0, site.progress - hours)
			continue
		if site.capturing != side: site.progress = 0.0
		site.capturing = side
		site.progress += hours
		if site.progress >= (8.0 if site.kind == "fort" else 0.4):
			site.owner = side
			site.progress = 0.0
			site.capturing = ""
			model.log_event(site.name + " secured by " + ("your army." if side == "player" else "the enemy."))
			if side == "player" and not site.rewarded:
				s.cash += 600 if site.kind == "fort" else 150
				site.rewarded = true
	var key_sites = s.operation.sites.filter(func(site): return site.id in ["valeggio", "mantua"])
	var supply = s.operation.sites.any(func(site): return site.kind == "depot" and site.owner == "player" and not site.contested)
	var held = supply and key_sites.all(func(site): return site.owner == "player" and not site.contested)
	s.operation.hold = s.operation.hold + hours if held else 0.0
	if s.operation.status == "active" and s.operation.hold >= 2.0:
		s.operation.status = "victory"
		s.paused = true
		model.log_event("Operation won: Mantua and Valeggio secured, with a supply depot retained.")
	if s.operation.status == "active" and FieldData.men(s.units) <= 0:
		s.operation.status = "defeat"
		s.paused = true

static func encounter(model, enemy_id: String) -> Dictionary:
	var s: Dictionary = model.state
	var enemy = force(s, enemy_id)
	var primary: Dictionary = s.army
	var origin = (FieldData.pos(primary) + FieldData.pos(enemy)) * 0.5
	if not model.terrain.passable(origin): origin = FieldData.pos(primary)
	var sites = s.operation.sites.duplicate()
	sites.sort_custom(func(a, b): return FieldData.pos(a).distance_squared_to(origin) < FieldData.pos(b).distance_squared_to(origin))
	var site: Dictionary = sites[0]
	var geographic_scale = FieldCampaign.map_multiplier(s.get("campaignMapVersion", 2))
	var scenario = "bridge" if absf(model.terrain.river_distance(origin)) < 240 * geographic_scale else "ridge" if origin.y < 850 * geographic_scale and origin.x < 1750 * geographic_scale else "village"
	var schedule: Array = []
	for a in [primary, enemy] + s.armies.filter(func(p): return p.id != primary.id) + s.enemies.filter(func(p): return p.id != enemy.id):
		if a.defeated or FieldData.men(roster(s, a)) <= 0 or a.retreatUntil > s.hours: continue
		var immediate = a.id in [primary.id, enemy.id]
		var path = route(model.terrain, a, origin)
		var hours = 0.0 if immediate else travel_hours(model.terrain, a, path)
		if not immediate and (path.is_empty() or hours > MAX_REINFORCEMENT_HOURS): continue
		var delta = FieldData.pos(a) - origin
		var edge = ("east" if delta.x > 0 else "west") if absf(delta.x) >= absf(delta.y) else ("south" if delta.y > 0 else "north")
		schedule.append({"armyId": a.id, "side": a.side, "arrival": 0.0 if immediate else maxf(15, hours * REINFORCEMENT_SECONDS_PER_HOUR), "edge": edge, "origin": FieldData.point(FieldData.pos(a)), "morale": a.morale, "supply": a.supply, "startMen": float(FieldData.men(roster(s, a)))})
	return {"schedule": schedule, "origin": FieldData.point(origin), "name": "Battle near " + site.name, "scenario": scenario, "edge": "east" if primary.x > enemy.x else "west", "siteId": site.id}

static func muster(s: Dictionary, encounter_data: Dictionary) -> Array:
	var units: Array = []
	for entry in encounter_data.schedule:
		var army = force(s, entry.armyId)
		var members = roster(s, army).filter(func(u): return u.men > 0)
		for i in members.size():
			var u: Dictionary = members[i].duplicate(true)
			var edge: String = entry.edge if entry.arrival > 0 else encounter_data.edge if army.side == "player" else "west" if encounter_data.edge == "east" else "east"
			var offset = 140.0 + (i + 0.5) * 650.0 / maxf(1, members.size())
			var p = Vector2(220 if edge == "west" else 1220, offset) if edge in ["west", "east"] else Vector2(offset + 230, 80 if edge == "north" else 880)
			u.merge({"side": army.side, "startMen": u.men, "x": p.x, "y": p.y, "morale": clampf(100 + (army.morale - NEUTRAL_MORALE) * 0.4, 76, 100), "armyMorale": army.morale, "condition": minf(u.condition, army.condition), "arrival": entry.arrival, "facing": {"west": 0.0, "east": PI, "north": PI / 2, "south": -PI / 2}[edge], "routed": false, "withdrawn": false, "retreating": false, "kills": 0.0, "reload": i * 0.3, "visible": army.side == "player", "target": null, "waypoints": [], "goal": null, "orderQueue": [], "attackId": null, "formationChange": null, "coverId": null, "coverOrderId": null}, true)
			units.append(u)
	return units

static func arrive(model, entry: Dictionary) -> void:
	var b: Dictionary = model.state.battle
	var wagon: Dictionary = b.wagons[0 if entry.side == "player" else 1]
	if wagon.health > 0: wagon.stock += entry.supply
	for u in b.units.filter(func(unit): return unit.armyId == entry.armyId):
		var origin = FieldData.pos(u)
		var found = false
		for radius in range(0, 193, 16):
			for angle in 16:
				var p = origin + Vector2.from_angle(angle * TAU / 16.0) * radius
				if not model.terrain.order_bounds().has_point(p) or not model.terrain.passable(p, true, FieldFormations.bounds(u).size.length() * 0.5): continue
				var trial = u.duplicate()
				trial.x = p.x
				trial.y = p.y
				if b.units.any(func(other): return other.id != u.id and other.arrival <= b.time and other.men > 0 and not other.withdrawn and FieldContact.gap(FieldContact.shape(trial), FieldContact.shape(other)) < 8): continue
				u.x = p.x
				u.y = p.y
				model.formations.reset(u)
				found = true
				break
			if found: break
	model.sync_hosts()
	model.log_event(force(model.state, entry.armyId).name + " reached the battlefield.")

static func resolve(model, won: bool, retreat: bool) -> bool:
	var s: Dictionary = model.state
	var b: Dictionary = s.battle
	var enemy_losses = 0.0
	var player_losses = 0.0
	var loot: Dictionary = {}
	var regiments: Array = []
	var morale_changes: Array = []
	var arrived = b.campaignForces.filter(func(entry): return entry.arrival <= b.time)
	var supply_start = {"player": 0.0, "enemy": 0.0}
	for entry in arrived: supply_start[entry.side] += entry.supply
	for entry in arrived:
		var a = force(s, entry.armyId)
		if entry.arrival > 0: a["redeployAt"] = b.origin.duplicate()
		var victory: bool = won if a.side == "player" else not won
		if a.side == "player" and a.get("officerId") != null:
			var commander = model.find_id(s.officers, a.officerId)
			if FieldData.ready(commander, s.hours): commander.xp += minf(40, b.time / 35.0 + (16 if victory else 5))
		var losses = 0.0
		var condition = 0.0
		var survivors = 0.0
		for u in roster(s, a):
			var result = model.find_id(b.units, u.id)
			if result.is_empty(): continue
			var pieces = [result] + b.units.filter(func(p): return p.get("parentId") == u.id)
			var men = 0.0
			var ammunition = 0.0
			var kills = 0.0
			var fatigue = 0.0
			for piece in pieces:
				men += piece.men
				ammunition += piece.ammo * piece.men
				fatigue += piece.condition * piece.men
				kills += piece.kills
			var lost = maxf(0, u.men - floorf(men))
			losses += lost
			if a.side == "enemy" and won:
				var captured = FieldArsenal.capture_count(u.kind, lost)
				loot[u.weapon] = loot.get(u.weapon, 0) + captured
			u.men = floorf(men)
			u.ammo = ammunition / maxf(1, men)
			u.condition = fatigue / maxf(1, men)
			u.skills = result.skills.duplicate(true)
			u.experience = minf(5, u.experience + (0.6 if victory else 0.2))
			u.history.push_front({"battle": b.name, "won": victory, "retreat": not victory, "losses": roundi(lost), "kills": floori(kills), "hours": s.hours})
			if u.history.size() > 12: u.history.resize(12)
			condition += u.condition * u.men
			survivors += u.men
			if a.side == "player":
				regiments.append({"id": u.id, "name": u.name, "men": u.men, "losses": lost, "kills": kills, "experience": u.experience})
				var officer = model.find_id(s.officers, u.officerId)
				if FieldData.ready(officer, s.hours):
					officer.xp += minf(45, b.time / 25.0 + (15 if victory else 5))
					if u.men < result.startMen * 0.12: officer.dead = true
					elif lost > result.startMen * 0.35:
						officer.woundedUntil = s.hours + 8
						officer.wounds += 1
					u.commander = FieldData.load_data().ranks[FieldData.rank_of(officer)] + " " + officer.name
		var old: float = a.morale
		a.morale = clampf(a.morale + (12 if victory else -18) - losses / maxf(1, entry.startMen) * 25, 0, 100)
		a.condition = condition / maxf(1, survivors)
		a.defeated = survivors <= 0
		a.path = []
		a.attackId = null
		a.erase("pendingOrder")
		a.intent = "Regrouping" if victory else "Withdrawing"
		a["withdrawing"] = not victory and not a.defeated
		# Repeated encounters cannot immediately re-catch the same retreating column.
		a.retreatUntil = s.hours + (0.5 if victory else 4.0)
		a["pursuitUntil"] = s.hours + PURSUIT_PAUSE_SECONDS * HOURS_PER_SECOND if victory else 0.0
		var wagon: Dictionary = b.wagons[0 if a.side == "player" else 1]
		var consumed = maxf(0, supply_start[a.side] - wagon.stock)
		a.supply = maxf(0, entry.supply - consumed * entry.supply / maxf(1, supply_start[a.side]))
		if a.side == "player":
			player_losses += losses
			morale_changes.append({"name": a.name, "before": old, "after": a.morale})
		else:
			enemy_losses += losses
			a.strength = survivors
		if not victory and not a.defeated:
			# The defeated force marches home after returning to the campaign; no teleport.
			a["needsRetreatRoute"] = true
		model.log_event("%s: morale %d -> %d; %d casualties." % [a.name, old, a.morale, losses])
	for corps in s.corps:
		if not arrived.any(func(entry): return entry.armyId == corps.armyId): continue
		var officer = model.find_id(s.officers, corps.officerId)
		if FieldData.ready(officer, s.hours):
			officer.xp += minf(35, b.time / 40 + (12 if won else 4))
			corps.commander = FieldData.load_data().ranks[FieldData.rank_of(officer)] + " " + officer.name
	var reward = 350 + floori(enemy_losses * 3) if won else 0
	s.cash += reward
	if won: s.victories += 1
	var damaged = FieldArsenal.salvage(s, loot)
	var officer_events: Array = []
	for previous in b.officerStart:
		var o = model.find_id(s.officers, previous.id)
		if o.dead and not previous.dead: officer_events.append({"name": o.name, "status": "Killed in action"})
		elif o.woundedUntil > previous.woundedUntil: officer_events.append({"name": o.name, "status": "Wounded"})
		elif FieldData.rank_of(o) > previous.rank: officer_events.append({"name": o.name, "status": "Promoted"})
	s.report = {"won": won, "retreat": retreat, "name": b.name, "casualties": player_losses, "enemyCasualties": enemy_losses, "reward": reward, "loot": loot.get("musket", 0), "capturedWeapons": loot, "armyMorale": morale_changes, "regiments": regiments, "officers": officer_events, "complete": false}
	s.report["damagedWeapons"] = damaged
	s.report.loot = loot.values().reduce(func(total, amount): return total + amount, 0)
	s.battle = null
	s.mode = "campaign"
	s.paused = true
	s.selected = []
	s.selectedCommander = null
	s.selectedSupply = false
	s.orderMode = "move"
	model.tactics.clear_ai()
	model.formations.groups.clear()
	model.formations.motion.clear()
	model.terrain.configure(s)
	for a in s.armies + s.enemies:
		if a.has("redeployAt"):
			var p = FieldData.pos(a.redeployAt)
			var direction = (FieldData.pos(a) - p).normalized()
			var offset = p + direction * 80
			if model.terrain.direct_route(p, offset): p = offset
			a.x = p.x
			a.y = p.y
			a.erase("redeployAt")
		if not a.get("needsRetreatRoute", false): continue
		a.erase("needsRetreatRoute")
		var bases = s.operation.sites.filter(func(site): return site.owner == a.side and site.kind in ["depot", "fort"])
		bases.sort_custom(func(x, y): return FieldData.distance(x, a) < FieldData.distance(y, a))
		var destination = FieldData.pos(bases[0]) if not bases.is_empty() else FieldData.pos(a.home)
		a.path = route(model.terrain, a, destination)
	var living = s.armies.filter(func(a): return not a.defeated)
	if not living.is_empty() and s.army.defeated: select(model, [living[0].id])
	if living.is_empty(): s.operation.status = "defeat"
	bind_selection(s)
	model.publish()
	return true

static func valid(model, s: Dictionary) -> bool:
	if not enabled(s): return s.get("theater") != "mantua"
	if s.get("theater") != "mantua" or not model.valid_shape(s.operation, {"version": 0, "nextForce": 0, "nextCorps": 0, "reserveSupply": 0.0, "hold": 0.0, "status": "", "sites": [], "aiIndex": 0}): return false
	if s.operation.version != 1 or s.operation.status not in ["active", "victory", "defeat"] or s.operation.reserveSupply < 0 or s.operation.hold < 0: return false
	for key in ["nextForce", "nextCorps", "aiIndex"]:
		if s.operation[key] != floor(s.operation[key]) or s.operation[key] < (2 if key == "nextForce" else 3 if key == "nextCorps" else 0): return false
	if not s.get("armies") is Array or s.armies.is_empty() or s.armies.size() > 4 or not s.get("enemyUnits") is Array or s.enemyUnits.size() > 32: return false
	if not s.get("armySelection") is Array or not s.get("selectedArmyId") is String: return false
	var army_ids: Dictionary = {}
	var map_size = FieldCampaign.layout("mantua", s.get("campaignMapVersion", 2)).size
	for a in s.armies + s.enemies:
		if not model.valid_shape(a, {"id": "", "name": "", "commander": "", "side": "", "x": 0.0, "y": 0.0, "morale": 0.0, "condition": 0.0, "supply": 0.0, "retreatUntil": 0.0, "scoutUntil": 0.0, "scoutReady": 0.0, "defeated": false, "intent": "", "home": {"x": 0.0, "y": 0.0}}): return false
		if a.id.is_empty() or army_ids.has(a.id) or a.side != ("player" if a in s.armies else "enemy") or not model.valid_points(a.get("path")): return false
		army_ids[a.id] = true
		for key in ["morale", "condition"]:
			if a[key] < 0 or a[key] > 100: return false
		if a.supply < 0 or a.supply > 500 or a.x < 0 or a.x > map_size.x or a.y < 0 or a.y > map_size.y: return false
		for point in a.path:
			if point.x < 0 or point.x > map_size.x or point.y < 0 or point.y > map_size.y: return false
		if not a.get("resting", false) is bool or not a.get("withdrawing", false) is bool or a.retreatUntil < 0 or a.scoutUntil < 0 or a.scoutReady < 0: return false
		if not model.valid_shape(a.get("pursuitUntil", 0.0), 0.0) or a.get("pursuitUntil", 0.0) < 0: return false
		if a.get("marchMode") not in FieldCampaign.MARCH_MODES or (a.get("attackId") != null and not s.enemies.any(func(e): return e.id == a.attackId)): return false
		var pending = a.get("pendingOrder")
		if pending != null:
			if a.side != "player" or not model.valid_shape(pending, {"x": 0.0, "y": 0.0}) or not pending.has("attackId"): return false
			if pending.x < 0 or pending.x > map_size.x or pending.y < 0 or pending.y > map_size.y: return false
			if pending.attackId != null and (not pending.attackId is String or not s.enemies.any(func(e): return e.id == pending.attackId)): return false
	if not s.armies.any(func(a): return a.id == s.selectedArmyId) or s.army.id != s.selectedArmyId or s.armySelection.is_empty(): return false
	for id in s.armySelection:
		if not s.armies.any(func(a): return a.id == id): return false
	if s.armySelection.size() != s.armySelection.reduce(func(ids, id): ids[id] = true; return ids, {}).size(): return false
	var ids: Dictionary = {}
	for u in s.units + s.enemyUnits:
		if not model.valid_regiment(u) or not u.get("armyId") is String or not army_ids.has(u.armyId) or ids.has(u.id): return false
		ids[u.id] = true
		if force(s, u.armyId).side != ("player" if u in s.units else "enemy"): return false
	for a in s.armies:
		if roster(s, a).is_empty() or roster(s, a).size() > 8: return false
		if a.get("officerId") != null and model.find_id(s.officers, a.officerId).is_empty(): return false
	var assigned: Dictionary = {}
	for target in s.armies + s.corps + s.units:
		var id = target.get("officerId")
		if id == null: continue
		if assigned.has(id): return false
		assigned[id] = true
	for c in s.corps:
		if not c.get("armyId") is String or not s.armies.any(func(a): return a.id == c.armyId): return false
		if s.units.any(func(u): return u.corpsId == c.id and u.armyId != c.armyId): return false
	var site_ids: Dictionary = {}
	if not s.operation.sites is Array or s.operation.sites.size() != FieldCampaign.layout("mantua").towns.size(): return false
	for site in s.operation.sites:
		if not model.valid_shape(site, {"id": "", "name": "", "x": 0.0, "y": 0.0, "kind": "", "owner": "", "progress": 0.0, "capturing": "", "contested": false, "rewarded": false}): return false
		if site_ids.has(site.id) or not FieldCampaign.layout("mantua").towns.any(func(t): return t.id == site.id and t.kind == site.kind): return false
		site_ids[site.id] = true
		if site.owner not in ["player", "enemy", "neutral"] or site.capturing not in ["player", "enemy", ""] or site.progress < 0 or site.progress > 8: return false
	if s.mode == "battle":
		if not model.valid_shape(s.battle.get("campaignForces"), [{"armyId": "", "side": "", "arrival": 0.0, "edge": "", "origin": {"x": 0.0, "y": 0.0}, "morale": 0.0, "supply": 0.0, "startMen": 0.0}]): return false
		var entries: Dictionary = {}
		for entry in s.battle.campaignForces:
			if not army_ids.has(entry.armyId) or entries.has(entry.armyId) or entry.side != force(s, entry.armyId).side or entry.edge not in ["west", "east", "north", "south"] or entry.arrival < 0 or entry.arrival > MAX_REINFORCEMENT_HOURS * REINFORCEMENT_SECONDS_PER_HOUR: return false
			entries[entry.armyId] = true
			if entry.supply < 0 or entry.supply > 500 or entry.morale < 0 or entry.morale > 100 or entry.startMen <= 0: return false
		if not s.battle.campaignForces.any(func(entry): return entry.side == "player" and entry.arrival == 0) or not s.battle.campaignForces.any(func(entry): return entry.side == "enemy" and entry.arrival == 0): return false
		for u in s.battle.units:
			if not entries.has(u.get("armyId")) or not model.valid_shape(u.get("armyMorale"), 0.0) or u.armyMorale < 0 or u.armyMorale > 100: return false
		for c in s.battle.commanders:
			if not model.valid_shape(c.get("arrival", 0.0), 0.0) or c.get("arrival", 0.0) < 0: return false
			if c.get("armyId") != null and (not c.armyId is String or not entries.has(c.armyId)): return false
	if s.report != null:
		if not model.valid_shape(s.report.get("armyMorale"), [{"name": "", "before": 0.0, "after": 0.0}]) or not s.report.get("capturedWeapons") is Dictionary: return false
		for key in s.report.capturedWeapons:
			if key not in FieldData.weapons() or not model.valid_shape(s.report.capturedWeapons[key], 0) or s.report.capturedWeapons[key] < 0: return false
	return true
