class_name FieldTactics
extends RefCounted

var fog_cursor = 0
var fog_budget = 0.0
var visibility_cursor = 0
var ai_context: Dictionary = {}
var ai_queue: Array = []
var ai_max_micros = 0
var cache_shots = false
var shot_cache: Dictionary = {}
var clear_cache: Dictionary = {}
var index = FieldBattleIndex.new()
var passage_plans = 1
var profile_sections = {"visibility": 0, "contacts": 0, "ai": 0, "support": 0, "movement": 0, "combat": 0, "finish": 0, "walk": 0, "target": 0, "orders": 0}

func clear_ai() -> void:
	index.enabled = false
	ai_context.clear()
	ai_queue.clear()
	ai_max_micros = 0

func update_contacts(model) -> void:
	var b: Dictionary = model.state.battle
	index.rebuild(b)
	var nearest: Dictionary = {}
	for u in b.units:
		u["meleeTargetId"] = null
		u["meleeContacts"] = []
	for a in index.players:
		var a_shape: Dictionary = index.shapes[a.id]
		for enemy in index.nearby(a_shape.p, a_shape.radius + FieldContact.REACH + 0.05, "enemy"):
			var other_shape: Dictionary = index.shapes[enemy.id]
			if not FieldContact.near(a_shape, other_shape, FieldContact.REACH + 0.05): continue
			var gap = FieldContact.gap(a_shape, other_shape)
			if gap > FieldContact.REACH + 0.05: continue
			enemy.visible = true
			for pair in [[a, enemy], [enemy, a]]:
				var u: Dictionary = pair[0]
				var other: Dictionary = pair[1]
				u.meleeContacts.append(other.id)
				if gap < nearest.get(u.id, INF):
					nearest[u.id] = gap
					u.meleeTargetId = other.id
				u.meleeUntil = b.time + 0.2
				u.fightingUntil = maxf(u.fightingUntil, b.time + 0.2)

func contact_target(model, u: Dictionary) -> Dictionary:
	if index.enabled: return index.units.get(u.get("meleeTargetId"), {})
	return model.find_id(model.state.battle.units, u.get("meleeTargetId"))

func nearby(model, u: Dictionary, side: String, padding: float) -> Array:
	if not index.enabled: return active(model.state.battle, side)
	var shape: Dictionary = index.shapes.get(u.id, {})
	if shape.is_empty(): return index.nearby(FieldData.pos(u), padding, side)
	return index.nearby(shape.p, shape.radius + padding, side)

func contact_shape(u: Dictionary) -> Dictionary:
	return index.shapes.get(u.id, {}) if index.enabled and index.shapes.has(u.id) else FieldContact.shape(u)

static func active(b: Dictionary, side: String) -> Array:
	return b.units.filter(func(u): return u.side == side and u.men > 0 and not u.routed and not u.withdrawn and u.arrival <= b.time)

func update_visibility(model, full_fog: bool = true, budget: int = 0) -> void:
	var b: Dictionary = model.state.battle
	var observers = active(b, "player") + b.commanders.filter(func(c): return not c.unavailable)
	var enemy_observers = active(b, "enemy")
	var targets: Array = b.units + b.wagons
	var count = targets.size() if budget <= 0 else mini(budget, targets.size())
	for i in count:
		var u: Dictionary = targets[(visibility_cursor + i) % targets.size()]
		u.visible = not u.get("withdrawn", false) and (u.side == "player" or (u.get("arrival", 0) <= b.time and observers.any(func(o): return model.terrain.line_of_sight(o, u))))
		u["seenByEnemy"] = not u.get("withdrawn", false) and u.get("arrival", 0) <= b.time and enemy_observers.any(func(o): return model.terrain.line_of_sight(o, u))
	visibility_cursor = (visibility_cursor + count) % targets.size()
	if full_fog or not b.has("visibleCells"):
		b["visibleCells"] = []
		var dimensions = model.terrain.fog_size()
		b.visibleCells.resize(dimensions.x * dimensions.y)
		fog_cursor = 0
		update_fog(model, b.visibleCells.size())

func update_fog(model, budget: int, time_budget_usec: int = 0) -> int:
	var b: Dictionary = model.state.battle
	var observers = active(b, "player") + b.commanders.filter(func(c): return not c.unavailable)
	var dimensions = model.terrain.fog_size()
	var deadline = Time.get_ticks_usec() + time_budget_usec if time_budget_usec > 0 else 0
	var processed = 0
	# Fog is cosmetic; spread its existing LOS samples across ticks to avoid large frame spikes.
	for n in budget:
		var i = fog_cursor
		var p = {"x": (i % dimensions.x) * 48 + 24, "y": (i / dimensions.x) * 48 + 24}
		b.visibleCells[i] = observers.any(func(o): return model.terrain.line_of_sight(o, p))
		fog_cursor = (fog_cursor + 1) % b.visibleCells.size()
		processed += 1
		if deadline > 0 and processed % 4 == 0 and Time.get_ticks_usec() >= deadline: break
	return processed

func visible_target(model, u: Dictionary, enemy: Dictionary) -> bool:
	return not enemy.is_empty() and enemy.side != u.side and enemy.men > 0 and not enemy.routed and not enemy.withdrawn and enemy.arrival <= model.state.battle.time and (enemy.get("seenByEnemy", false) if u.side == "enemy" else enemy.visible)

func inside_arc(u: Dictionary, enemy: Dictionary) -> bool:
	return FieldData.weapons()[u.weapon].range <= 45 or cos((FieldData.pos(enemy) - FieldData.pos(u)).angle() - u.facing) > 0.45

