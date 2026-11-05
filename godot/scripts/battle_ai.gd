class_name FieldBattleAI
extends RefCounted

const MEMORY_SECONDS = 16.0
const PLAN_SECONDS = 12.0
const STATES = ["line", "fire", "reserve", "reinforce", "screen", "flank", "charge", "battery", "displace", "recover", "withdraw", "cover", "melee", "square"]

static func strength(u: Dictionary) -> float:
	return u.men * (0.35 + u.morale * 0.0065) * (0.6 + u.condition * 0.004) * (2.5 if u.kind == "artillery" else 1.2 if u.kind == "cavalry" else 1.0)

static func initialize(model) -> Dictionary:
	var b: Dictionary = model.state.battle
	if not b.has("ai"):
		var commander = model.find_id(model.state.enemies, b.enemyIds[0]) if not b.enemyIds.is_empty() else {}
		b["ai"] = {"stance": "defend", "reason": "Establishing a defensive line", "personality": b.get("aiPersonality", commander.get("personality", "cautious")), "until": -1.0, "anchor": FieldData.point(FieldData.pos(model.terrain.field.objective)), "facing": PI if b.playerEdge == "west" else 0.0, "flank": 1.0, "contacts": []}
	for u in b.units:
		if u.side != "enemy": continue
		if not u.has("aiRole"): u["aiRole"] = "battery" if u.kind == "artillery" else "flank" if u.kind == "cavalry" else "line"
		if not u.has("ai"):
			u["ai"] = {"state": "reserve", "reason": "Awaiting orders", "until": -1.0, "station": FieldData.point(FieldData.pos(u)), "committed": false, "orders": 0}
	return b.ai

static func observe(model, friends: Array) -> Array:
	var b: Dictionary = model.state.battle
	var seen = FieldTactics.active(b, "player").filter(func(u): return friends.any(func(observer): return model.terrain.line_of_sight(observer, u)))
	var reports: Array = b.ai.contacts.filter(func(report): return b.time - report.at <= MEMORY_SECONDS and not seen.any(func(u): return u.id == report.id))
	for u in seen: reports.append({"id": u.id, "x": u.x, "y": u.y, "at": b.time, "strength": strength(u)})
	b.ai.contacts = reports
	return seen

static func choose_plan(model, friends: Array, seen: Array) -> void:
	var b: Dictionary = model.state.battle
	var ai: Dictionary = b.ai
	var power = 0.0
	var remaining = 0.0
	var original = 0.0
	var shaken = 0
	for u in b.units:
		if u.side == "enemy" and u.arrival <= b.time: original += u.startMen
	for u in friends:
		power += strength(u)
		remaining += u.men
		if u.morale < 38 or u.condition < 18: shaken += 1
	var opposing = 0.0
	for report in ai.contacts: opposing += report.strength
	var broken = remaining < original * 0.38 or (not friends.is_empty() and shaken > friends.size() * 0.6 and opposing > power * 1.3)
	if ai.stance == "withdraw" or (b.time >= 8 and broken):
		ai.stance = "withdraw"
		ai.reason = "Army cohesion lost; preserve the survivors"
		ai.until = b.time + PLAN_SECONDS
		return
	if b.time < ai.until: return
	ai.stance = "defend"
	ai.reason = "Hold the objective and keep a reserve"
	var objective = FieldData.pos(model.terrain.field.objective)
	var forward = Vector2.from_angle(ai.facing)
	var anchor = objective - forward * (70 if model.terrain.field.get("river", false) else 22)
	if model.terrain.field.type == "defend" or b.objective.owner == "player":
		ai.stance = "advance"
		ai.reason = "Advance together to contest the objective"
	elif ai.personality != "cautious" and opposing > 0 and power > opposing * (1.25 if ai.personality == "aggressive" else 1.65):
		ai.stance = "advance"
		ai.reason = "Local superiority favors a supported advance"
	var upper = 0.0
	var lower = 0.0
	for target in seen:
		if target.y < objective.y: upper += strength(target)
		else: lower += strength(target)
	if not seen.is_empty(): ai.flank = -1.0 if upper < lower else 1.0
	if ai.stance == "advance" and not seen.is_empty():
		var nearest: Dictionary = seen[0]
		for target in seen:
			if FieldData.pos(target).distance_to(objective) < FieldData.pos(nearest).distance_to(objective): nearest = target
		var contact = FieldData.pos(nearest) - forward * 125
		if contact.distance_to(objective) <= 270: anchor = contact
		if ai.personality == "opportunist" and not model.terrain.field.get("river", false) and friends.any(func(u): return u.kind == "cavalry"):
			ai.stance = "flank"
			ai.reason = "Pressure the weaker observed flank"
			anchor.y += ai.flank * 65
	ai.anchor = FieldData.point(anchor.clamp(Vector2(90, 100), model.terrain.map_size - Vector2(90, 100)))
	ai.until = b.time + PLAN_SECONDS
	assign_stations(model)

