class_name FieldCover
extends RefCounted

const TYPES = {
	"farm-wall": {"kind": "stone", "name": "Farm enclosure", "width": 112.0, "depth": 30.0, "capacity": 900, "protection": 0.45},
	"orchard-hedge": {"kind": "hedge", "name": "Orchard hedgerow", "width": 94.0, "depth": 24.0, "capacity": 720, "protection": 0.25},
	"field-redan": {"kind": "earth", "name": "Field redan", "width": 132.0, "depth": 38.0, "capacity": 900, "protection": 0.55}
}
static var garrisons: Dictionary = {}

static func outline(cover: Dictionary) -> Array[Vector2]:
	var w: float = cover.width
	var d: float = cover.depth
	match cover.kind:
		"stone": return [Vector2(-w / 2, -d), Vector2(-w / 2, 0), Vector2(w / 2, 0), Vector2(w / 2, -d)]
		"earth": return [Vector2(-w / 2, -d), Vector2(-w * 0.34, -8), Vector2(0, 10), Vector2(w * 0.34, -8), Vector2(w / 2, -d)]
	return [Vector2(-w / 2, -d), Vector2(-w * 0.34, -7), Vector2(0, 0), Vector2(w * 0.34, -7), Vector2(w / 2, -d)]

static func world_point(cover: Dictionary, point: Vector2) -> Vector2:
	return FieldData.pos(cover) + point.rotated(cover.facing - PI / 2)

static func entry(cover: Dictionary) -> Vector2:
	return world_point(cover, Vector2(0, -18))

static func garrison(u: Dictionary, count: int) -> Dictionary:
	var spec: Dictionary = TYPES.get(u.get("coverId"), TYPES["farm-wall"]).duplicate()
	spec.width = clampf(u.get("coverWidth", spec.width), 36, 200)
	var key = "%s:%s:%d" % [spec.kind, spec.width, count]
	if garrisons.has(key): return garrisons[key]
	var shape = outline(spec)
	var capacities: Array[int] = []
	var files: Array[int] = []
	var lengths: Array[float] = []
	var total_length = 0.0
	var capacity = 0
	for i in shape.size() - 1:
		var length = shape[i].distance_to(shape[i + 1])
		var available = maxi(1, floori((length - 12) / 6) + 1)
		lengths.append(length)
		capacities.append(available)
		files.append(0)
		capacity += available
		total_length += length
	# Allocate the frontage across each face, retaining at least two ranks.
	var columns = mini(capacity, maxi(1, ceili(count / 2.0)))
	for n in columns:
		var best = -1
		var deficit = -INF
		for i in files.size():
			var want = columns * lengths[i] / total_length - files[i]
			if files[i] < capacities[i] and want > deficit:
				best = i
				deficit = want
		files[best] += 1
	var stations: Array[Vector2] = []
	var normals: Array[Vector2] = []
	for i in files.size():
		var tangent = (shape[i + 1] - shape[i]).normalized()
		for j in files[i]:
			var distance = lengths[i] * 0.5 if files[i] == 1 else lerpf(6, lengths[i] - 6, float(j) / (files[i] - 1))
			stations.append(shape[i] + tangent * distance)
			normals.append(Vector2(-tangent.y, tangent.x))
	var points: Array[Vector2] = []
	var headings: Array[float] = []
	var file_ids: Array[int] = []
	var rank = 0
	while points.size() < count:
		for file in columns:
			var point = stations[file] - normals[file] * (6 + rank * 6) + Vector2(0, 18)
			# Adjacent wall faces share corners; do not assign two men the same space.
			if absf(point.x) > spec.width * 0.5 - 6 or points.any(func(other): return other.distance_squared_to(point) < 25): continue
			points.append(point)
			headings.append(normals[file].angle() - PI / 2)
			file_ids.append(file)
			if points.size() == count: break
		rank += 1
	var result = {"offsets": points, "headings": headings, "columns": columns, "files": file_ids}
	garrisons[key] = result
	return result

static func find(terrain, id) -> Dictionary:
	for cover in terrain.defenses:
		if cover.id == id: return cover
	return {}

static func occupant(battle: Dictionary, id, except_id = null) -> Dictionary:
	for u in battle.units:
		if u.id != except_id and u.arrival <= battle.time and u.men > 0 and not u.routed and not u.withdrawn and (u.get("coverId") == id or u.get("coverOrderId") == id): return u
	return {}

static func eligible(u: Dictionary, cover: Dictionary) -> bool:
	return not cover.is_empty() and u.kind == "infantry" and u.men > 0 and u.men <= cover.capacity and not u.routed and not u.withdrawn and not u.retreating

static func leave(u: Dictionary) -> void:
	u["coverId"] = null
	u["coverOrderId"] = null
	u["coverWidth"] = 0.0
	u["coverDeploy"] = 0.0

static func order(model, u: Dictionary, cover: Dictionary) -> bool:
	if not eligible(u, cover) or not occupant(model.state.battle, cover.id, u.id).is_empty(): return false
	if u.get("coverId") == cover.id or u.get("coverOrderId") == cover.id: return true
	if not model.path_unit(u, entry(cover), cover.facing): return false
	leave(u)
	model.clear_engagement(u)
	FieldCharge.cancel(u)
	u.attackId = null
	u.orderQueue = []
	u.fallingBack = false
	u.coverOrderId = cover.id
	FieldFormations.order(u, "line")
	return true

static func update(model, u: Dictionary, dt: float) -> void:
	if u.routed or u.withdrawn or u.men <= 0:
		leave(u)
		return
	var id = u.get("coverOrderId") if u.get("coverOrderId") != null else u.get("coverId")
	if id == null: return
	var cover = find(model.terrain, id)
	if not eligible(u, cover) or not occupant(model.state.battle, id, u.id).is_empty():
		leave(u)
		return
	if u.target != null or u.formationChange != null or FieldData.pos(u).distance_to(entry(cover)) > 2 or absf(angle_difference(u.facing, cover.facing)) > 0.1: return
	u.coverId = id
	u.coverOrderId = null
	u.coverWidth = cover.width
	if u.coverDeploy < 4.0:
		# The center arriving is not enough: the figures must also fill their slots.
		var slots = FieldFormations.offsets(u)
		var ready = 0
		var living = 0
		for soldier in model.formations.positions(u):
			if not soldier.alive: continue
			living += 1
			if soldier.p.distance_to(FieldFormations.world_point(u, slots[soldier.slot])) <= 3.0: ready += 1
		var filled = float(ready) / maxf(1, living)
		u.coverDeploy = minf(4.0 * filled, u.coverDeploy + dt)

static func protection(model, u: Dictionary, source: Dictionary, melee: bool) -> float:
	if u.get("coverId") == null or u.get("coverDeploy", 0.0) < 4: return 0.0
	var cover = find(model.terrain, u.coverId)
	if cover.is_empty(): return 0.0
	if u.target != null or FieldData.pos(u).distance_to(entry(cover)) > 2 or absf(angle_difference(u.facing, cover.facing)) > 0.1: return 0.0
	var bearing = (FieldData.pos(source) - FieldData.pos(u)).normalized()
	var forward = bearing.dot(Vector2.from_angle(cover.facing))
	if forward < -0.1: return 0.0
	# Side returns help on the flanks, but the open entrance is never rear cover.
	var coverage = 1.0 if forward >= 0.4 else 0.5 if cover.kind == "stone" else 0.35
	return cover.protection * coverage * (0.35 if melee else 1.0)
