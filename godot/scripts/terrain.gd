class_name FieldTerrain
extends RefCounted

var campaign = true
var field: Dictionary = {}
var towns: Array = []
var forests: Array = []
var roads: Array = []:
	set(value):
		roads = value
		road_index_ready = false
var road_segments: Array[Vector4] = []
var road_cells: Dictionary = {}
var road_index_ready = false
const ROAD_CELL = 256.0
var water = true
var map_size = Vector2(1440, 960)
var campaign_scale = 1.0
var battle_offset = Vector2.ZERO
var crossings: Array = []
var river_vertical = false
var river_path: Array = []
var render_bounds = Rect2(-1400, -1400, 4240, 3760)
var surface_cells = Vector2i(176, 156)
var relief = 1.0:
	set(value):
		relief = value
		heights.clear()
var grids: Dictionary = {}
var heights = PackedFloat64Array()
static var surface_cache: Dictionary = {}
var buildings: Array = []
var defenses: Array = []
var profile_enabled = false
var profile_usec = {"sight": 0, "route": 0, "direct": 0}
var profile_calls = {"sight": 0, "route": 0, "direct": 0}
const CAMPAIGN_HILLS = [Vector4(230, 195, 360, 230), Vector4(780, 145, 330, 175), Vector4(1280, 820, 340, 230), Vector4(80, 950, 300, 250), Vector4(1140, -130, 400, 210), Vector4(260, -190, 490, 260)]
const CAMPAIGN_HEIGHTS = [95, 80, 70, 55, 155, 170]
const BRIDGE_HALF_LENGTH = 78.0
const BRIDGE_HALF_WIDTH = 28.0

func configure(state: Dictionary) -> void:
	heights.clear()
	grids.clear()
	buildings.clear()
	defenses.clear()
	campaign = state.mode == "campaign"
	var layout = FieldCampaign.layout(state.get("theater", "italy"), state.get("campaignMapVersion", 1))
	campaign_scale = layout.scale if campaign else 1.0
	map_size = layout.size if campaign else FieldBattlefield.size_for(state.battle)
	battle_offset = Vector2.ZERO if campaign else FieldBattlefield.offset_for(state.battle)
	crossings = layout.crossings if campaign else FieldBattlefield.crossings_for(state.battle)
	river_vertical = campaign and state.get("theater") == "mantua"
	river_path = layout.get("river", []) if river_vertical else []
	render_bounds = Rect2(Vector2(-1400, -1400), map_size + Vector2(2800, 2800))
	var spacing = maxf(24.1, campaign_scale * 8.0) if campaign else 24.1
	surface_cells = Vector2i(ceil(render_bounds.size.x / spacing), ceil(render_bounds.size.y / spacing))
	if not campaign and battle_offset == Vector2.ZERO: surface_cells = Vector2i(176, 156)
	field = FieldData.load_data().fields.village if campaign else FieldBattlefield.layout(state.battle)
	forests = layout.forests if campaign else field.forests
	towns = layout.towns if campaign else field.towns
	water = campaign or field.get("river", false)
	if campaign:
		roads = layout.roads
	else:
		roads = field.roads
	if not campaign:
		defenses = FieldLandscape.defenses(state.battle.scenario)
		for defense in defenses:
			defense.x += battle_offset.x
			defense.y += battle_offset.y
	buildings = FieldLandscape.buildings(self)

func order_bounds(margin: float = 45.0) -> Rect2:
	return Rect2(Vector2.ONE * margin, map_size - Vector2.ONE * margin * 2.0)

func fog_size() -> Vector2i:
	return Vector2i(ceil(map_size.x / 48.0), ceil(map_size.y / 48.0))

func channel_x(y: float) -> float:
	return FieldData.channel_x(y - battle_offset.y) + battle_offset.x

func deployment_limit(east: bool) -> float:
	return battle_offset.x + (1050.0 if east else 390.0)

