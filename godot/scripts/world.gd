class_name FieldWorld
extends Node3D

signal inspect_requested(entity: Dictionary)
signal order_failed(message: String)
signal order_queued(message: String)

const CAMERA_PITCH = PI * 35.0 / 180.0

var model: FieldModel
var camera: Camera3D
var camera_pitch = CAMERA_PITCH
var view_height_factor = 1.0
var scenery_materials: Array[ShaderMaterial] = []
var scenery: Node3D
var ground_mesh: MeshInstance3D
var ground_material: ShaderMaterial
var fog_texture: ImageTexture
var fog_clock = -100.0
var water_material: ShaderMaterial
var overlay: Control
var center = Vector2(720, 480)
var zoom = 1.0
var show_ranges = true
var show_fog = true
var show_ai = false
var touch_orders = false
var input_blocked = false
var batches: Array[MultiMeshInstance3D] = []
var seen_mode = ""
var seen_scenario = ""
var entities: Array = []
var labels: Array = []
var font: Font
var serif: Font
var draw_clock = 0.0
var last_time = -1.0
var sprite_count = 0
var render_dirty = true
var right_start: Variant = null
var right_screen = Vector2.ZERO
var pointer = Vector2.ZERO
var left_start: Variant = null
var panning = false
var drag_panned = false
var touches: Dictionary = {}
var touch_origin = Vector2.ZERO
var touch_dragged = false
var cursor_attack: Texture2D
var cursor_move: Texture2D
var cover_icon: Texture2D
var cover_regions: Dictionary = {}
var cover_tooltip_rect = Rect2()
var ui_top = 64.0
var ui_bottom = 124.0
var viewport_size = Vector2.ZERO
var shadow_batch: MultiMeshInstance3D
var landscape_signature = ""
var process_micros = 0
var draw_micros = 0
var previous_positions: Dictionary = {}
var previous_animation_time = -1.0
var support_cache: Dictionary = {}
var interpolation = 1.0
var label_obstacles: Array[Rect2] = []
var town_label_regions: Array[Rect2] = []
var sunlight: DirectionalLight3D
var landscape_shadows: ImageTexture
var scenery_trees: Array = []
var scenery_buildings: Array = []
var scenery_fields: Array = []
var village_streets: Array = []
var smoke_batch: MultiMeshInstance3D
var smoke_count = 0
var muzzle_flashes: Array = []
var projection_version = 0
var gpu_interpolation = true
var last_figure_revision = -1
var render_fraction = 1.0
var projection_scale = 1.0
var projection_right = Vector3.RIGHT
var projection_up = Vector3.UP
var selection_visuals: Dictionary = {}
var regiment_cache: Dictionary = {}
var populating = false
var manual_buffer_change = false
var profile_sections = {"pose": 0, "footing": 0, "transform": 0, "selection": 0, "upload": 0}
var detailed_profile = false
var smoke_emissions: Dictionary = {}
var campaign_gaits: Dictionary = {}
var campaign_preview: Array = []
var selection_regions: Dictionary = {}
var placing_entity = ""
var body_mesh: MeshInstance3D
var body_material: ShaderMaterial
var body_count = -1
var body_geometry: Array[PackedVector3Array] = []

class FigureVisual:
	extends RefCounted
	var p = Vector2.INF
	var size = -1.0
	var height = 0.0
	var tilt = 0.0
	var light = 1.0
	var dx = 0.0
	var dz = 0.0
	var shadow: Transform3D
	var drawnPoint = Vector2.INF
	var drawnWidth = -1.0
	var drawnTransform: Transform3D
	var drawnShadow: Transform3D
	var inverse: Basis
	var shadowInverse: Basis
	var drawnColor = Color(-INF, -INF, -INF, -INF)
	var drawnCustom = Color(-INF, -INF, -INF, -INF)
	var shadowColor = Color(-INF, -INF, -INF, -INF)
	var screenRegion: Rect2
	var screenDelta = Vector2.ZERO
	var drawnDelta = Vector3.ZERO
	var projectionVersion = -1
	var shadowIndex = -1
	var liveMelee = false
	var facing = INF
	var moving = INF
	var meleeRank = -1
	var anchor = 0.42

func setup(game: FieldModel) -> void:
	model = game
	font = load("res://assets/fonts/Inter.woff2")
	serif = load("res://assets/fonts/Cormorant.woff2")
	cursor_attack = load("res://assets/icons/Swords.svg")
	cursor_move = load("res://assets/icons/Move.svg")
	cover_icon = load("res://assets/icons/Shield.svg")
	Input.set_custom_mouse_cursor(cursor_attack, Input.CURSOR_CROSS, Vector2(12, 12))
	Input.set_custom_mouse_cursor(cursor_move, Input.CURSOR_MOVE, Vector2(12, 12))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 6000.0
	add_child(camera)
	camera.current = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("82977c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bacdd5")
	environment.environment.ambient_light_energy = 0.32
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun = DirectionalLight3D.new()
	sunlight = sun
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-38, -42, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 2600.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.8
	sun.shadow_opacity = 0.55
	add_child(sun)
	make_troops()
	var layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.draw.connect(draw_overlay)
	model.changed.connect(invalidate)
	sync_map()
	home()

func invalidate() -> void:
	render_dirty = true

func sync_map() -> void:
	var key = model.state.mode + ":" + (str(model.state.battle.scenario) if model.state.battle != null else model.state.theater) + ":" + str(model.terrain.relief) + ":" + str(model.terrain.map_size)
	if key == landscape_signature:
		return
	landscape_signature = key
	var load_profile = "--profile-loading" in OS.get_cmdline_user_args()
	var load_started = Time.get_ticks_usec()
	support_cache.clear()
	regiment_cache.clear()
	smoke_emissions.clear()
	body_count = -1
	if is_instance_valid(scenery):
		remove_child(scenery)
		scenery.queue_free()
	scenery = Node3D.new()
	add_child(scenery)
	village_streets = FieldValeggio.lanes(model.terrain)
	build_ground()
	if load_profile: print("MAP GROUND %.2fs" % ((Time.get_ticks_usec() - load_started) / 1000000.0))
	build_scenery()
	if load_profile: print("MAP SCENERY %.2fs" % ((Time.get_ticks_usec() - load_started) / 1000000.0))
	build_defenses()
	prewarm_routes()
	if load_profile: print("MAP ROUTES %.2fs" % ((Time.get_ticks_usec() - load_started) / 1000000.0))
	for batch in batches + [shadow_batch, smoke_batch]:
		batch.multimesh.custom_aabb = map_aabb()
	if seen_mode != model.state.mode:
		campaign_gaits.clear()
		campaign_preview.clear()
		home()
	seen_mode = model.state.mode
	last_time = -1
	render_dirty = true

func prewarm_routes() -> void:
	if model.state.battle == null or model.terrain.buildings.is_empty(): return
	var units: Array = model.state.battle.units.filter(func(u): return u.arrival <= model.state.battle.time and u.men > 0 and model.terrain.passable(FieldData.pos(u), true, 2))
	var friendly = units.filter(func(u): return u.side == "player")
	var opposing = units.filter(func(u): return u.side == "enemy")
	if friendly.is_empty() or opposing.is_empty(): return
	# Prepare immutable visibility edges while the map loads, rather than
	# stalling the first march/AI order through a larger village district.
	for clearance in [1.0, 2.0]:
		model.terrain.building_route(FieldData.pos(friendly[0]), FieldData.pos(opposing[0]), clearance)