static func assign_stations(model) -> void:
	var b: Dictionary = model.state.battle
	var ai: Dictionary = b.ai
	var forward = Vector2.from_angle(ai.facing)
	var anchor = FieldData.pos(ai.anchor)
	# Preserve fallen regiments' sectors so reserves can fill actual gaps.
	var line = b.units.filter(func(u): return u.side == "enemy" and u.arrival <= b.time and u.kind == "infantry" and u.aiRole != "reserve")
	line.sort_custom(func(a, c): return a.id < c.id)
	var total = 0.0
	for u in line: total += FieldFormations.bounds(u).size.x + 24
	var cursor = -total * 0.5
	var half_front = minf(total * 0.5 + 45, (model.terrain.map_size.y - 220) * 0.5)
	for u in line:
		var width = FieldFormations.bounds(u).size.x + 24
		u.ai.station = FieldData.point(anchor + Vector2(0, clampf(cursor + width * 0.5, -half_front, half_front)))
		cursor += width
	var reserve_index = 0
	var cavalry_index = 0
	var battery_index = 0
	for u in b.units:
		if u.side != "enemy": continue
		if u.aiRole == "reserve" and not u.ai.committed:
			u.ai.station = FieldData.point(anchor - forward * 135 + Vector2(0, reserve_index * 100))
			reserve_index += 1
		elif u.kind == "cavalry":
			u.ai.station = FieldData.point((anchor - forward * (100 + cavalry_index * 85) + Vector2(0, ai.flank * (half_front + 55))).clamp(Vector2(90, 90), model.terrain.map_size - Vector2(90, 90)))
			cavalry_index += 1
		elif u.kind == "artillery":
			u.ai.station = FieldData.point((anchor - forward * (115 + battery_index * 55) + Vector2(0, (-1 if battery_index % 2 == 0 else 1) * minf(half_front * 0.7, 450))).clamp(Vector2(90, 90), model.terrain.map_size - Vector2(90, 90)))
			battery_index += 1

