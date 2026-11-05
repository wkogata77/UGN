class_name FieldLandscape
extends RefCounted

static func buildings(terrain) -> Array:
	var result: Array = []
	var expansive = terrain.campaign or terrain.map_size.x >= FieldBattlefield.SIZE.x
	var sites = [Vector2(-38, -36), Vector2(38, -36), Vector2(-38, 36), Vector2(38, 36), Vector2(-82, 0), Vector2(82, 0), Vector2(0, -75), Vector2(0, 75), Vector2(-76, -68), Vector2(76, 68), Vector2(76, -68), Vector2(-76, 68)]
	for y in range(-4 if expansive else -3, 5 if expansive else 4):
		for x in range(-4 if expansive else -3, 5 if expansive else 4):
			if abs(x) + abs(y) <= (6 if expansive else 4): sites.append(Vector2(x * 31 + 12, y * 31 + 10))
	for town_index in terrain.towns.size():
		var town: Dictionary = terrain.towns[town_index]
		var placed = 0
		var scale_value = 0.9 if terrain.campaign else 1.1
		var church_placed = false
		for index in sites.size():
			var p = FieldData.pos(town) + sites[(index + town_index * 2) % sites.size()] * scale_value
			var variant = (placed + town_index) % 6
			if terrain.field.get("authored", false) and variant == 2 and (church_placed or not town.get("major", false)): variant = 4 if placed % 2 == 0 else 3
			var size_value: float = [34, 27, 49, 32, 38, 25][variant] * scale_value
			if terrain.defenses.any(func(cover): return (FieldData.pos(cover) - Vector2.from_angle(cover.facing) * 18).distance_to(p) < cover.width * 0.65 + size_value * 0.5): continue
			if not terrain.ground_passable(p, true) or terrain.near_road(p, 10 + size_value * 0.25): continue
			if terrain.on_bridge(p): continue
			if result.any(func(b): return b.p.distance_to(p) < (b.size + size_value) * (0.48 if expansive else 0.6)): continue
			var footprint = Vector2(size_value * 0.64, size_value * 0.50)
			result.append({"id": "building-%d-%d" % [town_index, placed], "p": p, "size": size_value, "variant": variant, "rect": Rect2(p - footprint * 0.5, footprint), "height": size_value * 0.72})
			if variant == 2: church_placed = true
			placed += 1
			if placed >= ((22 if expansive else 15) if town.get("major", false) else (14 if expansive else 10)): break
	return result

static func segment_hit(a: Vector2, b: Vector2, rect: Rect2):
	if maxf(a.x, b.x) < rect.position.x or minf(a.x, b.x) > rect.end.x or maxf(a.y, b.y) < rect.position.y or minf(a.y, b.y) > rect.end.y: return null
	if rect.has_point(a): return a
	var corners = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var nearest = null
	for i in 4:
		var hit = Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4])
		if hit != null and (nearest == null or a.distance_squared_to(hit) < a.distance_squared_to(nearest)): nearest = hit
	return nearest

static func defenses(scenario: String) -> Array:
	var center = Vector2(535, 350) if scenario == "bridge" else Vector2(595, 350) if scenario == "village" else Vector2(555, 510)
	var positions = [{"id": "farm-wall", "x": center.x, "y": center.y, "facing": 0.0},
		{"id": "orchard-hedge", "x": 925.0 if scenario != "bridge" else 945.0, "y": 540.0 if scenario != "ridge" else 640.0, "facing": PI},
		{"id": "field-redan", "x": 445.0, "y": 680.0 if scenario != "ridge" else 270.0, "facing": 0.15}]
	for position in positions: position.merge(FieldCover.TYPES[position.id])
	return positions

static func cover_at(terrain, p: Vector2) -> Dictionary:
	for cover in terrain.defenses:
		var local = (p - FieldData.pos(cover)).rotated(PI / 2 - cover.facing)
		if Rect2(-cover.width * 0.5 - 8, -cover.depth, cover.width + 16, cover.depth + 16).has_point(local): return cover
	return {}