func terrain_mesh() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uv = PackedVector2Array()
	var indices = PackedInt32Array()
	var cells = model.terrain.surface_cells
	var stride = cells.x + 1
	for y in cells.y + 1:
		for x in cells.x + 1:
			var p = model.terrain.surface_point(Vector2i(x, y))
			vertices.append(Vector3(p.x, model.terrain.vertex_height(Vector2i(x, y)), p.y))
			normals.append(model.terrain.vertex_normal(Vector2i(x, y)))
			uv.append(Vector2(x, y) / Vector2(cells))
			if x < cells.x and y < cells.y:
				var i = y * stride + x
				indices.append_array(PackedInt32Array([i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func build_ground() -> void:
	ground_mesh = MeshInstance3D.new()
	ground_mesh.mesh = terrain_mesh()
	var material = ShaderMaterial.new()
	ground_material = material
	material.shader = load("res://shaders/ground.gdshader")
	material.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
	material.set_shader_parameter("valeggio", FieldValeggio.enabled(model.terrain))
	scenery_fields = FieldLandscapeArt.parcels(model.terrain)
	material.set_shader_parameter("landscape_style", true)
	material.set_shader_parameter("cultivated_map", FieldLandscapeArt.land_map(model.terrain, scenery_fields))
	material.set_shader_parameter("settlement_map", FieldLandscapeArt.settlement_map(model.terrain, village_streets))
	material.set_shader_parameter("meadow_texture", FieldArt.texture("valeggio-meadow-v1"))
	material.set_shader_parameter("land_materials", FieldArt.texture("terrain-materials-v3"))
	material.set_shader_parameter("woodland_map", woodland_map())
	material.set_shader_parameter("landscape_origin", model.terrain.render_bounds.position)
	material.set_shader_parameter("landscape_size", model.terrain.render_bounds.size)
	material.set_shader_parameter("campaign_scale", model.terrain.campaign_scale)
	material.set_shader_parameter("map_size", model.terrain.map_size)
	material.set_shader_parameter("battle_offset", model.terrain.battle_offset)
	material.set_shader_parameter("river_vertical", model.terrain.river_vertical)
	if model.terrain.river_vertical:
		var points = PackedVector2Array()
		for point in model.terrain.river_path: points.append(Vector2(point[0], point[1]))
		material.set_shader_parameter("river_points", points)
	fog_texture = null
	fog_clock = -100
	material.set_shader_parameter("campaign", model.terrain.campaign)
	material.set_shader_parameter("river", model.terrain.water)
	ground_mesh.material_override = material
	scenery.add_child(ground_mesh)
	if model.terrain.water:
		var vertices: Array[Vector3] = []
		var horizontal = model.terrain.campaign and not model.terrain.river_vertical
		var river_length = model.terrain.render_bounds.size.x if horizontal else model.terrain.render_bounds.size.y
		for i in ceili(river_length / 10.0) + 1:
			var n = -1400.0 + minf(i * 10.0, river_length)
			var p = model.terrain.river_point(n) if model.terrain.campaign else Vector2(model.terrain.channel_x(n), n)
			var bank_detail = sin(n * 0.09) * 0.7 + sin(n * 0.23) * 0.3
			var width = (16 * model.terrain.campaign_scale if model.terrain.campaign else 29) + bank_detail
			var side = Vector2(0, width) if horizontal else Vector2(width, 0)
			vertices.append(Vector3(p.x - side.x, -0.4, p.y - side.y))
			vertices.append(Vector3(p.x + side.x, -0.4, p.y + side.y))
		water_material = ShaderMaterial.new()
		water_material.shader = load("res://shaders/water.gdshader")
		water_material.set_shader_parameter("campaign", model.terrain.campaign)
		water_material.set_shader_parameter("valeggio", FieldValeggio.enabled(model.terrain))
		if FieldValeggio.enabled(model.terrain): water_material.set_shader_parameter("surface_texture", FieldArt.texture("valeggio-meadow-v1"))
		scenery.add_child(ribbon(vertices, water_material))
		for bank in [-1, 1]:
			var shore: Array[Vector3] = []
			for i in ceili(river_length / 10.0) + 1:
				var n = -1400.0 + minf(i * 10.0, river_length)
				var p = model.terrain.river_point(n) if model.terrain.campaign else Vector2(model.terrain.channel_x(n), n)
				for edge in [0, 1]:
					var width = (16.0 + edge * 15.0) * model.terrain.campaign_scale if model.terrain.campaign else 29.0 + edge * 19.0
					width += sin(n * 0.09) * 0.7 + sin(n * 0.23) * 0.3
					var q = p + (Vector2(0, width * bank) if horizontal else Vector2(width * bank, 0))
					shore.append(Vector3(q.x, maxf(-0.32, model.terrain.height_at(q, false) + 0.12), q.y))
			var material_shore = ShaderMaterial.new()
			material_shore.shader = load("res://shaders/shore.gdshader")
			material_shore.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
			material_shore.set_shader_parameter("valeggio", FieldValeggio.enabled(model.terrain))
			if FieldValeggio.enabled(model.terrain): material_shore.set_shader_parameter("ground_texture", FieldArt.texture("valeggio-meadow-v1"))
			scenery.add_child(ribbon(shore, material_shore))
		if model.terrain.campaign:
			for x in model.terrain.crossings:
				bridge(model.terrain.river_point(x), true)
		else:
			for y in model.terrain.crossings:
				bridge(Vector2(model.terrain.channel_x(y), y), false)
	for road in model.terrain.roads:
		var points: Array[Vector3] = []
		for i in range(1, road.size()):
			var a = FieldData.pos(road[i - 1])
			var b = FieldData.pos(road[i])
			var side = (b - a).normalized().orthogonal() * (3.0 if model.terrain.campaign else 12.0 if FieldValeggio.enabled(model.terrain) else 5.0)
			var steps = maxi(1, ceili(a.distance_to(b) / 8.0))
			for j in steps + 1:
				var p = a.lerp(b, float(j) / steps)
				for sign_value in [-1, 1]:
					var verge = 1.0 + (sin(p.x * 0.13 + p.y * 0.19) * 0.08 + sin(p.x * 0.43 - p.y * 0.24) * 0.03) if FieldValeggio.enabled(model.terrain) else 1.0
					var q = p + side * sign_value * verge
					points.append(Vector3(q.x, road_height(q), q.y))
		var road_material = ShaderMaterial.new()
		road_material.shader = load("res://shaders/road.gdshader")
		road_material.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
		road_material.set_shader_parameter("valeggio", FieldValeggio.enabled(model.terrain))
		if FieldValeggio.enabled(model.terrain): road_material.set_shader_parameter("ground_texture", FieldArt.texture("valeggio-meadow-v1"))
		scenery.add_child(ribbon(points, road_material))

func woodland_map() -> ImageTexture:
	var pixels = Image.create(128, 112, false, Image.FORMAT_R8)
	for y in 112:
		for x in 128:
			var p = model.terrain.render_bounds.position + Vector2((x + 0.5) / 128, (y + 0.5) / 112) * model.terrain.render_bounds.size
			var coverage = 0.0
			for forest in model.terrain.forests:
				coverage = maxf(coverage, 1.0 - smoothstep(0.65, 1.15, FieldData.ellipse(p, forest)))
			pixels.set_pixel(x, y, Color(coverage, 0, 0))
	return ImageTexture.create_from_image(pixels)

func road_clearance(p: Vector2) -> float:
	return model.terrain.road_distance(p, 64)

func road_height(p: Vector2) -> float:
	return model.terrain.height_at(p) + 1.35

func ribbon(points: Array[Vector3], material: Material) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, points.size() - 2, 2):
		for triangle in [[i, i + 1, i + 2], [i + 1, i + 3, i + 2]]:
			# Rivers run along different axes on the two maps; both must face upward.
			if (points[triangle[1]] - points[triangle[0]]).cross(points[triangle[2]] - points[triangle[0]]).y > 0:
				triangle.reverse()
			for index in triangle:
				tool.set_uv(Vector2(float(index) / points.size(), float(index % 2)))
				tool.set_normal(Vector3.UP)
				tool.add_vertex(points[index])
	tool.generate_tangents()
	var instance = MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func bridge(p: Vector2, campaign: bool) -> void:
	if FieldValeggio.enabled(model.terrain):
		FieldValeggio.bridge(self, p)
		return
	var root = Node3D.new()
	root.position = Vector3(p.x, 0, p.y)
	if campaign:
		root.rotation.y = 0.0 if model.terrain.river_vertical else PI / 2
		root.scale = Vector3(0.63 * model.terrain.campaign_scale, 0.75, 0.63 * model.terrain.campaign_scale)
	scenery.add_child(root)
	var stone = ShaderMaterial.new()
	stone.shader = load("res://shaders/stone.gdshader")
	for spec in [[Vector3(98, 7, 56), Vector3(0, 3, 0)], [Vector3(102, 6, 4), Vector3(0, 9, -29)], [Vector3(102, 6, 4), Vector3(0, 9, 29)], [Vector3(12, 15, 56), Vector3(-36, -5, 0)], [Vector3(12, 15, 56), Vector3(36, -5, 0)]]:
		var block = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = spec[0]
		block.mesh = mesh
		block.position = spec[1]
		block.material_override = stone
		root.add_child(block)
	# The road samples this deck and its approaches; no overlapping second road plane.
	for side in [-1, 1]:
		var ramp: Array[Vector3] = []
		for step in 9:
			for edge in [-28.0, 28.0]:
				var point = root.transform * Vector3(side * lerpf(49, 78, step / 8.0), 0, edge)
				point.y = model.terrain.height_at(Vector2(point.x, point.z)) + 0.025
				ramp.append(point)
		scenery.add_child(ribbon(ramp, stone))

func map_aabb() -> AABB:
	var bounds = model.terrain.render_bounds
	return AABB(Vector3(bounds.position.x, -100, bounds.position.y), Vector3(bounds.size.x, 1000, bounds.size.y))

func make_batch(mesh: Mesh, material: Material, count: int, custom: bool = false) -> MultiMeshInstance3D:
	var instance = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.use_colors = custom
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	mm.custom_aabb = map_aabb()
	instance.multimesh = mm
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func build_scenery() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 89 if model.terrain.campaign else 371
	scenery_trees.clear()
	scenery_buildings.clear()
	scenery_materials.clear()
	for forest in model.terrain.forests:
		for i in roundi(forest.rx * forest.ry / 330.0):
			var angle = rng.randf() * TAU
			var radius = sqrt(rng.randf())
			var p = Vector2(forest.x + cos(angle) * radius * forest.rx, forest.y + sin(angle) * radius * forest.ry)
			var size_value = rng.randf_range(33.0, 58.0)
			if forest.get("orchard", false):
				var columns = maxi(2, int(forest.rx / 18))
				p = FieldData.pos(forest) + Vector2((i % columns - (columns - 1) * 0.5) * 30, (floorf(float(i) / columns) - 1.5) * 30) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
				radius = FieldData.ellipse(p, forest)
				size_value = rng.randf_range(21, 27)
			if not forest.get("orchard", false):
				# Irregular canopy margins, with smaller trees at the edge of actual cover.
				var edge = 0.91 + sin(angle * 5.0 + forest.x) * 0.06 + sin(angle * 9.0) * 0.03
				if radius > edge: continue
				size_value *= lerpf(1.04, 0.58, smoothstep(0.55, 0.96, radius))
			if not model.terrain.passable(p, true) or road_clearance(p) < 10 + size_value * 0.15:
				continue
			if model.terrain.height_at(p) - model.terrain.height_at(p, false) > 1: continue
			if model.terrain.towns.any(func(t): return FieldData.pos(t).distance_to(p) < (95 if t.get("major", false) else 65)):
				continue
			scenery_trees.append({"p": p, "size": size_value, "variant": rng.randi_range(0, 5), "mirror": rng.randf() > 0.5})
	# Sparse edge growth and orchard trees connect woods and farms to the open landscape.
	for i in (1100 if model.terrain.campaign_scale > 1 else 150):
		var p = Vector2(rng.randf() * model.terrain.map_size.x, rng.randf() * model.terrain.map_size.y)
		var size_value = rng.randf_range(12, 27)
		if not model.terrain.passable(p, true) or road_clearance(p) < 10 + size_value * 0.15: continue
		if model.terrain.height_at(p) - model.terrain.height_at(p, false) > 1: continue
		if model.terrain.towns.any(func(t): return FieldData.pos(t).distance_to(p) < 62): continue
		if scenery_fields.any(func(plot): return plot.rect.grow(-9).has_point(p)): continue
		scenery_trees.append({"p": p, "size": size_value, "variant": 4 if i % 3 == 0 else 5, "mirror": rng.randf() > 0.5})
	if FieldValeggio.enabled(model.terrain):
		FieldValeggio.add_details(self, rng)
	FieldLandscapeArt.district_trees(self, rng)
	for variant in 6:
		var texture = FieldArt.scenery_texture("woodland-v4", variant)
		var material = scenery_material(texture, Color("cad1bc"))
		var quad = QuadMesh.new()
		quad.size = Vector2.ONE
		var points = scenery_trees.filter(func(p): return p.variant == variant)
		var trees = make_batch(quad, material, points.size(), true)
		trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		scenery.add_child(trees)
		for i in points.size():
			var p: Vector2 = points[i].p
			var size_value: float = points[i].size
			var width = size_value * texture.get_width() / texture.get_height()
			var basis_value = Basis(Vector3.RIGHT, -CAMERA_PITCH) * Basis.from_scale(Vector3(-width if points[i].mirror else width, size_value, 1))
			trees.multimesh.set_instance_transform(i, scenery_transform(p, basis_value))
			var light = scenery_light(p)
			trees.multimesh.set_instance_color(i, Color(light, light, light))
		trees.multimesh.visible_instance_count = points.size()
	for variant in 6:
		var texture = FieldArt.scenery_texture("architecture-v2", variant)
		var material = scenery_material(texture, Color.WHITE)
		var buildings: Array = model.terrain.buildings.filter(func(b): return b.variant == variant)
		var batch = make_batch(QuadMesh.new(), material, buildings.size(), true)
		batch.name = "VillageBuildings" + str(variant)
		scenery.add_child(batch)
		for i in buildings.size():
			var building: Dictionary = buildings[i]
			var p: Vector2 = building.p
			var size_value: float = building.size
			var width = size_value * texture.get_width() / texture.get_height()
			var basis_value = Basis(Vector3.RIGHT, -CAMERA_PITCH) * Basis.from_scale(Vector3(width, size_value, 1))
			batch.multimesh.set_instance_transform(i, scenery_transform(p, basis_value))
			var light = scenery_light(p)
			batch.multimesh.set_instance_color(i, Color(light * 0.96, light * 0.975, light * 0.94))
			scenery_buildings.append(building)
		batch.multimesh.visible_instance_count = buildings.size()
	landscape_shadows = FieldLandscapeArt.shadow_map(model.terrain, scenery_trees)
	ground_material.set_shader_parameter("landscape_shadows", landscape_shadows)
	for batch in batches:
		batch.material_override.set_shader_parameter("landscape_shadows", landscape_shadows)
		batch.material_override.set_shader_parameter("map_size", model.terrain.map_size)
	if model.terrain.field.get("authored", false): FieldValeggio.farm_details(self)

func scenery_material(texture: Texture2D, tint: Color) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/scenery.gdshader")
	material.set_shader_parameter("painting", texture)
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("camera_right", camera.global_basis.x)
	material.set_shader_parameter("camera_up", camera.global_basis.y)
	scenery_materials.append(material)
	return material

func scenery_light(p: Vector2) -> float:
	var dx = (model.terrain.height_at(p + Vector2(3, 0)) - model.terrain.height_at(p - Vector2(3, 0))) / 6.0
	var dz = (model.terrain.height_at(p + Vector2(0, 3)) - model.terrain.height_at(p - Vector2(0, 3))) / 6.0
	return clampf(0.88 + Vector3(-dx, 1, -dz).normalized().dot(Vector3(-0.45, 0.8, -0.35).normalized()) * 0.14, 0.72, 1.02)

func build_defenses() -> void:
	for cover in model.terrain.defenses:
		FieldFortificationArt.build(self, cover)

func village_lane(p: Vector2) -> void:
	var nearest = p
	var distance = INF
	for road in model.terrain.roads:
		for i in range(1, road.size()):
			var q = Geometry2D.get_closest_point_to_segment(p, FieldData.pos(road[i - 1]), FieldData.pos(road[i]))
			if q.distance_to(p) < distance:
				distance = q.distance_to(p)
				nearest = q
	if distance > 130 or distance < 8: return
	var points: Array[Vector3] = []
	var side = (nearest - p).normalized().orthogonal() * 2.6
	var steps = maxi(1, ceili(distance / 8.0))
	for i in steps + 1:
		var q = p.lerp(nearest, float(i) / steps)
		for sign_value in [-1, 1]:
			var point = q + side * sign_value
			points.append(Vector3(point.x, road_height(point), point.y))
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/road.gdshader")
	material.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
	scenery.add_child(ribbon(points, material))

func scenery_support(p: Vector2, basis_value: Basis) -> float:
	var support = -INF
	for x in [-0.5, 0.0, 0.5]:
		for y in [-0.5, 0.0, 0.5]:
			var offset = basis_value * Vector3(x, y, 0)
			support = maxf(support, model.terrain.height_at(p + Vector2(offset.x, offset.z)) - offset.y + 0.5)
	return support

func scenery_transform(p: Vector2, basis_value: Basis) -> Transform3D:
	# Anchor the bottom of the painting at its actual map root. Centering the
	# billboard at p displaces its visible feet toward the camera and off its shadow.
	var origin = Vector3(p.x, 0, p.y) + basis_value.y * 0.5
	# Transparent lower corners are not foundations. Lifting the whole painting
	# over those corners makes trees and houses float on even modest hills.
	origin.y = model.terrain.height_at(p) + 0.45 + basis_value.y.y * 0.5
	return Transform3D(basis_value, origin)

func make_troops() -> void:
	for type in 8:
		var quad = PlaneMesh.new()
		quad.orientation = PlaneMesh.FACE_Z
		quad.size = Vector2.ONE
		quad.subdivide_width = 6
		quad.subdivide_depth = 8
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/troops.gdshader")
		material.set_shader_parameter("atlas", FieldArt.texture("depth-units-keyed", true))
		material.set_shader_parameter("actions", FieldArt.texture("depth-unit-actions-keyed", true))
		material.set_shader_parameter("directions", FieldArt.texture("depth-unit-directions-v2", true))
		if type != 6:
			material.set_shader_parameter("walking", FieldArt.gun_cycle(type) if type in [4, 5] else FieldArt.motion_texture(type))
		if type < 4:
			material.set_shader_parameter("melee", FieldArt.melee_texture(type))
			material.set_shader_parameter("loading", FieldArt.reload_texture(type))
			material.set_shader_parameter("cycle", FieldArt.battle_cycle(type))
		material.set_shader_parameter("troop_type", type)
		material.set_shader_parameter("smooth_motion", gpu_interpolation)
		var instance = make_batch(quad, material, 1600, true)
		batches.append(instance)
		add_child(instance)
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/shadow.gdshader")
	material.set_shader_parameter("smooth_motion", gpu_interpolation)
	var quad = PlaneMesh.new()
	quad.size = Vector2.ONE
	shadow_batch = make_batch(quad, material, 2200, true)
	add_child(shadow_batch)
	var smoke_material = ShaderMaterial.new()
	smoke_material.shader = load("res://shaders/smoke.gdshader")
	smoke_material.set_shader_parameter("atlas", FieldArt.texture("smoke-v2"))
	var smoke_quad = QuadMesh.new()
	smoke_quad.size = Vector2.ONE
	smoke_batch = make_batch(smoke_quad, smoke_material, 256, true)
	add_child(smoke_batch)

func gather_entities() -> Array:
	if model.state.mode == "campaign":
		var operational = FieldOperations.enabled(model.state)
		var result: Array = []
		for a in model.state.armies if operational else [model.state.army]:
			if a.get("defeated", false): continue
			var army: Dictionary = a.duplicate()
			army.merge({"id": a.get("id", "army"), "kind": "army", "side": "player", "men": FieldData.men(FieldOperations.roster(model.state, a) if operational else model.state.units)}, true)
			result.append(army)
		for e in model.state.enemies:
			if e.defeated:
				continue
			var enemy: Dictionary = e.duplicate()
			enemy.merge({"kind": "army", "side": "enemy", "men": e.strength}, true)
			if not model.enemy_visible(e):
				enemy.merge({"x": e.intel.x, "y": e.intel.y, "men": e.intel.strength, "uncertain": true}, true)
				if operational:
					enemy.erase("morale")
					enemy.erase("condition")
					enemy.path = []
			result.append(enemy)
		return result
	var b: Dictionary = model.state.battle
	var result = b.units.filter(func(u): return u.visible and u.men > 0 and not u.withdrawn and u.arrival <= b.time)
	for c in b.commanders:
		if c.get("hostId") == null and c.get("arrival", 0.0) <= b.time:
			var general: Dictionary = c.duplicate()
			general.merge({"kind": "general", "side": "player"}, true)
			result.append(general)
	for w in b.wagons:
		if w.health > 0 and w.visible:
			result.append(w)
	return result

func remember_transforms() -> void:
	previous_animation_time = animation_time()
	var armies: Array = model.state.armies if FieldOperations.enabled(model.state) else [model.state.army]
	var units: Array = armies + model.state.enemies if model.state.battle == null else model.state.battle.units + model.state.battle.commanders + model.state.battle.wagons
	for u in units:
		previous_positions[u.get("id", "army")] = FieldData.pos(u)
		# Keep support gaits current even when several physics ticks precede one rendered frame.
		var kind: String = "army" if model.state.battle == null else u.get("kind", "general")
		if kind in ["army", "general", "wagon"]:
			campaign_gait({"id": u.get("id", "army"), "kind": kind}, previous_animation_time)

func animation_time() -> float:
	return (model.state.hours - 6.0) / 0.08 if model.state.mode == "campaign" else model.state.battle.time

func rendered_animation_time() -> float:
	var current = animation_time()
	if model.state.paused or previous_animation_time < 0 or previous_animation_time > current: return current
	return lerpf(previous_animation_time, current, interpolation)

func interpolated_entities() -> Array:
	var result: Array = []
	for u in gather_entities():
		if interpolation < 1 and previous_positions.has(u.id) and not u.get("uncertain", false):
			var render_unit: Dictionary = u.duplicate()
			var p: Vector2 = previous_positions[u.id].lerp(FieldData.pos(u), interpolation)
			render_unit.x = p.x
			render_unit.y = p.y
			result.append(render_unit)
		else:
			result.append(u)
	return result

func figure_footing(p: Vector2, size_value: float, type: int) -> Dictionary:
	var visual = FigureVisual.new()
	update_footing(visual, p, size_value, type)
	return {"p": visual.p, "size": visual.size, "height": visual.height, "tilt": visual.tilt, "light": visual.light, "dx": visual.dx, "dz": visual.dz, "shadow": visual.shadow}

func update_footing(visual: FigureVisual, p: Vector2, size_value: float, type: int) -> void:
	# Support boots/wheels, not the empty edges of the painted sprite.
	var radius = size_value * (0.20 if type < 2 else 0.38)
	var left = model.terrain.height_at(p - Vector2(radius, 0))
	var right = model.terrain.height_at(p + Vector2(radius, 0))
	var center_height = model.terrain.height_at(p)
	var tilt = 0.0 if type < 2 else clampf(atan2(right - left, radius * 2), -0.14, 0.14)
	var height = maxf(center_height, maxf(left + tan(tilt) * radius, right - tan(tilt) * radius)) + 0.22
	var shadow_point = p
	var sx = size_value * 0.48
	var sz = size_value * 0.21
	var dx = (right - left) / (radius * 2)
	var dz = (model.terrain.height_at(shadow_point + Vector2(0, sz * 0.5)) - model.terrain.height_at(shadow_point - Vector2(0, sz * 0.5))) / sz
	var basis_value = Basis(Vector3(sx, dx * sx, 0), Vector3(-dx, 1, -dz).normalized(), Vector3(0, dz * sz, sz))
	var shadow_height = center_height + 0.16
	for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)]:
		var offset = basis_value * Vector3(corner.x, 0, corner.y)
		shadow_height = maxf(shadow_height, model.terrain.height_at(shadow_point + Vector2(offset.x, offset.z)) - offset.y + 0.16)
	var surface_normal = Vector3(-dx, 1, -dz).normalized()
	var light = clampf(1.0 + (surface_normal.dot(Vector3(-0.52, 0.76, -0.4).normalized()) - 0.76) * 0.4, 0.76, 1.08)
	visual.p = p
	visual.size = size_value
	visual.height = height
	visual.tilt = tilt
	visual.light = light
	visual.dx = dx
	visual.dz = dz
	visual.shadow = Transform3D(basis_value, Vector3(shadow_point.x, shadow_height, shadow_point.y))
	visual.drawnPoint = Vector2.INF
	visual.drawnWidth = -1

