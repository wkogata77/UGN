class_name FieldValeggio
extends RefCounted

# Presentation only: use the saved terrain's roads, houses and crossing positions.
static func enabled(terrain) -> bool:
	return not terrain.campaign and terrain.water

static func plots(terrain) -> Array:
	var result: Array = []
	var offset: Vector2 = terrain.battle_offset
	var parcels = [
		[Vector2(60, 290), Vector2(260, 305), Vector2(242, 445), Vector2(45, 465)],
		[Vector2(350, 280), Vector2(580, 290), Vector2(595, 415), Vector2(362, 453)],
		[Vector2(40, 500), Vector2(250, 483), Vector2(245, 529), Vector2(38, 548)],
		[Vector2(100, 610), Vector2(285, 587), Vector2(290, 680), Vector2(95, 703)],
		[Vector2(520, 650), Vector2(643, 640), Vector2(635, 858), Vector2(550, 865)],
		[Vector2(555, 60), Vector2(634, 75), Vector2(650, 270), Vector2(555, 280)],
		[Vector2(786, 55), Vector2(915, 65), Vector2(903, 275), Vector2(787, 268)],
		[Vector2(1055, 380), Vector2(1300, 348), Vector2(1320, 394), Vector2(1060, 432)],
		[Vector2(1170, 495), Vector2(1395, 455), Vector2(1400, 595), Vector2(1190, 624)],
		[Vector2(810, 635), Vector2(990, 650), Vector2(965, 800), Vector2(823, 808)],
		[Vector2(825, 824), Vector2(945, 835), Vector2(952, 925), Vector2(810, 915)]
	]
	# Outer farms frame the expanded battlefield rather than repeating the center.
	if offset != Vector2.ZERO:
		for rect in [Rect2(-510, -310, 230, 135), Rect2(-230, -310, 280, 155), Rect2(60, -90, 230, 115), Rect2(-540, 210, 210, 160), Rect2(-530, 700, 280, 180), Rect2(-210, 1060, 285, 125), Rect2(510, 1090, 115, 230), Rect2(840, 1095, 265, 170), Rect2(1490, 680, 300, 155), Rect2(1670, 170, 245, 165), Rect2(1260, -320, 230, 145)]:
			parcels.append([rect.position, Vector2(rect.end.x - 15, rect.position.y + 9), rect.end, Vector2(rect.position.x + 12, rect.end.y - 7)])
	for parcel in parcels:
		var polygon = PackedVector2Array()
		for p in parcel: polygon.append(p + offset)
		var rect = Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: rect = rect.expand(p)
		result.append({"polygon": polygon, "rect": rect, "crop": result.size() % 3})
	return result

static func lanes(terrain) -> Array:
	var result: Array = []
	for town in terrain.towns:
		var center = FieldData.pos(town)
		var nearest = center
		var distance = INF
		for road in terrain.roads:
			for i in range(1, road.size()):
				var q = Geometry2D.get_closest_point_to_segment(center, FieldData.pos(road[i - 1]), FieldData.pos(road[i]))
				if q.distance_to(center) < distance:
					distance = q.distance_to(center)
					nearest = q
		if distance > 220: continue
		var axis = (nearest - center).normalized()
		if axis == Vector2.ZERO: axis = Vector2.DOWN
		var cross_axis = axis.orthogonal()
		var start = center - axis * 65
		var end = nearest
		result.append({"a": start, "b": end, "width": 7.0})
		result.append({"a": center - cross_axis * 93, "b": center + cross_axis * 93, "width": 5.0})
		for building in terrain.buildings:
			if building.p.distance_to(center) > 130: continue
			var a = Geometry2D.get_closest_point_to_segment(building.p, start, end)
			var b = Geometry2D.get_closest_point_to_segment(building.p, center - cross_axis * 93, center + cross_axis * 93)
			result.append({"a": building.p, "b": a if a.distance_to(building.p) < b.distance_to(building.p) else b, "width": 3.5})
	return result

static func paint_patch(pixels: Image, map_size: Vector2, polygon: PackedVector2Array, channel: int, feather: float) -> void:
	var scale_value = Vector2(pixels.get_size()) / map_size
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	for p in polygon: bounds = bounds.expand(p)
	var first = Vector2i((bounds.position * scale_value).floor()).clamp(Vector2i.ZERO, pixels.get_size())
	var last = Vector2i((bounds.end * scale_value).ceil()).clamp(Vector2i.ZERO, pixels.get_size())
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var p = (Vector2(x, y) + Vector2.ONE * 0.5) / scale_value
			if not Geometry2D.is_point_in_polygon(p, polygon): continue
			var distance = INF
			for i in polygon.size(): distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, polygon[i], polygon[(i + 1) % polygon.size()])))
			var color = pixels.get_pixel(x, y)
			color[channel] = maxf(color[channel], smoothstep(0, feather, distance))
			pixels.set_pixel(x, y, color)

