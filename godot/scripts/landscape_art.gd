class_name FieldLandscapeArt
extends RefCounted

# Land use and static canopy shadows are rasterized once per map. The larger
# landscapes add texture coverage, not per-frame nodes or per-pixel GDScript.
static func parcels(terrain: FieldTerrain) -> Array:
	if not terrain.campaign and terrain.map_size.x <= FieldBattlefield.STANDARD_SIZE.x and terrain.water:
		return FieldValeggio.plots(terrain)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1796 if terrain.campaign else 1805
	var scale_value = 1.0
	var cell = Vector2(520, 370)
	var columns = ceili(terrain.map_size.x / cell.x)
	var rows = ceili(terrain.map_size.y / cell.y)
	var vertices: Dictionary = {}
	for y in rows + 1:
		for x in columns + 1:
			vertices[Vector2i(x, y)] = Vector2(x * cell.x, y * cell.y) + Vector2(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.21, 0.21)) * cell
	var result: Array = [] if terrain.campaign else central_farms(terrain)
	for y in rows:
		for x in columns:
			if rng.randf() < (0.55 if terrain.campaign else 0.64): continue
			var polygon = PackedVector2Array([vertices[Vector2i(x, y)], vertices[Vector2i(x + 1, y)], vertices[Vector2i(x + 1, y + 1)], vertices[Vector2i(x, y + 1)]])
			var center = Vector2.ZERO
			for p in polygon: center += p * 0.25
			if not terrain.campaign and Rect2(1340, 1000, 3000, 1900).has_point(center): continue
			# Neighboring parcels share their boundaries, separated by a narrow
			# uncultivated verge, instead of floating as isolated little patches.
			for i in polygon.size(): polygon[i] = polygon[i].move_toward(center, 6.0 * maxf(1, scale_value))
			if terrain.forests.any(func(f): return FieldData.ellipse(center, f) < 0.65): continue
			var rect = Rect2(polygon[0], Vector2.ZERO)
			for p in polygon: rect = rect.expand(p)
			result.append({"polygon": polygon, "rect": rect, "crop": rng.randi_range(0, 2)})
	return result

static func central_farms(terrain: FieldTerrain) -> Array:
	var result: Array = []
	var crops = [2, 0, 1, 0, 1, 0, 2, 1]
	var fields = [
		[Vector2(1450, 1060), Vector2(2390, 1150), Vector2(2400, 1510), Vector2(1450, 1460)],
		[Vector2(1500, 1530), Vector2(2410, 1560), Vector2(2420, 1840), Vector2(1470, 1850)],
		[Vector2(1460, 2070), Vector2(2430, 2100), Vector2(2490, 2450), Vector2(1400, 2430)],
		[Vector2(1730, 2520), Vector2(2530, 2560), Vector2(2460, 2810), Vector2(1720, 2790)],
		[Vector2(3190, 1080), Vector2(4140, 1120), Vector2(4130, 1480), Vector2(3200, 1460)],
		[Vector2(3360, 1560), Vector2(4190, 1540), Vector2(4130, 1850), Vector2(3310, 1860)],
		[Vector2(3200, 2100), Vector2(4150, 2050), Vector2(4190, 2440), Vector2(3210, 2470)],
		[Vector2(3280, 2560), Vector2(4150, 2540), Vector2(4120, 2810), Vector2(3260, 2850)]
	]
	for i in fields.size():
		var polygon = PackedVector2Array(fields[i])
		var rect = Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: rect = rect.expand(p)
		result.append({"polygon": polygon, "rect": rect, "crop": crops[i]})
	return result

