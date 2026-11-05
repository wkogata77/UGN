class_name FieldFortificationArt
extends RefCounted

static func material(color: Color, texture: String = "") -> Material:
	var result = ShaderMaterial.new()
	result.shader = load("res://shaders/fortification.gdshader")
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("masonry", texture == "stone")
	result.set_shader_parameter("wicker", texture == "wicker")
	result.set_shader_parameter("timber", texture == "timber")
	result.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
	return result

static func batch(world, parent: Node3D, name: String, mesh: Mesh, surface: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty(): return
	var instance = world.make_batch(mesh, surface, transforms.size())
	instance.name = name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in transforms.size(): instance.multimesh.set_instance_transform(i, transforms[i])
	instance.multimesh.visible_instance_count = transforms.size()
	parent.add_child(instance)

static func block(world, cover: Dictionary, p: Vector2, size_value: Vector3, angle: float = 0.0, lift: float = 0.0) -> Transform3D:
	var point = FieldCover.world_point(cover, p)
	var rotation = cover.facing - PI / 2 + angle
	var basis_value = Basis(Vector3.UP, -rotation) * Basis.from_scale(size_value)
	var height = world.model.terrain.height_at(point) + size_value.y / 2 + lift
	return Transform3D(basis_value, Vector3(point.x, height, point.y))

static func ground_strip(world, parent: Node3D, cover: Dictionary, outline: Array[Vector2], earth: bool) -> void:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cross-sections follow relief; the earth parapet is a bank, not a floating wall.
	var section = [Vector2(-6, 0.2), Vector2(-3.5, 4.6), Vector2(3, 4.9), Vector2(12, 0.2)] if earth else [Vector2(-10, 0.16), Vector2(10, 0.16)]
	for i in outline.size() - 1:
		var a = outline[i]
		var b = outline[i + 1]
		var tangent = (b - a).normalized()
		var normal = Vector2(-tangent.y, tangent.x)
		var start_normal = normal
		var end_normal = normal
		if i > 0:
			var previous = (a - outline[i - 1]).normalized()
			start_normal = (normal + Vector2(-previous.y, previous.x)).normalized()
			start_normal /= maxf(0.4, start_normal.dot(normal))
		if i + 2 < outline.size():
			var next = (outline[i + 2] - b).normalized()
			end_normal = (normal + Vector2(-next.y, next.x)).normalized()
			end_normal /= maxf(0.4, end_normal.dot(normal))
		var steps = ceili(a.distance_to(b) / 5)
		for step in steps:
			for band in section.size() - 1:
				for vertex in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
					var cross: Vector2 = section[band + vertex.y]
					var local = (a + start_normal * cross.x).lerp(b + end_normal * cross.x, float(step + vertex.x) / steps)
					var point = FieldCover.world_point(cover, local)
					tool.set_uv(Vector2(float(step + vertex.x) / steps, (cross.x + 12) / 24))
					tool.add_vertex(Vector3(point.x, world.model.terrain.height_at(point) + cross.y, point.y))
	tool.generate_normals()
	var instance = MeshInstance3D.new()
	instance.name = "EarthParapet" if earth else "WornGround"
	instance.mesh = tool.commit()
	if earth:
		instance.material_override = material(Color("474532"))
	else:
		var surface = ShaderMaterial.new()
		surface.shader = load("res://shaders/road.gdshader")
		surface.set_shader_parameter("ground_texture", FieldArt.texture("terrain-v2"))
		instance.material_override = surface
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if earth else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

static func build(world, cover: Dictionary) -> void:
	var parent = Node3D.new()
	parent.name = "Defense-" + cover.id
	world.scenery.add_child(parent)
	var outline = FieldCover.outline(cover)
	ground_strip(world, parent, cover, outline, cover.kind == "earth")
	var cube = BoxMesh.new()
	cube.size = Vector3.ONE
	var blocks: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var brush: Array[Transform3D] = []
	var gabions: Array[Transform3D] = []
	for i in outline.size() - 1:
		var a = outline[i]
		var b = outline[i + 1]
		var tangent = (b - a).normalized()
		var normal = Vector2(-tangent.y, tangent.x)
		var distance = a.distance_to(b)
		var count = ceili(distance / (6 if cover.kind == "stone" else 8))
		for j in count:
			var p = a.lerp(b, (j + 0.5) / count)
			var seed_value = float(i * 47 + j * 13)
			if cover.kind == "stone":
				var height = 3.6 + sin(seed_value) * 0.2
				blocks.append(block(world, cover, p, Vector3(distance / count + 0.3, height, 4.4), tangent.angle()))
				caps.append(block(world, cover, p, Vector3(distance / count + 0.5, 0.85, 5.2), tangent.angle(), height))
			elif cover.kind == "hedge":
				posts.append(block(world, cover, p, Vector3(1.0, 4.2, 1.0)))
				blocks.append(block(world, cover, p, Vector3(distance / count + 0.4, 0.65, 0.6), tangent.angle(), 2.4))
				var point = FieldCover.world_point(cover, p + normal * sin(seed_value) * 1.2)
				var basis_value = Basis(Vector3.RIGHT, -world.CAMERA_PITCH) * Basis.from_scale(Vector3(13 + sin(seed_value) * 2, 8 + cos(seed_value) * 1.2, 1))
				brush.append(Transform3D(basis_value, Vector3(point.x, world.scenery_support(point, basis_value), point.y)))
			else:
				blocks.append(block(world, cover, p - normal * 4.2, Vector3(distance / count + 0.2, 2.8, 1.1), tangent.angle()))
				posts.append(block(world, cover, p - normal * 5, Vector3(1.1, 3.7, 1.1)))
				if j % 3 == 0:
					gabions.append(block(world, cover, p + normal * 0.7, Vector3(4.4, 4.3, 4.4), 0, 3.8))
	if cover.kind == "stone":
		for p in [outline[0], outline[-1]]:
			posts.append(block(world, cover, p, Vector3(5.6, 5.5, 5.6)))
	batch(world, parent, "Masonry" if cover.kind == "stone" else "Timber", cube, material(Color("606459"), "stone") if cover.kind == "stone" else material(Color("483e30"), "timber"), blocks)
	batch(world, parent, "Coping", cube, material(Color("777a6c"), "stone"), caps)
	batch(world, parent, "Piers" if cover.kind == "stone" else "Posts", cube, material(Color("5f6256"), "stone") if cover.kind == "stone" else material(Color("504330"), "timber"), posts)
	if not brush.is_empty():
		var quad = QuadMesh.new()
		quad.size = Vector2.ONE
		var surface = StandardMaterial3D.new()
		surface.albedo_texture = FieldArt.scenery_texture("woodland-v3", 5)
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		surface.alpha_scissor_threshold = 0.18
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.albedo_color = Color("d1d5bc")
		batch(world, parent, "Hedgerow", quad, surface, brush)
	if not gabions.is_empty():
		var basket = CylinderMesh.new()
		basket.top_radius = 0.5
		basket.bottom_radius = 0.44
		basket.height = 1.0
		basket.radial_segments = 10
		batch(world, parent, "Gabions", basket, material(Color("655e46"), "wicker"), gabions)