func place(counts: Array, type: int, p: Vector2, size_value: float, facing: float, phase: float, moving: float, age: float, shot_kind: String, index: int, melee_rank: int = 0, reload_duration: float = 2.8, gait: int = 0, previous_point: Vector2 = Vector2.INF, previous_phase: float = NAN, previous_moving: float = NAN, shot_timestamp: float = NAN) -> void:
	if not populating: manual_buffer_change = true
	var profiling = detailed_profile
	var start = Time.get_ticks_usec() if profiling else 0
	var vertical = sin(facing)
	var horizontal = cos(facing)
	var direction = 1 if vertical < -0.70 else 2 if vertical > 0.70 else 0
	var mirror = 1 if direction == 0 and horizontal < 0 else 0
	if type < 4:
		direction = 2 if vertical < -0.92 else 1 if vertical < -0.38 else 4 if vertical > 0.92 else 3 if vertical > 0.38 else 0
		mirror = 1 if direction != 2 and direction != 4 and horizontal < 0 else 0
	var shot_age = age - float(index % 8) * 0.025
	var pose = (1 if shot_age < 0.38 else 2 if shot_age < reload_duration else 0) if type < 6 and shot_age >= 0 and (shot_kind == "musket" or shot_kind == "cannon") else 0
	var loading_progress = clampf((shot_age - 0.38) / maxf(0.01, reload_duration - 0.38), 0, 1) if pose == 1 or pose == 2 else 0.0
	if type != 6 and pose == 0 and moving >= 0.08:
		var frame = FieldFormations.infantry_frame(phase, moving)
		pose = frame + 2 if frame > 0 else 0
	if shot_kind == "melee":
		shot_age = 100.0
		loading_progress = 0.0
		if type < 4: pose = (8 if melee_rank <= 1 else 9) if gpu_interpolation else 5 + FieldFormations.melee_frame(phase, melee_rank)
	var live_fire = not is_nan(shot_timestamp) and (pose == 1 or pose == 2) and moving < 0.1
	if live_fire: pose = 10
	var width = size_value * (2.0 if pose >= 5 and pose < 10 and type < 2 else 1.6 if type < 2 else 1.0)
	var cache_key = Vector2i(type, counts[type])
	if profiling:
		profile_sections.pose += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
	var cached: FigureVisual = support_cache.get(cache_key)
	if cached == null:
		cached = FigureVisual.new()
		support_cache[cache_key] = cached
	if cached.size != size_value or cached.p.distance_squared_to(p) > 4.0 or (p != cached.p and model.terrain.water and model.terrain.on_bridge(p) != model.terrain.on_bridge(cached.p)):
		update_footing(cached, p, size_value, type)
	if profiling:
		profile_sections.footing += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
	var changed = cached.drawnPoint != p or cached.drawnWidth != width
	if changed:
		var surface_step: Vector2 = p - cached.p
		var slope_height: float = surface_step.x * cached.dx + surface_step.y * cached.dz
		var height: float = cached.height + slope_height
		var foot_anchor = 0.92 if type < 2 else 0.915 if type == 6 else 0.94
		cached.anchor = foot_anchor - 0.5
		var basis_value: Basis = cached.drawnTransform.basis
		if cached.drawnWidth != width:
			var world_height = size_value / cos(CAMERA_PITCH)
			basis_value = Basis(Vector3.FORWARD, -cached.tilt) * Basis.from_scale(Vector3(width, world_height, 1))
			cached.inverse = basis_value.inverse()
			cached.shadowInverse = cached.shadow.basis.inverse()
		var origin = Vector3(p.x, height, p.y) + basis_value.y * (foot_anchor - 0.5)
		cached.drawnTransform = Transform3D(basis_value, origin)
		var shadow: Transform3D = cached.shadow
		shadow.origin += Vector3(surface_step.x, slope_height, surface_step.y)
		cached.drawnShadow = shadow
		cached.drawnPoint = p
		cached.drawnWidth = width
		batches[type].multimesh.set_instance_transform(counts[type], cached.drawnTransform)
	var delta = Vector3.ZERO
	if gpu_interpolation and previous_point != Vector2.INF:
		var step = previous_point - p
		delta = Vector3(step.x, step.x * cached.dx + step.y * cached.dz, step.y)
	var color = Color(cached.light, cached.light, cached.light, 1)
	var shadow_color = Color(0, 0, 0, 1)
	if gpu_interpolation:
		var local: Vector3 = cached.inverse * delta
		color = Color(local.x, local.y, local.z, cached.light)
		local = cached.shadowInverse * delta
		shadow_color = Color(local.x, local.y, local.z, 1)
	if cached.drawnColor != color:
		batches[type].multimesh.set_instance_color(counts[type], color)
		cached.drawnColor = color
	cached.screenDelta = Vector2(delta.dot(projection_right), -delta.dot(projection_up)) * projection_scale
	cached.drawnDelta = delta
	if profiling:
		profile_sections.transform += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
	if not placing_entity.is_empty():
		if changed or cached.projectionVersion != projection_version:
			cached.screenRegion = figure_region(cached)
			cached.projectionVersion = projection_version
		selection_regions[placing_entity].append(cached.screenRegion)
		selection_visuals[placing_entity].append(cached)
	if profiling:
		profile_sections.selection += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
	var progress = loading_progress * 0.5
	var extra = shot_age
	if pose != 1 and pose != 2:
		progress = 0.25 + (previous_moving - moving) * 0.25 if not is_nan(previous_moving) else 0.25
		extra = angle_difference(phase, previous_phase) if not is_nan(previous_phase) else 0.0
	if live_fire:
		progress = 0.0
		extra = fposmod(shot_timestamp + float(index % 8) * 0.025, 32.0)
	var live_melee = shot_kind == "melee" and gpu_interpolation and not model.state.paused
	if live_melee:
		phase = fposmod(index * 1.71, TAU)
		extra = 3.4 + float(index % 7) * 0.08
		progress = 0.25
	cached.liveMelee = live_melee
	cached.facing = facing
	cached.moving = moving
	cached.meleeRank = melee_rank
	var custom = Color(reload_duration if live_fire else phase, moving + gait * 2.0, float(mirror + direction * 2 + pose * 10) + progress, extra)
	if cached.drawnCustom != custom:
		batches[type].multimesh.set_instance_custom_data(counts[type], custom)
		cached.drawnCustom = custom
	counts[type] += 1
	if sprite_count < shadow_batch.multimesh.instance_count:
		var moved_index: bool = cached.shadowIndex != sprite_count
		if changed or moved_index:
			shadow_batch.multimesh.set_instance_transform(sprite_count, cached.drawnShadow)
		if moved_index or cached.shadowColor != shadow_color:
			shadow_batch.multimesh.set_instance_color(sprite_count, shadow_color)
		cached.shadowIndex = sprite_count
		cached.shadowColor = shadow_color
	sprite_count += 1
	if profiling: profile_sections.upload += Time.get_ticks_usec() - start