func clear_shot(model, u: Dictionary, enemy: Dictionary) -> bool:
	if cache_shots and u.kind != "artillery":
		var key = [u.id, enemy.id, u.x, u.y, u.facing, u.weapon]
		if clear_cache.has(key): return clear_cache[key]
		var result = shot_obstruction(model, u, enemy, FieldData.pos(u)).is_empty()
		clear_cache[key] = result
		return result
	if u.kind == "artillery": return not firing_lanes(model, u, enemy).is_empty()
	return shot_obstruction(model, u, enemy, FieldData.pos(u)).is_empty()

func shot_obstruction(model, u: Dictionary, enemy: Dictionary, a: Vector2) -> String:
	var origin = {"x": a.x, "y": a.y, "kind": u.kind}
	var b = FieldData.pos(enemy)
	var arc = minf(70, a.distance_to(b) * 0.24) if FieldArsenal.ammunition(u, a.distance_to(b)) == "shell" else 0.0
	if not model.terrain.line_of_sight(origin, enemy, true, arc): return "Terrain blocks fire"
	var delta = b - a
	if delta.length_squared() < 0.0001:
		return ""
	for other in model.state.battle.units:
		if other.side != u.side or other.men <= 0 or other.withdrawn or other.arrival > model.state.battle.time: continue
		if other.id == u.id:
			continue
		var local_a = (a - FieldData.pos(other)).rotated(PI / 2.0 - other.facing)
		var local_b = (b - FieldData.pos(other)).rotated(PI / 2.0 - other.facing)
		var bounds = FieldFormations.bounds(other)
		var hit = FieldLandscape.segment_hit(local_a, local_b, bounds)
		if hit == null: continue
		if arc > 0:
			var exit_hit = FieldLandscape.segment_hit(local_b, local_a, bounds)
			var clear = true
			for edge in [hit, exit_hit if exit_hit != null else hit]:
				var t = local_a.distance_to(edge) / delta.length()
				var point = a.lerp(b, t)
				var height = lerpf(model.terrain.height_at(a) + 6, model.terrain.height_at(b) + 6, t) + 4 * arc * t * (1 - t)
				if height <= model.terrain.height_at(point) + 16: clear = false
			if clear: continue
		return "Friendly troops block fire"
	return ""

func firing_lanes(model, u: Dictionary, enemy: Dictionary) -> Array:
	var key = str(u.id) + ":" + str(enemy.id)
	if cache_shots and shot_cache.has(key): return shot_cache[key]
	var lanes: Array = []
	var offsets = FieldFormations.offsets(u)
	var count = clampi(ceili(u.men / 30.0), 1, 12)
	var living = 0
	for i in offsets.size():
		if i in u.get("deadSlots", []): continue
		if living >= count: break
		living += 1
		var origin = FieldFormations.world_point(u, offsets[i])
		if shot_obstruction(model, u, enemy, origin).is_empty(): lanes.append(origin)
	if cache_shots: shot_cache[key] = lanes
	return lanes

func battery_status(model, u: Dictionary, enemy: Dictionary) -> String:
	if u.retreating: return "Withdrawing"
	if u.holdFire: return "Hold fire"
	if u.target != null: return "Moving"
	if enemy.is_empty():
		var nearest = INF
		for candidate in model.state.battle.units:
			if not visible_target(model, u, candidate): continue
			var d = FieldData.distance(u, candidate)
			if d < nearest:
				nearest = d
				enemy = candidate
	if enemy.is_empty(): return "No spotted target"
	if not visible_target(model, u, enemy): return "Target not spotted"
	if FieldData.distance(u, enemy) > FieldData.weapons()[u.weapon].range: return "Out of range"
	if not inside_arc(u, enemy): return "Outside firing arc"
	if u.reload > 0: return "Reloading"
	var lanes = firing_lanes(model, u, enemy)
	if lanes.is_empty():
		var reason = shot_obstruction(model, u, enemy, FieldData.pos(u))
		return "No clear gun lane" if reason.is_empty() else reason
	if u.reload > 0: return "Reloading"
	return "%d guns clear / %s" % [lanes.size(), FieldArsenal.ammunition(u, FieldData.distance(u, enemy)).capitalize()]

func seek_firing_position(model, u: Dictionary, enemy: Dictionary) -> bool:
	if model.state.battle.time < u.get("batteryRetryAt", 0.0): return false
	u["batteryRetryAt"] = model.state.battle.time + 3.0
	var start = FieldData.pos(u)
	var target = FieldData.pos(enemy)
	var reach: float = FieldData.weapons()[u.weapon].range
	var candidates: Array[Vector2] = []
	for radius in [55.0, 110.0, 165.0]:
		for i in 8: candidates.append(start + Vector2.from_angle(i * TAU / 8.0) * radius)
	candidates.sort_custom(func(a, b): return a.distance_squared_to(start) + a.distance_squared_to(target) * 0.05 < b.distance_squared_to(start) + b.distance_squared_to(target) * 0.05)
	for p in candidates:
		if not model.terrain.order_bounds().has_point(p) or p.distance_to(target) > reach * 0.96 or p.distance_to(target) < 90: continue
		if not model.terrain.passable(p, true, 12): continue
		var trial = u.duplicate()
		trial.x = p.x
		trial.y = p.y
		trial.facing = (target - p).angle()
		var shape = FieldContact.shape(trial)
		if model.state.battle.units.any(func(other): return other.id != u.id and other.men > 0 and not other.withdrawn and other.arrival <= model.state.battle.time and FieldContact.gap(shape, FieldContact.shape(other)) < 12): continue
		if not clear_shot(model, trial, enemy): continue
		if not model.path_unit(u, p, trial.facing): continue
		u["batteryReposition"] = true
		u.aimComplete = false
		return true
	return false

