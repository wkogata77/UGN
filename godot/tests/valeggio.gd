extends SceneTree

var checks = 0
var failures: Array[String] = []
var world: FieldWorld
var hud: FieldHud
var model: FieldModel

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 6) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func click(point: Vector2, button: int) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func capture(name: String) -> Image:
	await frames()
	var result = root.get_texture().get_image()
	result.save_png("res://test-results/valeggio-" + name + ".png")
	var colors: Dictionary = {}
	var leaked = 0
	for y in range(180, result.get_height() - 180, 5):
		for x in range(5, result.get_width(), 5):
			var c = result.get_pixel(x, y)
			colors[Vector3i(c.r * 31, c.g * 31, c.b * 31)] = true
			if c.r > 0.7 and c.b > 0.6 and c.g < 0.35: leaked += 1
	check(colors.size() > 100, name + " contains rendered landscape and troops")
	check(leaked < 20, name + " has no keyed sprite leaks")
	for i in world.labels.size():
		var rect: Rect2 = world.labels[i].rect
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rect), name + " label stays within viewport")
		check(not world.label_obstacles.any(func(obstacle): return obstacle.intersects(rect)), name + " label avoids interface")
		for j in range(i + 1, world.labels.size()): check(not rect.intersects(world.labels[j].rect), name + " labels do not overlap")
	return result