func campaign_gait(u: Dictionary, time: float) -> Dictionary:
	var actual: Dictionary = FieldOperations.force(model.state, u.id) if model.state.battle == null and FieldOperations.enabled(model.state) else model.state.army if u.id == "army" else model.find_id(model.state.enemies, u.id) if model.state.battle == null else model.find_id(model.state.battle.wagons + model.state.battle.commanders, u.id)
	var p = FieldData.pos(actual)
	if not campaign_gaits.has(u.id) or time < campaign_gaits[u.id].time:
		var moving = 1.0 if actual.get("target") != null or not actual.get("path", []).is_empty() else 0.0
		campaign_gaits[u.id] = {"p": p, "time": time, "phase": 0.0, "moving": moving, "previousPhase": 0.0, "previousMoving": moving}
	var gait: Dictionary = campaign_gaits[u.id]
	var elapsed: float = time - gait.time
	if elapsed > 0.000001:
		var distance: float = gait.p.distance_to(p)
		gait.previousPhase = gait.phase
		gait.previousMoving = gait.moving
		gait.phase = FieldFormations.stride_phase(gait.phase, distance, u.kind)
		gait.moving = move_toward(gait.moving, clampf(distance / elapsed / 14.0, 0, 1), elapsed * 3.0)
		gait.p = p
		gait.time = time
	return gait

func reserve_figures() -> void:
	var grew = false
	var required = [0, 0, 0, 0, 0, 0, 0, 0]
	for u in entities:
		if u.get("uncertain", false): continue
		var enemy = u.side == "enemy"
		if u.kind in ["general", "wagon", "army"]:
			if u.kind == "army": required[1 if enemy else 0] += 18
			required[7 if u.kind == "wagon" else 6] += 1
		else:
			var type = (5 if enemy else 4) if u.kind == "artillery" else (3 if enemy else 2) if u.kind == "cavalry" and not u.dismounted else 1 if enemy else 0
			required[type] += model.formations.positions(u).size()
	var total = 0
	for type in 8:
		total += required[type]
		if required[type] > batches[type].multimesh.instance_count:
			grew = true
			batches[type].multimesh.instance_count = maxi(required[type], batches[type].multimesh.instance_count * 2)
			batches[type].multimesh.visible_instance_count = 0
	if total > shadow_batch.multimesh.instance_count:
		grew = true
		shadow_batch.multimesh.instance_count = maxi(total, shadow_batch.multimesh.instance_count * 2)
		shadow_batch.multimesh.visible_instance_count = 0
	if grew:
		support_cache.clear()
		regiment_cache.clear()
	var particles = maxi(256, entities.size() * 24)
	if particles > smoke_batch.multimesh.instance_count:
		smoke_batch.multimesh.instance_count = particles
		smoke_batch.multimesh.visible_instance_count = 0

func populate() -> void:
	reserve_figures()
	if manual_buffer_change:
		support_cache.clear()
		regiment_cache.clear()
		manual_buffer_change = false
	populating = true
	var counts = [0, 0, 0, 0, 0, 0, 0, 0]
	sprite_count = 0
	smoke_count = 0
	muzzle_flashes.clear()
	selection_regions.clear()
	selection_visuals.clear()
	var time = rendered_animation_time()
	for u in entities:
		if u.get("uncertain", false):
			continue
		selection_regions[u.id] = []
		selection_visuals[u.id] = []
		placing_entity = u.id
		var screen = project(FieldData.pos(u))
		if not Rect2(Vector2(-200, -200), get_viewport().get_visible_rect().size + Vector2(400, 400)).has_point(screen):
			continue
		var enemy = u.side == "enemy"
		if u.kind in ["general", "wagon", "army"]:
			var command_p = FieldData.pos(u)
			var previous_command = previous_positions.get(u.id, command_p)
			if model.state.mode == "battle" and not model.state.paused and model.figure_commands.has(u.id):
				command_p = model.figure_commands[u.id]
				previous_command = model.figure_previous_commands.get(u.id, command_p)
			var gait = campaign_gait(u, animation_time())
			var gait_phase = lerp_angle(gait.previousPhase, gait.phase, interpolation)
			var gait_moving = lerpf(gait.previousMoving, gait.moving, interpolation)
			if u.kind == "army":
				for i in 18:
					var offset = Vector2(-26 + (i % 6) * 10, (i / 6) * 7)
					place(counts, 1 if enemy else 0, command_p + offset, 17, u.get("facing", 0.0), gait_phase + i * 1.71, gait_moving, 100, "", i, 0, 2.8, 0, previous_command + offset, gait.previousPhase + i * 1.71, gait.previousMoving)
			var offset = Vector2(-30, 17) if u.kind == "army" else Vector2.ZERO
			place(counts, 7 if u.kind == "wagon" else 6, command_p + offset, 35 if u.kind == "wagon" else 28 if u.kind == "army" else 31, u.get("facing", 0.0), gait_phase, gait_moving, 100, "", 0, 0, 2.8, 0, previous_command + offset, gait.previousPhase, gait.previousMoving)
			continue
		var type = (5 if enemy else 4) if u.kind == "artillery" else (3 if enemy else 2) if u.kind == "cavalry" and not u.dismounted else 1 if enemy else 0
		var age: float = time - u.get("shotTime", -100.0)
		var reload_duration: float = u.get("shotReload", (4.2 if u.kind == "artillery" else 2.8) * (1.15 - u.skills.firearms / 300.0))
		var flow: Dictionary = model.formations.motion.get(u.id, {})
		var active_shot = age >= 0 and age < reload_duration + 0.3
		var old: Dictionary = regiment_cache.get(u.id, {})
		var reusable = gpu_interpolation and not model.state.paused and flow.get("sleeping", false)
		if reusable and not old.is_empty() and old.start == counts[type] and old.shadow == sprite_count and old.type == type and old.revision == flow.get("revision", -1) and old.shotTime == u.get("shotTime", -100.0) and old.activeShot == active_shot:
			selection_regions[u.id] = old.regions
			selection_visuals[u.id] = old.visuals
			if old.projection != projection_version:
				refresh_cached_regions(u.id, old.visuals)
				old.regions = selection_regions[u.id]
				old.projection = projection_version
			counts[type] += old.count
			sprite_count += old.count
			if age >= 0 and age < 6.0 and u.get("shotKind", "") != "melee": place_smoke(u, age)
			continue
		var start_count: int = counts[type]
		var start_shadow = sprite_count
		var points = model.formations.positions(u)
		var melee = u.get("meleeTargetId") != null and not u.routed
		var shot_kind: String = "melee" if melee else u.get("shotKind", "")
		if not melee and shot_kind == "melee": shot_kind = ""
		var volley = not melee and (shot_kind == "musket" or shot_kind == "cannon")
		var flashing = volley and age >= 0 and age < 0.32
		var aiming = volley and age < reload_duration
		var aiming_facing: float = u.facing
		var free_facing = u.get("coverId") != null
		var size_value = 25.0 if u.kind == "artillery" else 19.0 if u.kind == "cavalry" else 13.5
		var cannon: bool = u.kind == "artillery"
		var gait = (2 if u.get("charging", false) else 1 if u.get("running", false) else 0) if type == 2 or type == 3 else 0
		var forward = Vector2.from_angle(u.facing)
		var front_edge = -INF
		if flashing:
			for figure in points:
				if figure.alive: front_edge = maxf(front_edge, figure.p.dot(forward))
		if age >= 0 and age < 6.0 and u.get("shotKind", "") in ["musket", "cannon"]:
			place_smoke(u, age)
		for i in points.size():
			var p: FieldFormations.Soldier = points[i]
			if not p.alive: continue
			var location = p.p
			var facing = p.facing
			var phase = p.phase
			var moving = p.moving
			if not gpu_interpolation:
				location = p.previous.lerp(p.p, interpolation)
				facing = lerp_angle(p.previousFacing, p.facing, interpolation)
				phase = lerp_angle(p.previousPhase, p.phase, interpolation)
				moving = lerpf(p.previousMoving, p.moving, interpolation)
			if melee: phase = FieldFormations.melee_phase(time, i)
			if flashing:
				var flash_age = age - float(i % 8) * 0.025
				if flash_age >= 0 and flash_age < 0.12 and (cannon or p.p.dot(forward) >= front_edge - 7):
					muzzle_flashes.append({"p": location + forward * (13 if cannon else 5), "age": flash_age, "cannon": cannon})
			# A casualty can wake a regiment while most of its soldiers remain at
			# their contact slots. Their shader clocks already animate independently.
			if melee and gpu_interpolation and not model.state.paused and location == p.previous:
				var cached: FigureVisual = support_cache.get(Vector2i(type, counts[type]))
				if cached != null and cached.liveMelee and cached.drawnPoint == location and cached.drawnDelta == Vector3.ZERO and cached.facing == facing and cached.moving == moving and cached.meleeRank == p.melee_rank and cached.shadowIndex == sprite_count and cached.projectionVersion == projection_version:
					selection_regions[u.id].append(cached.screenRegion)
					selection_visuals[u.id].append(cached)
					counts[type] += 1
					sprite_count += 1
					continue
			var old_phase = FieldFormations.melee_phase(time - (model.figure_sample_clock - model.figure_previous_clock) * model.state.speed, i) if melee else p.previousPhase
			place(counts, type, location, size_value, aiming_facing if aiming and moving < 0.1 and not free_facing else facing, phase, moving, age, shot_kind, i, p.melee_rank, reload_duration, gait, p.previous, old_phase, p.previousMoving, u.get("shotTime", NAN) if volley and gpu_interpolation and not model.state.paused else NAN)
		place_march_dust(u, time)
		if reusable:
			regiment_cache[u.id] = {"type": type, "start": start_count, "shadow": start_shadow, "count": counts[type] - start_count, "revision": flow.get("revision", -1), "shotTime": u.get("shotTime", -100.0), "activeShot": active_shot, "projection": projection_version, "regions": selection_regions[u.id], "visuals": selection_visuals[u.id]}
		else: regiment_cache.erase(u.id)
	if model.state.battle != null:
		for impact in model.state.battle.artilleryImpacts:
			var age: float = time - impact.time
			if impact.visible and age >= 0 and age < 2.6: place_dust(FieldData.pos(impact) + Vector2(age * 3, -age), 13 + age * 9, minf(1, age / 0.08) * (1.0 - age / 2.6) * 0.42)
	for i in 8:
		batches[i].multimesh.visible_instance_count = counts[i]
	shadow_batch.multimesh.visible_instance_count = sprite_count
	smoke_batch.multimesh.visible_instance_count = smoke_count
	for id in smoke_emissions.keys():
		if time - smoke_emissions[id].time >= 6.0:
			smoke_emissions.erase(id)
	if water_material != null:
		water_material.set_shader_parameter("simulation_time", time)
	ground_material.set_shader_parameter("fog_enabled", show_fog and model.state.battle != null)
	if model.state.battle != null and (absf(time - fog_clock) >= 0.25 or fog_texture == null):
		var dimensions = model.terrain.fog_size()
		var pixels = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_R8)
		for i in dimensions.x * dimensions.y:
			var lit = model.state.battle.visibleCells[i]
			pixels.set_pixel(i % dimensions.x, i / dimensions.x, Color.WHITE if lit else Color.BLACK)
		if fog_texture == null:
			fog_texture = ImageTexture.create_from_image(pixels)
			ground_material.set_shader_parameter("fog_map", fog_texture)
		else:
			fog_texture.update(pixels)
		fog_clock = time
	update_bodies()
	placing_entity = ""
	populating = false