static func surface_map(terrain, parcels: Array, streets: Array) -> ImageTexture:
	var size_value = Vector2i((terrain.map_size / 3.0).ceil())
	var pixels = Image.create(size_value.x, size_value.y, false, Image.FORMAT_RGBA8)
	for parcel in parcels: paint_patch(pixels, terrain.map_size, parcel.polygon, parcel.crop, 6.0)
	for lane in streets:
		var side = (lane.b - lane.a).normalized().orthogonal() * (lane.width + 4.0)
		paint_patch(pixels, terrain.map_size, PackedVector2Array([lane.a - side, lane.b - side, lane.b + side, lane.a + side]), 3, 4.0)
	for building in terrain.buildings:
		var half_size: Vector2 = building.rect.size * 0.5 + Vector2(8, 7)
		var p: Vector2 = building.p
		paint_patch(pixels, terrain.map_size, PackedVector2Array([p - half_size, p + Vector2(half_size.x, -half_size.y), p + half_size, p + Vector2(-half_size.x, half_size.y)]), 3, 7.0)
	if terrain.field.get("authored", false):
		for garden in gardens(terrain): paint_patch(pixels, terrain.map_size, garden, 1, 2.0)
	return ImageTexture.create_from_image(pixels)

static func gardens(terrain) -> Array:
	var result: Array = []
	for building in terrain.buildings:
		if building.variant == 2: continue
		var center: Vector2 = building.p + Vector2(0, building.rect.size.y * 0.5 + 13)
		var rect = Rect2(center - Vector2(9, 7), Vector2(18, 14))
		if terrain.buildings.any(func(other): return other.rect.intersects(rect)): continue
		if terrain.near_road(center, 18) or not terrain.ground_passable(center, true): continue
		result.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	return result

static func farm_details(world) -> void:
	# Small stored timbers occupy existing house footprints; gardens remain passable.
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color("77715a")
	wood.roughness = 1.0
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	var buildings: Array = world.model.terrain.buildings.filter(func(b): return b.variant in [1, 3, 5])
	var stacks = world.make_batch(mesh, wood, buildings.size() * 3)
	stacks.name = "FarmTimberStores"
	for i in buildings.size():
		var building: Dictionary = buildings[i]
		for row in 3:
			var p: Vector2 = building.p + Vector2(building.rect.size.x * 0.35, building.rect.size.y * 0.43 - row * 0.8)
			var size_value = Vector3(5.5, 0.6, 0.7)
			stacks.multimesh.set_instance_transform(i * 3 + row, Transform3D(Basis.from_scale(size_value), Vector3(p.x, world.model.terrain.height_at(p) + 0.5 + row * 0.45, p.y)))
	stacks.multimesh.visible_instance_count = buildings.size() * 3
	world.scenery.add_child(stacks)