func automatic_target(model, u: Dictionary, enemy: Dictionary) -> bool:
	# Keep tracking a spotted target while reloading. Full weapon/terrain lanes
	# are checked again on the exact tick a volley can actually be released.
	return visible_target(model, u, enemy) and FieldData.distance(u, enemy) <= FieldData.weapons()[u.weapon].range and inside_arc(u, enemy) and (u.reload > 0 or clear_shot(model, u, enemy))

func combat_target(model, u: Dictionary) -> Dictionary:
	var contact = contact_target(model, u)
	if not contact.is_empty(): return contact
	var units: Array = model.state.battle.units
	var ordered: Dictionary = index.units.get(u.attackId, {}) if index.enabled else model.find_id(units, u.attackId)
	if visible_target(model, u, ordered):
		if FieldData.distance(u, ordered) > FieldData.weapons()[u.weapon].range:
			u.aimComplete = false
		u.fireTargetId = ordered.id
		return ordered
	if u.attackId != null:
		FieldCharge.cancel(u)
		u.attackId = null
		if u.side == "player":
			u.target = null
			u.waypoints = []
	if u.kind == "infantry" and u.target != null and not u.fallingBack: return {}
	var previous: Dictionary = index.units.get(u.fireTargetId, {}) if index.enabled else model.find_id(units, u.fireTargetId)
	if automatic_target(model, u, previous):
		return previous
	var nearest: Dictionary = {}
	var best = INF
	var candidates = index.nearby(FieldData.pos(u), FieldData.weapons()[u.weapon].range, "enemy" if u.side == "player" else "player") if index.enabled else units
	for enemy in candidates:
		var d = FieldData.distance(u, enemy)
		if d >= best: continue
		if not automatic_target(model, u, enemy):
			continue
		if d < best:
			nearest = enemy
			best = d
	u.fireTargetId = nearest.get("id")
	return nearest

func engagement_facing(u: Dictionary, enemy: Dictionary):
	if u.get("meleeTargetId") != null: return null
	if u.attackId == null or enemy.is_empty():
		return u.desiredFacing
	if FieldData.distance(u, enemy) > FieldData.weapons()[u.weapon].range:
		return null
	if u.aimOrderId != u.attackId:
		u.aimOrderId = u.attackId
		u.aimComplete = false
	if u.aimComplete:
		return null
	if inside_arc(u, enemy):
		u.aimComplete = true
		u.turnVelocity = 0.0
		return null
	var bearing = (FieldData.pos(enemy) - FieldData.pos(u)).angle()
	return bearing - signf(angle_difference(u.facing, bearing)) * (acos(0.45) - 0.06)

func melee_power(model, u: Dictionary, enemy: Dictionary, impact: float = 1.0) -> float:
	var power: float = u.men * 0.045 * FieldArsenal.melee_power(u) * (1.0 + u.experience * 0.12)
	power *= 0.85 + u.skills.melee / 200.0
	if u.side == "player": power *= model.efficiency(u)
	if FieldCharge.mounted(u): power *= 2.1
	power *= impact
	if enemy.formation == "square" and enemy.formationChange == null and FieldCharge.mounted(u): power *= 0.2
	if enemy.formationChange != null: power *= 1.18
	if enemy.get("role") == "skirmishers" or enemy.dismounted: power *= 1.2
	if FieldTerrain.kind(FieldData.pos(enemy), model.terrain.field) == "woods": power *= 0.85
	if FieldTerrain.kind(FieldData.pos(u), model.terrain.field) == "hill": power *= 1.18
	power *= 1.0 - FieldCover.protection(model, enemy, u, true)
	if incoming_sector(u, enemy) == "rear": power *= 1.4
	power *= (u.morale / 100.0) * (0.65 + u.condition * 0.0035) * (0.85 if u.side == "enemy" else 1.0)
	return power

func turn(model, u: Dictionary, angle: float, dt: float) -> void:
	var time: float = model.state.battle.time
	if time - u.get("lastTurnAt", -100.0) > dt * 1.5 + 0.000001:
		u.turnVelocity = 0.0
	u["lastTurnAt"] = time
	FieldFormations.turn(u, angle, dt)
	if index.enabled and u.has("men"): index.update_unit(u)

func set_goal(model, u: Dictionary, p: Vector2, facing = null) -> void:
	if u.get("goal") == null or FieldData.pos(u.goal).distance_to(p) > 45 or u.get("target") == null:
		model.path_unit(u, p, facing)

