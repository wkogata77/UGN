class_name FieldPassage
extends RefCounted

static func bridge_wait(model, u: Dictionary) -> bool:
	if not model.terrain.water or model.terrain.campaign or u.get("target") == null: return false
	var b: Dictionary = model.state.battle
	if not b.has("bridgeTraffic"): b["bridgeTraffic"] = {}
	var p = FieldData.pos(u)
	var goal = FieldData.pos(u.goal if u.get("goal") != null else u.target)
	for y in model.terrain.crossings:
		var bridge = Vector2(model.terrain.channel_x(y), y)
		if absf(p.x - bridge.x) > 200 or absf(p.y - y) > 65: continue
		if (p.x - bridge.x) * (goal.x - bridge.x) > 0 and not model.terrain.on_bridge(goal): continue
		var key = "%s:%s" % [u.side, y]
		var owner = model.find_id(b.units, b.bridgeTraffic.get(key))
		if not owner.is_empty():
			var points = model.formations.groups.get(owner.id, [])
			var occupied = points.any(func(soldier): return soldier.alive and absf(soldier.p.x - bridge.x) < 90 and absf(soldier.p.y - y) < 34)
			var owner_goal = FieldData.pos(owner.goal if owner.get("goal") != null else owner)
			var cleared = (owner.x - bridge.x) * signf(owner_goal.x - bridge.x) > 100 and not occupied
			if owner.men <= 0 or owner.withdrawn or cleared or (owner.target == null and not occupied): owner = {}
		if owner.is_empty():
			b.bridgeTraffic[key] = u.id
			return false
		if owner.id == u.id or absf(p.x - bridge.x) < 95: return false
		u["movementBlocked"] = "Waiting for bridge"
		return true
	return false

static func clear_segment(a: Vector2, b: Vector2, obstacles: Array) -> bool:
	for rect in obstacles:
		if FieldLandscape.segment_hit(a, b, rect) == null: continue
		if not rect.has_point(a): return false
		# Escape existing clearance overlap outward before turning around the unit.
		# A tangential leg can otherwise cross its actual frontage while remaining
		# equally close to the edge of the inflated planning rectangle.
		var step = b - a
		var offset = a - rect.get_center()
		if not ((absf(step.y) < 0.001 and step.x * offset.x >= 0) or (absf(step.x) < 0.001 and step.y * offset.y >= 0)): return false
		for i in range(1, 9):
			if FieldTerrain.rect_distance(a.lerp(b, i / 8.0), rect) < FieldTerrain.rect_distance(a, rect) - 0.001: return false
	return true