func refresh_cached_regions(id: String, visuals: Array) -> void:
	var regions: Array = []
	for cached: FigureVisual in visuals:
		cached.screenRegion = figure_region(cached)
		cached.screenDelta = Vector2(cached.drawnDelta.dot(projection_right), -cached.drawnDelta.dot(projection_up)) * projection_scale
		cached.projectionVersion = projection_version
		regions.append(cached.screenRegion)
	selection_regions[id] = regions

func figure_region(visual: FigureVisual) -> Rect2:
	var transform = visual.drawnTransform
	var basis = transform.basis
	var extent = Vector2(absf(projection_right.dot(basis.x)) + absf(projection_right.dot(basis.y)) * view_height_factor, absf(projection_up.dot(basis.x)) + absf(projection_up.dot(basis.y)) * view_height_factor) * projection_scale * 0.5
	var center_point = transform.origin + basis.y * visual.anchor * (view_height_factor - 1.0)
	return Rect2(camera.unproject_position(center_point) - extent, extent * 2).grow(2)

func update_bodies() -> void:
	var bodies: Array = model.state.battle.get("bodies", []) if model.state.battle != null else []
	if body_count != bodies.size():
		var previous = maxi(0, body_count)
		if body_count < 0 or bodies.size() < body_count:
			if is_instance_valid(body_mesh): body_mesh.queue_free()
			body_mesh = null
			body_geometry.clear()
			previous = 0
		body_count = bodies.size()
		if body_count > 0:
			if not is_instance_valid(body_mesh):
				body_mesh = MeshInstance3D.new()
				body_mesh.mesh = ArrayMesh.new()
				body_material = ShaderMaterial.new()
				body_material.shader = load("res://shaders/casualties.gdshader")
				body_material.set_shader_parameter("atlas", FieldArt.casualty_texture())
				body_mesh.material_override = body_material
				body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(body_mesh)
			# Sample each body's nine ground points once. Tail mesh updates reuse
			# that geometry as well as preserving completed 128-body surfaces.
			for i in range(body_geometry.size(), body_count):
				body_geometry.append(body_points(bodies[i]))
			var first = (previous / 128) * 128
			var mesh: ArrayMesh = body_mesh.mesh
			if previous % 128 != 0 and mesh.get_surface_count() > 0: mesh.surface_remove(mesh.get_surface_count() - 1)
			for start in range(first, body_count, 128):
				append_bodies(mesh, bodies, start, mini(body_count, start + 128))
	if is_instance_valid(body_mesh):
		body_material.set_shader_parameter("fog_enabled", show_fog)
		body_material.set_shader_parameter("map_size", model.terrain.map_size)
		body_material.set_shader_parameter("fog_map", fog_texture)

func body_points(body: Dictionary) -> PackedVector3Array:
	var size_value = 20.0 if body.mounted else 13.0
	var center = FieldData.pos(body)
	var clearance = 1.57 if road_clearance(center) < size_value * 0.71 + 5.0 else 0.22
	var points = PackedVector3Array()
	for y in 3:
		for x in 3:
			var p = center + ((Vector2(x, y) * 0.5 - Vector2(0.5, 0.5)) * size_value).rotated(body.facing + PI / 2.0)
			points.append(Vector3(p.x, model.terrain.height_at(p) + clearance, p.y))
	return points

func append_bodies(mesh: ArrayMesh, bodies: Array, first: int, end: int) -> void:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	for i in range(first, end):
		var body: Dictionary = bodies[i]
		var index = (5 if body.side == "enemy" else 4) if body.mounted else (3 if body.side == "enemy" else 2) if body.kind == "artillery" else 1 if body.side == "enemy" else 0
		tool.set_color(Color.RED if body.side == "enemy" else Color.BLACK)
		var points: PackedVector3Array = body_geometry[i]
		for y in 2:
			for x in 2:
				for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var cell = Vector2i(x, y) + corner
					var uv = Vector2(cell) * 0.5
					tool.set_uv((uv + Vector2(index % 3, index / 3)) / Vector2(3, 2))
					tool.add_vertex(points[cell.y * 3 + cell.x])
	tool.commit(mesh)

func place_smoke(u: Dictionary, age: float) -> void:
	if not smoke_emissions.has(u.id) or smoke_emissions[u.id].time != u.shotTime:
		var points = model.formations.positions(u).filter(func(figure): return figure.alive)
		var forward = Vector2.from_angle(u.facing)
		var front = -INF
		for figure in points: front = maxf(front, figure.p.dot(forward))
		var origins: Array = []
		for figure in points:
			if u.kind == "artillery" or figure.p.dot(forward) >= front - 7: origins.append(figure.p + forward * (13 if u.kind == "artillery" else 5))
		if origins.is_empty(): origins.append(FieldData.pos(u))
		smoke_emissions[u.id] = {"time": u.shotTime, "origin": FieldData.pos(u), "origins": origins, "facing": u.facing, "bounds": FieldFormations.bounds(u)}
	var emission: Dictionary = smoke_emissions[u.id]
	var bounds: Rect2 = emission.bounds
	var cannon = u.kind == "artillery"
	var count = mini(10, emission.origins.size())
	for i in count:
		if smoke_count >= smoke_batch.multimesh.instance_count:
			return
		var local_age = age - (i % 4) * 0.06
		if local_age < 0:
			continue
		var p: Vector2 = emission.origins[mini(emission.origins.size() - 1, floori((i + 0.5) * emission.origins.size() / count))]
		p += Vector2(local_age * 4.5, -local_age * 1.7)
		var size_value = (26.0 if cannon else 18.0) + local_age * 6.0
		var opacity = minf(1, local_age / 0.18) * pow(1.0 - local_age / 6.0, 1.4) * (0.75 if cannon else 0.60)
		var cell = (3 if cannon else 0) + (0 if local_age < 0.6 else 1 if local_age < 2.5 else 2)
		var basis_value = camera.global_basis * Basis.from_scale(Vector3(size_value, size_value * 0.8, 1))
		smoke_batch.multimesh.set_instance_transform(smoke_count, Transform3D(basis_value, Vector3(p.x, model.terrain.height_at(p) + 7.0 + local_age * 2.0, p.y)))
		smoke_batch.multimesh.set_instance_custom_data(smoke_count, Color(cell, opacity, 0, 0))
		smoke_count += 1

func place_dust(p: Vector2, size_value: float, opacity: float) -> void:
	if smoke_count >= smoke_batch.multimesh.instance_count or opacity <= 0: return
	var basis_value = camera.global_basis * Basis.from_scale(Vector3(size_value, size_value * 0.55, 1))
	smoke_batch.multimesh.set_instance_transform(smoke_count, Transform3D(basis_value, Vector3(p.x, model.terrain.height_at(p) + size_value * 0.12, p.y)))
	smoke_batch.multimesh.set_instance_custom_data(smoke_count, Color(1, opacity, 1, 0))
	smoke_count += 1

func place_march_dust(u: Dictionary, time: float) -> void:
	if u.target == null or u.get("movementBlocked", "") != "" or model.terrain.on_bridge(FieldData.pos(u)) or FieldTerrain.kind(FieldData.pos(u), model.terrain.field) == "woods": return
	var count = 5 if u.kind == "cavalry" else 3 if u.running or u.charging else 1
	var forward = Vector2.from_angle(u.facing)
	for i in count:
		var age = fposmod(time * 0.8 + i * 0.47, 2.2)
		var p = FieldData.pos(u) - forward * (age * 13 + 14) + forward.orthogonal() * sin(i * 3.1) * 12
		place_dust(p, 11 + age * 7, sin(age / 2.2 * PI) * (0.12 if u.kind == "cavalry" else 0.065))

func home() -> void:
	camera_pitch = CAMERA_PITCH
	center = model.terrain.map_size * 0.5
	zoom = 1.0
	if model.terrain.campaign:
		center = FieldData.pos(model.state.army) + Vector2(420, -230)
		zoom = 0.78
	if get_viewport().get_visible_rect().size.x < 650:
		center = FieldData.pos(model.state.army) + Vector2(90, -60) if model.state.mode == "campaign" else FieldData.pos(model.terrain.field.objective) - Vector2(80, 0)
	update_camera()

func overview() -> void:
	center = model.terrain.map_size * 0.5
	var viewport = get_viewport().get_visible_rect().size
	var aspect = viewport.x / viewport.y
	var base = 650.0 / aspect if viewport.x < 650 else 970.0
	zoom = base / maxf(model.terrain.map_size.x / aspect, model.terrain.map_size.y * sin(camera_pitch)) / 1.18
	update_camera()

func update_camera() -> void:
	projection_version += 1
	var size_value = get_viewport().get_visible_rect().size
	var aspect = size_value.x / maxf(1, size_value.y)
	var base = 650.0 / aspect if size_value.x < 650 else 970.0
	var available = model.terrain.render_bounds.grow(-100)
	zoom = clampf(zoom, maxf(0.05, maxf(base * aspect / available.size.x, base / sin(camera_pitch) / available.size.y)), 6.0)
	camera.size = base / zoom
	var half_x = camera.size * aspect / 2.0
	var half_y = camera.size / (2.0 * sin(camera_pitch))
	center = center.clamp(available.position + Vector2(half_x, half_y), available.end - Vector2(half_x, half_y))
	var elevation = maxf(1250, camera.size)
	camera.far = maxf(6000, elevation * 4.0)
	camera.position = Vector3(center.x, elevation, center.y + elevation / tan(camera_pitch))
	camera.look_at(Vector3(center.x, 0, center.y))
	projection_scale = size_value.y / camera.size
	projection_right = camera.global_basis.x
	projection_up = camera.global_basis.y
	view_height_factor = cos(CAMERA_PITCH) / cos(camera_pitch)
	for material in scenery_materials:
		material.set_shader_parameter("camera_right", projection_right)
		material.set_shader_parameter("camera_up", projection_up)
	for batch in batches: batch.material_override.set_shader_parameter("view_height_factor", view_height_factor)
	viewport_size = size_value
	invalidate()

func adjust_pitch(degrees_delta: float) -> void:
	camera_pitch = clampf(camera_pitch + deg_to_rad(degrees_delta), deg_to_rad(28), deg_to_rad(60))
	update_camera()

func set_zoom(multiplier: float) -> void:
	zoom *= multiplier
	update_camera()

func center_entity(entity: Dictionary) -> void:
	center = FieldData.pos(entity)
	update_camera()

func ground(screen: Vector2):
	var origin = camera.project_ray_origin(screen)
	var direction = camera.project_ray_normal(screen)
	if absf(direction.y) < 0.001:
		return null
	var low = 0.0
	var high = camera.far
	for i in 24:
		var t = (low + high) / 2.0
		var p = origin + direction * t
		if p.y > model.terrain.height_at(Vector2(p.x, p.z)):
			low = t
		else:
			high = t
	var point = origin + direction * ((low + high) / 2.0)
	return Vector2(point.x, point.z)

func project(p: Vector2, above: float = 0.0) -> Vector2:
	return camera.unproject_position(Vector3(p.x, model.terrain.height_at(p) + above, p.y))

func map_input(p: Vector2) -> bool:
	var size_value = get_viewport().get_visible_rect().size
	return not input_blocked and p.y > ui_top and p.y < size_value.y - ui_bottom

func entity_regions(u: Dictionary) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var base = 25.0 if u.kind == "artillery" else 19.0 if u.kind == "cavalry" and not u.get("dismounted", false) else 13.5
	if u.kind in ["general", "wagon", "army"]:
		base = 35.0 if u.kind == "wagon" else 31.0
		var p = project(FieldData.pos(u))
		var pixels = base / camera.size * get_viewport().get_visible_rect().size.y
		regions.append(Rect2(p - Vector2(pixels * 0.6, pixels), Vector2(pixels * 1.2, pixels)))
		if u.kind != "army": return regions
		base = 17.0
	var positions: Array = []
	if u.kind == "army":
		for i in 18: positions.append(FieldData.pos(u) + Vector2(-26 + (i % 6) * 10, (i / 6) * 7))
	else:
		for p in model.formations.positions(u):
			if p.get("alive") == false: continue
			positions.append(p.previous.lerp(p.p, interpolation))
	var pixels = base / camera.size * get_viewport().get_visible_rect().size.y
	for position in positions:
		var p = project(position)
		regions.append(Rect2(p - Vector2(pixels * 0.5, pixels * 1.07), Vector2(pixels, pixels * 1.1)).grow(2))
	return regions

