class_name FieldFormations
extends RefCounted

var groups: Dictionary = {}
var motion: Dictionary = {}
var spacing_time = -1
var terrain_ref: FieldTerrain
var path_budget = 6
var profile_sections = {"setup": 0, "grid": 0, "figures": 0}
static var layouts: Dictionary = {}
static var footprints: Dictionary = {}
static var loose_patterns: Dictionary = {}
static var transition_geometry: Dictionary = {}
static var turning_radii: Dictionary = {}
const INFANTRY_STRIDE_DISTANCE = 18.0
const WALK_CADENCE = 2.0 / 3.0

static func infantry_phase(phase: float, distance: float) -> float:
	return fposmod(phase + maxf(0, distance) / INFANTRY_STRIDE_DISTANCE * TAU * WALK_CADENCE, TAU)

static func stride_phase(phase: float, distance: float, kind: String) -> float:
	var stride = 26.0 if kind == "cavalry" else 16.0 if kind == "artillery" else 24.0 if kind == "wagon" else INFANTRY_STRIDE_DISTANCE
	return fposmod(phase + maxf(0, distance) / stride * TAU * WALK_CADENCE, TAU)

static func infantry_frame(phase: float, moving: float) -> int:
	return 0 if moving < 0.08 else 1 if sin(phase) >= 0 else 2

static func melee_frame(phase: float, rank: int = 0) -> int:
	var beat = fposmod(phase, TAU) / TAU
	if rank <= 1 and beat >= 0.18 and beat < 0.45: return 1
	return 2 if beat >= 0.58 and beat < 0.82 else 0

static func melee_phase(time: float, index: int) -> float:
	return time * (3.4 + float(index % 7) * 0.08) + index * 1.71

class Soldier:
	extends RefCounted
	var p: Vector2
	var previous: Vector2
	var velocity = Vector2.ZERO
	var facing: float
	var previousFacing: float
	var phase: float
	var previousPhase: float
	var moving = 0.0
	var previousMoving = 0.0
	var separation = Vector2.ZERO
	var alive = true
	var slot = 0
	var melee_rank = -1
	var path: Array = []
	var path_goal = Vector2.ZERO
	var path_retry = 0.0
	func _init(position: Vector2, angle: float, stride: float) -> void:
		p = position
		previous = position
		facing = angle
		previousFacing = angle
		phase = stride
		previousPhase = stride

static func order(u: Dictionary, value: String) -> bool:
	if u.kind != "infantry" or u.routed or not value in ["line", "column", "square"]:
		return false
	if u.formationChange != null:
		u.queuedFormation = null if value == u.formationChange.to else value
		return true
	if u.formation == value:
		return false
	u.formationChange = {"from": u.formation, "to": value, "elapsed": 0.0, "duration": {"line": 8.0, "column": 6.0, "square": 12.0}[value] * (1.0 - minf(5, u.experience) * 0.045) * (1.0 + (100.0 - u.morale) / 180.0)}
	u.charging = false
	return true

static func advance_order(u: Dictionary, dt: float) -> void:
	if u.formationChange == null:
		return
	var c: Dictionary = u.formationChange
	c.elapsed = minf(c.duration, c.elapsed + dt)
	if c.elapsed >= c.duration:
		u.formation = c.to
		u.formationChange = null
		var next = u.queuedFormation
		u.queuedFormation = null
		if next != null:
			order(u, next)

static func layout(formation: String, i: int, count: int, kind: String) -> Vector2:
	if formation == "square":
		var edge = i % 4
		var offset = (floorf(i / 4.0) / maxf(1, ceilf(count / 4.0) - 1.0) - 0.5) * 54.0
		return Vector2(offset if edge < 2 else -27.0 if edge == 2 else 27.0, offset if edge >= 2 else -27.0 if edge == 0 else 27.0)
	var columns = 8 if kind == "cavalry" else 7 if formation == "column" else ceili(count / 4.0)
	return Vector2(((i % columns) - (columns - 1) / 2.0) * (8.0 if kind == "cavalry" else 5.0), (floorf(float(i) / columns) - (ceilf(float(count) / columns) - 1.0) / 2.0) * 6.0)

static func figure_count(u: Dictionary, men: float) -> int:
	return 0 if men <= 0 else ceili(men / 30.0) if u.kind == "artillery" else clampi(ceili(men / 9.0), 4, 100)

static func offsets(u: Dictionary) -> Array[Vector2]:
	var count: int = u.get("visualCount", figure_count(u, u.get("startMen", u.men)))
	var formation = u.get("formation", "line")
	if u.get("coverId") != null:
		return FieldCover.garrison(u, count).offsets
	var scale_value = 1.7 if u.get("role") == "skirmishers" else 1.0
	var key = "%s:%s:%d:%s" % [u.kind, formation, count, scale_value]
	if not layouts.has(key): layouts[key] = make_layout(u.kind, formation, count, scale_value)
	if u.get("formationChange") == null: return layouts[key]
	var transition_key: Array = []
	var identity: String = u.get("id", "")
	if u.get("formationChange") != null:
		var c: Dictionary = u.formationChange
		transition_key = [key, c.to, c.elapsed, c.duration]
		var cached: Dictionary = transition_geometry.get(identity, {})
		if cached.get("key") == transition_key: return cached.points
	var c: Dictionary = u.formationChange
	var to_key = "%s:%s:%d:%s" % [u.kind, c.to, count, scale_value]
	if not layouts.has(to_key): layouts[to_key] = make_layout(u.kind, c.to, count, scale_value)
	var from: Array[Vector2] = layouts[key]
	var to: Array[Vector2] = layouts[to_key]
	var t = clampf(c.elapsed / c.duration, 0, 1)
	var blend = t * t * (3.0 - 2.0 * t)
	var points: Array[Vector2] = []
	points.resize(count)
	for i in count: points[i] = from[i].lerp(to[i], blend)
	transition_geometry[identity] = {"key": transition_key, "points": points}
	return points