static func district_trees(world, rng: RandomNumberGenerator) -> void:
	var terrain: FieldTerrain = world.model.terrain
	for town in terrain.towns:
		for group in (7 if terrain.campaign else 3):
			var angle = rng.randf() * TAU
			var center = FieldData.pos(town) + Vector2.from_angle(angle) * rng.randf_range(150, 330)
			for i in rng.randi_range(6, 13):
				var p = center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 55
				var size_value = rng.randf_range(18, 39)
				if not terrain.order_bounds(15).has_point(p) or not terrain.passable(p, true) or terrain.near_road(p, 10 + size_value * 0.15): continue
				if terrain.buildings.any(func(b): return b.rect.grow(12).has_point(p)): continue
				world.scenery_trees.append({"p": p, "size": size_value, "variant": rng.randi_range(0, 5), "mirror": rng.randf() > 0.5})

static func begin_svg(size_value: Vector2, resolution: int) -> String:
	var height = roundi(resolution * size_value.y / size_value.x)
	return '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %f %f">' % [resolution, height, size_value.x, size_value.y]

static func polygon_svg(polygon: PackedVector2Array, color: String) -> String:
	var points = PackedStringArray()
	for p in polygon: points.append("%.2f,%.2f" % [p.x, p.y])
	return '<polygon points="%s" fill="%s"/>' % [" ".join(points), color]

static func raster(svg: String) -> ImageTexture:
	var pixels = Image.new()
	var error = pixels.load_svg_from_string(svg + "</svg>")
	assert(error == OK, "Landscape mask must rasterize")
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)

static func land_map(terrain: FieldTerrain, plots: Array) -> ImageTexture:
	var svg = begin_svg(terrain.map_size, 1536)
	svg += '<rect width="100%" height="100%" fill="black"/>'
	for plot in plots: svg += polygon_svg(plot.polygon, ["#ff0000", "#00ff00", "#0000ff"][plot.crop])
	return raster(svg)

static func settlement_map(terrain: FieldTerrain, streets: Array) -> ImageTexture:
	var svg = begin_svg(terrain.map_size, 2048)
	svg += '<rect width="100%" height="100%" fill="black"/>'
	for building in terrain.buildings:
		svg += '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="white"/>' % [building.p.x, building.p.y, building.size * 0.76, building.size * 0.6]
	for lane in streets:
		svg += '<path d="M %.2f %.2f L %.2f %.2f" stroke="white" stroke-width="%.2f" stroke-linecap="round"/>' % [lane.a.x, lane.a.y, lane.b.x, lane.b.y, lane.width * 2]
	return raster(svg)

static func shadow_map(terrain: FieldTerrain, trees: Array) -> ImageTexture:
	var fragments = PackedStringArray([begin_svg(terrain.map_size, 2048)])
	fragments.append('<rect width="100%" height="100%" fill="white"/>')
	for tree in trees:
		if tree.size < 9: continue
		# Contact and cast shade share the terrain material; no redundant meshes.
		fragments.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="#6c7865" opacity="0.32"/>' % [tree.p.x, tree.p.y, tree.size * 0.24, tree.size * 0.14])
		var length: float = tree.size * 0.83
		var p: Vector2 = tree.p + Vector2(0.72, 0.60) * length * 0.66
		var width: float = tree.size * (0.23 if tree.variant == 1 else 0.42)
		fragments.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" transform="rotate(39 %.2f %.2f)" fill="#263025" opacity="0.22"/>' % [p.x, p.y, length, width, p.x, p.y])
		p += Vector2(width * 0.12, -width * 0.10)
		fragments.append('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" transform="rotate(39 %.2f %.2f)" fill="#263025" opacity="0.13"/>' % [p.x, p.y, length * 0.78, width * 0.75, p.x, p.y])
	for building in terrain.buildings:
		var p: Vector2 = building.p + Vector2(0.45, 0.4) * building.size
		var size_value: float = building.size
		fragments.append(polygon_svg(PackedVector2Array([p + Vector2(-size_value * 0.35, -size_value * 0.24), p + Vector2(size_value * 0.3, -size_value * 0.24), p + Vector2(size_value * 0.55, size_value * 0.4), p + Vector2(-size_value * 0.1, size_value * 0.4)]), "#a0a59a"))
	return raster("".join(fragments))