func run() -> void:
	check(ResourceLoader.exists("res://assets/valeggio-meadow-v1.png"), "original meadow texture has been imported")
	model = FieldModel.new(false)
	model.start_battle("e1", true)
	model.state.battle.name = "The Valeggio Crossing"
	var terrain = model.terrain
	check(FieldValeggio.enabled(terrain), "bridge receives the benchmark treatment")
	var state_before = JSON.stringify(model.state)
	var buildings_before = terrain.buildings.duplicate(true)
	var before_paths: Array = []
	for crossing in terrain.crossings:
		var p = Vector2(terrain.channel_x(crossing), crossing)
		before_paths.append(terrain.route(p - Vector2(150, 0), p + Vector2(150, 0)))
	var parcels = FieldValeggio.plots(terrain)
	check(parcels.size() == 22, "expanded battlefield has 22 authored parcels")
	check(parcels == FieldValeggio.plots(terrain), "layout is deterministic")
	check(not FieldValeggio.lanes(terrain).is_empty(), "village streets connect existing buildings")
	if DisplayServer.get_name() == "headless":
		var mask = FieldValeggio.surface_map(terrain, parcels, FieldValeggio.lanes(terrain)).get_image()
		check(mask.get_size() == Vector2i(960, 640), "land use mask has fixed bounded resolution")
		var plot = parcels[0]
		var pixel = Vector2i(plot.rect.get_center() / terrain.map_size * Vector2(mask.get_size()))
		check(mask.get_pixelv(pixel).r > 0.9, "authored soil parcel reaches the ground shader")
		check(JSON.stringify(model.state) == state_before, "presentation does not mutate campaign or battle")
		print("GODOT VALEGGIO MODEL: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	root.size = Vector2i(1440, 900)
	world = FieldWorld.new()
	root.add_child(world)
	world.setup(model)
	check(world.ground_material.get_shader_parameter("meadow_texture") != null, "meadow texture is bound to the native ground")
	check(world.water_material.get_shader_parameter("surface_texture") != null, "water surface detail is bound")
	hud = FieldHud.new()
	root.add_child(hud)
	hud.setup(model, world, true)
	world.show_fog = false
	await frames(12)
	check(JSON.stringify(model.state) == state_before, "native scenery construction leaves battle state untouched")
	check(terrain.buildings == buildings_before, "house collision and LOS footprints are unchanged")
	check(world.scenery_fields.size() == 22, "renderer uses authored parcels instead of procedural tiles")
	check(world.scenery.get_children().filter(func(node): return node.has_meta("valeggio_bridge")).size() == 3, "all three crossings have arch bridges")
	for i in terrain.crossings.size():
		var p = Vector2(terrain.channel_x(terrain.crossings[i]), terrain.crossings[i])
		check(terrain.height_at(p) == 6.5, "new bridge retains saved traversable deck height")
		check(terrain.route(p - Vector2(150, 0), p + Vector2(150, 0)) == before_paths[i], "new scenery preserves crossing path")
	world.home()
	await capture("center")
	check(world.labels.any(func(label): return label.rect.size == Vector2(100, 35)), "unselected labels use compact dimensions")
	FieldBattleAI.initialize(model)
	world.show_ai = true
	world.invalidate()
	await frames()
	check(world.labels.any(func(label): return label.entity.side == "enemy" and label.rect.size.y == 47), "AI diagnostics retain an expanded intent row")
	world.show_ai = false
	world.invalidate()
	var water_time: float = world.water_material.get_shader_parameter("simulation_time")
	await frames(10)
	check(is_equal_approx(water_time, world.water_material.get_shader_parameter("simulation_time")), "river animation freezes while paused")
	world.overview()
	await capture("overview")
	world.center = Vector2(1440, 960)
	world.zoom = 2.6
	world.update_camera()
	await capture("bridge")
	world.center = Vector2(915, 405) + terrain.battle_offset
	world.zoom = 2.0
	world.update_camera()
	await capture("village")
	world.home()
	await frames()
	var unit: Dictionary = model.state.battle.units[0]
	var label: Array = world.labels.filter(func(item): return item.entity.id == unit.id)
	check(not label.is_empty(), "player label is visible and selectable")
	if not label.is_empty():
		await click(label[0].rect.get_center(), MOUSE_BUTTON_LEFT)
		check(unit.id in model.state.selected, "compact label still selects regiment")
	# Use the actual mouse order handler, then advance the simulation without saves.
	var destination = FieldData.pos(unit) + Vector2(0, 85)
	await click(world.project(destination), MOUSE_BUTTON_RIGHT)
	check(unit.target != null, "ground right click still issues movement")
	var position = FieldData.pos(unit)
	model.state.paused = false
	for i in 120: model.tick(1.0 / 30.0)
	model.state.paused = true
	check(FieldData.pos(unit).distance_to(position) > 3, "regiment moves with the benchmark scenery")
	model.publish(false)
	await capture("orders")
	check(world.water_material.get_shader_parameter("simulation_time") > water_time, "river animation advances with battle time")
	var samples: Array[float] = []
	var simulation_samples: Array[float] = []
	model.state.paused = false
	for i in 120:
		var start = Time.get_ticks_usec()
		world.remember_transforms()
		model.tick(1.0 / 60.0)
		simulation_samples.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	model.state.paused = true
	samples.sort()
	simulation_samples.sort()
	print("VALEGGIO FRAME SAMPLE: median %.2fms / p95 %.2fms / worst %.2fms" % [samples[60], samples[114], samples.back()])
	print("VALEGGIO SIMULATION SAMPLE: median %.2fms / p95 %.2fms / worst %.2fms" % [simulation_samples[60], simulation_samples[114], simulation_samples.back()])
	root.size = Vector2i(390, 900)
	await frames()
	world.home()
	hud.build()
	await capture("narrow")
	# Legacy saves receive the presentation without migrating soldiers or geography.
	for entity in model.state.battle.units + model.state.battle.commanders + model.state.battle.wagons:
		entity.x -= FieldBattlefield.OFFSET.x
		entity.y -= FieldBattlefield.OFFSET.y
		if entity.has("weapon"):
			model.stop_unit(entity)
			model.formations.reset(entity)
	model.state.battle.mapVersion = 1
	terrain.configure(model.state)
	check(FieldValeggio.plots(terrain).size() == 11, "legacy battlefield uses the original-area parcels")
	world.sync_map()
	root.size = Vector2i(1440, 900)
	world.home()
	await capture("legacy")
	for scenario in ["village", "ridge"]:
		model.state.battle.scenario = scenario
		model.state.battle.name = "Saint Martin" if scenario == "village" else "The Heights"
		terrain.configure(model.state)
		world.sync_map()
		world.home()
		hud.build()
		check(not FieldValeggio.enabled(terrain), scenario + " retains its existing landscape treatment")
		check(not world.ground_material.get_shader_parameter("valeggio"), scenario + " does not enable Valeggio ground shading")
		await capture(scenario + "-control")
	hud.queue_free()
	world.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	await process_frame
	print("GODOT VALEGGIO VISUAL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