static func kind(p: Vector2, data: Dictionary) -> String:
	for f in data.forests:
		if FieldData.ellipse(p, f) < 1.0:
			return "woods"
	for h in data.get("hills", []):
		if FieldData.ellipse(p, h) < 1.0:
			return "hill"
	return "open"

static func elevation(p: Vector2, data: Dictionary) -> float:
	var h = 0.0
	for hill in data.hills:
		h = maxf(h, 1.0 - FieldData.ellipse(p, hill))
	return h

func line_of_sight(a: Dictionary, b: Dictionary, shooting: bool = false, arc: float = 0.0) -> bool:
	if not profile_enabled: return trace_sight(a, b, shooting, arc)
	var started = Time.get_ticks_usec()
	var result = trace_sight(a, b, shooting, arc)
	profile_usec.sight += Time.get_ticks_usec() - started
	profile_calls.sight += 1
	return result

func trace_sight(a: Dictionary, b: Dictionary, shooting: bool = false, arc: float = 0.0) -> bool:
	var p = FieldData.pos(a)
	var q = FieldData.pos(b)
	var squared = p.distance_squared_to(q)
	if not shooting and squared > 540.0 * 540.0: return false
	var d = sqrt(squared)
	if d < 0.01:
		return true
	if not shooting:
		if d > (540.0 if a.get("kind", "") == "cavalry" or kind(p, field) == "hill" else 410.0):
			return false
		if kind(q, field) == "woods" and d > 230.0:
			return false
	var steps = maxi(2, ceili(d / 12.0))
	# Trace above the same triangular ground surface used to place the figures.
	var ah = height_at(p) + (11.0 if a.get("kind") == "cavalry" else 6.0)
	var bh = height_at(q) + (11.0 if b.get("kind") == "cavalry" else 6.0)
	if not campaign:
		for building in buildings:
			var hit = FieldLandscape.segment_hit(p, q, building.rect)
			if hit == null: continue
			var exit_hit = FieldLandscape.segment_hit(q, p, building.rect)
			for edge in [hit, exit_hit if exit_hit != null else hit]:
				var t = p.distance_to(edge) / d
				if height_at(building.p) + building.height > lerpf(ah, bh, t) + 4.0 * arc * t * (1.0 - t): return false
	var woods = 0.0
	var corridor = Rect2(p, Vector2.ZERO).expand(q)
	var woodland: Array = []
	for forest in field.forests:
		if corridor.intersects(Rect2(forest.x - forest.rx, forest.y - forest.ry, forest.rx * 2, forest.ry * 2), true): woodland.append(forest)
	for i in range(1, steps):
		var sample = p.lerp(q, float(i) / steps)
		var t = float(i) / steps
		var trajectory = lerpf(ah, bh, t) + 4.0 * arc * t * (1.0 - t)
		if woodland.any(func(forest): return FieldData.ellipse(sample, forest) < 1.0) and (arc <= 0 or trajectory < height_at(sample) + 22):
			woods += d / steps
		if woods > (150.0 if shooting else 180.0) or height_at(sample) > trajectory:
			return false
	return true

func river_y(x: float) -> float:
	if river_vertical:
		for i in range(1, river_path.size()):
			if x <= river_path[i][1]:
				var a: Array = river_path[i - 1]
				var b: Array = river_path[i]
				return lerpf(a[0], b[0], clampf((x - a[1]) / (b[1] - a[1]), 0, 1))
		return river_path.back()[0]
	return FieldData.river_y(x / campaign_scale) * campaign_scale

func river_point(n: float) -> Vector2:
	return Vector2(river_y(n), n) if river_vertical else Vector2(n, river_y(n))

func river_distance(p: Vector2) -> float:
	return absf(p.x - river_y(p.y)) if river_vertical else absf(p.y - river_y(p.x))

func on_bridge(p: Vector2) -> bool:
	if not water: return false
	if not campaign and absf(p.x - (720.0 + battle_offset.x)) > 113.0: return false
	if not campaign: return crossings.any(func(y): return absf(p.x - channel_x(y)) <= BRIDGE_HALF_LENGTH and absf(p.y - y) <= BRIDGE_HALF_WIDTH)
	for crossing in crossings:
		var delta = (p - river_point(crossing)).abs()
		if river_vertical: delta = Vector2(delta.y, delta.x)
		if delta.x <= 28 * 0.63 * campaign_scale and delta.y <= 78 * 0.63 * campaign_scale: return true
	return false