func walk(model, u: Dictionary, dt: float, pace: float) -> void:
	u["movementBlocked"] = ""
	if u.get("target") == null:
		return
	if u.has("men") and FieldPassage.bridge_wait(model, u): return
	if u.has("men") and model.state.battle.time >= u.get("passageRetryAt", -1):
		# Plan passage before a turn carries the frontage into its neighbor.
		var shape = contact_shape(u)
		for friendly in nearby(model, u, u.side, 40):
			if friendly.id == u.id: continue
			var other = contact_shape(friendly)
			if FieldContact.near(shape, other, 40) and FieldContact.gap(shape, other) < 40 and FieldPassage.detour(model, u, friendly):
				u.movementBlocked = "Moving around friendly troops"
				break
	var delta = FieldData.pos(u.target) - FieldData.pos(u)
	var d = delta.length()
	var step = minf(d, dt * pace)
	if d > 0.1:
		var bearing = delta.angle()
		pace *= model.terrain.movement_factor(FieldData.pos(u), FieldData.pos(u) + delta.normalized() * 12)
		if u.has("men"): u["marchPace"] = pace
		step = minf(d, dt * pace)
		var contact = contact_target(model, u)
		var withdrawing = not contact.is_empty() and delta.dot(FieldData.pos(u) - FieldData.pos(contact)) > 0
		if not u.get("fallingBack", false) and (contact.is_empty() or withdrawing):
			turn(model, u, bearing, dt)
		step *= FieldFormations.alignment(u, bearing)
		if u.has("men") and not u.fallingBack:
			var radius = FieldFormations.bounds(u).size.length() * 0.5
			step = minf(step, dt * maxf(0, pace - absf(u.turnVelocity) * radius))
		if u.has("men"):
			if index.enabled: index.update_unit(u)
			var trial: Dictionary = u.duplicate()
			trial.x += delta.x / d * step
			trial.y += delta.y / d * step
			var current_shape = contact_shape(u)
			var next_shape = FieldContact.shape(trial)
			var passage_blocker: Dictionary = {}
			for enemy in nearby(model, u, "enemy" if u.side == "player" else "player", FieldContact.REACH + step):
				var enemy_shape = contact_shape(enemy)
				if not FieldContact.near(current_shape, enemy_shape, FieldContact.REACH + step): continue
				var before = FieldContact.gap(current_shape, enemy_shape)
				var after = FieldContact.gap(next_shape, enemy_shape)
				if after <= FieldContact.REACH and after < before:
					step *= clampf((before - FieldContact.REACH) / maxf(0.0001, before - after), 0, 1)
					if before <= FieldContact.REACH: step = 0
			for friendly in nearby(model, u, u.side, 3 + step):
				if friendly.id == u.id: continue
				var shape = contact_shape(friendly)
				if not FieldContact.near(current_shape, shape, 3 + step): continue
				var before = FieldContact.gap(current_shape, shape)
				var after = FieldContact.gap(next_shape, shape)
				# Existing overlaps can separate; advancing into occupied frontage waits.
				if after < 3 and after < before - 0.0001:
					step *= clampf((before - 3) / maxf(0.001, before - after), 0, 1)
					u.movementBlocked = "Waiting for passage"
					passage_blocker = friendly
			var next = FieldData.pos(u) + delta.normalized() * step
			if model.terrain.buildings.any(func(building): return building.rect.grow(2).has_point(next) and FieldTerrain.rect_distance(next, building.rect) < FieldTerrain.rect_distance(FieldData.pos(u), building.rect) - 0.001):
				step = 0
				u.movementBlocked = "Building obstructs route"
			if not passage_blocker.is_empty() and FieldPassage.detour(model, u, passage_blocker):
				u.movementBlocked = "Moving around friendly troops"
				return
		u.x += delta.x / d * step
		u.y += delta.y / d * step
		if index.enabled and u.has("men"): index.update_unit(u)
	if d <= step + 0.00001:
		u.x = u.target.x
		u.y = u.target.y
		u.target = u.waypoints.pop_front() if not u.get("waypoints", []).is_empty() else null
		if u.target == null and not u.get("orderQueue", []).is_empty():
			var next: Dictionary = u.orderQueue.pop_front()
			model.path_unit(u, FieldData.pos(next.point), next.facing)
		if u.target == null:
			u["fallingBack"] = false

func plan_enemy(model) -> void:
	FieldBattleAI.update(model)

func rout_walk(model, u: Dictionary, dt: float) -> void:
	var direction = -1.0 if (u.side == "player") == (model.state.battle.playerEdge == "west") else 1.0
	var p = FieldData.pos(u)
	var next = p + Vector2(direction * dt * 30.0, 0)
	if model.terrain.water and p.x > 0 and p.x < model.terrain.map_size.x:
		var path: Array = u.get("routPath", [])
		while not path.is_empty() and p.distance_to(FieldData.pos(path[0])) < 0.1: path.pop_front()
		if path.is_empty() and not model.terrain.figure_segment_clear(p, next, 4):
			if model.state.battle.time >= u.get("routRetryAt", -1.0):
				var destination = Vector2(45.0 if direction < 0 else model.terrain.map_size.x - 45, clampf(p.y, 45, model.terrain.map_size.y - 45))
				path = model.terrain.route(p, destination, 2)
				u["routRetryAt"] = model.state.battle.time + 3.0
			if path.is_empty(): return
		if not path.is_empty(): next = p.move_toward(FieldData.pos(path[0]), dt * 30.0)
		u["routPath"] = path
	u.x = clampf(next.x, -50, model.terrain.map_size.x + 50)
	u.y = next.y