static func target_for(model, u: Dictionary, seen: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score = -INF
	for target in seen:
		var score = -FieldData.distance(u, target)
		if target.id == u.attackId: score += 45
		if target.kind == "artillery" and u.kind == "cavalry": score += 100
		if target.morale < 40: score += 35
		if u.kind != "cavalry" and model.tactics.clear_shot(model, u, target): score += 45
		if score > best_score:
			best_score = score
			best = target
	return best

static func candidates(p: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = [p]
	for offset in [Vector2(0, -48), Vector2(0, 48), Vector2(-48, 0), Vector2(48, 0), Vector2(0, -96), Vector2(0, 96), Vector2(-96, 0), Vector2(96, 0), Vector2(-64, -64), Vector2(64, 64)]: result.append(p + offset)
	return result

static func position_score(model, u: Dictionary, p: Vector2, wanted: Vector2, friends: Array) -> float:
	if not model.terrain.order_bounds().grow(0.5).has_point(p): return -INF
	var radius = minf(60, FieldFormations.bounds(u).size.length() * 0.5)
	if not model.terrain.passable(p, true, 2): return -INF
	var trial = u.duplicate()
	trial.x = p.x
	trial.y = p.y
	trial.facing = model.state.battle.ai.facing
	var shape = FieldContact.shape(trial)
	var score = -p.distance_to(wanted) - p.distance_to(FieldData.pos(u)) * 0.08
	# Prefer open formation space, but retain reachable streets in dense villages.
	if not model.terrain.passable(p, true, radius): score -= 75
	for ally in friends:
		if ally.id == u.id: continue
		var gap = FieldContact.gap(shape, FieldContact.shape(ally))
		if gap < 8: score -= 160 + (8 - gap) * 3
	return score

static func position_for(model, u: Dictionary, wanted: Vector2, friends: Array):
	var best = null
	var score = -INF
	for p in candidates(wanted):
		var value = position_score(model, u, p, wanted, friends)
		if value > score:
			score = value
			best = p
	return best

static func issue(model, u: Dictionary, state: String, reason: String, destination = null, enemy: Dictionary = {}, urgent: bool = false) -> bool:
	var b: Dictionary = model.state.battle
	var ai: Dictionary = u.ai
	if b.time < ai.until and (not urgent or ai.state == state): return false
	var target_id = enemy.get("id")
	var facing: float = b.ai.facing
	var moving = destination != null and FieldData.pos(u).distance_to(destination) > (0.5 if state == "withdraw" else 8.0)
	if moving:
		var same_goal = u.goal != null and FieldData.pos(u.goal).distance_to(destination) < 18 and u.target != null
		if not same_goal and not model.path_unit(u, destination, facing):
			ai.state = state
			ai.reason = "No route to assigned position"
			ai.until = b.time + 6
			return false
	else:
		u.target = null
		u.waypoints = []
		u.desiredFacing = facing
	FieldCover.leave(u)
	if state != "charge": FieldCharge.cancel(u)
	if u.attackId != target_id: model.clear_engagement(u)
	u.attackId = target_id
	u.orderQueue = []
	u.retreating = state == "withdraw"
	u.fallingBack = state in ["recover", "withdraw", "displace"]
	if u.kind == "artillery" and u.limberChange <= 0:
		var limber = moving and (u.limbered or FieldData.pos(u).distance_to(destination) > 65)
		if u.limbered != limber:
			u["nextLimber"] = limber
			u.limberChange = FieldData.weapons()[u.weapon].deploy
	ai.state = state
	ai.reason = reason
	ai.until = b.time + (4.0 if b.ai.personality == "aggressive" else 8.0 if b.ai.personality == "cautious" else 6.0)
	ai.orders += 1
	return true

static func pressure(model, seen: Array, claimed: Array) -> Dictionary:
	var b: Dictionary = model.state.battle
	var worst: Dictionary = {}
	var severity = 0.0
	for ally in b.units:
		if ally.side != "enemy" or ally.kind != "infantry" or ally.aiRole == "reserve" or ally.arrival > b.time or ally.id in claimed: continue
		var station = FieldData.pos(ally.ai.station)
		if b.units.any(func(other): return other.side == "enemy" and other.ai.committed and not other.routed and not other.withdrawn and other.men > 0 and FieldData.pos(other.ai.station).distance_to(station) < 30): continue
		var threats = 0.0
		for target in seen:
			if FieldData.pos(target).distance_to(station) < 245: threats += strength(target)
		if threats <= 0: continue
		var missing = ally.routed or ally.withdrawn or ally.men <= 0 or ally.ai.state in ["withdraw", "recover"]
		var value = 500.0 if missing else maxf(0, threats - strength(ally) * 1.3) + maxf(0, 50 - ally.morale) * 8
		if value > severity:
			severity = value
			worst = {"id": ally.id, "point": station, "reason": "Fill the broken infantry sector" if missing else "Reinforce the threatened infantry sector"}
	return worst

static func charge_safe(model, u: Dictionary, enemy: Dictionary, seen: Array, friends: Array) -> bool:
	if enemy.is_empty() or not FieldCharge.mounted(u) or u.condition < 40 or u.morale < 45: return false
	if enemy.formation == "square" or (enemy.formationChange != null and enemy.formationChange.to == "square"): return false
	var d = FieldData.distance(u, enemy)
	if d < 70 or d > 220 or not model.terrain.direct_route(FieldData.pos(u), FieldData.pos(enemy), 3): return false
	if FieldTerrain.kind(FieldData.pos(enemy), model.terrain.field) == "woods" or enemy.get("coverId") != null: return false
	var supported = friends.any(func(ally): return ally.id != u.id and ally.kind == "infantry" and not ally.retreating and FieldData.distance(ally, enemy) < 230)
	var guards = seen.any(func(other): return other.id != enemy.id and other.kind == "infantry" and other.morale > 45 and FieldData.distance(other, enemy) < 125)
	var vulnerable = enemy.morale < 42 or enemy.kind == "artillery" or (model.tactics.incoming_sector(u, enemy) != "front" and supported)
	if not vulnerable or (guards and not supported): return false
	for ally in friends:
		if ally.id == u.id: continue
		var a = (FieldData.pos(u) - FieldData.pos(ally)).rotated(PI / 2 - ally.facing)
		var z = (FieldData.pos(enemy) - FieldData.pos(ally)).rotated(PI / 2 - ally.facing)
		if FieldLandscape.segment_hit(a, z, FieldFormations.bounds(ally).grow(8)) != null: return false
	return true

static func battery_position(model, u: Dictionary, enemy: Dictionary, friends: Array):
	var wanted = FieldData.pos(u.ai.station)
	var points = candidates(wanted)
	points.push_front(FieldData.pos(u))
	var reach: float = FieldData.weapons()[u.weapon].range
	if not enemy.is_empty():
		var offset = (FieldData.pos(u) - FieldData.pos(enemy)).normalized() * reach * 0.8
		for angle in [-0.65, -0.35, 0.0, 0.35, 0.65]: points.append(FieldData.pos(enemy) + offset.rotated(angle))
	var best = null
	var score = -INF
	for p in points:
		var value = position_score(model, u, p, wanted, friends)
		if value == -INF: continue
		var trial = u.duplicate()
		trial.x = p.x
		trial.y = p.y
		if not enemy.is_empty():
			var d = p.distance_to(FieldData.pos(enemy))
			if d < 145 or d > reach * 0.97 or not model.tactics.clear_shot(model, trial, enemy): continue
			var screened = false
			for ally in friends:
				if ally.kind != "infantry" or ally.aiRole == "reserve": continue
				var station = FieldData.pos(ally.ai.station)
				var a = (p - station).rotated(PI / 2 - model.state.battle.ai.facing)
				var z = (FieldData.pos(enemy) - station).rotated(PI / 2 - model.state.battle.ai.facing)
				if FieldLandscape.segment_hit(a, z, FieldFormations.bounds(ally)) != null: screened = true
			if screened: continue
			value += 150
		if p.distance_to(FieldData.pos(u)) < 8: value += 80
		value += minf(25, model.terrain.height_at(p) * 0.3)
		if value > score:
			score = value
			best = p
	return best

static func prepare(model) -> Dictionary:
	initialize(model)
	var friends = FieldTactics.active(model.state.battle, "enemy")
	var seen = observe(model, friends)
	choose_plan(model, friends, seen)
	return {"friends": friends, "seen": seen.map(func(u): return u.duplicate(true)), "claimed": []}

static func update(model, context: Dictionary = {}, unit_id: String = "") -> void:
	if context.is_empty(): context = prepare(model)
	var b: Dictionary = model.state.battle
	var ai: Dictionary = b.ai
	var friends: Array = context.friends
	if friends.is_empty(): return
	var seen: Array = context.seen
	var forward = Vector2.from_angle(ai.facing)
	var claimed: Array = context.claimed
	var wagon: Dictionary = b.wagons[1] if b.wagons[1].health > 0 and b.wagons[1].stock > 0 else {}
	for u in friends:
		if (not unit_id.is_empty() and u.id != unit_id) or u.routed or u.withdrawn or u.men <= 0: continue
		var withdrawing = ai.stance == "withdraw" or u.retreating or u.morale < 30 or (u.men < u.startMen * 0.35 and u.morale < 50) or (u.kind == "artillery" and u.ammo < 1 and wagon.is_empty())
		if withdrawing:
			var destination = Vector2(model.terrain.map_size.x - 45 if b.playerEdge == "west" else 45, clampf(u.y, 90, model.terrain.map_size.y - 90))
			issue(model, u, "withdraw", ai.reason if ai.stance == "withdraw" else "Preserve the depleted regiment", destination, {}, true)
			continue
		var recovering = u.condition < 18 or (u.ammo < 12 and not wagon.is_empty()) or (u.ai.state == "recover" and (u.condition < 55 or (u.ammo < 45 and not wagon.is_empty())))
		if recovering:
			var rear = FieldData.pos(wagon) if not wagon.is_empty() else FieldData.pos(ai.anchor) - forward * 200
			var destination = position_for(model, u, rear + Vector2(0, friends.find(u) * 35 - 70), friends)
			issue(model, u, "recover", "Rest and replenish behind the line", destination, {}, u.ai.state != "recover")
			continue
		if u.kind == "artillery":
			var threats = seen.filter(func(other): return FieldData.distance(u, other) < (160 if FieldCharge.mounted(other) else 105))
			if not threats.is_empty():
				threats.sort_custom(func(a, c): return FieldData.distance(u, a) < FieldData.distance(u, c))
				var away = (FieldData.pos(u) - FieldData.pos(threats[0])).normalized()
				var point = position_for(model, u, FieldData.pos(u) + away * 155, friends)
				issue(model, u, "displace", "Displace from a close enemy threat", point, {}, true)
				continue
		if u.get("meleeTargetId") != null:
			u.ai.state = "melee"
			u.ai.reason = "Engaged at close quarters"
			continue
		if u.charging:
			var targets = seen.filter(func(other): return other.id == u.chargeTargetId)
			if targets.is_empty() or targets[0].formation == "square" or (targets[0].formationChange != null and targets[0].formationChange.to == "square"):
				FieldCharge.cancel(u)
				u.ai.until = -1
			else:
				issue(model, u, "charge", "Complete the committed charge", FieldData.pos(targets[0]), targets[0])
				continue
		if u.kind == "infantry" and u.get("coverId") == null and u.get("coverOrderId") == null:
			var cavalry = seen.filter(func(other): return FieldCharge.mounted(other) and other.charging and FieldData.distance(u, other) < 190)
			if not cavalry.is_empty():
				FieldFormations.order(u, "square")
				issue(model, u, "square", "Close ranks against the cavalry threat", null, cavalry[0], true)
				continue
		if b.time < u.ai.until: continue
		var enemy = target_for(model, u, seen)
		if u.kind == "cavalry" and not u.dismounted:
			if charge_safe(model, u, enemy, seen, friends) and FieldCharge.eligible(u, b.time):
				if issue(model, u, "charge", "Exploit an exposed or wavering enemy", FieldData.pos(enemy), enemy): FieldCharge.start(u, enemy, b.time)
			else:
				var destination = FieldData.pos(u.ai.station)
				var flanking = not enemy.is_empty() and not model.terrain.field.get("river", false) and u.condition > 55
				if flanking: destination = FieldData.pos(enemy) - forward * 110 + Vector2(0, ai.flank * 190)
				issue(model, u, "flank" if flanking else "screen", "Seek a supported flank opening" if flanking else "Screen the line and conserve cavalry", position_for(model, u, destination, friends))
			continue
		if u.kind == "artillery":
			var point = battery_position(model, u, enemy, friends)
			issue(model, u, "battery", "Fire from a clear supporting lane" if point != null else "No safe firing lane; holding battery", point, enemy if point != null else {})
			continue
		if u.kind == "infantry" and u.get("coverId") == null and u.get("coverOrderId") == null:
			FieldFormations.order(u, "line")
		if u.aiRole == "reserve" and not u.ai.committed:
			var gap = pressure(model, seen, claimed)
			if gap.is_empty() and ai.stance in ["advance", "flank"] and u.condition > 60:
				for target in seen:
					if target.id not in claimed and target.morale < 38 and friends.any(func(ally): return ally.kind == "infantry" and ally.aiRole != "reserve" and FieldData.distance(ally, target) < 160):
						gap = {"id": target.id, "point": FieldData.pos(target) - forward * 110, "reason": "Support an attack on a wavering sector"}
						break
			if not gap.is_empty():
				claimed.append(gap.id)
				u.ai.committed = true
				u.ai.station = FieldData.point(gap.point)
				u.ai.reason = gap.reason
			else:
				issue(model, u, "reserve", "Keep a fresh regiment behind the line", position_for(model, u, FieldData.pos(u.ai.station), friends))
				continue
		if u.get("coverId") != null or u.get("coverOrderId") != null:
			if ai.stance == "defend" and (enemy.is_empty() or model.tactics.incoming_sector(enemy, u) == "front"):
				u.ai.state = "cover"
				u.ai.reason = "Man the position and hold its firing arc"
				u.attackId = null
				continue
			FieldCover.leave(u)
		if ai.stance == "defend" and not u.ai.committed:
			var best_cover: Dictionary = {}
			var score = -INF
			for cover in model.terrain.defenses:
				if not FieldCover.eligible(u, cover) or absf(angle_difference(cover.facing, ai.facing)) > 0.2 or not FieldCover.occupant(b, cover.id, u.id).is_empty(): continue
				var distance = FieldData.pos(cover).distance_to(FieldData.pos(u.ai.station))
				if distance > 160: continue
				var value = cover.protection * 150 - distance
				if value > score:
					score = value
					best_cover = cover
			if not best_cover.is_empty() and FieldCover.order(model, u, best_cover):
				u.ai.state = "cover"
				u.ai.reason = "Occupy cover supporting the defensive line"
				u.ai.until = b.time + 6
				continue
		var station = FieldData.pos(u.ai.station)
		var reach: float = FieldData.weapons()[u.weapon].range
		if not enemy.is_empty() and FieldData.distance(u, enemy) <= reach * 0.96 and FieldData.pos(u).distance_to(station) < 130 and model.tactics.clear_shot(model, u, enemy):
			issue(model, u, "fire", "Hold the sector and deliver fire", null, enemy)
		else:
			issue(model, u, "reinforce" if u.ai.committed else "line", "Fill the threatened sector" if u.ai.committed else "Maintain the assigned infantry frontage", position_for(model, u, station, friends), enemy)

static func valid(model, b: Dictionary) -> bool:
	if b.has("aiPersonality") and b.aiPersonality not in ["aggressive", "cautious", "opportunist"]: return false
	if b.has("ai"):
		if not model.valid_shape(b.ai, {"stance": "", "reason": "", "personality": "", "until": 0.0, "anchor": {"x": 0.0, "y": 0.0}, "facing": 0.0, "flank": 0.0, "contacts": [{"id": "", "x": 0.0, "y": 0.0, "at": 0.0, "strength": 0.0}]}): return false
		if b.ai.stance not in ["defend", "advance", "flank", "withdraw"] or b.ai.personality not in ["aggressive", "cautious", "opportunist"] or b.ai.contacts.size() > 48: return false
	for u in b.units:
		if not u.has("ai"): continue
		if not model.valid_shape(u.ai, {"state": "", "reason": "", "until": 0.0, "station": {"x": 0.0, "y": 0.0}, "committed": false, "orders": 0.0}) or u.ai.state not in STATES: return false
	return true