func surface_point(cell: Vector2i) -> Vector2:
	return render_bounds.position + Vector2(cell) / Vector2(surface_cells) * render_bounds.size

func ground_passable(p: Vector2, conservative: bool = false) -> bool:
	if p.x < 0 or p.x > map_size.x or p.y < 0 or p.y > map_size.y:
		return false
	if campaign:
		return river_distance(p) >= 26.0 * campaign_scale or crossings.any(func(x): return absf((p.y if river_vertical else p.x) - x) <= (16.0 if river_vertical else 42.0) * campaign_scale)
	return not field.get("river", false) or absf(p.x - channel_x(p.y)) > (48.0 if conservative else 31.0) or crossings.any(func(y): return absf(p.y - y) < (19.0 if conservative else BRIDGE_HALF_WIDTH))

func figure_ground_clear(p: Vector2, radius: float = 3.0) -> bool:
	if campaign or not water: return true
	if absf(p.x - channel_x(p.y)) >= 48.0 + radius: return true
	return crossings.any(func(y): return absf(p.x - channel_x(y)) <= BRIDGE_HALF_LENGTH and absf(p.y - y) <= BRIDGE_HALF_WIDTH - radius)

func figure_segment_clear(a: Vector2, b: Vector2, radius: float = 3.0) -> bool:
	if campaign or not water: return true
	# The channel's sine bend stays within +/-35. Segments wholly beyond
	# either bank cannot intersect water, regardless of their length or heading.
	var axis = 720.0 + battle_offset.x
	if maxf(a.x, b.x) < axis - 83.0 - radius or minf(a.x, b.x) > axis + 83.0 + radius: return true
	var steps = maxi(1, ceili(a.distance_to(b) / 6.0))
	for i in range(1, steps + 1):
		if not figure_ground_clear(a.lerp(b, float(i) / steps), radius): return false
	return true

func figure_ground_point(p: Vector2, radius: float = 3.0) -> Vector2:
	if figure_ground_clear(p, radius): return p
	var side = -1.0 if p.x < channel_x(p.y) else 1.0
	var nearest = Vector2(channel_x(p.y) + side * (48.0 + radius + 0.1), p.y)
	for y in crossings:
		var bridge = Vector2(channel_x(y), y)
		var q = p.clamp(bridge - Vector2(BRIDGE_HALF_LENGTH, BRIDGE_HALF_WIDTH - radius), bridge + Vector2(BRIDGE_HALF_LENGTH, BRIDGE_HALF_WIDTH - radius))
		if q.distance_squared_to(p) < nearest.distance_squared_to(p): nearest = q
	return nearest

func passable(p: Vector2, conservative: bool = false, clearance: float = 0.0) -> bool:
	if not ground_passable(p, conservative): return false
	return campaign or not buildings.any(func(b): return b.rect.grow(clearance + 2).has_point(p))

func index_roads() -> void:
	road_index_ready = true
	road_cells.clear()
	road_segments.clear()
	for road in roads:
		for i in range(1, road.size()):
			var a = FieldData.pos(road[i - 1])
			var b = FieldData.pos(road[i])
			var index = road_segments.size()
			road_segments.append(Vector4(a.x, a.y, b.x, b.y))
			var first = Vector2i((a.min(b) / ROAD_CELL).floor())
			var last = Vector2i((a.max(b) / ROAD_CELL).floor())
			for y in range(first.y, last.y + 1):
				for x in range(first.x, last.x + 1):
					var cell = Vector2i(x, y)
					if not road_cells.has(cell): road_cells[cell] = []
					road_cells[cell].append(index)