func update_commanders(model, dt: float) -> void:
	var b: Dictionary = model.state.battle
	for c in b.commanders:
		if c.get("arrival", 0.0) > b.time:
			c.unavailable = true
			continue
		c.unavailable = (c.corpsId != null or c.officerId != null) and not FieldData.ready(model.find_id(model.state.officers, c.officerId), model.state.hours)
		if c.get("hostId") != null:
			var host = model.find_id(b.units, c.hostId)
			if not host.is_empty() and host.arrival > b.time:
				c.unavailable = true
				continue
		c.cooldown = maxf(0, c.cooldown - dt)
		c.shaken = maxf(0, c.shaken - dt)
		c.rallyFlash = maxf(0, c.rallyFlash - dt)
		var danger = active(b, "enemy").any(func(u): return FieldData.distance(u, c) < 85)
		if danger:
			c.shaken = 7.0
			if c.get("hostId") == null:
				c.x = clampf(c.x + (1 if b.playerEdge == "east" else -1) * dt * 46, 30, model.terrain.map_size.x - 30)
			c["pressure"] = c.get("pressure", 0.0) + dt
			var o: Dictionary = model.find_id(model.state.officers, c.officerId)
			if not o.is_empty() and c.pressure > 15 and o.woundedUntil <= model.state.hours:
				o.woundedUntil = model.state.hours + 8
				o.wounds += 1
				model.log_event(o.name + " wounded under fire.")
			continue
		if c.get("hostId") != null:
			continue
		if c.following:
			var own = active(b, "player").filter(func(u): return c.get("armyId") == null or u.get("armyId") == c.armyId)
			var center = Vector2.ZERO
			for u in own:
				center += FieldData.pos(u)
			if not own.is_empty():
				center /= own.size()
				center.x -= 150 * (-1 if b.playerEdge == "east" else 1)
				if c.get("goal") == null or FieldData.pos(c.goal).distance_to(center) > 30 or (c.target == null and FieldData.pos(c).distance_to(center) > 25):
					model.path_unit(c, center)
		walk(model, c, dt, 40)
	model.sync_hosts()

func update_wagons(model, dt: float) -> void:
	var b: Dictionary = model.state.battle
	for w in b.wagons:
		if w.health <= 0:
			continue
		var threats = active(b, "enemy" if w.side == "player" else "player").filter(func(u): return FieldData.distance(u, w) < 75)
		w["underAttack"] = not threats.is_empty()
		if not threats.is_empty():
			w.health = maxf(0, w.health - dt * (9 if threats[0].kind == "cavalry" else 5))
			if w.health <= 0:
				w.stock = 0
				w.target = null
				model.log_event(("French" if w.side == "player" else "Austrian") + " supply train destroyed.")
		walk(model, w, dt, 22)
		if w.underAttack or w.stock <= 0 or w.health <= 0:
			continue
		for u in active(b, w.side):
			if FieldData.distance(u, w) <= 145 and u.ammo < 100 and w.stock > 0:
				var amount = minf(100 - u.ammo, minf(dt * 4, w.stock))
				u.ammo += amount
				w.stock -= amount

func artillery_volley(model, u: Dictionary, enemy: Dictionary, power: float, lanes: Array = []) -> float:
	u["artilleryShots"] = u.get("artilleryShots", 0) + 1
	var seed_value = int(u.artilleryShots) & 0xffffffff
	for c in str(u.id):
		seed_value = (seed_value * 31 + c.unicode_at(0)) & 0xffffffff
	var randoms: Array = []
	for i in 48:
		seed_value = (seed_value * 1664525 + 1013904223) & 0xffffffff
		randoms.append(float(seed_value) / 4294967296.0)
	var d = FieldData.distance(u, enemy)
	var weapon: Dictionary = FieldData.weapons()[u.weapon]
	var ammunition = FieldArsenal.ammunition(u, d)
	var spread = (4 + d * 0.055) * (1.25 - clampf(u.skills.firearms, 0, 100) * 0.006) * (1 + (100 - u.condition) * 0.004)
	spread /= weapon.accuracy
	var direction = (FieldData.pos(enemy) - FieldData.pos(u)).angle()
	var bounds = Rect2()
	var slots = FieldFormations.offsets(enemy)
	if not slots.is_empty():
		bounds.position = slots[0]
		for p in slots:
			bounds = bounds.expand(p)
	bounds = bounds.grow(9.0 if d < 120 else 5.0)
	if ammunition == "shell": bounds = bounds.grow(weapon.blast)
	var count = clampi(ceili(u.men / 30.0), 1, 12)
	var firing = count if lanes.is_empty() else mini(count, lanes.size())
	var hits = 0
	var impacts: Array = []
	for i in firing:
		var delta = Vector2((randoms[i * 4] + randoms[i * 4 + 1] - 1) * spread * 2.5, (randoms[i * 4 + 2] + randoms[i * 4 + 3] - 1) * spread * 1.5).rotated(direction)
		var local = delta.rotated(-(enemy.facing - PI / 2.0))
		var hit = bounds.has_point(local)
		if hit:
			hits += 1
		var point = FieldData.pos(enemy) + delta
		var origin: Vector2 = FieldData.pos(u) if lanes.is_empty() else lanes[i]
		impacts.append({"id": str(u.id) + ":" + str(u.artilleryShots) + ":" + str(i), "x": point.x, "y": point.y, "origin": FieldData.point(origin), "hit": hit, "kind": ammunition, "time": model.state.battle.time, "visible": u.side == "player" or u.visible})
	u["artilleryImpacts"] = impacts
	model.state.battle.artilleryImpacts.append_array(impacts)
	if model.state.battle.artilleryImpacts.size() > 128:
		model.state.battle.artilleryImpacts = model.state.battle.artilleryImpacts.slice(-128)
	return power * hits / count

func condition(u: Dictionary, before: Dictionary, time: float, dt: float) -> void:
	var moving = FieldData.pos(u).distance_to(before.p) > 0.0001
	var turning = absf(angle_difference(before.facing, u.facing)) > 0.0001
	var working = before.working or u.formationChange != null or u.limberChange > 0
	var fighting = u.fightingUntil > time
	var melee = u.meleeUntil > time
	if moving or turning or working or fighting:
		u.restAfter = time + 2
	var march = (FieldCharge.exertion(u) if before.get("charging", u.charging) else 0.9 if u.running or u.routed else 0.2) if moving else 0.0
	var exertion = march * (0.75 if u.perk == "march" else 1.0) + (1.4 if melee else 0.4 if fighting else 0.0) + (0.3 if working else 0.16 if turning else 0.0)
	var recovery = 0.7 if exertion == 0 and time >= u.restAfter else 0.0
	u.condition = clampf(u.condition + dt * (recovery - exertion * (1.15 - u.skills.stamina / 200.0)), 0, 100)
	if u.condition < 12:
		u.running = false
		FieldCharge.cancel(u)