static func detour(model, u: Dictionary, blocker: Dictionary) -> bool:
	# In a head-on meeting the higher ID gives way; do not make both formations weave.
	if blocker.target != null and str(u.id) < str(blocker.id): return false
	var now: float = model.state.battle.time
	if now < float(u.get("passageRetryAt", -1)): return false
	# Route searches are cosmetic traffic planning; collision checks still run
	# every tick. Spread simultaneous requests instead of bunching them together.
	if model.tactics.index.enabled:
		if model.tactics.passage_plans <= 0: return false
		model.tactics.passage_plans -= 1
	u["passageRetryAt"] = now + 2.0
	var a = FieldData.pos(u)
	var b = FieldData.pos(u.target)
	var remaining: Array = u.waypoints.duplicate()
	var clearance = FieldFormations.bounds(u).size.length() * 0.5
	var obstacles: Array = []
	var corridor = Rect2(a, Vector2.ZERO).expand(b).grow(clearance + 180)
	var friends = model.tactics.active(model.state.battle, u.side).filter(func(friendly): return friendly.id != u.id and corridor.has_point(FieldData.pos(friendly)))
	for friendly in friends:
		var shape = FieldContact.shape(friendly)
		var half = Vector2(FieldContact.extent(shape, Vector2.RIGHT), FieldContact.extent(shape, Vector2.DOWN))
		var rect = Rect2(shape.p - half, half * 2)
		obstacles.append(rect.grow(clearance + 7))
	# Keep a safe committed approach instead of repeatedly sending it back to
	# the turning-circle boundary on each planning tick.
	if obstacles.any(func(rect): return rect.has_point(b)) and model.terrain.direct_route(a, b, 2) and clear_approach(a, b, u, friends): return false
	while obstacles.any(func(rect): return rect.has_point(b)):
		if remaining.is_empty(): break
		b = FieldData.pos(remaining.pop_front())
	if clear_segment(a, b, obstacles) and model.terrain.direct_route(a, b, 2):
		if remaining.size() == u.waypoints.size(): return false
		u.target = FieldData.point(b)
		u.waypoints = remaining
		return true
	var graph = AStar2D.new()
	graph.add_point(0, a)
	graph.add_point(1, b)
	var corners: Array = obstacles.map(func(rect): return rect.grow(3))
	for building in model.terrain.buildings:
		if corridor.intersects(building.rect): corners.append(building.rect.grow(4.5))
	for rect in corners:
		var points = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		if rect.has_point(a):
			points.append_array([Vector2(rect.position.x, a.y), Vector2(rect.end.x, a.y), Vector2(a.x, rect.position.y), Vector2(a.x, rect.end.y)])
		for p in points:
			if model.terrain.passable(p, true, 2) and not obstacles.any(func(other): return other.has_point(p)):
				graph.add_point(graph.get_point_count(), p)
	var positions = PackedVector2Array()
	for i in graph.get_point_count(): positions.append(graph.get_point_position(i))
	var triangles = Geometry2D.triangulate_delaunay(positions)
	var edges: Dictionary = {}
	for i in range(0, triangles.size(), 3):
		for pair in [Vector2i(triangles[i], triangles[i + 1]), Vector2i(triangles[i + 1], triangles[i + 2]), Vector2i(triangles[i + 2], triangles[i])]:
			edges[Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))] = true
	for i in positions.size():
		# Each point's nearest corners plus both endpoints keep small detours
		# connected without testing every house against every possible edge.
		var nearest: Array = []
		for j in positions.size():
			if i == j: continue
			var distance = positions[i].distance_squared_to(positions[j])
			var slot = 0
			while slot < nearest.size() and nearest[slot].d < distance: slot += 1
			if slot >= 6: continue
			nearest.insert(slot, {"id": j, "d": distance})
			if nearest.size() > 6: nearest.pop_back()
		for neighbor in nearest: edges[Vector2i(mini(i, neighbor.id), maxi(i, neighbor.id))] = true
		for endpoint in 2:
			if i > endpoint: edges[Vector2i(endpoint, i)] = true
	for edge in edges:
		var i: int = edge.x
		var j: int = edge.y
		var start = graph.get_point_position(i)
		var finish = graph.get_point_position(j)
		var clear = clear_segment(start, finish, obstacles)
		# A street destination may fit the actual frontage but not its turning
		# circle. Permit a straight, collision-checked final approach from outside.
		if not clear and i == 1 and j > 1: clear = clear_approach(finish, start, u, friends)
		if clear and model.terrain.direct_route(start, finish, 2): graph.connect_points(i, j)
	var path = graph.get_point_path(0, 1)
	if path.size() < 3: return false
	var points: Array = []
	for i in range(1, path.size()): points.append(FieldData.point(path[i]))
	u.target = points.pop_front()
	u.waypoints = points + remaining
	return true

static func clear_approach(a: Vector2, b: Vector2, u: Dictionary, friends: Array) -> bool:
	var trial = u.duplicate()
	trial.facing = (b - a).angle()
	trial.x = a.x
	trial.y = a.y
	var shape = FieldContact.shape(trial)
	for friend in friends:
		if FieldContact.sweep_hit(shape, b - a, FieldContact.shape(friend), 2.9999): return false
	return true