func road_distance(p: Vector2, limit: float = INF) -> float:
	if not road_index_ready: index_roads()
	var distance = limit
	if is_inf(limit):
		for segment in road_segments:
			distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(segment.x, segment.y), Vector2(segment.z, segment.w))))
		return distance
	var first = Vector2i(((p - Vector2.ONE * limit) / ROAD_CELL).floor())
	var last = Vector2i(((p + Vector2.ONE * limit) / ROAD_CELL).floor())
	var seen: Dictionary = {}
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for index in road_cells.get(Vector2i(x, y), []):
				if seen.has(index): continue
				seen[index] = true
				var segment = road_segments[index]
				distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(segment.x, segment.y), Vector2(segment.z, segment.w))))
	return distance

func near_road(p: Vector2, distance: float) -> bool:
	return road_distance(p, distance) < distance

func movement_factor(a: Vector2, b: Vector2) -> float:
	var slope = absf(height_at(b) - height_at(a)) / maxf(1, a.distance_to(b))
	return clampf(1.0 - slope * 0.65, 0.45, 1.0) * (1.08 if near_road(a, 7) else 1.0)

func direct_route(a: Vector2, b: Vector2, clearance: float = 0.0) -> bool:
	if not profile_enabled: return trace_route(a, b, clearance)
	var started = Time.get_ticks_usec()
	var result = trace_route(a, b, clearance)
	profile_usec.direct += Time.get_ticks_usec() - started
	profile_calls.direct += 1
	return result

func trace_route(a: Vector2, b: Vector2, clearance: float = 0.0) -> bool:
	if not campaign:
		for building in buildings:
			var rect: Rect2 = building.rect.grow(clearance + 2)
			if FieldLandscape.segment_hit(a, b, rect) == null: continue
			if not rect.has_point(a): return false
			# Permit old deployments to escape an overlap without crossing the house.
			for i in range(1, maxi(2, ceili(a.distance_to(b) / 8.0)) + 1):
				var p = a.lerp(b, float(i) / maxi(2, ceili(a.distance_to(b) / 8.0)))
				if rect_distance(p, building.rect) < rect_distance(a, building.rect) - 0.001: return false
	if campaign or water:
		var steps = maxi(1, ceili(a.distance_to(b) / 8.0))
		for i in range(1, steps + 1):
			if not ground_passable(a.lerp(b, float(i) / steps), true): return false
	elif not ground_passable(b, true): return false
	return true

func open_point(p: Vector2, clearance: float = 0.0):
	if not ground_passable(p): return null
	if passable(p, false, clearance): return p
	var best = null
	var distance = INF
	for building in buildings:
		var rect: Rect2 = building.rect.grow(clearance + 2.5)
		if not rect.grow(48).has_point(p): continue
		for q in [Vector2(rect.position.x, clampf(p.y, rect.position.y, rect.end.y)), Vector2(rect.end.x, clampf(p.y, rect.position.y, rect.end.y)), Vector2(clampf(p.x, rect.position.x, rect.end.x), rect.position.y), Vector2(clampf(p.x, rect.position.x, rect.end.x), rect.end.y)]:
			var d = p.distance_squared_to(q)
			if d < distance and d <= 48 * 48 and passable(q, true, clearance):
				best = q
				distance = d
	return best

static func rect_distance(p: Vector2, rect: Rect2) -> float:
	var d = (p - rect.get_center()).abs() - rect.size * 0.5
	return d.max(Vector2.ZERO).length() + minf(maxf(d.x, d.y), 0)

func grid_connection(p: Vector2, other: Vector2, grid: AStarGrid2D, cells: Vector2i, clearance: float, exiting: bool) -> Vector2i:
	var cell = Vector2i(p / 24.0).clamp(Vector2i.ZERO, cells - Vector2i.ONE)
	var best = Vector2i(-1, -1)
	var score = INF
	for radius in range(0, maxi(4, ceili(clearance / 24.0) + 3)):
		for x in range(maxi(0, cell.x - radius), mini(cells.x, cell.x + radius + 1)):
			for y in range(maxi(0, cell.y - radius), mini(cells.y, cell.y + radius + 1)):
				var candidate = Vector2i(x, y)
				if grid.is_point_solid(candidate): continue
				var q = grid.get_point_position(candidate)
				var cost = p.distance_to(q) + other.distance_to(q) * 0.1
				if cost >= score: continue
				if not (direct_route(p, q, clearance) if exiting else direct_route(q, p, clearance)): continue
				best = candidate
				score = cost
		if best.x >= 0: break
	return best