func hit_entity(screen: Vector2) -> Dictionary:
	for label in labels:
		if label.rect.has_point(screen):
			return label.entity
	var nearest: Dictionary = {}
	var best = 32.0
	for entity in entities:
		if drawn_regions(entity.id).any(func(rect): return rect.has_point(screen)):
			return entity
		var d = project(FieldData.pos(entity), 12).distance_to(screen)
		if d < best:
			best = d
			nearest = entity
	return nearest

func drawn_regions(id: String) -> Array:
	if not gpu_interpolation or model.state.paused: return selection_regions.get(id, [])
	var result: Array = []
	for visual: FigureVisual in selection_visuals.get(id, []): result.append(Rect2(visual.screenRegion.position + visual.screenDelta * (1.0 - render_fraction), visual.screenRegion.size))
	return result

func cover_marker_rect(cover: Dictionary) -> Rect2:
	var size_value = get_viewport().get_visible_rect().size
	var available = Rect2(Vector2(0, ui_top), Vector2(size_value.x, size_value.y - ui_top - ui_bottom))
	var anchor = project(FieldData.pos(cover), 8)
	for offset in [Vector2(12, -54), Vector2(-48, -54), Vector2(12, 18), Vector2(-48, 18)]:
		var rect = Rect2(anchor + offset, Vector2(36, 36))
		if available.encloses(rect) and not label_obstacles.any(func(obstacle): return obstacle.intersects(rect)): return rect
	return Rect2()

func hit_cover(screen: Vector2) -> Dictionary:
	if model.state.battle == null or not map_input(screen): return {}
	for cover in model.terrain.defenses:
		if cover_marker_rect(cover).has_point(screen): return cover
	return {}

func visible_cover_occupant(cover: Dictionary) -> Dictionary:
	var occupant = FieldCover.occupant(model.state.battle, cover.id)
	if not occupant.is_empty() and occupant.side == "enemy" and not occupant.visible: return {}
	return occupant

func cover_status(occupant: Dictionary) -> String:
	if occupant.is_empty(): return "Vacant / infantry"
	if occupant.side == "enemy": return "Enemy-held"
	if occupant.get("coverOrderId") != null: return "Approaching"
	if occupant.coverDeploy < 4: return "Manning / %d%%" % roundi(occupant.coverDeploy * 25)
	return "Occupied / protected"

func inspect_entity(entity: Dictionary, additive: bool = false) -> void:
	if entity.side == "player" and model.state.mode == "campaign" and FieldOperations.enabled(model.state):
		var ids: Array = model.state.armySelection.duplicate() if additive else []
		if additive and entity.id in ids: ids.erase(entity.id)
		else: ids.append(entity.id)
		model.select_armies(ids)
	if entity.side == "player" and model.state.mode == "battle":
		if entity.kind == "general":
			model.select_commander(entity.id)
		elif entity.kind == "wagon":
			model.select_supply()
		else:
			var selected: Array = model.state.selected.duplicate() if additive else []
			if additive and entity.id in selected:
				selected.erase(entity.id)
			else:
				selected.append(entity.id)
			model.select(selected)
	inspect_requested.emit(entity)

func issue_order(start: Vector2, finish: Vector2, dragged: bool, anchor = null) -> void:
	var destination = ground(start) if anchor == null else anchor
	if not dragged:
		var cover = hit_cover(start)
		if not cover.is_empty():
			if model.occupy_cover(cover.id) == 0: order_failed.emit("Position occupied, too small, or requires infantry.")
			return
	var entity = hit_entity(start)
	if not dragged and not entity.is_empty() and entity.side == "enemy" and not entity.get("uncertain", false):
		destination = FieldData.pos(entity)
	if destination == null or not (model.terrain.passable(destination) if model.state.mode == "campaign" else model.terrain.ground_passable(destination)):
		order_failed.emit("Destination is not traversable.")
		return
	if model.state.mode == "campaign":
		if model.campaign_selection().is_empty():
			order_failed.emit("No army selected.")
			return
		var attack = not dragged and not entity.is_empty() and entity.side == "enemy" and not entity.get("uncertain", false)
		if not (model.attack_army(entity.id) if attack else model.move_army(destination)):
			order_failed.emit("No route to that destination.")
		elif FieldOperations.enabled(model.state):
			var waiting = model.campaign_selection().filter(func(a): return a.get("pendingOrder") != null)
			if not waiting.is_empty():
				var description = "Order" if waiting.size() == 1 else "%d orders" % waiting.size()
				var reason = "reforming after battle" if FieldOperations.pursuit_paused(model.state, waiting[0]) else "completing withdrawal"
				order_queued.emit("%s queued / %s%s" % [description, reason, " / Paused" if model.state.paused else ""])
			elif model.state.paused:
				order_queued.emit("March ordered / time paused")
		return
	if model.state.orderMode == "deploy":
		if not model.deploy(destination):
			order_failed.emit("Deployment is limited to your starting edge before battle begins.")
		return
	var endpoint = ground(finish)
	if dragged and model.state.orderMode == "frontline" and endpoint != null:
		model.frontline(destination, endpoint)
		return
	var facing = (endpoint - destination).angle() if dragged and endpoint != null else null
	var attack = entity.id if not entity.is_empty() and entity.side == "enemy" and not entity.get("uncertain", false) and not dragged else null
	if attack != null:
		destination = FieldData.pos(entity)
	if not model.move_units(destination, attack, Input.is_key_pressed(KEY_SHIFT), facing):
		var selected = model.selected_units()
		order_failed.emit("No route to that destination." if selected.any(func(u): return not u.get("movementBlocked", "").is_empty()) else "No eligible selection or route.")
	elif model.selected_units().any(func(u): return u.get("movementBlocked", "") == "No route to destination"):
		order_failed.emit("Some units cannot reach their destinations.")

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(camera) or input_blocked:
		return
	if event is InputEventScreenTouch:
		if event.pressed and map_input(event.position):
			touches[event.index] = event.position
			if touches.size() == 1:
				touch_origin = event.position
				touch_dragged = false
			else:
				touch_dragged = true
		elif not event.pressed and touches.has(event.index):
			if touches.size() == 1 and not touch_dragged:
				var entity = hit_entity(event.position)
				if touch_orders: issue_order(event.position, event.position, false)
				elif not entity.is_empty(): inspect_entity(entity)
			touches.erase(event.index)
		return
	if event is InputEventScreenDrag and touches.has(event.index):
		var previous = touches.values()
		touches[event.index] = event.position
		if touches.size() >= 2:
			var next = touches.values()
			var before: float = previous[0].distance_to(previous[1])
			if before > 2: set_zoom(next[0].distance_to(next[1]) / before)
			touch_dragged = true
		else:
			if touch_origin.distance_to(event.position) > 8: touch_dragged = true
			if touch_dragged: pan_pixels(event.relative)
		return
	# UI buttons retain Godot's touch-to-mouse emulation; map gestures are handled above.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			right_start = null
			campaign_preview.clear()
			left_start = null
			invalidate()
		elif event.keycode == KEY_SPACE:
			model.pause()
		elif event.keycode == KEY_H:
			model.halt()
		elif event.keycode == KEY_HOME:
			home()
		elif event.keycode == KEY_F:
			model.engage_enemy()
		elif event.keycode == KEY_R:
			model.retreat_units()
		elif event.keycode == KEY_C:
			model.charge()
		elif event.keycode == KEY_X:
			model.fall_back()
		elif event.keycode == KEY_1:
			model.select_corps("c1")
		elif event.keycode == KEY_2:
			model.select_corps("c2")
	if event is InputEventMouseButton:
		pointer = event.position
		if not map_input(pointer) and right_start == null and left_start == null:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(1.16)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(1.0 / 1.16)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				right_screen = pointer
				right_start = ground(pointer)
				prepare_campaign_preview()
			else:
				if right_start != null:
					issue_order(right_screen, pointer, pointer.distance_to(right_screen) > 8, right_start)
				right_start = null
				campaign_preview.clear()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.alt_pressed or panning:
				panning = event.pressed
				left_start = null
				return
			if event.pressed:
				left_start = pointer
				drag_panned = false
				if event.double_click:
					var entity = hit_entity(pointer)
					if not entity.is_empty(): center_entity(entity)
			else:
				if left_start != null and not drag_panned:
					if pointer.distance_to(left_start) > 8:
						var box = Rect2(left_start, pointer - left_start).abs()
						var operational = model.state.mode == "campaign" and FieldOperations.enabled(model.state)
						var ids: Array = (model.state.armySelection if operational else model.state.selected).duplicate() if event.shift_pressed else []
						for u in entities:
							if u.side == "player" and drawn_regions(u.id).any(func(rect): return box.intersects(rect)):
								if operational:
									if not u.id in ids: ids.append(u.id)
								elif model.state.mode == "campaign": inspect_entity(u)
								elif u.kind in ["infantry", "cavalry", "artillery"] and not u.id in ids: ids.append(u.id)
						if model.state.mode == "battle": model.select(ids)
						elif operational: model.select_armies(ids)
					else:
						var entity = hit_entity(pointer)
						if touch_orders:
							issue_order(pointer, pointer, false)
						elif not entity.is_empty():
							inspect_entity(entity, event.shift_pressed or event.ctrl_pressed)
				left_start = null
		invalidate()
	elif event is InputEventMouseMotion:
		var previous_cover = hit_cover(pointer)
		pointer = event.position
		if panning:
			pan_pixels(event.relative)
		if map_input(pointer):
			var entity = hit_entity(pointer)
			var cover = hit_cover(pointer)
			var shape = Input.CURSOR_ARROW
			if right_start != null: shape = Input.CURSOR_MOVE
			elif not cover.is_empty():
				var occupant = visible_cover_occupant(cover)
				var eligible = model.selected_units().any(func(u): return FieldCover.eligible(u, cover) and (occupant.is_empty() or occupant.id == u.id))
				shape = Input.CURSOR_POINTING_HAND if eligible else Input.CURSOR_FORBIDDEN
			elif not entity.is_empty() and entity.side == "enemy" and not entity.get("uncertain", false): shape = Input.CURSOR_CROSS
			Input.set_default_cursor_shape(shape)
		if right_start != null or left_start != null or not previous_cover.is_empty() or not hit_cover(pointer).is_empty():
			invalidate()

func pan_pixels(delta: Vector2) -> void:
	var factor = camera.size / get_viewport().get_visible_rect().size.y
	center -= delta * Vector2(factor, factor / sin(camera_pitch))
	update_camera()

func _process(dt: float) -> void:
	var start = Time.get_ticks_usec()
	if not is_instance_valid(camera):
		return
	sync_map()
	if viewport_size != get_viewport().get_visible_rect().size:
		update_camera()
	if not input_blocked and not get_viewport().gui_get_focus_owner() is LineEdit:
		var tilt_input = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
		if tilt_input != 0: adjust_pitch(tilt_input * minf(dt, 0.1) * 24.0)
		var direction = Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)), float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		if direction.length_squared() > 0:
			center += direction.normalized() * minf(dt, 0.1) * 540.0 / zoom
			update_camera()
	var time: float = model.state.hours if model.state.mode == "campaign" else model.state.battle.time
	var changed_tick = time != last_time
	var fraction = 1.0 if model.state.paused else Engine.get_physics_interpolation_fraction()
	if model.state.mode == "battle" and not model.state.paused and model.figure_revision > 0:
		var render_clock = model.visual_clock + Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
		fraction = clampf((render_clock - model.figure_interval - model.figure_previous_clock) / maxf(0.000001, model.figure_sample_clock - model.figure_previous_clock), 0, 1)
	render_fraction = fraction
	if gpu_interpolation:
		var simulation_clock = animation_time() if model.state.paused else lerpf(previous_animation_time, animation_time(), Engine.get_physics_interpolation_fraction()) if previous_animation_time >= 0 else animation_time()
		for batch in batches:
			batch.material_override.set_shader_parameter("interpolation_fraction", fraction)
			batch.material_override.set_shader_parameter("simulation_time", simulation_clock)
		shadow_batch.material_override.set_shader_parameter("interpolation_fraction", fraction)
	var figures_changed = model.state.mode != "battle" or model.figure_revision != last_figure_revision
	if render_dirty or (changed_tick and figures_changed) or (not gpu_interpolation and not model.state.paused):
		interpolation = 1.0 if model.state.paused else Engine.get_physics_interpolation_fraction()
		entities = interpolated_entities()
		if gpu_interpolation:
			interpolation = 1.0
			entities = gather_entities()
		populate()
		if render_dirty or changed_tick: overlay.queue_redraw()
		last_time = time
		last_figure_revision = model.figure_revision
		render_dirty = false
	process_micros = Time.get_ticks_usec() - start

