extends SceneTree

var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func frames() -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw

func right_click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames()

func capture(name: String, world: FieldWorld, center: Vector2, zoom: float) -> void:
	world.center = center
	world.zoom = zoom
	world.update_camera()
	await frames()
	root.get_texture().get_image().save_png("res://test-results/grand-landscape-" + name + ".png")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var m = FieldBattleExercises.create(20)
	check(m.valid_state(m.state), "grand exercise has valid complete state")
	check(m.terrain.map_size == Vector2(5760, 3840) and m.terrain.crossings.size() == 5, "new battle has four times the area and five crossings")
	check(m.state.battle.units.all(func(u): return m.terrain.order_bounds(0).has_point(FieldData.pos(u))), "every formation and reserve starts inside expanded bounds")
	if not "--visual" in OS.get_cmdline_user_args():
		await rules_checks(m)
	if "--visual" in OS.get_cmdline_user_args():
		var world = FieldWorld.new()
		root.add_child(world)
		world.setup(m)
		world.input_blocked = true
		var hud = FieldHud.new()
		root.add_child(hud)
		hud.setup(m, world, true)
		var center = m.terrain.map_size * 0.5
		await capture("command", world, center - Vector2(350, 0), 0.85)
		await capture("village", world, FieldData.pos(m.terrain.towns[0]), 1.8)
		await capture("ridges", world, Vector2(1030, 650), 0.8)
		check(is_equal_approx(rad_to_deg(world.camera_pitch), 35), "battlefield starts at an oblique 35-degree camera angle")
		var lower: Button
		for control in hud.tools.get_children():
			if control is Button and control.tooltip_text == "Lower camera angle / Q": lower = control
		check(lower != null, "camera angle has a visible control")
		if lower != null: lower.pressed.emit()
		await frames()
		check(is_equal_approx(rad_to_deg(world.camera_pitch), 30), "camera control actually lowers the view")
		var unit: Dictionary = m.state.battle.units[0]
		unit.x = 2580
		unit.y = 1800
		m.formations.reset(unit)
		for angle in [28.0, 35.0, 50.0, 60.0]:
			world.adjust_pitch(angle - rad_to_deg(world.camera_pitch))
			await capture("tilt-" + str(int(angle)), world, FieldData.pos(unit), 2.3)
			var point = Vector2(m.terrain.channel_x(1920), 1920)
			check(world.ground(world.project(point)).distance_to(point) < 0.1, "terrain picking remains accurate at %.0f degrees" % angle)
			var regions = world.drawn_regions(unit.id)
			check(not regions.is_empty() and world.hit_entity(regions[regions.size() / 2].get_center()).get("id") == unit.id, "rendered unit remains selectable at %.0f degrees" % angle)
			world.input_blocked = false
			m.select([unit.id])
			var destination = FieldData.pos(unit) + Vector2(-65, -35)
			await right_click(world.project(destination))
			check(unit.goal != null and FieldData.pos(unit.goal).distance_to(destination) < 0.2, "native right click gives precise movement at %.0f degrees" % angle)
			world.input_blocked = true
		world.adjust_pitch(35 - rad_to_deg(world.camera_pitch))
		world.input_blocked = false
		var key = InputEventKey.new()
		key.keycode = KEY_Q
		key.pressed = true
		Input.parse_input_event(key)
		await frames()
		world._process(0.1)
		var release = key.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		await frames()
		check(rad_to_deg(world.camera_pitch) < 35, "Q key lowers camera while battle is paused")
		world.input_blocked = true
		world.adjust_pitch(35 - rad_to_deg(world.camera_pitch))
		# Each alternate scene must own the viewport by itself. Two worlds under
		# the same viewport otherwise combine terrain, lights and overlay labels.
		root.remove_child(world)
		hud.hide()
		for scenario in ["village", "ridge"]:
			var exercise = FieldModel.new(false)
			exercise.start_battle("e1", true)
			exercise.state.battle.scenario = scenario
			exercise.state.battle.name = "Saint Martin" if scenario == "village" else "The Heights"
			exercise.terrain.configure(exercise.state)
			exercise.prepare_deployment()
			var alternate = FieldWorld.new()
			root.add_child(alternate)
			alternate.setup(exercise)
			alternate.input_blocked = true
			var alternate_hud = FieldHud.new()
			root.add_child(alternate_hud)
			alternate_hud.setup(exercise, alternate, true)
			await capture(scenario + "-field", alternate, FieldData.pos(exercise.terrain.field.objective), 0.85)
			check(alternate.scenery_trees.size() > 100 and alternate.scenery_buildings.size() > 50, scenario + " shares complete environment presentation")
			alternate_hud.queue_free()
			alternate.queue_free()
			await process_frame
		root.add_child(world)
		hud.show()
		world.camera.current = true
		world.overview()
		await frames()
		root.get_texture().get_image().save_png("res://test-results/grand-landscape-overview.png")
		check(world.landscape_shadows != null and world.ground_material.get_shader_parameter("cultivated_map") != null, "whole battlefield has land use and static canopy shading")
		var root_position = m.terrain.towns[0]
		var p = FieldData.pos(root_position)
		var basis = Basis(Vector3.RIGHT, -FieldWorld.CAMERA_PITCH) * Basis.from_scale(Vector3(40, 50, 1))
		var foot = world.scenery_transform(p, basis) * Vector3(0, -0.5, 0)
		check(Vector2(foot.x, foot.z).distance_to(p) < 0.01 and absf(foot.y - m.terrain.height_at(p) - 0.45) < 0.01, "scenery feet meet their true terrain root instead of floating above it")
		hud.queue_free()
		world.queue_free()
		await process_frame
		m = FieldModel.new(false)
		m.new_campaign("mantua")
		check(m.terrain.map_size == Vector2(17280, 11520) and m.valid_state(m.state), "expanded campaign validates")
		world = FieldWorld.new()
		root.add_child(world)
		world.setup(m)
		world.input_blocked = true
		hud = FieldHud.new()
		root.add_child(hud)
		hud.setup(m, world, false)
		await capture("campaign", world, FieldData.pos(m.state.army) + Vector2(250, -130), 0.65)
		check(is_equal_approx(rad_to_deg(world.camera_pitch), 35), "campaign shares the oblique camera")
		world.input_blocked = false
		await right_click(world.project(FieldData.pos(m.state.army) + Vector2(100, 0)))
		check(not m.state.army.path.is_empty(), "campaign native right click still queues a march at the lower angle")
		world.input_blocked = true
		world.overview()
		await frames()
		root.get_texture().get_image().save_png("res://test-results/grand-landscape-campaign-overview.png")
		hud.queue_free()
		world.queue_free()
		await process_frame
	print("GODOT GRAND LANDSCAPE: %d checks, %d failures" % [checks, failures.size()])
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	quit(0 if failures.is_empty() else 1)