func route(a: Vector2, b: Vector2, clearance: float = 0.0) -> Array:
	if not profile_enabled: return find_route(a, b, clearance)
	var started = Time.get_ticks_usec()
	var result = find_route(a, b, clearance)
	profile_usec.route += Time.get_ticks_usec() - started
	profile_calls.route += 1
	return result

func find_route(a: Vector2, b: Vector2, clearance: float = 0.0) -> Array:
	if not passable(b, false, clearance):
		return []
	if direct_route(a, b, clearance):
		return [FieldData.point(b)]
	if not campaign: return building_route(a, b, clearance)
	var key = "campaign" if campaign else str(field.name) + ":" + str(ceili(clearance / 4.0) * 4)
	var cells = Vector2i(ceil(map_size.x / 24), ceil(map_size.y / 24))
	if not grids.has(key):
		var grid = AStarGrid2D.new()
		grid.region = Rect2i(Vector2i.ZERO, cells)
		grid.cell_size = Vector2(24, 24)
		grid.offset = Vector2(12, 12)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		for x in cells.x:
			for y in cells.y:
				grid.set_point_solid(Vector2i(x, y), not passable(Vector2(x * 24 + 12, y * 24 + 12), true, ceili(clearance / 4.0) * 4))
		grids[key] = grid
	var grid: AStarGrid2D = grids[key]
	var start = grid_connection(a, b, grid, cells, clearance, true)
	var finish = grid_connection(b, a, grid, cells, clearance, false)
	if start.x < 0 or finish.x < 0: return []
	var path = grid.get_point_path(start, finish)
	if path.is_empty():
		return []
	path.append(b)
	return smooth_route(a, path, clearance)

func smooth_route(a: Vector2, path: PackedVector2Array, clearance: float) -> Array:
	var points: Array = []
	var anchor = a
	var i = 0
	while i < path.size():
		# Include the exact destination when pulling the path taut, not afterwards.
		var end = path.size() - 1
		while end >= i and not direct_route(anchor, path[end], clearance): end -= 1
		if end < i: return []
		anchor = path[end]
		if points.is_empty() or FieldData.pos(points.back()).distance_to(anchor) > 0.01:
			points.append(FieldData.point(anchor))
		i = end + 1
	return points