static func add_details(world, rng: RandomNumberGenerator) -> void:
	var terrain = world.model.terrain
	var stones: Array = []
	for y in range(20, int(terrain.map_size.y), 15):
		for side in [-1, 1]:
			var p = Vector2(terrain.channel_x(y) + side * rng.randf_range(34, 47), y + rng.randf_range(-6, 6))
			if terrain.on_bridge(p) or terrain.near_road(p, 20): continue
			if sin(y * 0.018) + sin(y * 0.051) * 0.5 > 0.25 and rng.randf() < 0.8:
				stones.append({"p": p, "size": Vector3(rng.randf_range(1.5, 4), rng.randf_range(0.7, 1.6), rng.randf_range(1.4, 3))})
			var shrub = p + Vector2(side * rng.randf_range(7, 16), 2)
			if terrain.passable(shrub, true) and rng.randf() < 0.65:
				world.scenery_trees.append({"p": shrub, "size": rng.randf_range(4.5, 9), "variant": 5, "mirror": rng.randf() > 0.5})
	# Low verge growth, not tall hedges that would imply unmodeled cover.
	for parcel in world.scenery_fields:
		var polygon: PackedVector2Array = parcel.polygon
		for i in polygon.size():
			var a = polygon[i]
			var b = polygon[(i + 1) % polygon.size()]
			for step in int(a.distance_to(b) / 19.0):
				var p = a.lerp(b, (step + 0.5) / maxf(1, int(a.distance_to(b) / 19.0)))
				if rng.randf() > 0.45 or terrain.near_road(p, 20) or not terrain.passable(p, true): continue
				if terrain.towns.any(func(t): return FieldData.pos(t).distance_to(p) < 125): continue
				if terrain.forests.any(func(f): return FieldData.ellipse(p, f) < 1.05): continue
				world.scenery_trees.append({"p": p, "size": rng.randf_range(3, 5), "variant": 5, "mirror": rng.randf() > 0.5})
	var mesh = SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.radius = 0.5
	mesh.height = 1.0
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("77776a")
	material.roughness = 1.0
	var rocks = world.make_batch(mesh, material, stones.size())
	rocks.name = "RiverStones"
	for i in stones.size():
		var p: Vector2 = stones[i].p
		var size_value: Vector3 = stones[i].size
		var basis_value = Basis(Vector3.UP, rng.randf() * TAU).scaled(size_value)
		rocks.multimesh.set_instance_transform(i, Transform3D(basis_value, Vector3(p.x, terrain.height_at(p, false) + size_value.y * 0.22, p.y)))
	rocks.multimesh.visible_instance_count = stones.size()
	world.scenery.add_child(rocks)

static func bridge(world, p: Vector2) -> void:
	var root = Node3D.new()
	root.name = "ValeggioStoneBridge"
	root.set_meta("valeggio_bridge", true)
	root.position = Vector3(p.x, 0, p.y)
	world.scenery.add_child(root)
	var stone = ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	stone.set_shader_parameter("stone_color", Vector3(0.43, 0.405, 0.35))
	var masonry = ShaderMaterial.new()
	masonry.shader = load("res://shaders/stone.gdshader")
	masonry.set_shader_parameter("stone_color", Vector3(0.29, 0.285, 0.245))
	# Three open arches beneath the existing 6.5-high traversable deck.
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arch_center in [-32.0, 0.0, 32.0]:
		for step in 16:
			var x0 = arch_center + lerpf(-13, 13, step / 16.0)
			var x1 = arch_center + lerpf(-13, 13, (step + 1) / 16.0)
			var y0 = -3.0 + sqrt(maxf(0, 1 - pow((x0 - arch_center) / 13, 2))) * 7.0
			var y1 = -3.0 + sqrt(maxf(0, 1 - pow((x1 - arch_center) / 13, 2))) * 7.0
			for z in [-28.0, 28.0]:
				for v in [Vector3(x0, y0, z), Vector3(x0, 6.5, z), Vector3(x1, y1, z), Vector3(x1, y1, z), Vector3(x0, 6.5, z), Vector3(x1, 6.5, z)]: tool.add_vertex(v)
			for v in [Vector3(x0, y0, -28), Vector3(x1, y1, -28), Vector3(x0, y0, 28), Vector3(x1, y1, -28), Vector3(x1, y1, 28), Vector3(x0, y0, 28)]: tool.add_vertex(v)
	tool.generate_normals()
	var arches = MeshInstance3D.new()
	arches.mesh = tool.commit()
	arches.material_override = masonry
	root.add_child(arches)
	for spec in [[Vector3(98, 1.3, 56), Vector3(0, 5.85, 0)], [Vector3(100, 3.5, 3), Vector3(0, 8.25, -29.5)], [Vector3(100, 3.5, 3), Vector3(0, 8.25, 29.5)], [Vector3(6, 13, 56), Vector3(-48, 0, 0)], [Vector3(6, 13, 56), Vector3(-16, 0, 0)], [Vector3(6, 13, 56), Vector3(16, 0, 0)], [Vector3(6, 13, 56), Vector3(48, 0, 0)]]:
		var block = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = spec[0]
		block.mesh = mesh
		block.position = spec[1]
		block.material_override = stone
		root.add_child(block)
	for side in [-1, 1]:
		var ramp: Array[Vector3] = []
		for step in 9:
			for edge in [-28.0, 28.0]:
				var point = p + Vector2(side * lerpf(49, 78, step / 8.0), edge)
				ramp.append(Vector3(point.x, world.model.terrain.height_at(point) + 0.06, point.y))
		world.scenery.add_child(world.ribbon(ramp, stone))