func line_world(points: Array, color: Color, width: float = 1.0, closed: bool = false, outlined: bool = false) -> void:
	var screen = PackedVector2Array()
	for p in points:
		screen.append(project(p))
	if closed and screen.size() > 1:
		screen.append(screen[0])
	if screen.size() > 1:
		if outlined:
			overlay.draw_polyline(screen, Color(0.05, 0.08, 0.07, 0.8), width + 2.0, true)
		overlay.draw_polyline(screen, color, width, true)

func circle_world(p: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	var points: Array = []
	for i in 65:
		points.append(p + Vector2.from_angle(float(i) / 64.0 * TAU) * radius)
	line_world(points, color, width)

func draw_range(u: Dictionary) -> void:
	var reach: float = FieldData.weapons()[u.weapon].range
	var half = PI if reach <= 45 else acos(0.45)
	var points: Array = []
	var bounds = Rect2()
	var offsets = FieldFormations.offsets(u)
	if not offsets.is_empty():
		bounds.position = offsets[0]
		for p in offsets:
			bounds = bounds.expand(p)
	if reach > 45:
		points.append(FieldFormations.world_point(u, Vector2(bounds.end.x + 3, bounds.end.y + 3)))
	for i in 51:
		points.append(FieldData.pos(u) + Vector2.from_angle(u.facing - half + float(i) / 50.0 * half * 2) * reach)
	if reach > 45:
		points.append(FieldFormations.world_point(u, Vector2(bounds.position.x - 3, bounds.end.y + 3)))
	line_world(points, Color(0.95, 0.84, 0.55, 0.6), 1.0, true)
	var screen = PackedVector2Array()
	for p in points:
		screen.append(project(p))
	# Projected relief can fold an otherwise valid ground arc. Keep its outline
	# without submitting an untriangulatable fill to the renderer.
	if screen.size() > 2 and not Geometry2D.triangulate_polygon(screen).is_empty():
		overlay.draw_colored_polygon(screen, Color(0.9, 0.83, 0.55, 0.055))
	var target = model.find_id(model.state.battle.units, u.attackId if u.attackId != null else u.fireTargetId)
	if not target.is_empty() and target.visible and not target.withdrawn and reach > 45 and u.get("meleeTargetId") == null:
		var clear: bool = model.tactics.clear_shot(model, u, target)
		var color = Color("a4c487") if clear else Color("e57964")
		line_world([FieldData.pos(u), FieldData.pos(target)], color, 1.5)
		if not clear:
			var midpoint = project(FieldData.pos(u).lerp(FieldData.pos(target), 0.5), 8)
			overlay.draw_line(midpoint - Vector2(4, 4), midpoint + Vector2(4, 4), color, 2)
			overlay.draw_line(midpoint - Vector2(4, -4), midpoint + Vector2(4, -4), color, 2)

func label_rect(preferred: Rect2) -> Rect2:
	var viewport = get_viewport().get_visible_rect().size
	var available = Rect2(Vector2(2, ui_top + 2), Vector2(viewport.x - 4, viewport.y - ui_top - ui_bottom - 4))
	for offset in [0, -48, 48, -96, 96, -144, 144, -192, 192, -240, 240]:
		var candidate = preferred
		candidate.position.x = clampf(candidate.position.x, available.position.x, available.end.x - candidate.size.x)
		candidate.position.y += offset
		if not available.encloses(candidate): continue
		if label_obstacles.any(func(rect): return rect.intersects(candidate)): continue
		if labels.any(func(item): return item.rect.grow(2).intersects(candidate)): continue
		if town_label_regions.any(func(rect): return rect.grow(2).intersects(candidate)): continue
		if cover_regions.values().any(func(rect): return rect.grow(4).intersects(candidate)): continue
		if cover_tooltip_rect.has_area() and cover_tooltip_rect.grow(4).intersects(candidate): continue
		return candidate
	return Rect2()

func prepare_cover_markers() -> void:
	cover_regions.clear()
	cover_tooltip_rect = Rect2()
	if model.state.battle == null: return
	for cover in model.terrain.defenses:
		var rect = cover_marker_rect(cover)
		if rect.has_area(): cover_regions[cover.id] = rect
	var hovered = hit_cover(pointer)
	if hovered.is_empty(): return
	var rect = cover_marker_rect(hovered)
	var width = minf(244, get_viewport().get_visible_rect().size.x - 12)
	cover_tooltip_rect = label_rect(Rect2(rect.position + Vector2(44, -16), Vector2(width, 66)))

func draw_cover_markers() -> void:
	if model.state.battle == null: return
	for cover in model.terrain.defenses:
		if not cover_regions.has(cover.id): continue
		var rect: Rect2 = cover_regions[cover.id]
		var occupant = visible_cover_occupant(cover)
		var color = Color("cbb779") if occupant.is_empty() else Color("82b4bf") if occupant.side == "player" else Color("d98978")
		var hovered = rect.has_point(pointer) and not input_blocked
		if hovered:
			var perimeter: Array = []
			for point in FieldCover.outline(cover): perimeter.append(FieldCover.world_point(cover, point))
			line_world(perimeter, color, 2)
		overlay.draw_line(project(FieldData.pos(cover), 8), Vector2(rect.get_center().x, rect.end.y), Color(color, 0.7), 1, true)
		overlay.draw_rect(rect, Color("293d37") if hovered else Color("182321"))
		overlay.draw_rect(rect, color, false, 2 if hovered else 1)
		overlay.draw_texture_rect(cover_icon, Rect2(rect.position + Vector2(8, 6), Vector2(20, 20)), false, color)
		if not occupant.is_empty() and occupant.side == "player":
			overlay.draw_rect(Rect2(rect.position + Vector2(4, 30), Vector2(28, 3)), Color("46514a"))
			overlay.draw_rect(Rect2(rect.position + Vector2(4, 30), Vector2(28 * occupant.coverDeploy / 4.0, 3)), color)
		if not hovered: continue
		var detail = cover_tooltip_rect
		if not detail.has_area(): continue
		var width = detail.size.x
		overlay.draw_rect(detail, Color("182321"))
		overlay.draw_rect(detail, color, false, 1)
		overlay.draw_string(font, detail.position + Vector2(10, 18), cover.name, HORIZONTAL_ALIGNMENT_LEFT, width - 20, 13, Color("f0e8d1"))
		overlay.draw_string(font, detail.position + Vector2(10, 37), cover_status(occupant), HORIZONTAL_ALIGNMENT_LEFT, width - 20, 11, color)
		overlay.draw_string(font, detail.position + Vector2(10, 55), "%d men / %d%% frontal protection" % [cover.capacity, roundi(cover.protection * 100)], HORIZONTAL_ALIGNMENT_LEFT, width - 20, 11, Color("c6cbc3"))

func prepare_campaign_preview() -> void:
	campaign_preview.clear()
	if right_start == null or model.state.mode != "campaign" or not FieldOperations.enabled(model.state): return
	var armies = model.campaign_selection()
	for i in armies.size():
		var army: Dictionary = armies[i]
		var path = FieldOperations.route(model.terrain, army, right_start + Vector2(0, i * FieldOperations.FORCE_SPACING))
		if path.is_empty(): continue
		var pace_factor = FieldOperations.recovery_pace(model.state, army)
		var hours = FieldOperations.travel_hours(model.terrain, army, path, pace_factor)
		var wait_hours = minf(maxf(0, army.retreatUntil - model.state.hours), FieldOperations.travel_hours(model.terrain, army, army.path, pace_factor)) if FieldOperations.forced_retreat(model.state, army) else maxf(0, army.get("pursuitUntil", 0.0) - model.state.hours)
		var fatigue = clampf(100 - army.condition + hours / FieldOperations.HOURS_PER_SECOND * FieldCampaign.MARCH_MODES[army.marchMode].fatigue, 0, 100)
		campaign_preview.append({"army": army, "path": path, "hours": hours + wait_hours, "wait_hours": wait_hours, "fatigue": fatigue})
	invalidate()

func draw_campaign_preview() -> void:
	if right_start == null or campaign_preview.is_empty(): return
	var lines: Array[String] = []
	for entry in campaign_preview:
		var points: Array = [FieldData.pos(entry.army)]
		for point in entry.path: points.append(FieldData.pos(point))
		line_world(points, FieldUI.GOLD, 1.5)
		circle_world(points.back(), 9, FieldUI.GOLD, 1.5)
		var detail = ("reforming first" if FieldOperations.pursuit_paused(model.state, entry.army) else "withdrawal first") if entry.wait_hours > 0 else "%d%% fatigue" % entry.fatigue
		lines.append("%s / %dh %02dm / %s" % [entry.army.name.left(20), int(entry.hours), int(fmod(entry.hours, 1) * 60), detail])
	var width = minf(310, get_viewport().get_visible_rect().size.x - 24)
	var rect = label_rect(Rect2(right_screen + Vector2(14, 15), Vector2(width, 12 + lines.size() * 18)))
	if not rect.has_area(): return
	town_label_regions.append(rect)
	overlay.draw_rect(rect, FieldUI.INK)
	overlay.draw_rect(rect, FieldUI.GOLD, false, 1)
	for i in lines.size(): overlay.draw_string(font, rect.position + Vector2(8, 18 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 16, 10, FieldUI.GOLD)

func order_preview() -> Array:
	if right_start == null or pointer.distance_to(right_screen) <= 8 or model.state.mode != "battle" or model.state.orderMode == "deploy":
		return []
	var endpoint = ground(pointer)
	if endpoint == null:
		return []
	if model.state.orderMode == "frontline":
		return model.frontline_placements(right_start, endpoint)
	return model.move_placements(right_start, (endpoint - right_start).angle())

func draw_order_preview() -> void:
	if model.state.mode == "campaign":
		draw_campaign_preview()
		return
	var placements = order_preview()
	if placements.is_empty():
		return
	var endpoint: Vector2 = ground(pointer)
	line_world([right_start, endpoint], Color("f1d28a"), 1.0, false, true)
	circle_world(right_start, 3.0, Color("f1d28a"), 1.5)
	for placement in placements:
		var u: Dictionary = placement.unit
		var center_point: Vector2 = placement.point
		var open = model.terrain.open_point(center_point, 2)
		if open != null: center_point = open
		var angle: float = placement.facing - PI / 2.0
		var bounds = FieldFormations.bounds(u)
		var corners: Array = []
		var screen = PackedVector2Array()
		for p in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			var corner: Vector2 = center_point + p.rotated(angle)
			corners.append(corner)
			screen.append(project(corner))
		var color = Color("f1d28a") if open != null and model.terrain.ground_passable(right_start) else Color("ed9281")
		overlay.draw_colored_polygon(screen, Color(color, 0.12))
		line_world(corners, color, 1.5, true, true)
		line_world([corners[2], corners[3]], color, 3.0, false, true)
		if not u.has("radius") and not u.get("kind", "") in ["general", "wagon"]:
			var slots = FieldFormations.offsets(u)
			for i in slots.size():
				if i in u.get("deadSlots", []): continue
				var slot: int = u.get("visualSlots", range(slots.size()))[i]
				overlay.draw_circle(project(center_point + slots[slot].rotated(angle)), 1.5, Color(color, 0.55))
		var front = center_point + Vector2(bounds.get_center().x, bounds.end.y).rotated(angle)
		var tip = front + Vector2(0, 20).rotated(angle)
		line_world([front, tip], color, 1.5, false, true)
		line_world([tip + Vector2(-5, -7).rotated(angle), tip, tip + Vector2(5, -7).rotated(angle)], color, 1.5, false, true)

func battle_label(u: Dictionary, p: Vector2, selected: bool, color: Color) -> void:
	var battle: Dictionary = model.state.battle
	var warning = ""
	if u.get("routed", false): warning = "Routing"
	elif u.get("retreating", false): warning = "Withdrawing"
	elif u.get("firePressureUntil", 0.0) > battle.time: warning = "Rear attack!" if u.firePressure == "rear" else "Flank attack!"
	elif u.get("charging", false): warning = "Charging"
	var diagnostics = show_ai and u.side == "enemy" and u.has("ai")
	var expanded = selected or diagnostics or not warning.is_empty()
	var label_width = 128.0 if expanded else 100.0
	var height = 47.0 if expanded else 35.0
	var top = p.y
	for region in selection_regions.get(u.id, []): top = minf(top, region.position.y)
	var rect = label_rect(Rect2(Vector2(p.x - label_width * 0.5, top - height - 6), Vector2(label_width, height)))
	if not rect.has_area(): return
	overlay.draw_line(p, Vector2(rect.get_center().x, rect.end.y), Color(color, 0.34), 1, true)
	if selected:
		overlay.draw_rect(rect, Color(0.055, 0.065, 0.055, 0.76))
		overlay.draw_line(rect.position, rect.position + Vector2(label_width, 0), FieldUI.GOLD, 1)
	else:
		overlay.draw_rect(Rect2(rect.position + Vector2(22, 0), Vector2(label_width - 22, 29)), Color(0.035, 0.045, 0.035, 0.22))
	FieldUI.pennant(overlay, Rect2(rect.position + Vector2(1, 2), Vector2(19, 25)), u.kind, u.side, selected)
	var strength = str(roundi(u.get("men", 0)))
	if u.kind == "general": strength = "Command"
	elif u.kind == "wagon": strength = "%d supply" % roundi(u.stock)
	var pulse = u.side == "enemy" and u.get("morale", 100) < 35 and sin(battle.time * 8) > 0
	var ink = Color.WHITE if pulse else FieldUI.TEXT
	var name: String = u.name
	while font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > label_width - 25 and name.length() > 3:
		name = name.left(-3) + ".."
	for row in [{"text": strength, "y": 12, "size": 12}, {"text": name, "y": 24, "size": 10}]:
		var point = rect.position + Vector2(23, row.y)
		overlay.draw_string_outline(font, point, row.text, HORIZONTAL_ALIGNMENT_LEFT, label_width - 25, row.size, 3, Color(0.04, 0.045, 0.035, 0.9))
		overlay.draw_string(font, point, row.text, HORIZONTAL_ALIGNMENT_LEFT, label_width - 25, row.size, ink)
	if expanded:
		var status = warning if not warning.is_empty() else "M %d / Fatigue %d" % [roundi(u.get("morale", 100)), roundi(100 - u.get("condition", 100))]
		if warning.is_empty() and u.kind == "artillery" and not str(u.get("blocked", "")).is_empty(): status = u.blocked
		if u.kind == "general": status = "Army command"
		elif u.kind == "wagon": status = "Supply train"
		if diagnostics and warning.is_empty(): status = "AI / " + u.ai.state.capitalize()
		while font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > label_width - 25 and status.length() > 3:
			status = status.left(-3) + ".."
		overlay.draw_string_outline(font, rect.position + Vector2(23, 36), status, HORIZONTAL_ALIGNMENT_LEFT, label_width - 25, 9, 3, Color(0.04, 0.045, 0.035, 0.9))
		overlay.draw_string(font, rect.position + Vector2(23, 36), status, HORIZONTAL_ALIGNMENT_LEFT, label_width - 25, 9, color if warning.is_empty() else FieldUI.GOLD)
	if u.has("morale"):
		for bar in [{"value": u.morale, "y": height - 7, "color": Color.WHITE if pulse else color}, {"value": u.condition, "y": height - 3, "color": FieldUI.FATIGUE}]:
			var bar_rect = Rect2(rect.position + Vector2(23, bar.y), Vector2(label_width - 26, 2))
			overlay.draw_rect(bar_rect, Color(0.07, 0.085, 0.07, 0.85))
			bar_rect.size.x *= clampf(bar.value / 100.0, 0, 1)
			overlay.draw_rect(bar_rect, bar.color)
	labels.append({"rect": rect, "entity": u})

func draw_overlay() -> void:
	var start = Time.get_ticks_usec()
	if not is_instance_valid(camera):
		return
	labels.clear()
	town_label_regions.clear()
	prepare_cover_markers()
	var size_value = get_viewport().get_visible_rect().size
	var battle = model.state.battle
	for flash in muzzle_flashes:
		var p = project(flash.p, 6)
		var radius = (3.2 if flash.cannon else 1.8) * clampf(zoom, 0.65, 2.2)
		overlay.draw_circle(p, radius, Color(1.0, 0.88, 0.5, 1.0 - flash.age / 0.12))
	if battle != null:
		var objective: Dictionary = model.terrain.field.objective
		circle_world(FieldData.pos(objective), objective.radius, Color(0.91, 0.79, 0.47, 0.45))
		if model.state.orderMode == "deploy":
			var x = model.terrain.deployment_limit(battle.playerEdge == "east")
			line_world([Vector2(x, 40), Vector2(x, model.terrain.map_size.y - 40)], Color("a9d1d7"), 2)
		var selected = model.selected_units()
		if show_ranges and not selected.is_empty() and right_start == null:
			draw_range(selected[0])
		for impact in battle.artilleryImpacts:
			if impact.visible:
				var age: float = battle.time - impact.time
				var color = Color("e9c373") if impact.hit else Color("e7e6d4")
				color.a = clampf(1.0 - age / 6, 0, 1)
				var shell = impact.get("kind", "roundshot") == "shell"
				circle_world(FieldData.pos(impact), (9.0 if shell else 4.0) + minf(age, 0.5) * (18.0 if shell else 5.0), color, 1.5)
				if shell and age < 0.65:
					var burst = project(FieldData.pos(impact), 6 + age * 18)
					overlay.draw_circle(burst, (3 + age * 9) * zoom, Color(0.88, 0.70, 0.42, (1 - age / 0.65) * 0.65))
	for town in model.terrain.towns:
		if model.terrain.campaign:
			var p = project(FieldData.pos(town), 35)
			if not Rect2(Vector2(0, ui_top), Vector2(size_value.x, size_value.y - ui_top - ui_bottom)).has_point(p): continue
			var name: String = town.get("name", "")
			if FieldOperations.enabled(model.state):
				var site = model.find_id(model.state.operation.sites, town.id)
				var site_color = FieldUI.BLUE if site.owner == "player" else FieldUI.RED if site.owner == "enemy" else FieldUI.GOLD
				circle_world(FieldData.pos(town), 65 if site.kind == "fort" else 40, site_color, 2)
				var symbol = FieldUI.icon("Shield" if site.kind == "fort" else "Truck" if site.kind == "depot" else "Flag")
				overlay.draw_texture_rect(symbol, Rect2(p + Vector2(-9, -47), Vector2(18, 18)), false, site_color)
				if site.progress > 0:
					overlay.draw_rect(Rect2(p + Vector2(-30, -25), Vector2(60, 3)), Color("333b39"))
					overlay.draw_rect(Rect2(p + Vector2(-30, -25), Vector2(60 * site.progress / (8 if site.kind == "fort" else 0.4), 3)), FieldUI.GOLD)
			var width = serif.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 8
			var rect = label_rect(Rect2(p - Vector2(width * 0.5, 22), Vector2(width, 24)))
			if rect.size == Vector2.ZERO: continue
			town_label_regions.append(rect)
			overlay.draw_string_outline(serif, rect.position + Vector2(4, 18), name, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 18, 3, Color(0.10, 0.15, 0.13, 0.8))
			overlay.draw_string(serif, rect.position + Vector2(4, 18), name, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 18, Color("f0e8d1"))
	draw_order_preview()
	for u in entities:
		var p = project(FieldData.pos(u), 8)
		if not Rect2(Vector2(0, ui_top), Vector2(size_value.x, size_value.y - ui_top - ui_bottom)).has_point(p):
			continue
		var selected = (u.id in model.state.selected and model.state.mode == "battle") or u.id == model.state.selectedCommander or (u.kind == "wagon" and u.side == "player" and model.state.selectedSupply) or (u.id in model.state.armySelection if model.state.mode == "campaign" and FieldOperations.enabled(model.state) else u.id == "army")
		var color = FieldUI.BLUE if u.side == "player" else FieldUI.RED
		if selected:
			circle_world(FieldData.pos(u), 34 if u.kind in ["general", "wagon", "army"] else 46, Color("eed18d"), 1.5)
			if u.kind == "army" and u.get("pendingOrder") != null and right_start == null:
				var destination = FieldData.pos(u.pendingOrder)
				circle_world(destination, 12, FieldUI.GOLD, 1.5)
				overlay.draw_texture_rect(FieldUI.icon("Flag"), Rect2(project(destination) - Vector2(9, 27), Vector2(18, 18)), false, FieldUI.GOLD)
		var path: Array = u.get("path", []).duplicate()
		if u.get("target") != null:
			path = [u.target] + u.get("waypoints", [])
		if (selected or (show_ai and u.side == "enemy")) and not path.is_empty() and right_start == null:
			var points = [FieldData.pos(u)]
			for node in path:
				points.append(FieldData.pos(node))
			line_world(points, Color(0.95, 0.83, 0.53, 0.7), 1.0)
			circle_world(points.back(), 6, Color("f0d593"))
			var direction: Vector2 = (points.back() - points[points.size() - 2]).normalized()
			line_world([points.back() - direction.rotated(0.5) * 15, points.back(), points.back() - direction.rotated(-0.5) * 15], Color("f0d593"), 1.5)
		if battle != null:
			battle_label(u, p, selected, color)
			continue
		var label_width = 138.0 if selected else 122.0
		var top = p.y
		for region in selection_regions.get(u.id, []): top = minf(top, region.position.y)
		var preferred = Rect2(Vector2(p.x - label_width / 2.0, top - 46), Vector2(label_width, 38))
		var rect = label_rect(preferred)
		if rect.size == Vector2.ZERO: continue
		overlay.draw_line(p, Vector2(rect.get_center().x, rect.end.y), Color(color, 0.45), 1, true)
		var background = Color(0.07, 0.09, 0.12, 0.86 if selected else 0.62)
		overlay.draw_rect(rect, background)
		if selected: overlay.draw_line(rect.position + Vector2(0, 38), rect.end, FieldUI.GOLD, 2)
		FieldUI.pennant(overlay, Rect2(rect.position + Vector2(4, 4), Vector2(21, 28)), u.kind, u.side, selected)
		var name = font.get_string_size(u.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var text = u.name
		while name.x > label_width - 36 and text.length() > 4:
			text = text.left(text.length() - 2)
			name = font.get_string_size(text + "..", HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		if text != u.name:
			text += ".."
		overlay.draw_string(font, rect.position + Vector2(31, 12), text, HORIZONTAL_ALIGNMENT_LEFT, label_width - 36, 10, FieldUI.TEXT)
		var status = "%d / F %d%%" % [roundi(u.get("men", 0)), roundi(100 - u.get("condition", 100.0))]
		if u.kind == "general":
			status = "Army command"
		elif u.kind == "wagon":
			status = "%d supplies" % roundi(u.stock)
		elif u.get("uncertain", false):
			status = "~%d reported" % roundi(u.men)
		elif u.kind == "army" and u.get("retreatUntil", 0.0) > model.state.hours:
			status = "Reforming" if FieldOperations.pursuit_paused(model.state, u) else "Withdrawing" if FieldOperations.forced_retreat(model.state, u) else "March / recovery" if not u.path.is_empty() else "Recover " + FieldOperations.regroup_time(model.state, u)
		elif u.get("routed", false):
			status = "Routing"
		elif u.get("retreating", false):
			status = "Retreat / F %d%%" % roundi(100 - u.condition)
		elif battle != null and u.get("firePressureUntil", 0.0) > battle.time:
			status = "Rear attack!" if u.firePressure == "rear" else "Flank attack!"
		elif u.get("charging", false):
			status = "Charge / %d%%" % roundi(FieldCharge.momentum(u) * 100)
		if show_ai and u.side == "enemy" and u.has("ai"):
			status = "AI / " + u.ai.state.capitalize()
		overlay.draw_string(font, rect.position + Vector2(31, 25), status, HORIZONTAL_ALIGNMENT_LEFT, label_width - 36, 9, color)
		if u.has("morale"):
			var pulse = battle != null and u.side == "enemy" and u.morale < 35 and sin(battle.time * 8) > 0
			overlay.draw_rect(Rect2(rect.position + Vector2(31, 30), Vector2(label_width - 36, 2)), Color("494d51"))
			overlay.draw_rect(Rect2(rect.position + Vector2(31, 30), Vector2((label_width - 36) * clampf(u.morale / 100.0, 0, 1), 2)), Color.WHITE if pulse else color)
			overlay.draw_rect(Rect2(rect.position + Vector2(31, 34), Vector2(label_width - 36, 2)), Color("494d51"))
			overlay.draw_rect(Rect2(rect.position + Vector2(31, 34), Vector2((label_width - 36) * clampf(u.condition / 100.0, 0, 1), 2)), FieldUI.FATIGUE)
		labels.append({"rect": rect, "entity": u})
		if battle != null and u.has("shotTime"):
			var age: float = battle.time - u.shotTime
			if age >= 0 and age < 2.0 and u.get("shotKind") != "melee":
				var muzzle = project(FieldData.pos(u) + Vector2.from_angle(u.facing) * 18, 12)
				if age < 0.20:
					overlay.draw_circle(muzzle, 4.0 if u.kind == "artillery" else 2.8, Color("fff1b0"))
	draw_cover_markers()
	if left_start != null and pointer.distance_to(left_start) > 8:
		var rect = Rect2(left_start, pointer - left_start).abs()
		overlay.draw_rect(rect, Color(0.7, 0.85, 0.9, 0.12))
		overlay.draw_rect(rect, Color("b8dfe4"), false)
	draw_micros = Time.get_ticks_usec() - start