func building_route(a: Vector2, b: Vector2, clearance: float) -> Array:
	# Visibility edges use real building corners, so narrow streets are not lost
	# to grid resolution and detours have no cell-center stair steps.
	var key = "buildings:%s:%s" % [clearance, hash(buildings)]
	if not grids.has(key):
		var graph = AStar2D.new()
		var candidates: Array[Vector2] = []
		for building in buildings:
			var rect: Rect2 = building.rect.grow(clearance + 2.5)
			candidates.append_array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		if water:
			for y in range(12, int(map_size.y), 48):
				for side in [-1, 1]: candidates.append(Vector2(channel_x(y) + side * 52, y))
			for y in crossings:
				for side in [-1, 1]: candidates.append(Vector2(channel_x(y) + side * 60, y))
		for p in candidates:
			if passable(p, true, clearance): graph.add_point(graph.get_point_count(), p)
		var positions = PackedVector2Array()
		for i in graph.get_point_count(): positions.append(graph.get_point_position(i))
		var triangles = Geometry2D.triangulate_delaunay(positions)
		var edges: Dictionary = {}
		for i in range(0, triangles.size(), 3):
			for pair in [Vector2i(triangles[i], triangles[i + 1]), Vector2i(triangles[i + 1], triangles[i + 2]), Vector2i(triangles[i + 2], triangles[i])]:
				edges[Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))] = true
		# Local visibility edges avoid a quadratic first-order stall. Full visibility
		# remains a lazy fallback for rare disconnected obstacle configurations.
		for i in positions.size():
			var neighbors: Array[Vector2] = []
			for j in positions.size(): neighbors.append(Vector2(positions[i].distance_squared_to(positions[j]), j))
			neighbors.sort()
			for neighbor in neighbors.slice(1, 9):
				var j = int(neighbor.y)
				edges[Vector2i(mini(i, j), maxi(i, j))] = true
		for edge in edges:
			if direct_route(positions[edge.x], positions[edge.y], clearance): graph.connect_points(edge.x, edge.y)
		grids[key] = graph
	var graph: AStar2D = grids[key]
	var start = graph.get_point_count()
	var finish = start + 1
	graph.add_point(start, a)
	graph.add_point(finish, b)
	var from_start: Array[Vector2] = []
	var from_finish: Array[Vector2] = []
	for i in start:
		var p = graph.get_point_position(i)
		from_start.append(Vector2(a.distance_squared_to(p), i))
		from_finish.append(Vector2(b.distance_squared_to(p), i))
	from_start.sort()
	from_finish.sort()
	for endpoint in [0, 1]:
		var connected = 0
		for candidate in (from_start if endpoint == 0 else from_finish):
			var i = int(candidate.y)
			var p = graph.get_point_position(i)
			if not (direct_route(a, p, clearance) if endpoint == 0 else direct_route(p, b, clearance)): continue
			graph.connect_points(start, i) if endpoint == 0 else graph.connect_points(i, finish)
			connected += 1
			if connected >= 8: break
	var path = graph.get_point_path(start, finish)
	if path.is_empty():
		for i in start:
			var p = graph.get_point_position(i)
			if not graph.are_points_connected(start, i) and direct_route(a, p, clearance): graph.connect_points(start, i)
			if not graph.are_points_connected(i, finish) and direct_route(p, b, clearance): graph.connect_points(i, finish)
		path = graph.get_point_path(start, finish)
		if path.is_empty() and not grids.has(key + ":complete"):
			for i in start:
				for j in range(i + 1, start):
					if not graph.are_points_connected(i, j) and direct_route(graph.get_point_position(i), graph.get_point_position(j), clearance): graph.connect_points(i, j)
			grids[key + ":complete"] = true
			path = graph.get_point_path(start, finish)
	graph.remove_point(start)
	graph.remove_point(finish)
	return smooth_route(a, path.slice(1), clearance) if not path.is_empty() else []

static func hill_profile(delta: Vector2, radii: Vector2) -> float:
	# A rounded cap with zero slope and curvature where it meets the plain.
	var q = delta / radii
	var shoulder = maxf(0.0, 1.0 - q.length_squared())
	return shoulder * shoulder * shoulder

func raw_height(p: Vector2) -> float:
	var height_squared = 0.0
	if campaign:
		for index in CAMPAIGN_HILLS.size():
			var hill: Vector4 = CAMPAIGN_HILLS[index]
			var profile = hill_profile(p / campaign_scale - Vector2(hill.x, hill.y), Vector2(hill.z, hill.w) * 1.16)
			var vertical_scale = sqrt(campaign_scale / 3.0) * 1.2 if campaign_scale >= 6 else minf(1.0, campaign_scale / 3.0)
			var height = profile * CAMPAIGN_HEIGHTS[index] * 1.1 * vertical_scale
			height_squared += height * height
	else:
		for hill in field.hills:
			var radii = Vector2(hill.rx, hill.ry)
			var profile = hill_profile(p - FieldData.pos(hill), radii * 1.22)
			# Small knolls should not be as tall as the broad objective ridge.
			var height = profile * float(hill.get("height", minf(62.0, minf(radii.x, radii.y) * 0.38)))
			height_squared += height * height
	# Blend overlapping shoulders without a hard max() crease between hills.
	var h = sqrt(height_squared)
	h += (sin(p.x / 83.0) * cos(p.y / 107.0) + 0.35 * sin((p.x + p.y) / 39.0)) * 1.6
	var bank = river_distance(p) / campaign_scale if campaign else absf(p.x - channel_x(p.y)) if water else 1000.0
	if not campaign and water:
		# Broad new ridges must ease into the floodplain without a steep bank
		# ramp under the regiment. Keep the shore envelope within marching grades.
		h = minf(h, maxf(0.0, bank - 40.0) * 0.32)
	return (h * smoothstep(36.0, 156.0, bank) - 5.0 * (1.0 - smoothstep(0.0, 42.0, bank))) * relief