func rules_checks(m: FieldModel) -> void:
	var roads_agree = true
	for i in 240:
		var p = Vector2(fposmod(i * 971.7, m.terrain.map_size.x), fposmod(i * 613.1, m.terrain.map_size.y))
		for limit in [7.0, 24.0, 64.0, 300.0]:
			roads_agree = roads_agree and is_equal_approx(m.terrain.road_distance(p, limit), minf(limit, m.terrain.road_distance(p)))
	check(roads_agree, "spatial road queries agree with an exact full-segment scan at multiple radii")
	var same = FieldTerrain.new()
	same.configure(m.state)
	var crest = FieldData.pos(m.terrain.field.hills[0])
	var height = same.height_at(crest)
	m.terrain.relief = 0
	check(is_equal_approx(same.height_at(crest), height) and is_zero_approx(m.terrain.height_at(crest)), "cached height surfaces remain isolated between models and relief settings")
	m.terrain.relief = 1
	for scenario in ["bridge", "village", "ridge"]:
		m.state.battle.scenario = scenario
		m.state.battle.erase("battlePolish")
		m.terrain.configure(m.state)
		check(m.terrain.field.towns.size() >= 9 and m.terrain.field.hills.size() >= 10, scenario + " has populated approach districts and ridges")
		var u: Dictionary = m.state.battle.units[0]
		for other in m.state.battle.units: other.arrival = 99999
		u.arrival = 0
		u.x = 500
		u.y = 1500
		u.facing = 0
		u.target = null
		m.formations.reset(u)
		check(m.path_unit(u, Vector2(1000, 1500)), scenario + " outer district accepts a real route")
		var previous = FieldData.pos(u)
		m.tactics.walk(m, u, 0.1, 25)
		check(FieldData.pos(u).distance_to(previous) > 0, scenario + " troop moves outside the former battle boundaries")
	# Save/load must keep an already active smaller battle in place.
	var legacy = FieldModel.new(false)
	legacy.start_battle("e1", true, 2)
	var old_position = FieldData.pos(legacy.state.battle.units[0])
	check(legacy.save_campaign("user://test-grand-legacy.json"), "legacy battle snapshot saves")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-grand-legacy.json") and restored.terrain.map_size == FieldBattlefield.STANDARD_SIZE, "active version-2 battle keeps its physical dimensions")
	check(FieldData.pos(restored.state.battle.units[0]).is_equal_approx(old_position), "existing battle figures retain their exact coordinates")
	for kind in ["infantry", "cavalry", "artillery"]:
		for crossing in FieldBattlefield.crossings_for({"mapVersion": 3}):
			for direction in [1.0, -1.0]: crossing_check(kind, crossing, direction)

func crossing_check(kind: String, y: float, direction: float) -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.terrain.buildings.clear()
	for other in m.state.battle.units: other.arrival = 99999
	var u: Dictionary = m.state.battle.units[0]
	u.merge({"kind": kind, "men": 360.0 if kind == "infantry" else 144.0 if kind == "cavalry" else 90.0, "startMen": 360.0 if kind == "infantry" else 144.0 if kind == "cavalry" else 90.0, "arrival": 0.0, "formation": "line", "formationChange": null, "holdFire": true, "target": null, "waypoints": []}, true)
	u.weapon = "cannon" if kind == "artillery" else "sabre" if kind == "cavalry" else "musket"
	var bridge = Vector2(m.terrain.channel_x(y), y)
	u.x = bridge.x - direction * 165
	u.y = y
	u.facing = 0.0 if direction > 0 else PI
	m.formations.reset_roster(u)
	m.formations.reset(u)
	var destination = bridge + Vector2(direction * 190, 0)
	var accepted = m.path_unit(u, destination)
	var dry = true
	var radius = FieldFormations.figure_radius(u)
	for i in 600:
		m.state.battle.time += 0.1
		m.tactics.walk(m, u, 0.1, 24)
		m.formations.advance([u], m.state.battle.time, 0.1, [], m.terrain)
		for soldier in m.formations.positions(u):
			if soldier.alive:
				dry = dry and m.terrain.figure_ground_clear(soldier.p, radius) and m.terrain.figure_ground_clear(soldier.previous.lerp(soldier.p, 0.5), radius)
	check(accepted and dry and FieldData.pos(u).distance_to(destination) < 0.1, "%s crosses %.0f in direction %.0f without stepping or interpolating into water" % [kind, y, direction])