static func incoming_sector(source: Dictionary, target: Dictionary) -> String:
	var angle = absf(angle_difference(target.facing, (FieldData.pos(source) - FieldData.pos(target)).angle()))
	return "rear" if angle >= PI * 0.75 else "side" if angle > PI * 0.25 else "front"

static func morale_multiplier(sector: String) -> float:
	return 3.0 if sector == "rear" else 2.0 if sector == "side" else 1.0

func update(model, dt: float) -> void:
	var profiling: bool = model.terrain.profile_enabled
	var stage = Time.get_ticks_usec() if profiling else 0
	var b: Dictionary = model.state.battle
	var activity: Dictionary = {}
	for u in b.units:
		activity[u.id] = {"p": FieldData.pos(u), "facing": u.facing, "working": u.formationChange != null or u.limberChange > 0, "charging": u.charging}
	b.time += dt
	for entry in b.get("campaignForces", []):
		if entry.arrival > b.time - dt and entry.arrival <= b.time:
			FieldOperations.arrive(model, entry)
	b.visibilityClock += dt
	b.aiClock += dt
	if not b.has("visibleCells"): update_visibility(model, true)
	# Refresh the same set over 0.6 seconds rather than tracing both armies at once.
	var visibility_step = 0.6 / (b.units.size() + b.wagons.size())
	var visibility_count = int(b.visibilityClock / visibility_step)
	if visibility_count > 0:
		b.visibilityClock -= visibility_count * visibility_step
		update_visibility(model, false, visibility_count)
	fog_budget += dt * 1000.0
	var cells = mini(60, int(fog_budget))
	if cells > 0: fog_budget -= update_fog(model, cells, 700)
	fog_budget = minf(fog_budget, 120)
	if profiling:
		profile_sections.visibility += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	update_contacts(model)
	index.enabled = true
	passage_plans = 1
	if profiling:
		profile_sections.contacts += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	if b.aiClock >= 2:
		b.aiClock = 0.0
		var started = Time.get_ticks_usec()
		ai_context = FieldBattleAI.prepare(model)
		ai_queue = ai_context.friends.map(func(u): return u.id)
		ai_max_micros = maxi(ai_max_micros, Time.get_ticks_usec() - started)
	# Issue one regiment's orders per tick instead of bunching route searches together.
	if not ai_queue.is_empty():
		var started = Time.get_ticks_usec()
		FieldBattleAI.update(model, ai_context, ai_queue.pop_front())
		ai_max_micros = maxi(ai_max_micros, Time.get_ticks_usec() - started)
	update_commanders(model, dt)
	if profiling:
		profile_sections.ai += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	update_wagons(model, dt)
	if profiling:
		profile_sections.support += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	var damage: Array = []
	for u in b.units:
		u.flash = maxf(0, u.flash - dt)
		if u.arrival > b.time or u.men <= 0 or u.withdrawn:
			continue
		if u.routed:
			FieldCover.leave(u)
			FieldCharge.cancel(u)
			u.formationChange = null
			u.queuedFormation = null
			rout_walk(model, u, dt)
			continue
		var support: Array = model.command_support(u)
		var detail_start = Time.get_ticks_usec() if profiling else 0
		var terrain_kind = FieldTerrain.kind(FieldData.pos(u), model.terrain.field)
		FieldFormations.advance_order(u, dt * (1.2 if support.any(func(c): return c.specialty == "Drill") else 1.0))
		if u.formationChange != null and index.enabled: index.update_unit(u)
		if u.limberChange > 0:
			u.limberChange = maxf(0, u.limberChange - dt)
			if u.limberChange == 0:
				u.limbered = u.nextLimber
		u.reload = maxf(0, u.reload - dt)
		if profiling:
			profile_sections.orders += Time.get_ticks_usec() - detail_start
			detail_start = Time.get_ticks_usec()
		var enemy = {} if u.retreating else combat_target(model, u)
		if profiling:
			profile_sections.target += Time.get_ticks_usec() - detail_start
			detail_start = Time.get_ticks_usec()
		if u.get("meleeTargetId") != null and not u.fallingBack and not u.retreating and (u.attackId != null or u.target == null):
			u.target = null
			u.waypoints = []
		if u.side == "player" and u.attackId != null and not enemy.is_empty():
			var repositioning = u.kind == "artillery" and u.get("batteryReposition", false) and u.target != null
			if repositioning:
				if clear_shot(model, u, enemy) and FieldData.distance(u, enemy) <= model.attack_stop_distance(u):
					u.target = null
					u.waypoints = []
					u.batteryReposition = false
			elif u.get("meleeTargetId") == null and FieldData.distance(u, enemy) > model.attack_stop_distance(u):
				set_goal(model, u, FieldData.pos(enemy))
			else:
				u.target = null
				u.waypoints = []
				if u.kind == "artillery" and u.get("meleeTargetId") == null and not clear_shot(model, u, enemy): seek_firing_position(model, u, enemy)
			if u.kind == "artillery" and u.limberChange <= 0:
				var deploy = u.target == null
				if deploy and u.limbered:
					u["nextLimber"] = false
					u.limberChange = FieldData.weapons()[u.weapon].deploy
		var moving = u.target != null
		activity[u.id].charging = u.charging
		if moving:
			var pace = FieldFormations.march_pace(u, terrain_kind)
			u["marchPace"] = pace
			if not (u.retreating and u.kind == "artillery" and u.limberChange > 0): walk(model, u, dt, pace)
			u.skills.stamina = minf(100, u.skills.stamina + dt * 0.008)
		else:
			u.erase("marchPace")
		FieldCharge.advance(u, activity[u.id], enemy, b.time, dt)
		if u.retreating and u.target == null and (u.x <= 46 if (u.side == "player") == (b.playerEdge == "west") else u.x >= model.terrain.map_size.x - 46):
			model.stop_unit(u)
			u.withdrawn = true
			u.visible = false
			u["meleeTargetId"] = null
			model.state.selected.erase(u.id)
			continue
		if not moving or u.fallingBack:
			var facing = engagement_facing(u, enemy)
			if facing != null:
				turn(model, u, facing, dt)
		FieldCover.update(model, u, dt)
		if profiling: profile_sections.walk += Time.get_ticks_usec() - detail_start
	if profiling:
		profile_sections.movement += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	# Resolve all movement before deciding anyone's weapon mode this tick.
	update_contacts(model)
	if profiling:
		profile_sections.contacts += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	shot_cache.clear()
	clear_cache.clear()
	cache_shots = true
	for u in b.units:
		if u.arrival > b.time or u.men <= 0 or u.routed or u.withdrawn: continue
		var enemy = combat_target(model, u)
		var terrain_kind = FieldTerrain.kind(FieldData.pos(u), model.terrain.field)
		u.blocked = "Reforming" if u.formationChange != null else "Preparing guns" if u.limberChange > 0 else "Limbered" if u.limbered else "No ammunition" if u.ammo < 1 and u.kind != "cavalry" else ""
		if u.kind == "artillery" and u.blocked.is_empty(): u.blocked = battery_status(model, u, enemy)
		if enemy.is_empty():
			continue
		var d = FieldData.distance(u, enemy)
		var melee = u.get("meleeTargetId") != null
		var impact = FieldCharge.impact(u, enemy, b.time) if melee else 1.0
		if impact > 1.0: u.reload = 0.0
		if melee: u.blocked = "Melee"
		var reach: float = FieldData.weapons()[u.weapon].range
		var visible = visible_target(model, u, enemy)
		var unobstructed = melee or u.reload > 0 or clear_shot(model, u, enemy)
		if d <= reach and not unobstructed and u.blocked.is_empty():
			u.blocked = "Obstructed"
		if not melee and u.get("role") == "skirmishers" and u.attackId == null and u.target == null and d < 90:
			var angle = (FieldData.pos(u) - FieldData.pos(enemy)).angle()
			u.fallingBack = true
			model.path_unit(u, FieldData.pos(u) + Vector2.from_angle(angle) * 65, angle + PI)
		if u.reload > 0 or (not melee and (not visible or d > reach or not unobstructed or u.formationChange != null or u.limbered or u.limberChange > 0 or not inside_arc(u, enemy))):
			continue
		if not melee and (u.charging or u.retreating or reach <= 45 or u.ammo < 1 or u.holdFire or (u.target != null and not u.fallingBack and u.kind != "cavalry")):
			continue
		var weapon: Dictionary = FieldData.weapons()[u.weapon]
		var weapon_power: float = FieldArsenal.melee_power(u) if melee else weapon.power
		var power: float = u.men * (0.24 if u.kind == "artillery" and not melee else 0.045) * weapon_power * (1.0 + u.experience * 0.12)
		power *= 0.85 + (u.skills.melee if melee else u.skills.firearms) / 200.0
		if u.side == "player":
			power *= model.efficiency(u)
		if u.kind == "cavalry" and melee and not u.dismounted:
			power *= 2.1
		if not melee:
			power *= FieldArsenal.fire_factor(u, d)
			power *= 0.4 if u.formation == "column" else 0.55 if u.formation == "square" else 1.0
		power *= impact
		if u.kind == "artillery" and not melee:
			power *= 1.8 if d < 120 else 1.15 if d < 220 else 0.8
		if u.fallingBack and not melee:
			power *= 0.55
		if u.perk == "volley" and not melee:
			power *= 1.15
		if enemy.formation == "square" and enemy.formationChange == null and u.kind == "cavalry" and not u.dismounted:
			power *= 0.2
		if enemy.formationChange != null:
			power *= 1.18
		if enemy.get("role") == "skirmishers" or enemy.dismounted:
			power *= 1.2 if melee else 0.7
		if FieldTerrain.kind(FieldData.pos(enemy), model.terrain.field) == "woods":
			power *= 0.85 if melee else 0.55
		if terrain_kind == "hill":
			power *= 1.18
		var cover = FieldCover.protection(model, enemy, u, melee)
		if not melee and FieldArsenal.ammunition(u, d) == "shell": cover *= 0.55
		power *= 1.0 - cover
		var sector = incoming_sector(u, enemy)
		power *= 1.4 if sector == "rear" else 1.0
		power *= (u.morale / 100.0) * (0.65 + u.condition * 0.0035) * (0.85 if u.side == "enemy" else 1.0)
		if u.kind == "artillery" and not melee:
			power = artillery_volley(model, u, enemy, power, firing_lanes(model, u, enemy))
		var morale: float = power / maxf(1, enemy.startMen) * 100 * 1.4 * morale_multiplier(sector) * (0.88 if not model.command_support(enemy).is_empty() else 1.0) * (0.8 if enemy.perk == "steadfast" else 1.0) * (1.15 - enemy.skills.discipline / 250.0)
		morale *= FieldOperations.morale_factor(enemy.get("armyMorale", FieldOperations.NEUTRAL_MORALE))
		if melee and u.get("meleeContacts", []).size() > 1:
			var contacts: Array = []
			for id in u.meleeContacts:
				var other = model.find_id(b.units, id)
				if not other.is_empty() and other.men > 0 and not other.routed: contacts.append(other)
			var share = 1.0 / maxi(1, contacts.size())
			power *= share
			morale *= share
			for other in contacts:
				if other.id == enemy.id: continue
				var other_power = melee_power(model, u, other) * share
				var other_sector = incoming_sector(u, other)
				var other_morale = other_power / maxf(1, other.startMen) * 140.0 * morale_multiplier(other_sector) * (0.88 if not model.command_support(other).is_empty() else 1.0) * (0.8 if other.perk == "steadfast" else 1.0) * (1.15 - other.skills.discipline / 250.0) * FieldOperations.morale_factor(other.get("armyMorale", FieldOperations.NEUTRAL_MORALE))
				damage.append({"source": u, "enemy": other, "power": other_power, "morale": other_morale, "sector": other_sector})
				other.fightingUntil = maxf(other.fightingUntil, b.time + 1.6)
				other.meleeUntil = maxf(other.meleeUntil, b.time + 1.6)
		damage.append({"source": u, "enemy": enemy, "power": power, "morale": morale, "sector": sector})
		u.reload = (1.6 if melee else weapon.reload) * (1.15 - (u.skills.melee if melee else u.skills.firearms) / 300.0)
		u.flash = 0.0 if melee else 0.45
		u["shotTime"] = b.time
		u["shotReload"] = u.reload
		u["shotKind"] = "melee" if melee else "cannon" if u.kind == "artillery" else "musket"
		u["firedAt"] = FieldData.point(FieldData.pos(enemy))
		u.fightingUntil = maxf(u.fightingUntil, b.time + u.reload + 0.5)
		if melee:
			u.meleeUntil = maxf(u.meleeUntil, u.fightingUntil)
		if power > 0:
			enemy.fightingUntil = maxf(enemy.fightingUntil, u.fightingUntil)
			if melee:
				enemy.meleeUntil = maxf(enemy.meleeUntil, u.fightingUntil)
		if not melee:
			u.ammo = maxf(0, u.ammo - weapon.get("ammoCost", 3))
		var skill = "melee" if melee else "firearms"
		u.skills[skill] = minf(100, u.skills[skill] + 0.08)
		if u.visible:
			model.sound_requested.emit(u.shotKind, u.x)
	cache_shots = false
	shot_cache.clear()
	clear_cache.clear()
	index.enabled = false
	if profiling:
		profile_sections.combat += Time.get_ticks_usec() - stage
		stage = Time.get_ticks_usec()
	for hit in damage:
		hit.source.kills += minf(hit.enemy.men, hit.power)
		hit.enemy.men = maxf(0, hit.enemy.men - hit.power)
		hit.enemy.morale = maxf(0, hit.enemy.morale - hit.morale)
		hit.enemy["lastHit"] = b.time
		if hit.sector != "front" and hit.power > 0:
			hit.enemy["flankedUntil"] = b.time + 3
			if hit.enemy.get("firePressureUntil", 0.0) <= b.time or hit.sector == "rear" or hit.enemy.get("firePressure") != "rear":
				hit.enemy["firePressure"] = hit.sector
				hit.enemy["firePressureUntil"] = b.time + 3
		hit.enemy.skills.discipline = minf(100, hit.enemy.skills.discipline + 0.03)
	for u in b.units:
		if u.withdrawn: continue
		if u.men > 0 and u.arrival <= b.time:
			condition(u, activity[u.id], b.time, dt)
		if u.routed or u.men <= 0 or u.arrival > b.time:
			continue
		var support: Array = model.command_support(u)
		if not support.is_empty():
			u.morale = minf(100, u.morale + dt * (0.38 if support.any(func(c): return c.specialty == "Resolve") else 0.2))
		if u.morale < 20 or u.men < u.startMen * 0.23:
			FieldCharge.cancel(u)
			u.routed = true
			u.target = null
			u.erase("routPath")
			u.erase("routRetryAt")
	model.sync_hosts()
	b.artilleryImpacts = b.artilleryImpacts.filter(func(p): return b.time - p.time < 6)
	if not b.units.any(func(u): return u.side == "player" and not u.routed and not u.withdrawn and u.men > 0):
		model.finish_battle(false, b.units.any(func(u): return u.side == "player" and u.withdrawn))
		return
	if not b.units.any(func(u): return u.side == "enemy" and not u.routed and not u.withdrawn and u.men > 0):
		model.finish_battle(true)
		return
	var objective: Dictionary = model.terrain.field.objective
	var french = active(b, "player").any(func(u): return FieldData.distance(u, objective) <= objective.radius)
	var austrian = active(b, "enemy").any(func(u): return FieldData.distance(u, objective) <= objective.radius)
	b.objective.owner = "player" if french and not austrian else "enemy" if austrian and not french else null
	if b.objective.owner != null:
		b.objective[b.objective.owner] += dt
	if b.objective.player >= objective.seconds:
		model.finish_battle(true)
	elif b.objective.enemy >= (50 if model.terrain.field.type == "defend" else objective.seconds + 60):
		model.finish_battle(false)
	if profiling: profile_sections.finish += Time.get_ticks_usec() - stage