static func make_layout(kind: String, formation: String, count: int, scale_value: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in count:
		var p = Vector2((i - (count - 1) / 2.0) * 25.0, 0) if kind == "artillery" else layout(formation, i, count, kind)
		points.append(p * scale_value)
	return points

static func world_point(u: Dictionary, p: Vector2) -> Vector2:
	return FieldData.pos(u) + p.rotated(u.get("facing", 0.0) - PI / 2.0)

static func loose_pattern(mounted: bool, count: int) -> PackedVector2Array:
	var key = Vector2i(1 if mounted else 0, count)
	if loose_patterns.has(key): return loose_patterns[key]
	var result = PackedVector2Array()
	for i in count:
		var variation = float((i * 37 + 13) % 101) / 100.0
		result.append(Vector2(sin(i * 2.39) * (1.6 if mounted else 0.25), -variation * (3.0 if mounted else 0.6)))
	loose_patterns[key] = result
	return result

static func bounds(u: Dictionary) -> Rect2:
	if u.has("radius") or u.get("kind", "") in ["general", "wagon"]:
		return Rect2(-16, -12, 32, 24)
	var key = "%s:%s:%d:%s:%s:%s" % [u.kind, u.get("formation", "line"), u.get("visualCount", figure_count(u, u.get("startMen", u.men))), u.get("role", ""), u.get("coverId"), u.get("coverWidth", 0)]
	if u.get("formationChange") == null and footprints.has(key): return footprints[key]
	var points = offsets(u)
	var changing: bool = u.get("formationChange") != null and u.get("coverId") == null
	var identity: String = u.get("id", "")
	if changing and transition_geometry[identity].has("bounds"): return transition_geometry[identity].bounds
	var rect = Rect2(points[0], Vector2.ZERO) if not points.is_empty() else Rect2()
	for p in points:
		rect = rect.expand(p)
	var result = rect.grow(6.0)
	if u.get("formationChange") == null: footprints[key] = result
	elif changing: transition_geometry[identity]["bounds"] = result
	return result

static func turn_rate(u: Dictionary) -> float:
	if u.has("stock"):
		return 0.32
	if u.has("radius"):
		return 0.75
	var radius = 12.0
	if u.get("formationChange") != null and u.get("coverId") == null:
		var points = offsets(u)
		var geometry: Dictionary = transition_geometry[u.get("id", "")]
		if not geometry.has("radius"):
			for p in points: radius = maxf(radius, p.length())
			geometry["radius"] = radius
		else: radius = geometry.radius
	else:
		var key = "%s:%s:%d:%s:%s:%s" % [u.kind, u.get("formation", "line"), u.get("visualCount", figure_count(u, u.get("startMen", u.men))), u.get("role", ""), u.get("coverId"), u.get("coverWidth", 0)]
		if turning_radii.has(key): radius = turning_radii[key]
		else:
			for p in offsets(u): radius = maxf(radius, p.length())
			turning_radii[key] = radius
	var mounted = u.kind == "cavalry" and not u.get("dismounted", false)
	var guns = u.kind == "artillery"
	var pace = 29.0 if mounted else (16.0 if u.limbered else 9.0) if guns else 17.0
	return minf(0.65 if mounted else 0.28 if guns else 0.42, pace / radius) * (0.7 + u.get("condition", 100.0) * 0.003)

static func turn(u: Dictionary, angle: float, dt: float) -> void:
	var facing: float = u.get("facing", 0.0)
	var error = angle_difference(facing, angle)
	var limit = turn_rate(u)
	var want = signf(error) * minf(limit, absf(error) * 2.0)
	var velocity = move_toward(float(u.get("turnVelocity", 0.0)), want, limit * 2.5 * dt)
	var change = velocity * dt
	if absf(error) < 0.0001 or (signf(change) == signf(error) and absf(change) >= absf(error)):
		u.facing = facing + error
		u.turnVelocity = 0.0
	else:
		u.facing = facing + change
		u.turnVelocity = velocity

static func alignment(u: Dictionary, bearing: float) -> float:
	return 1.0 if u.get("fallingBack", false) else pow(maxf(0, cos(bearing - u.get("facing", 0.0))), 2)

static func march_pace(u: Dictionary, terrain_kind: String = "open") -> float:
	var pace = (25.0 if u.dismounted else 49.0) if u.kind == "cavalry" else (34.0 if u.limbered else 9.0) if u.kind == "artillery" else 24.0
	if u.kind == "artillery": pace *= FieldData.weapons()[u.weapon].get("mobility", 1.0)
	pace *= 1.45 if u.formation == "column" else 0.35 if u.formation == "square" else 1.0
	pace *= 0.58 if terrain_kind == "woods" else 1.0
	pace *= 0.55 + u.condition * 0.0045
	pace *= 0.3 if u.formationChange != null else 1.0
	pace *= 0.15 if u.limberChange > 0 else 1.0
	pace *= FieldCharge.pace_multiplier(u) if u.charging else 1.45 if u.running else 1.0
	pace *= 0.65 if u.fallingBack else 1.0
	return pace * (1.15 if u.get("role") == "skirmishers" else 1.0)

func reset(u: Dictionary) -> Array[Soldier]:
	var points: Array[Soldier] = []
	for p in offsets(u):
		points.append(Soldier.new(world_point(u, p), u.facing, float(points.size()) * 1.71))
	if not u.has("visualSlots") or u.visualSlots.size() != points.size():
		u["visualSlots"] = range(points.size())
	for i in points.size():
		points[i].slot = int(u.visualSlots[i])
		points[i].p = world_point(u, offsets(u)[points[i].slot])
	var flow = {"p": FieldData.pos(u), "velocity": Vector2.ZERO, "distance": 0.0, "looseness": 0.0}
	update_bridge(u, points, flow, 0.0)
	for i in points.size():
		var p = bridge_goal(u, points[i].slot, flow, points[i].p)
		points[i].p = terrain_ref.figure_ground_point(p, figure_radius(u)) if terrain_ref != null else p
		points[i].previous = points[i].p
	if not u.has("deadSlots"):
		u["deadSlots"] = []
		var order = casualty_order(u, points)
		for i in maxi(0, points.size() - figure_count(u, u.men)):
			u.deadSlots.append(order[i])
	for i in u.deadSlots:
		if i >= 0 and i < points.size(): points[int(i)].alive = false
	groups[u.id] = points
	motion[u.id] = flow
	return points

func reset_roster(u: Dictionary) -> void:
	u["visualCount"] = figure_count(u, u.men)
	u["deadSlots"] = []
	u.erase("visualSlots")
	groups.erase(u.id)
	motion.erase(u.id)

func advance_motion(u: Dictionary, dt: float) -> Dictionary:
	var flow: Dictionary = motion[u.id]
	var p = FieldData.pos(u)
	var step: Vector2 = p - flow.p
	var distance = step.length()
	if distance > 220:
		reset(u)
		return motion[u.id]
	flow.distance += distance
	flow.velocity = step / dt
	flow.looseness = move_toward(flow.looseness, clampf(distance / dt / 12.0, 0, 1), dt * (0.65 if distance > 0.05 else 0.3))
	flow.p = p
	return flow

func movement_goal(u: Dictionary, slot: Vector2, index: int, flow: Dictionary, _front: float) -> Vector2:
	var rigid = world_point(u, slot)
	var bridge_slot: int = u.visualSlots[index] if u.has("visualSlots") and index < u.visualSlots.size() else index
	if flow.get("streetBlend", 0.0) > 0:
		var count: int = u.get("visualCount", figure_count(u, u.get("startMen", u.men)))
		var spacing = 18.0 if u.kind == "artillery" else 8.0 if u.kind == "cavalry" and not u.dismounted else 5.0
		var columns = maxi(1, mini(7, floori(flow.streetWidth / spacing)))
		var depth = 24.0 if u.kind == "artillery" else 10.0 if u.kind == "cavalry" and not u.dismounted else 6.0
		var narrow = Vector2((bridge_slot % columns - (columns - 1) * 0.5) * spacing, (floorf(float(bridge_slot) / columns) - (ceilf(float(count) / columns) - 1) * 0.5) * depth)
		rigid = rigid.lerp(world_point(u, narrow), flow.streetBlend)
	if flow.looseness < 0.001 or u.kind == "artillery" or u.fallingBack: return bridge_goal(u, bridge_slot, flow, rigid)
	var mounted = u.kind == "cavalry" and not u.dismounted
	var variation = float((index * 37 + 13) % 101) / 100.0
	# Small individual offsets, not expanding frontage or differently rotated rows.
	var offset = Vector2(sin(index * 2.39) * (1.6 if mounted else 0.25), -variation * (3.0 if mounted else 0.6))
	return bridge_goal(u, bridge_slot, flow, rigid + offset.rotated(u.facing - PI / 2.0) * flow.looseness)

func update_street(u: Dictionary, flow: Dictionary, dt: float) -> void:
	var target = 0.0
	if terrain_ref != null and not terrain_ref.campaign and not terrain_ref.buildings.is_empty() and u.get("coverId") == null and flow.get("bridgeBlend", 0.0) < 0.01:
		var front = Vector2.from_angle(u.facing)
		var lateral = front.orthogonal()
		var half = minf(bounds(u).size.x * 0.5, 80)
		var center = FieldData.pos(u)
		var nearby: Array = []
		var reach = half + 45
		for building in terrain_ref.buildings:
			if absf(building.p.x - center.x) < reach + building.size and absf(building.p.y - center.y) < reach + building.size: nearby.append(building.rect.grow(4))
		var available = half * 2
		for look in ([0.0, 35.0] if not nearby.is_empty() else []):
			var p = FieldData.pos(u) + front * look
			var width = 0.0
			for side in [-1, 1]:
				var clear = half
				for n in range(5, int(half) + 5, 5):
					if nearby.any(func(rect): return rect.has_point(p + lateral * side * n)):
						clear = maxf(0, n - 5)
						break
				width += clear
			available = minf(available, width)
		if available < half * 2 - 4 and available >= 10:
			flow["streetWidth"] = maxf(10, available - 5)
			flow["streetClearDistance"] = flow.distance + 60
			target = 1.0
		elif flow.distance < flow.get("streetClearDistance", 0.0): target = 1.0
	flow["streetBlend"] = move_toward(float(flow.get("streetBlend", 0.0)), target, dt * 0.8)

static func figure_radius(u: Dictionary) -> float:
	return 8.0 if u.kind == "artillery" else 5.0 if u.kind == "cavalry" and not u.dismounted else 3.0

func update_bridge(u: Dictionary, points: Array[Soldier], flow: Dictionary, dt: float) -> void:
	if terrain_ref == null or terrain_ref.campaign or not terrain_ref.water or u.get("coverId") != null:
		flow.erase("bridge")
		flow["bridgeBlend"] = 0.0
		return
	var center = FieldData.pos(u)
	var radius = bounds(u).size.length() * 0.5
	var nearest = Vector2.ZERO
	var distance = INF
	for y in terrain_ref.crossings:
		var bridge = Vector2(terrain_ref.channel_x(y), y)
		var delta = (center - bridge).abs()
		if delta.y > radius + 60 or delta.x > radius + 180: continue
		if center.distance_squared_to(bridge) < distance:
			distance = center.distance_squared_to(bridge)
			nearest = bridge
	var target = 0.0
	if distance < INF:
		target = 1.0 - smoothstep(110.0, radius + 170.0, absf(center.x - nearest.x))
		if not flow.has("bridge") or flow.bridge != nearest:
			flow["bridge"] = nearest
			flow["bridgeDirection"] = -1.0 if cos(u.facing) < 0 else 1.0
	# Keep the files until the last figure has left the deck and its approaches.
	if flow.has("bridge") and points.any(func(soldier): return soldier.alive and absf(soldier.p.x - flow.bridge.x) < 90 and absf(soldier.p.y - flow.bridge.y) < 34): target = 1.0
	flow["bridgeBlend"] = target if dt <= 0 else move_toward(float(flow.get("bridgeBlend", 0.0)), target, dt * 0.65)
	if target == 0 and flow.bridgeBlend < 0.001: flow.erase("bridge")

func bridge_goal(u: Dictionary, index: int, flow: Dictionary, goal: Vector2) -> Vector2:
	if not flow.has("bridge") or flow.get("bridgeBlend", 0.0) <= 0: return goal
	var count: int = u.get("visualCount", figure_count(u, u.get("startMen", u.men)))
	var columns = 2 if u.kind == "artillery" else 4 if u.kind == "cavalry" and not u.dismounted else 7
	var spacing = 18.0 if u.kind == "artillery" else 8.0 if u.kind == "cavalry" and not u.dismounted else 5.0
	var depth = 24.0 if u.kind == "artillery" else 11.0 if u.kind == "cavalry" and not u.dismounted else 6.0
	var lateral = ((index % columns) - (columns - 1) * 0.5) * spacing
	var longitudinal = (floorf(float(index) / columns) - (ceilf(float(count) / columns) - 1) * 0.5) * depth
	var direction: float = flow.bridgeDirection
	var narrow = FieldData.pos(u) + Vector2(longitudinal, -lateral) * direction
	var allowance = maxf(0, FieldTerrain.BRIDGE_HALF_WIDTH - figure_radius(u) - 2.0 - (columns - 1) * spacing * 0.5)
	narrow.y = flow.bridge.y + clampf(u.y - flow.bridge.y, -allowance, allowance) - lateral * direction
	return goal.lerp(narrow, flow.bridgeBlend)

func water_goal(soldier: Soldier, goal: Vector2, flow: Dictionary, radius: float) -> Vector2:
	if terrain_ref == null or terrain_ref.campaign or not terrain_ref.water: return goal
	var axis = 720.0 + terrain_ref.battle_offset.x
	if maxf(soldier.p.x, goal.x) < axis - 83.0 - radius or minf(soldier.p.x, goal.x) > axis + 83.0 + radius: return goal
	goal = terrain_ref.figure_ground_point(goal, radius)
	if terrain_ref.figure_segment_clear(soldier.p, goal, radius): return goal
	var bridge: Vector2 = flow.get("bridge", Vector2.ZERO)
	if not flow.has("bridge"):
		var best = INF
		for y in terrain_ref.crossings:
			var p = Vector2(terrain_ref.channel_x(y), y)
			var distance = soldier.p.distance_to(p) + goal.distance_to(p)
			if distance < best:
				best = distance
				bridge = p
	var lane = clampf(goal.y - bridge.y, -FieldTerrain.BRIDGE_HALF_WIDTH + radius + 2, FieldTerrain.BRIDGE_HALF_WIDTH - radius - 2)
	var side = -1.0 if soldier.p.x < bridge.x else 1.0
	var goal_side = -1.0 if goal.x < bridge.x else 1.0
	var entry = bridge + Vector2(side * 92, lane)
	var exit = bridge + Vector2(goal_side * 92, lane)
	if terrain_ref.figure_segment_clear(soldier.p, exit, radius): return exit
	return entry

func water_step(p: Vector2, step: Vector2, radius: float) -> Vector2:
	if terrain_ref == null or terrain_ref.campaign or not terrain_ref.water or terrain_ref.figure_segment_clear(p, p + step, radius): return step
	var best = Vector2.ZERO
	for slide in [Vector2(step.x, 0), Vector2(0, step.y)]:
		if slide.length_squared() > best.length_squared() and terrain_ref.figure_segment_clear(p, p + slide, radius): best = slide
	if best != Vector2.ZERO: return best
	var fraction = 1.0
	for i in 8:
		fraction *= 0.5
		if terrain_ref.figure_segment_clear(p, p + step * fraction, radius): return step * fraction
	return Vector2.ZERO

func casualty_order(u: Dictionary, points: Array[Soldier]) -> Array:
	var order: Array = []
	var slots = offsets(u)
	var flow: Dictionary = motion.get(u.id, {})
	if u.get("meleeTargetId") != null and flow.has("contactKey"):
		slots = flow.contactFiles
	for i in points.size():
		if points[i].alive: order.append(i)
	if u.get("coverId") != null and u.get("meleeTargetId") == null:
		order.sort_custom(func(a, b): return points[a].slot < points[b].slot)
		return order
	order.sort_custom(func(a, b): return slots[points[a].slot].y > slots[points[b].slot].y if not is_equal_approx(slots[points[a].slot].y, slots[points[b].slot].y) else points[a].slot < points[b].slot)
	return order

func fill_ranks(u: Dictionary, points: Array[Soldier], slots: Array[Vector2], flow: Dictionary, context: String = "") -> void:
	if not (u.kind == "infantry" or (u.kind == "cavalry" and not context.is_empty())) or (u.formation == "square" and context.is_empty()) or u.formationChange != null: return
	var signature = "%s:%d:%s:%s" % [u.formation, u.deadSlots.size(), context, u.get("coverId")]
	if flow.get("filled") == signature: return
	flow["filled"] = signature
	# Move vacancies rearward within each file; soldier identities and bodies stay intact.
	var vacancies: Array = []
	for i in points.size():
		if not points[i].alive: vacancies.append(i)
	if u.get("coverId") != null and context.is_empty():
		var files: Array = FieldCover.garrison(u, points.size()).files
		vacancies.sort_custom(func(a, b): return points[a].slot < points[b].slot)
		for vacancy in vacancies:
			var empty: Soldier = points[vacancy]
			for next in range(empty.slot + 1, points.size()):
				if files[next] != files[empty.slot]: continue
				for soldier in points:
					if soldier.alive and soldier.slot == next:
						soldier.slot = empty.slot
						empty.slot = next
		for i in points.size(): u.visualSlots[i] = points[i].slot
		return
	vacancies.sort_custom(func(a, b): return slots[points[a].slot].y > slots[points[b].slot].y)
	for vacancy in vacancies:
		var empty: Soldier = points[vacancy]
		while true:
			var destination = slots[empty.slot]
			var replacement = -1
			var nearest = INF
			for i in points.size():
				if not points[i].alive: continue
				if not context.is_empty() and flow.has("contactSlots") and flow.contactSlots[empty.slot].get("enemyId") != flow.contactSlots[points[i].slot].get("enemyId"): continue
				var from = slots[points[i].slot]
				var distance = destination.y - from.y
				if is_equal_approx(from.x, destination.x) and distance > 0 and distance < nearest:
					replacement = i
					nearest = distance
			if replacement < 0: break
			var old_slot = points[replacement].slot
			points[replacement].slot = empty.slot
			empty.slot = old_slot
	for i in points.size(): u.visualSlots[i] = points[i].slot

func casualties(u: Dictionary, points: Array[Soldier], time: float, bodies: Array) -> void:
	var lost = points.size() - u.deadSlots.size() - figure_count(u, u.men)
	if lost <= 0: return
	var order = casualty_order(u, points)
	for i in mini(lost, order.size()):
		var slot: int = order[i]
		var soldier: Soldier = points[slot]
		soldier.alive = false
		soldier.moving = 0.0
		u.deadSlots.append(slot)
		if bodies.size() < 4096:
			bodies.append({"x": soldier.p.x, "y": soldier.p.y, "facing": soldier.facing, "side": u.side, "kind": u.kind, "mounted": u.kind == "cavalry" and not u.dismounted, "time": time})

func melee_layout(u: Dictionary, enemy: Dictionary, slots: Array[Vector2], flow: Dictionary, opponents: Array = []) -> Dictionary:
	if opponents.size() > 1: return multiple_fronts(u, slots, flow, opponents)
	var front = FieldContact.front(u, enemy)
	var key = "%s:%s:%d" % [enemy.id, u.formation, slots.size()]
	if flow.get("contactKey") != key:
		var mounted = u.kind == "cavalry" and not u.dismounted
		var spacing = 8.0 if mounted else 5.0
		var columns = clampi(floori(front.width / spacing) + 1, 1, 8 if mounted else ceili(slots.size() / 4.0))
		var order: Array = range(slots.size())
		var projected: Array[Vector2] = []
		for slot in slots:
			var p = world_point(u, slot)
			projected.append(Vector2(p.dot(front.tangent), p.dot(front.normal)))
		order.sort_custom(func(a, b): return projected[a].y > projected[b].y if not is_equal_approx(projected[a].y, projected[b].y) else projected[a].x < projected[b].x)
		var positions: Dictionary = {}
		for row in ceili(slots.size() / float(columns)):
			var rank: Array = order.slice(row * columns, (row + 1) * columns)
			rank.sort_custom(func(a, b): return projected[a].x < projected[b].x)
			for i in rank.size():
				positions[rank[i]] = {"x": (i - (columns - 1) * 0.5) * spacing, "rank": row}
		flow["contactSlots"] = positions
		var files: Array[Vector2] = []
		for i in slots.size(): files.append(Vector2(positions[i].x, -positions[i].rank * 6.0))
		flow["contactFiles"] = files
		flow["contactKey"] = key
	front["slots"] = flow.contactSlots
	return front

func multiple_fronts(u: Dictionary, slots: Array[Vector2], flow: Dictionary, opponents: Array) -> Dictionary:
	opponents.sort_custom(func(a, b): return str(a.id) < str(b.id))
	var ids = opponents.map(func(enemy): return enemy.id)
	var key = "%s:%s:%d" % [str(ids), u.formation, slots.size()]
	var fronts: Dictionary = {}
	for enemy in opponents: fronts[enemy.id] = FieldContact.front(u, enemy)
	if flow.get("contactKey") != key:
		var assignments: Dictionary = {}
		var groups_by_front: Dictionary = {}
		var width = 0.0
		for id in ids:
			groups_by_front[id] = []
			width += fronts[id].width
		var order: Array = range(slots.size())
		var world_points: Array = slots.map(func(slot): return world_point(u, slot))
		order.sort_custom(func(a, b): return world_points[a].distance_squared_to(fronts[ids[0]].p) < world_points[b].distance_squared_to(fronts[ids[0]].p))
		for index in order:
			var best: String = ids[0]
			var score = INF
			for id in ids:
				var quota = maxf(1, slots.size() * fronts[id].width / width)
				var value = world_points[index].distance_squared_to(fronts[id].p) + pow(maxf(0, groups_by_front[id].size() - quota + 1), 2) * 10000
				if value < score:
					score = value
					best = id
			groups_by_front[best].append(index)
		var mounted = u.kind == "cavalry" and not u.dismounted
		var spacing = 8.0 if mounted else 5.0
		for id in ids:
			var members: Array = groups_by_front[id]
			var face: Dictionary = fronts[id]
			members.sort_custom(func(a, b): return world_points[a].dot(face.normal) > world_points[b].dot(face.normal))
			var columns = clampi(floori(face.width / spacing) + 1, 1, maxi(1, ceili(members.size() / 3.0)))
			for row in ceili(members.size() / float(columns)):
				var rank: Array = members.slice(row * columns, (row + 1) * columns)
				rank.sort_custom(func(a, b): return world_points[a].dot(face.tangent) < world_points[b].dot(face.tangent))
				for i in rank.size(): assignments[rank[i]] = {"enemyId": id, "x": (i - (rank.size() - 1) * 0.5) * spacing, "rank": row}
		flow["contactSlots"] = assignments
		var files: Array[Vector2] = []
		for i in slots.size(): files.append(Vector2(assignments[i].x, -assignments[i].rank * 6.0))
		flow["contactFiles"] = files
		flow["contactKey"] = key
	var result: Dictionary = fronts[ids[0]].duplicate()
	result["fronts"] = fronts
	result["slots"] = flow.contactSlots
	return result

func positions(u: Dictionary) -> Array[Soldier]:
	if not groups.has(u.id):
		return reset(u)
	return groups[u.id]

func obstacle_goal(soldier: Soldier, goal: Vector2, terrain, obstacles: Array, time: float, radius: float = 3.0) -> Vector2:
	if obstacles.is_empty():
		soldier.path.clear()
		return goal
	if obstacles.any(func(rect): return rect.has_point(goal)):
		var open = terrain.open_point(goal, 1)
		if open == null: return soldier.p
		goal = open
	if FieldPassage.clear_segment(soldier.p, goal, obstacles):
		soldier.path.clear()
		return goal
	if time >= soldier.path_retry and (soldier.path.is_empty() or soldier.path_goal.distance_to(goal) > 8):
		if path_budget > 0:
			path_budget -= 1
			soldier.path = terrain.route(soldier.p, goal, 1)
			soldier.path_goal = goal
			soldier.path_retry = time + 0.75
	while not soldier.path.is_empty() and soldier.p.distance_to(terrain.figure_ground_point(FieldData.pos(soldier.path[0]), radius)) < 1:
		soldier.path.pop_front()
	return terrain.figure_ground_point(FieldData.pos(soldier.path[0]), radius) if not soldier.path.is_empty() else soldier.p

func prepare_spacing(points: Array[Soldier], mounted: bool) -> void:
	var grid: Dictionary = {}
	var pushes = PackedVector2Array()
	pushes.resize(points.size())
	for i in points.size():
		if not points[i].alive: continue
		var cell = Vector2i((points[i].p / 8.0).floor())
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(i)
	var spacing = 5.0 if mounted else 3.2
	var squared = spacing * spacing
	for cell in grid:
		# Build neighboring candidates once per occupied cell, rather than nine
		# dictionary/empty-array lookups for every soldier. Evaluate each pair once
		# against the same snapshot so the result does not depend on figure order.
		var candidates: Array = []
		for y in range(-1, 2):
			for x in range(-1, 2):
				var other = cell + Vector2i(x, y)
				if grid.has(other): candidates.append_array(grid[other])
		for i in grid[cell]:
			for j in candidates:
				if j <= i: continue
				var away: Vector2 = points[i].p - points[j].p
				var distance_squared = away.length_squared()
				if distance_squared < 0.0001 or distance_squared >= squared: continue
				var distance = sqrt(distance_squared)
				var force = away / distance * (spacing - distance) * 3.0
				pushes[i] += force
				pushes[j] -= force
	for i in points.size(): points[i].separation = pushes[i].limit_length(10)

func advance(units: Array, time: float, dt: float, bodies: Array = [], terrain = null) -> void:
	if dt <= 0: return
	path_budget = 6
	if terrain != null: terrain_ref = terrain
	var update_spacing = int(time * 20) != spacing_time
	spacing_time = int(time * 20)
	var present: Dictionary = {}
	var by_id: Dictionary = {}
	for u in units: by_id[u.id] = u
	for u in units:
		if u.arrival > time or u.get("withdrawn", false) or (u.men <= 0 and not groups.has(u.id)):
			continue
		var profiling: bool = terrain_ref != null and terrain_ref.profile_enabled
		var stage = Time.get_ticks_usec() if profiling else 0
		present[u.id] = true
		var slots = offsets(u)
		var cover_headings: Array = FieldCover.garrison(u, slots.size()).headings if u.get("coverId") != null else []
		var points = positions(u)
		var flow = advance_motion(u, dt)
		points = groups[u.id]
		var old_bridge = float(flow.get("bridgeBlend", 0.0))
		var old_street = float(flow.get("streetBlend", 0.0))
		update_bridge(u, points, flow, dt)
		update_street(u, flow, dt)
		casualties(u, points, time, bodies)
		if points.size() > slots.size():
			points.resize(slots.size())
		while points.size() < slots.size():
			points.append(Soldier.new(world_point(u, slots[points.size()]), u.facing, float(points.size()) * 1.71))
			points.back().slot = points.size() - 1
		var enemy: Dictionary = by_id.get(u.get("meleeTargetId"), {})
		var fighting = not enemy.is_empty() and enemy.men > 0 and not enemy.routed and not u.routed and not u.fallingBack and u.target == null and u.kind != "artillery"
		var opponents: Array = []
		if fighting:
			for id in u.get("meleeContacts", []):
				var opponent: Dictionary = by_id.get(id, {})
				if not opponent.is_empty() and opponent.men > 0 and not opponent.routed: opponents.append(opponent)
		var old_contact = flow.get("contactKey", "")
		var contact = melee_layout(u, enemy, slots, flow, opponents) if fighting else {}
		var contact_frame: Array = []
		if fighting:
			for face in contact.fronts.values() if contact.has("fronts") else [contact]:
				contact_frame.append_array([face.p, face.normal, face.width])
		var stable_contact = old_contact == flow.get("contactKey", "") and flow.get("lastContactFrame", []) == contact_frame
		fill_ranks(u, points, flow.contactFiles if fighting else slots, flow, str(flow.get("contactKey", enemy.id)) if fighting else "")
		if not fighting: flow.erase("contactKey")
		var resting = u.target == null and (not fighting or stable_contact) and flow.get("lastFighting", false) == fighting and u.formationChange == null and absf(u.turnVelocity) < 0.001 and flow.velocity.length_squared() < 0.001 and flow.looseness < 0.001
		if resting and flow.get("settled", false) and flow.get("lastFacing", INF) == u.facing and flow.get("lastCover") == u.get("coverId") and flow.get("lastDeadCount", -1) == u.deadSlots.size() and is_equal_approx(old_bridge, flow.get("bridgeBlend", 0.0)) and is_equal_approx(old_street, flow.get("streetBlend", 0.0)):
			if not flow.get("sleeping", false):
				flow["revision"] = int(flow.get("revision", 0)) + 1
				for soldier in points:
					soldier.previous = soldier.p
					soldier.previousFacing = soldier.facing
					soldier.previousPhase = soldier.phase
					soldier.previousMoving = soldier.moving
			flow["sleeping"] = true
			if profiling: profile_sections.setup += Time.get_ticks_usec() - stage
			continue
		flow["sleeping"] = false
		flow["revision"] = int(flow.get("revision", 0)) + 1
		var unsettled = false
		var march_limit = float(u.get("marchPace", march_pace(u)))
		if not u.has("marchPace") and flow.velocity.length() > 0.1: march_limit = flow.velocity.length()
		if u.routed: march_limit = 30.0
		if flow.velocity.length() < 0.1 and u.target == null:
			march_limit = minf(march_limit, 29.0 if u.kind == "cavalry" and not u.dismounted else 17.0)
		var need_spacing = fighting or u.formationChange != null or absf(u.turnVelocity) > 0.02 or flow.looseness > 0.02
		# A settled infantry contact has files at least five units apart. Below
		# half a unit of slot error these cannot touch the 3.2-unit separation
		# radius, so rebuilding a neighbor grid would find no possible contact.
		if fighting and u.kind == "infantry" and opponents.size() <= 1 and u.formationChange == null and old_contact == flow.get("contactKey", "") and flow.get("goalError", INF) < 0.25: need_spacing = false
		var front = 0.0
		for slot in slots: front = maxf(front, slot.y)
		var obstacles: Array = []
		if terrain != null:
			var occupied = Rect2(FieldData.pos(u), Vector2.ZERO)
			var box = bounds(u)
			for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
				occupied = occupied.expand(world_point(u, corner))
			for soldier in points:
				if soldier.alive: occupied = occupied.expand(soldier.p)
			occupied = occupied.grow(8)
			for building in terrain.buildings:
				if occupied.intersects(building.rect):
					obstacles.append(building.rect.grow(3))
		var mounted: bool = u.kind == "cavalry" and not u.dismounted
		if need_spacing and update_spacing: prepare_spacing(points, mounted)
		var infantry: bool = u.kind == "infantry" or (u.kind == "cavalry" and u.dismounted)
		var unit_facing: float = u.facing
		var falling_back: bool = u.fallingBack
		var unit_velocity: Vector2 = flow.velocity
		var translating_unit = unit_velocity.length_squared() > 0.01 and not fighting
		var radius = figure_radius(u)
		var has_obstacles = not obstacles.is_empty()
		var near_water = terrain_ref != null and terrain_ref.water and not terrain_ref.campaign
		var simple_goals = not fighting and flow.get("bridgeBlend", 0.0) <= 0.0 and flow.get("streetBlend", 0.0) <= 0.0
		var world_goals = PackedVector2Array()
		var world_jitter = PackedVector2Array()
		if simple_goals:
			var frame = Transform2D(unit_facing - PI / 2.0, FieldData.pos(u))
			world_goals = frame * PackedVector2Array(slots)
			if flow.looseness >= 0.001 and u.kind != "artillery" and not falling_back:
				world_jitter = Transform2D(unit_facing - PI / 2.0, Vector2.ZERO).scaled(Vector2.ONE * flow.looseness) * loose_pattern(mounted, points.size())
		if profiling:
			profile_sections.setup += Time.get_ticks_usec() - stage
			stage = Time.get_ticks_usec()
		var goal_error = 0.0
		for i in points.size():
			var soldier: Soldier = points[i]
			if not soldier.alive: continue
			var filling = u.kind == "infantry" and not fighting and u.target == null and u.formationChange == null and absf(u.turnVelocity) < 0.02 and flow.looseness < 0.02 and soldier.slot != i
			var max_speed = minf(17, march_limit) if filling else march_limit
			soldier.previous = soldier.p
			soldier.previousFacing = soldier.facing
			soldier.previousPhase = soldier.phase
			soldier.previousMoving = soldier.moving
			var goal: Vector2
			if fighting:
				goal = Vector2.ZERO # Contact slots below replace ordinary marching goals.
			elif simple_goals:
				goal = world_goals[soldier.slot]
				if not world_jitter.is_empty(): goal += world_jitter[i]
			else: goal = movement_goal(u, slots[soldier.slot], i, flow, front)
			var soldier_contact: Dictionary = contact
			soldier.melee_rank = -1
			if fighting:
				var position: Dictionary = contact.slots[soldier.slot]
				if contact.has("fronts"): soldier_contact = contact.fronts[position.enemyId]
				soldier.melee_rank = position.rank
				var mounted_contact = u.kind == "cavalry" and not u.dismounted
				goal = soldier_contact.p + soldier_contact.tangent * position.x - soldier_contact.normal * ((7.0 if mounted_contact else 4.5) + position.rank * (8.0 if mounted_contact else 5.5))
				# The shader animates thrusts and parries. Keep the physical contact
				# slots stable so settled ranks can sleep between real changes.
			if near_water: goal = water_goal(soldier, goal, flow, radius)
			if terrain != null and has_obstacles: goal = obstacle_goal(soldier, goal, terrain, obstacles, time, radius)
			elif not soldier.path.is_empty(): soldier.path.clear()
			var delta: Vector2 = goal - soldier.p
			goal_error = maxf(goal_error, delta.length_squared())
			if fighting and delta.length_squared() < 0.0001 and soldier.velocity.length_squared() < 0.0001 and soldier.moving == 0.0 and absf(angle_difference(soldier.facing, soldier_contact.normal.angle())) < 0.001:
				continue
			var translating: bool = translating_unit and soldier.path.is_empty()
			var want: Vector2 = (unit_velocity + delta * 2.0).normalized() * max_speed if translating else delta.normalized() * minf(max_speed, delta.length() / dt)
			if fighting: want = delta.limit_length(max_speed / 3.8) * 3.8
			if need_spacing and delta.length() > 0.4:
				want = (want + soldier.separation).normalized() * want.length()
			# One cruise speed for every figure. Slot error changes direction, never pace.
			soldier.velocity = soldier.velocity.move_toward(want, max_speed * 4.0 * dt).limit_length(max_speed)
			var step: Vector2 = soldier.velocity * dt
			if not translating and step.length() >= delta.length(): step = delta
			if fighting and (soldier.p - soldier_contact.p).dot(soldier_contact.normal) <= -3.5:
				var crossing: float = (soldier.p + step - soldier_contact.p).dot(soldier_contact.normal) + 3.5
				if crossing > 0: step -= soldier_contact.normal * crossing
			if has_obstacles and not FieldPassage.clear_segment(soldier.p, soldier.p + step, obstacles):
				var slide = Vector2(step.x, 0)
				if not FieldPassage.clear_segment(soldier.p, soldier.p + slide, obstacles): slide = Vector2(0, step.y)
				step = slide if FieldPassage.clear_segment(soldier.p, soldier.p + slide, obstacles) else Vector2.ZERO
			if near_water: step = water_step(soldier.p, step, radius)
			if has_obstacles and not FieldPassage.clear_segment(soldier.p, soldier.p + step, obstacles): step = Vector2.ZERO
			soldier.p += step
			soldier.velocity = step / dt
			var speed: float = soldier.velocity.length()
			if delta.length() < 0.035 and speed < 0.15 and (terrain_ref == null or terrain_ref.figure_ground_clear(goal, radius)):
				soldier.p = goal
				soldier.velocity = Vector2.ZERO
			var heading: float = soldier.velocity.angle() if speed > 2.0 and delta.length() > 0.12 and not falling_back else unit_facing
			if not cover_headings.is_empty() and speed <= 2.0: heading = unit_facing + cover_headings[soldier.slot]
			if fighting: heading = soldier_contact.normal.angle()
			soldier.facing = rotate_toward(soldier.facing, heading, dt * (1.7 if mounted else 2.4))
			if speed > 0.15:
				if infantry:
					soldier.phase = infantry_phase(soldier.phase, step.length())
				else:
					soldier.phase = stride_phase(soldier.phase, step.length(), u.kind)
			soldier.moving = move_toward(soldier.moving, clampf(speed / 14.0, 0, 1), dt * 3.0)
			unsettled = unsettled or delta.length_squared() > 0.01 or speed > 0.1 or soldier.moving > 0.01 or absf(angle_difference(soldier.facing, heading)) > 0.01
		flow["settled"] = not unsettled
		flow["lastFacing"] = u.facing
		flow["lastCover"] = u.get("coverId")
		flow["lastDeadCount"] = u.deadSlots.size()
		flow["goalError"] = goal_error
		flow["lastFighting"] = fighting
		flow["lastContactFrame"] = contact_frame
		if profiling: profile_sections.figures += Time.get_ticks_usec() - stage
	for id in groups.keys():
		if not present.has(id):
			groups.erase(id)
			motion.erase(id)