func vertex_height(cell: Vector2i) -> float:
	ensure_surface()
	return heights[cell.y * (surface_cells.x + 1) + cell.x]

func vertex_normal(cell: Vector2i) -> Vector3:
	var left = Vector2i(maxi(0, cell.x - 1), cell.y)
	var right = Vector2i(mini(surface_cells.x, cell.x + 1), cell.y)
	var back = Vector2i(cell.x, maxi(0, cell.y - 1))
	var front = Vector2i(cell.x, mini(surface_cells.y, cell.y + 1))
	var spacing = render_bounds.size / Vector2(surface_cells)
	var dx = (vertex_height(right) - vertex_height(left)) / ((right.x - left.x) * spacing.x)
	var dz = (vertex_height(front) - vertex_height(back)) / ((front.y - back.y) * spacing.y)
	return Vector3(-dx, 1.0, -dz).normalized()

func ensure_surface() -> void:
	if not heights.is_empty(): return
	var key = JSON.stringify([campaign, campaign_scale, battle_offset, map_size, render_bounds, surface_cells, relief, water, river_vertical, river_path, [] if campaign else field.get("hills", [])])
	if surface_cache.has(key):
		heights = surface_cache[key].duplicate()
		return
	heights.resize((surface_cells.x + 1) * (surface_cells.y + 1))
	for y in surface_cells.y + 1:
		for x in surface_cells.x + 1:
			heights[y * (surface_cells.x + 1) + x] = raw_height(surface_point(Vector2i(x, y)))
	if surface_cache.size() >= 6: surface_cache.erase(surface_cache.keys()[0])
	surface_cache[key] = heights.duplicate()

func height_at(p: Vector2, bridge: bool = true) -> float:
	# Match the rendered triangle surface, not an independently sampled curve.
	if heights.is_empty(): ensure_surface()
	var sample = ((p - render_bounds.position) / render_bounds.size * Vector2(surface_cells)).clamp(Vector2.ZERO, Vector2(surface_cells))
	var gx = sample.x
	var gy = sample.y
	var x = mini(int(gx), surface_cells.x - 1)
	var y = mini(int(gy), surface_cells.y - 1)
	var fx = gx - x
	var fy = gy - y
	var stride = surface_cells.x + 1
	var i = y * stride + x
	var h00 = heights[i]
	var h10 = heights[i + 1]
	var h01 = heights[i + stride]
	var h11 = heights[i + stride + 1]
	var h = h00 + (h10 - h00) * fx + (h01 - h00) * fy if fx + fy <= 1.0 else h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fy)
	if bridge and water and (campaign or absf(p.x - (720.0 + battle_offset.x)) <= 113.0):
		if campaign:
			for crossing in crossings:
				var scale_value = 0.63 * campaign_scale
				var delta = (p - river_point(crossing)).abs()
				if river_vertical: delta = Vector2(delta.y, delta.x)
				var across = delta.y / scale_value
				if delta.x <= 28 * scale_value and across <= 78:
					h = 4.9 if across <= 49 else lerpf(4.9, h, (across - 49) / 29.0)
		else:
			for crossing in crossings:
				var across = absf(p.x - channel_x(crossing))
				if across <= 78 and absf(p.y - crossing) <= 28:
					h = 6.5 if across <= 49 else lerpf(6.5, h, (across - 49) / 29.0)
	return h
