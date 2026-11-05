extends Node

var app
var failures: Array = []
var captures: Array = []
var checks = 0
var output = "res://test-results"
var performance: Dictionary = {}
var expansion_completed = false
var melee_completed = false
var orders_completed = false
var polish_completed = false
var animation_completed = false
var ai_completed = false

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error("FAIL: " + text)

func frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> Image:
	await frames()
	var image = get_viewport().get_texture().get_image()
	image.save_png(output + "/" + name + ".png")
	var colors: Dictionary = {}
	var magenta = 0
	# Dimmed modal captures need finer bins to retain their visible dark shading.
	var color_steps = 127 if is_instance_valid(app.hud.modal) else 31
	for y in range(80, image.get_height() - 100, 4):
		for x in range(4, image.get_width() - 4, 4):
			var c = image.get_pixel(x, y)
			colors[Vector3i(int(c.r * color_steps), int(c.g * color_steps), int(c.b * color_steps))] = true
			if c.r > 0.7 and c.b > 0.6 and c.g < 0.35:
				magenta += 1
	check(colors.size() > 100, name + " has rendered image content")
	check(magenta < 20, name + " has no chroma-key leaks")
	if name in ["campaign-desktop", "campaign-mobile", "battle-desktop", "battle-mobile"]:
		var overlap = false
		var covered = false
		for i in app.world.labels.size():
			var rect: Rect2 = app.world.labels[i].rect
			for j in range(i + 1, app.world.labels.size()):
				overlap = overlap or rect.intersects(app.world.labels[j].rect)
			covered = covered or app.world.label_obstacles.any(func(obstacle): return rect.intersects(obstacle))
		check(not overlap, name + " has nonoverlapping unit labels")
		check(not covered, name + " labels avoid interface panels")
	captures.append({"name": name, "size": [image.get_width(), image.get_height()], "colors": colors.size(), "magenta": magenta, "troops": app.world.sprite_count, "drawCalls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
	return image

func click(p: Vector2, mouse_button: int) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = p
		event.global_position = p
		event.button_index = mouse_button
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

func button(root: Node, match_text: String) -> Button:
	if root is Button and (root.text == match_text or root.tooltip_text == match_text):
		return root
	for child in root.get_children():
		var found = button(child, match_text)
		if found != null: return found
	return null

func press(match_text: String) -> void:
	var target = button(app.hud.root, match_text)
	check(target != null, "button exists: " + match_text)
	if target != null:
		target.pressed.emit()
	await frames()

func advance(seconds: float) -> void:
	app.model.state.paused = false
	for i in ceili(seconds * 60):
		app.model.tick(1.0 / 60.0)
	app.model.state.paused = true
	app.model.publish(false)
	await frames()

func run(main) -> void:
	app = main
	DirAccess.make_dir_recursive_absolute(output)
	await frames(10)
	get_window().size = Vector2i(1440, 900)
	await get_tree().create_timer(0.4).timeout
	await frames(10)
	check(get_viewport().get_visible_rect().size == Vector2(1440, 900), "desktop viewport dimensions")
	if "--verify-maps" in OS.get_cmdline_user_args():
		await large_map_checks()
		print("GODOT LARGE MAPS VISUAL: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-animation" in OS.get_cmdline_user_args():
		await animation_checks()
		await infantry_walk_checks()
		await melee_checks()
		await expansion_checks()
		await animation_transition_checks()
		check(animation_completed and melee_completed and expansion_completed, "focused animation exercises completed")
		print("GODOT ANIMATION: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-theme" in OS.get_cmdline_user_args():
		await theme_checks()
		print("GODOT THEME: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-slopes" in OS.get_cmdline_user_args():
		await slope_checks()
		app.world.home()
		await frames(12)
		await expansion_checks()
		print("GODOT SLOPES: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-campaign" in OS.get_cmdline_user_args():
		await campaign_checks()
		print("GODOT CAMPAIGN VISUAL: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-ai" in OS.get_cmdline_user_args():
		await ai_checks()
		check(ai_completed, "battle-AI exercise checks completed")
		print("GODOT AI VISUAL: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--verify-cover" in OS.get_cmdline_user_args():
		await polish_checks()
		check(polish_completed, "focused fortification checks completed")
		print("GODOT FORTIFICATIONS: %d checks, %d failures" % [checks, failures.size()])
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	art_checks()
	await capture("campaign-desktop")
	check(app.world.sprite_count > 0, "campaign army sprites visible")
	await depth_checks("campaign")
	await scenery_checks("campaign")
	await camera_checks()
	var army_point = app.world.selection_regions.army[0].get_center()
	await click(army_point, MOUSE_BUTTON_LEFT)
	check(is_instance_valid(app.hud.inspector), "left-click inspects army")
	await press("Close unit information")
	var destination = FieldData.pos(app.model.state.army) + Vector2(180, 3)
	await click(app.world.project(destination), MOUSE_BUTTON_RIGHT)
	check(not app.model.state.army.path.is_empty(), "right-click orders campaign march")
	var army_x: float = app.model.state.army.x
	await advance(3)
	check(app.model.state.army.x > army_x, "campaign army moves")
	check(app.world.campaign_gaits.army.moving > 0, "campaign infantry gait follows actual displacement")
	var march_phase: float = app.world.campaign_gaits.army.phase
	await frames(10)
	check(app.world.campaign_gaits.army.phase == march_phase and app.world.campaign_gaits.army.moving > 0, "paused campaign preserves marching pose")
	var campaign_state = JSON.stringify(app.model.state)
	app.start_skirmish("bridge")
	await frames(10)
	await capture("battle-desktop")
	check(app.world.sprite_count > 100, "battle regiments render")
	await depth_checks("battle")
	await scenery_checks("battle")
	var unit: Dictionary = app.model.state.battle.units[0]
	app.model.select([unit.id])
	await press("Column formation")
	check(unit.formationChange != null and unit.formation == "line", "formation toolbar gives timed order")
	app.model.move_units(Vector2(570, 370))
	await advance(4)
	check(unit.x > 490 and unit.formationChange.elapsed > 0, "formation and movement animate")
	app.world.center = FieldData.pos(unit)
	app.world.zoom = 4.0
	app.world.update_camera()
	await capture("battle-close-moving")
	var a = Vector2(530, 390)
	var b = Vector2(570, 435)
	var a_screen = app.world.project(a)
	var b_screen = app.world.project(b)
	app.world.issue_order(a_screen, b_screen, true)
	check(FieldData.pos(unit.goal).distance_to(a) < 0.5, "drag destination anchored at press point")
	check(absf(angle_difference(unit.desiredFacing, (b - a).angle())) < 0.01, "drag faces release point")
	await placement_checks()
	var was_center = app.world.center
	var key = InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.2).timeout
	key.pressed = false
	Input.parse_input_event(key)
	check(app.world.center.x > was_center.x, "WASD pans camera")
	app.world.home()
	app.model.select(["u5"])
	await press("Limber / deploy guns")
	check(app.model.selected_units()[0].limberChange > 0, "artillery action wired")
	app.model.select_commander("general")
	check(app.model.state.selectedCommander == "general", "general selectable")
	await capture("battle-command")
	app.resume_campaign()
	await frames(8)
	check(JSON.stringify(app.model.state) == campaign_state, "exercise leaves campaign untouched")
	await press("Army headquarters")
	check(is_instance_valid(app.hud.hq), "headquarters opens")
	await capture("headquarters-army-desktop")
	await commander_checks()
	await press("Armory")
	await capture("headquarters-armory-desktop")
	var cash: float = app.model.state.cash
	await press("Buy reserve weapons")
	check(app.model.state.cash < cash, "native armory purchase works")
	await press("Officers")
	await capture("headquarters-officers-desktop")
	await press("Return to map")
	await press("Settings and saves")
	await capture("settings-desktop")
	await press("Close")
	get_window().size = Vector2i(390, 844)
	await get_tree().create_timer(0.4).timeout
	await frames(15)
	await capture("campaign-mobile")
	check(app.world.camera.size > 0 and app.world.sprite_count > 0, "mobile campaign framed")
	await press("Army headquarters")
	await capture("headquarters-army-mobile")
	await press("Armory")
	await capture("headquarters-armory-mobile")
	await press("Officers")
	await capture("headquarters-officers-mobile")
	await press("Return to map")
	app.start_skirmish("bridge")
	await frames(10)
	await capture("battle-mobile")
	app.world.right_start = Vector2(630, 400)
	app.world.right_screen = app.world.project(app.world.right_start)
	app.world.pointer = app.world.project(Vector2(665, 425))
	app.model.select(["u1", "u2"])
	app.world.invalidate()
	await capture("battle-mobile-facing")
	check(app.world.order_preview().size() == 2, "mobile viewport retains both formation previews")
	app.world.right_start = null
	app.model.select(["u1"])
	app.world.zoom = 6
	app.world.center_entity(app.model.state.battle.units[0])
	await capture("battle-mobile-6x")
	check(app.world.zoom == 6, "6x battle zoom")
	var before = get_viewport().get_texture().get_image().get_data()
	await frames(10)
	check(before == get_viewport().get_texture().get_image().get_data(), "pause freezes scene pixels")
	get_window().size = Vector2i(1440, 900)
	await frames(10)
	for scenario in ["village", "ridge"]:
		app.start_skirmish(scenario)
		await frames(10)
		await capture("battle-" + scenario)
		await advance(8)
		check(app.model.state.battle != null and app.model.state.battle.time > 0, scenario + " simulation runs")
	app.model.finish_battle(true)
	await frames(10)
	await capture("battle-report")
	check(app.model.state.report != null, "battle report opens")
	await animation_checks()
	check(animation_completed, "animation verification completed without script errors")
	await infantry_walk_checks()
	await expansion_checks()
	check(expansion_completed, "expanded native verification completed without script errors")
	await melee_checks()
	check(melee_completed, "melee verification completed without script errors")
	await battle_order_checks()
	check(orders_completed, "battle order verification completed without script errors")
	await polish_checks()
	check(polish_completed, "polish verification completed without script errors")
	app.resume_campaign()
	await ai_checks()
	check(ai_completed, "battle AI verification completed without script errors")
	await town_movement_checks()
	await performance_check()
	await campaign_checks()
	await theme_checks()
	await slope_checks()
	var file = FileAccess.open(output + "/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures, "performance": performance, "renderer": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_current_rendering_method()}, "  "))
	file.close()
	print("GODOT VISUAL: %d checks, %d failures, %d captures" % [checks, failures.size(), captures.size()])
	for failure in failures: print("FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func town_movement_checks() -> void:
	app.start_skirmish("village")
	var m: FieldModel = app.model
	m.state.battle.aiClock = -10000
	for other in m.state.battle.units: other.arrival = 99999
	var u: Dictionary = m.state.battle.units[0]
	u.merge({"x": 530.0, "y": 270.0, "facing": 0.0, "arrival": 0.0, "holdFire": true}, true)
	m.formations.reset(u)
	m.select([u.id])
	app.world.center = Vector2(670, 350)
	app.world.zoom = 3
	app.world.show_fog = false
	app.world.update_camera()
	await frames()
	var destination = FieldData.pos(m.terrain.towns[0])
	await click(app.world.project(destination), MOUSE_BUTTON_RIGHT)
	check(u.target != null and FieldData.pos(u.goal).distance_to(destination) < 24, "native right-click on town routes to nearby street")
	await advance(22)
	check(u.x > 600, "native town order advances the regiment")
	await capture("battle-town-march")
	await advance(70)
	check(u.target == null and FieldData.pos(u).distance_to(FieldData.pos(u.goal)) < 0.1, "native town order arrives without a grid-point reversal")
	check(m.formations.positions(u).all(func(soldier): return not m.terrain.buildings.any(func(b): return b.rect.has_point(soldier.p))), "arrived figures remain outside building footprints")
	await capture("battle-town-arrived")
	get_window().size = Vector2i(390, 844)
	await frames(12)
	await capture("battle-town-mobile")
	get_window().size = Vector2i(1440, 900)
	await frames(12)

func art_checks() -> void:
	for type in 2:
		var atlas = FieldArt.infantry_texture(type)
		check(atlas == FieldArt.infantry_texture(type), "infantry walking atlas is cached " + str(type))
		var pixels = atlas.get_image()
		check(pixels.get_size() == FieldArt.INFANTRY_CELL * 3, "registered infantry atlas dimensions " + str(type))
		for row in 3:
			for frame in 3:
				var region = pixels.get_region(Rect2i(Vector2i(frame, row) * FieldArt.INFANTRY_CELL, FieldArt.INFANTRY_CELL))
				var bounds = region.get_used_rect()
				check(bounds.size.y > 390 and bounds.position.x > 8 and bounds.end.x < region.get_width() - 8 and bounds.position.y > 8 and bounds.end.y < region.get_height() - 8, "infantry frame has complete keyed silhouette %d/%d/%d" % [type, row, frame])
	for name in ["woodland-v2", "architecture-v2", "smoke-v2"]:
		var image = FieldArt.texture(name).get_image()
		var clear = 0
		var solid = 0
		var samples = 0
		for y in range(0, image.get_height(), 8):
			for x in range(0, image.get_width(), 8):
				var a = image.get_pixel(x, y).a
				if a < 0.05: clear += 1
				if a > 0.4: solid += 1
				samples += 1
		check(clear > samples * 0.25 and solid > samples * 0.04, name + " contains real alpha cutouts and visible artwork")
		check(image.get_width() == 1536 and image.get_height() == 1024, name + " atlas dimensions")
	for type in [2, 3, 4, 5, 7]:
		var texture = FieldArt.motion_texture(type)
		var pixels = texture.get_image()
		var columns = 5 if type in [4, 5] else 3
		check(pixels.get_size() == Vector2i(384 * columns, 1152) and texture == FieldArt.motion_texture(type), "registered motion atlas cached " + str(type))
		for row in 3:
			var a = pixels.get_region(Rect2i(384, row * 384, 384, 384))
			var b = pixels.get_region(Rect2i(768, row * 384, 384, 384))
			check(a.get_data() != b.get_data() and a.get_used_rect().size.y > 100 and b.get_used_rect().size.y > 100, "painted movement frames differ for type/direction %d/%d" % [type, row])
	for name in ["woodland-v2", "architecture-v2"]:
		for i in 6:
			var sprite = FieldArt.scenery_texture(name, i)
			check(sprite.get_width() > 100 and sprite.get_height() > 100 and sprite == FieldArt.scenery_texture(name, i), name + " variant " + str(i) + " is populated and cached")

func scenery_checks(mode: String) -> void:
	check(app.world.scenery_trees.size() > 100, mode + " individual woodland sprites populated")
	var variants: Dictionary = {}
	for tree in app.world.scenery_trees: variants[tree.variant] = true
	check(variants.size() == 6, mode + " woodland mixes all six painted variants")
	check(app.world.scenery_trees.all(func(p): return app.model.terrain.passable(p.p, true) and app.world.road_clearance(p.p) >= 10 + p.size * 0.15), mode + " tree roots keep roads and water clear")
	check(app.world.scenery_buildings.size() >= 4, mode + " villages assembled from individual buildings")
	check(app.world.scenery_buildings.all(func(p): return app.model.terrain.ground_passable(p.p, true) and app.world.road_clearance(p.p) >= 10 + p.size * 0.25), mode + " buildings keep roads and water clear")
	check(app.world.scenery_buildings == app.model.terrain.buildings, mode + " scenery uses shared simulation building footprints")
	var old_center = app.world.center
	var old_zoom = app.world.zoom
	app.world.zoom = 3.5
	app.world.center = FieldData.pos(app.model.terrain.towns[1])
	app.world.update_camera()
	await capture(mode + "-village-art")
	app.world.center = app.world.scenery_trees[0].p
	app.world.update_camera()
	await capture(mode + "-woodland-art")
	app.world.center = old_center
	app.world.zoom = old_zoom
	app.world.update_camera()
	await frames()

func depth_checks(mode: String) -> void:
	var meshes_upward = true
	for node in app.world.scenery.get_children():
		if not node is MeshInstance3D:
			continue
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for i in range(0, vertices.size() if indices.is_empty() else indices.size(), 3):
			var a: Vector3 = vertices[i if indices.is_empty() else indices[i]]
			var b: Vector3 = vertices[i + 1 if indices.is_empty() else indices[i + 1]]
			var c: Vector3 = vertices[i + 2 if indices.is_empty() else indices[i + 2]]
			meshes_upward = meshes_upward and (b - a).cross(c - a).y <= 0.001
	check(meshes_upward, mode + " terrain roads water and contact meshes face upward")
	check(app.world.sunlight.shadow_enabled, mode + " directional shadows enabled")
	var water_point = Vector2(1950, app.model.terrain.river_y(1950)) if mode == "campaign" else Vector2(FieldData.channel_x(300), 300)
	var original_center = app.world.center
	app.world.center = water_point
	app.world.update_camera()
	await frames()
	var water_screen: Vector2 = app.world.project(water_point)
	var water_color = get_viewport().get_texture().get_image().get_pixelv(Vector2i(water_screen))
	check(water_color.get_luminance() > 0.12 and water_color.b > water_color.r, mode + " water stays visible and cool-toned")
	app.world.center = original_center
	app.world.update_camera()
	await frames()
	var map_point = Vector2(230, 195) if mode == "campaign" else Vector2(370, 400)
	check(app.world.ground(app.world.project(map_point)).distance_to(map_point) < 0.1, mode + " terrain picking matches raised surface")
	check(absf(app.world.camera.rotation.x + FieldWorld.CAMERA_PITCH) < 0.001, mode + " oblique camera pitch")
	var lit = get_viewport().get_texture().get_image().get_data()
	app.world.sunlight.shadow_enabled = false
	await frames()
	check(lit != get_viewport().get_texture().get_image().get_data(), mode + " cast shadows affect rendered pixels")
	app.world.sunlight.shadow_enabled = true
	await frames()
	var relief = get_viewport().get_texture().get_image().get_data()
	app.model.terrain.relief = 0
	await frames(8)
	check(relief != get_viewport().get_texture().get_image().get_data(), mode + " relief affects rendered pixels")
	app.model.terrain.relief = 1
	await frames(8)
	var basis_value = Basis(Vector3.RIGHT, -FieldWorld.CAMERA_PITCH) * Basis.from_scale(Vector3(45, 36, 1))
	var support: float = app.world.scenery_support(map_point, basis_value)
	var grounded = true
	for x in [-0.5, 0.0, 0.5]:
		for y in [-0.5, 0.0, 0.5]:
			var offset = basis_value * Vector3(x, y, 0)
			grounded = grounded and support + offset.y > app.model.terrain.height_at(map_point + Vector2(offset.x, offset.z))
	check(grounded, mode + " scenery footprint clears hillside")

func placement_checks() -> void:
	app.world.zoom = 2.0
	app.world.center = Vector2(410, 250)
	app.world.update_camera()
	app.model.select(["u1", "u2"])
	var anchor = Vector2(410, 250)
	var start: Vector2 = app.world.project(anchor)
	var finish: Vector2 = app.world.project(anchor + Vector2(65, 35))
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_RIGHT
	press_event.position = start
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await frames()
	var motion = InputEventMouseMotion.new()
	motion.position = finish
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion)
	await frames()
	var preview: Array = app.world.order_preview()
	check(preview.size() == 2 and preview[0].point != preview[1].point, "right drag previews each selected regiment")
	await capture("battle-multi-unit-facing")
	app.world.pan_pixels(Vector2(12, 0))
	await frames()
	preview = app.world.order_preview()
	check(app.world.right_start.distance_to(anchor) < 0.5, "camera movement preserves ground anchor during drag")
	# Release at the sampled preview pointer, including any native cursor motion.
	press_event.position = app.world.pointer
	press_event.pressed = false
	Input.parse_input_event(press_event)
	await frames()
	check(preview.all(func(p): return FieldData.pos(p.unit.goal).distance_to(p.point) < 0.01 and absf(angle_difference(p.unit.desiredFacing, p.facing)) < 0.01), "mouse release orders every previewed position and facing")
	check(app.world.order_preview().is_empty(), "release clears group preview")
	app.model.select(["u1", "u4", "u5"])
	app.world.right_screen = app.world.project(anchor)
	app.world.right_start = anchor
	app.world.pointer = app.world.project(anchor + Vector2(0, -70))
	app.world.invalidate()
	await capture("battle-mixed-unit-facing")
	check(app.world.order_preview().size() == 3, "mixed unit preview includes infantry cavalry and artillery")
	var cancel = InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await frames()
	check(app.world.order_preview().is_empty(), "Escape cancels all formation previews")
	app.model.select_commander("general")
	app.world.right_start = anchor
	app.world.right_screen = app.world.project(anchor)
	app.world.pointer = app.world.project(anchor + Vector2(50, 40))
	app.world.invalidate()
	await frames()
	check(app.world.order_preview().size() == 1, "independent general facing preview")
	app.world.right_start = null
	app.world.invalidate()

func clear_drill_buildings() -> void:
	# Animation and command fixtures are open-ground drills, not scenery tests.
	# Rebuild their actual scene too so screenshots do not show fire through houses.
	app.model.terrain.buildings.clear()
	app.model.terrain.defenses.clear()
	app.model.terrain.grids.clear()
	app.model.terrain.field = app.model.terrain.field.duplicate(true)
	app.model.terrain.field.forests = []
	app.model.terrain.field.hills = []
	app.model.terrain.forests = []
	app.model.terrain.relief = 0
	app.world.landscape_signature = ""
	app.world.sync_map()

func animation_checks() -> void:
	for kind in ["infantry", "cavalry", "artillery"]:
		app.start_skirmish("bridge")
		clear_drill_buildings()
		var battle: Dictionary = app.model.state.battle
		battle.aiClock = -1000
		var shooter: Dictionary = battle.units.filter(func(u): return u.side == "player" and u.kind == kind)[0]
		var target: Dictionary = battle.units.filter(func(u): return u.side == "enemy" and u.kind == "infantry")[0]
		for u in battle.units: u.arrival = 9999
		shooter.merge({"x": 480.0, "y": 480.0, "facing": 0.0, "arrival": 0.0, "reload": 0.0}, true)
		target.merge({"x": 570.0 if kind == "cavalry" else 620.0, "y": 480.0, "arrival": 0.0, "holdFire": true}, true)
		if kind == "cavalry": shooter.weapon = "carbine"
		app.model.formations.groups.clear()
		app.model.tactics.update_visibility(app.model)
		app.model.select([shooter.id])
		app.world.center = Vector2(500, 480)
		app.world.zoom = 6.0
		app.world.update_camera()
		await advance(0.15)
		check(shooter.get("shotTime", -1) >= 0, kind + " produces actual firing event")
		check(is_equal_approx(shooter.get("shotReload", 0), shooter.reload + battle.time - shooter.shotTime), kind + " records its actual reload duration for animation")
		await capture("battle-" + kind + "-fire")
		shooter.holdFire = true
		await advance(1.0)
		check(app.world.smoke_count > 0, kind + " volley emits painted smoke")
		await capture("battle-" + kind + "-smoke")
		var smoke_pixels = get_viewport().get_texture().get_image().get_data()
		await frames(10)
		if smoke_pixels != get_viewport().get_texture().get_image().get_data():
			var debug_image = Image.create_from_data(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y, false, get_viewport().get_texture().get_image().get_format(), smoke_pixels)
			debug_image.save_png(output + "/pause-before-" + kind + ".png")
			get_viewport().get_texture().get_image().save_png(output + "/pause-after-" + kind + ".png")
		check(smoke_pixels == get_viewport().get_texture().get_image().get_data(), kind + " smoke freezes when paused")
		var smoke_origin: Vector2 = app.world.smoke_emissions[shooter.id].origin
		await advance(2.0)
		await capture("battle-" + kind + "-reload")
		app.model.move_units(Vector2(580, 480))
		var original = get_viewport().get_texture().get_image().get_data()
		var positions = app.model.formations.positions(shooter)
		var phase: float = positions[0].phase
		await advance(3.0)
		check(app.world.smoke_emissions[shooter.id].origin == smoke_origin, kind + " smoke stays at the firing position as troops move")
		check(phase != positions[0].phase and positions[0].moving > 0, kind + " has displacement-driven gait")
		check(original != get_viewport().get_texture().get_image().get_data(), kind + " animation changes rendered pixels")
		await capture("battle-" + kind + "-moving")
	animation_completed = true

func infantry_walk_checks() -> void:
	app.start_skirmish("bridge")
	clear_drill_buildings()
	app.world.zoom = 6.0
	app.world.center = Vector2(552, 470)
	app.world.show_ranges = false
	app.world.show_fog = false
	app.world.update_camera()
	var battle: Dictionary = app.model.state.battle
	battle.aiClock = -10000.0
	for u in battle.units:
		u.arrival = 99999.0
		u.holdFire = true
	var units = [battle.units[0], battle.units.filter(func(u): return u.side == "enemy" and u.kind == "infantry")[0]]
	var tracks: Array = []
	for type in 2:
		var u: Dictionary = units[type]
		u.merge({"x": 552.0, "y": 440.0 + type * 60.0, "men": 36, "startMen": 36, "arrival": 0.0, "visible": true, "shotTime": -100.0}, true)
		app.model.formations.reset_roster(u)
		tracks.append(app.model.formations.reset(u))
		for i in 4:
			var soldier: FieldFormations.Soldier = tracks[type][i]
			soldier.p = Vector2(500 + i * 35, 440 + type * 60)
			soldier.previous = soldier.p
			soldier.facing = [0.0, PI, -PI / 2, PI / 2][i]
			soldier.previousFacing = soldier.facing
	var pictures: Array[Image] = []
	for frame in 3:
		for group in tracks:
			for soldier in group:
				soldier.moving = 0.0 if frame == 0 else 1.0
				soldier.phase = TAU * 0.02 if frame < 2 else TAU * 0.52
				soldier.previousPhase = soldier.phase
		app.world.invalidate()
		pictures.append(await capture("battle-infantry-" + ["idle", "step-a", "step-b"][frame]))
		for type in 2:
			var expected_pose = 0 if frame == 0 else frame + 2
			var all_frames_match = true
			for i in 4:
				var data = app.world.batches[type].multimesh.get_instance_custom_data(i)
				all_frames_match = all_frames_match and int(floor(data.b / 10.0)) == expected_pose
			check(all_frames_match, "infantry batch selects frame %d for side %d" % [frame, type])
		await frames(10)
		check(pictures.back().get_data() == get_viewport().get_texture().get_image().get_data(), "infantry pose freezes while paused " + str(frame))
	for type in 2:
		for i in 4:
			var foot: Vector2 = app.world.project(tracks[type][i].p)
			var region = Rect2i(Vector2i(foot) - Vector2i(26, 32), Vector2i(52, 32))
			var a = pictures[1].get_region(region)
			var b = pictures[2].get_region(region)
			var changed = 0
			for y in a.get_height():
				for x in a.get_width():
					if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)): continue
					changed += 1
			check(changed > 15, "painted infantry boots change in facing %d side %d" % [i, type])
	app.model.formations.groups.clear()
	app.model.select([units[0].id])
	app.model.move_units(Vector2(650, 440))
	var seen: Dictionary = {}
	for i in 12:
		await advance(0.15)
		var soldier: FieldFormations.Soldier = app.model.formations.positions(units[0])[0]
		seen[FieldFormations.infantry_frame(soldier.phase, soldier.moving)] = true
	check(seen.has(1) and seen.has(2), "actual infantry march cycles through both painted steps")
	app.model.halt()
	await advance(8)
	check(app.model.formations.positions(units[0]).all(func(p): return FieldFormations.infantry_frame(p.phase, p.moving) == 0), "halted infantry settles into its separate idle frame")

func animation_gallery(phase: float, moving: float, age: float = 100.0, action: String = "", facing: float = 0.0, rank: int = 0, reload_duration: float = 2.8) -> Image:
	var counts = [0, 0, 0, 0, 0, 0, 0, 0]
	app.world.sprite_count = 0
	for type in 8:
		app.world.place(counts, type, Vector2(440 + (type % 4) * 40, 440 + (type / 4) * 55), 18 if type < 2 else 27, facing, phase, moving, age, action, 0, rank, reload_duration)
	for type in 8: app.world.batches[type].multimesh.visible_instance_count = counts[type]
	app.world.shadow_batch.multimesh.visible_instance_count = 8
	await frames(1)
	return get_viewport().get_texture().get_image()

func animation_difference(a: Image, b: Image) -> float:
	var difference = 0.0
	for y in range(180, 700, 2):
		for x in range(250, 1200, 2):
			var left = a.get_pixel(x, y)
			var right = b.get_pixel(x, y)
			difference += absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)
	return difference

func animation_transition_checks() -> void:
	app.start_skirmish("bridge")
	clear_drill_buildings()
	app.set_physics_process(false)
	var b: Dictionary = app.model.state.battle
	app.model.state.paused = false
	app.world.previous_animation_time = b.time
	b.time += 0.1
	app.world.interpolation = 0.5
	check(is_equal_approx(app.world.rendered_animation_time(), b.time - 0.05), "combat animation interpolates between simulation ticks")
	app.model.state.paused = true
	check(app.world.rendered_animation_time() == b.time, "paused animation uses the exact simulation pose")
	for speed in [0.5, 1.0, 2.0, 4.0]:
		app.model.state.speed = speed
		app.model.state.paused = false
		var before: float = app.world.animation_time()
		app.world.remember_transforms()
		app.model.tick(1.0 / 30.0)
		check(is_equal_approx(app.world.animation_time() - before, speed / 30.0), "animation clock follows %.1fx simulation speed" % speed)
		app.model.state.paused = true
	app.model.state.speed = 1.0
	app.world.zoom = 6.0
	app.world.center = Vector2(500, 462)
	app.world.update_camera()
	await frames()
	app.world.set_process(false)
	app.hud.hide()
	app.world.overlay.hide()
	app.world.smoke_batch.multimesh.visible_instance_count = 0
	if is_instance_valid(app.world.body_mesh): app.world.body_mesh.hide()
	for facing in [0.0, PI, -PI / 2, PI / 2]:
		var a = await animation_gallery(TAU * 0.02, 1, 100, "", facing)
		var b_pose = await animation_gallery(TAU * 0.52, 1, 100, "", facing)
		var passing = await animation_gallery(TAU * 0.27, 1, 100, "", facing)
		var before = await animation_gallery(0.19, 1, 100, "", facing)
		var after = await animation_gallery(0.21, 1, 100, "", facing)
		check(animation_difference(a, b_pose) > 5, "painted strides differ at facing %.2f" % facing)
		check(animation_difference(passing, a) > 5 and animation_difference(passing, b_pose) > 5, "passing pose connects both feet at facing %.2f" % facing)
		var adjacent = animation_difference(before, after)
		check(adjacent > 0.01 and adjacent < animation_difference(a, b_pose) * 0.45, "stride transition is gradual at facing %.2f" % facing)
		if facing == 0:
			a.save_png(output + "/animation-step-left.png")
			passing.save_png(output + "/animation-passing.png")
			b_pose.save_png(output + "/animation-step-right.png")
	var idle = await animation_gallery(PI / 2, 0)
	var moving = await animation_gallery(PI / 2, 1)
	var settling = await animation_gallery(PI / 2, 0.4)
	check(animation_difference(idle, settling) > 5 and animation_difference(moving, settling) > 5, "start and stop blend through a distinct settling pose")
	var moving_reload = await animation_gallery(PI / 2, 1, 1, "musket")
	check(animation_difference(moving, moving_reload) < 0.01, "moving troops use their gait instead of sliding in a reload pose")
	var firing = await animation_gallery(0.0, 0, 0.2, "cannon")
	var loading = await animation_gallery(0.0, 0, 0.6, "cannon")
	var firing_change = animation_difference(firing, loading)
	check(firing_change > 5, "firing and loading retain distinct painted poses")
	for age in [0.0, 0.38, 2.8]:
		var a = await animation_gallery(0.0, 0, age - 0.001, "cannon")
		var c = await animation_gallery(0.0, 0, age + 0.001, "cannon")
		var delta = animation_difference(a, c)
		print("Firing transition %.2f: %.2f / %.2f total pose change" % [age, delta, firing_change])
		if delta >= firing_change * 0.05:
			a.save_png(output + "/firing-transition-before.png")
			c.save_png(output + "/firing-transition-after.png")
		check(delta < firing_change * 0.05, "firing poses have no hard cut at %.2f seconds" % age)
	await reload_checks()
	var guard = await animation_gallery(0.0, 0, 100, "melee")
	var thrust = await animation_gallery(TAU * 0.3, 0, 100, "melee")
	var recovery = await animation_gallery(TAU * 0.4, 0, 100, "melee")
	check(animation_difference(guard, thrust) > 5 and animation_difference(thrust, recovery) > 5, "melee has a strike and distinct recovery")
	var rear = await animation_gallery(TAU * 0.3, 0, 100, "melee", 0, 3)
	check(animation_difference(guard, rear) < 0.01, "rear ranks remain in guard during a front-rank thrust")
	for beat in [0.18, 0.45, 0.58, 0.82, 1.0]:
		var a = await animation_gallery(TAU * (beat - 0.001), 0, 100, "melee")
		var c = await animation_gallery(TAU * (beat + 0.001), 0, 100, "melee")
		check(animation_difference(a, c) < 30, "melee returns through guard at phase %.2f" % beat)
	var paused = get_viewport().get_texture().get_image().get_data()
	await frames(10)
	check(paused == get_viewport().get_texture().get_image().get_data(), "all shader motion freezes without simulation advancement")
	app.hud.show()
	app.world.overlay.show()
	app.world.set_process(true)
	app.set_physics_process(true)
	app.world.invalidate()

func reload_checks() -> void:
	for type in 4:
		var texture = FieldArt.reload_texture(type)
		check(texture == FieldArt.reload_texture(type), "loading atlas is cached for type " + str(type))
		var pixels = texture.get_image()
		var size = Vector2i(pixels.get_width() / 2, pixels.get_height() / 3)
		for direction in 3:
			var a = pixels.get_region(Rect2i(Vector2i(0, direction) * size, size))
			var c = pixels.get_region(Rect2i(Vector2i(1, direction) * size, size))
			check(a.get_used_rect().size.y > 200 and c.get_used_rect().size.y > 200 and a.get_data() != c.get_data(), "distinct planted loading poses for type %d direction %d" % [type, direction])
	for facing in [0.0, PI, -PI / 2, PI / 2]:
		var lowered = await animation_gallery(0, 0, 0.65, "musket", facing)
		var raised = await animation_gallery(0, 0, 1.45, "musket", facing)
		var primed = await animation_gallery(0, 0, 2.15, "musket", facing)
		check(animation_difference(lowered, raised) > 5, "loading hands visibly move at facing %.2f" % facing)
		for type in 6:
			var foot: Vector2 = app.world.project(Vector2(440 + (type % 4) * 40, 440 + (type / 4) * 55))
			var crop = Rect2i(Vector2i(foot) - Vector2i(80, 190), Vector2i(160, 192))
			var next_stage: Image = primed if type < 2 and absf(cos(facing)) > 0.9 else raised
			check(lowered.get_region(crop).get_data() != next_stage.get_region(crop).get_data(), "individual loading figure changes for type %d facing %.2f" % [type, facing])
		var direction_name: String = {0.0: "right", PI: "left", -PI / 2: "rear", PI / 2: "front"}[facing]
		lowered.save_png(output + "/reload-" + direction_name + "-lowered.png")
		raised.save_png(output + "/reload-" + direction_name + "-raised.png")
		var paused = primed.get_data()
		await frames(10)
		check(paused == get_viewport().get_texture().get_image().get_data(), "loading freezes on pause in " + direction_name + " view")
	await animation_gallery(0, 0, 3.2, "cannon", 0, 0, 4.2)
	check(int(app.world.batches[4].multimesh.get_instance_custom_data(0).b / 10) == 2, "gun crew keeps loading beyond the old 2.8-second cutoff")
	await animation_gallery(0, 0, 4.3, "cannon", 0, 0, 4.2)
	check(int(app.world.batches[4].multimesh.get_instance_custom_data(0).b / 10) == 0, "gun crew returns to ready at the actual cooldown end")

func commander_checks() -> void:
	var hq = app.hud.hq
	var u: Dictionary = app.model.state.units[0]
	var previous = u.officerId
	app.model.hire_officer("reserve-0")
	var portrait = button(hq, "Change commander: " + u.name)
	check(portrait != null, "unit commander portrait is actionable")
	portrait.pressed.emit()
	await frames()
	check(is_instance_valid(hq.commander_dialog) and hq.commander_dialog.visible, "commander click opens officer chooser")
	check(hq.available_commanders(u).any(func(o): return o.id == "reserve-0"), "officer chooser includes hired reserve commander")
	check(not hq.available_commanders(u).any(func(o): return o.id == app.model.state.corps[0].officerId), "officer chooser excludes occupied commands")
	await capture("headquarters-commander-chooser")
	var officer: Dictionary = app.model.find_id(app.model.state.officers, "reserve-0")
	var candidate = button(hq.commander_dialog, "Assign " + officer.id)
	check(candidate != null, "reserve commander has assign action")
	if candidate != null: candidate.pressed.emit()
	await frames()
	check(u.officerId == "reserve-0" and hq.available_commanders(u).any(func(o): return o.id == previous), "commander swap returns previous officer to reserve")

func expansion_checks() -> void:
	app.resume_campaign()
	await frames(8)
	var was_center = app.world.center
	var army_rect: Rect2 = app.world.selection_regions.army[0]
	var start = army_rect.position - Vector2(10, 10)
	var end = army_rect.end + Vector2(10, 10)
	map_drag(start, end)
	await frames()
	check(app.world.center == was_center and is_instance_valid(app.hud.inspector), "campaign left drag selects army without panning")
	await press("Close unit information")
	app.world.overview()
	await capture("campaign-expanded-overview")
	check(app.world.zoom < 0.6 and app.world.scenery_fields.size() > 25, "expanded overview contains full region and cultivated fields")
	app.start_skirmish("bridge")
	clear_drill_buildings()
	app.world.zoom = 4.0
	app.world.center = Vector2(500, 470)
	app.world.show_fog = false
	app.world.show_ranges = false
	app.world.update_camera()
	var battle: Dictionary = app.model.state.battle
	battle.aiClock = -10000
	for unit in battle.units:
		unit.arrival = 99999
		unit.holdFire = true
	var u: Dictionary = battle.units[0]
	u.merge({"x": 500.0, "y": 470.0, "arrival": 0.0, "facing": PI / 2.0}, true)
	app.model.formations.reset(u)
	await frames()
	var regions: Array = app.world.selection_regions[u.id].duplicate()
	regions.sort_custom(func(a, b): return a.position.x < b.position.x)
	var edge: Vector2 = regions.back().get_center()
	check(edge.distance_to(app.world.project(FieldData.pos(u))) > 45 and app.world.hit_entity(edge).get("id") == u.id, "outermost infantry figure selects its regiment")
	app.model.select([])
	map_drag(edge - Vector2(3, 3), edge + Vector2(9, 9))
	await frames()
	check(u.id in app.model.state.selected, "box selection intersects outer soldier without enclosing unit center")
	var enemy: Dictionary = battle.units.filter(func(unit): return unit.side == "enemy")[0]
	enemy.merge({"x": 600.0, "y": 470.0, "arrival": 0.0, "facing": PI / 2.0, "visible": true}, true)
	app.model.formations.reset(enemy)
	app.world.invalidate()
	await frames()
	edge = app.world.selection_regions[enemy.id].back().get_center()
	app.world.issue_order(edge, edge, false)
	check(u.attackId == enemy.id, "right-click enemy body issues attack rather than ground move")
	app.model.halt()
	var count = app.world.sprite_count
	u.men -= 45
	app.model.formations.advance(battle.units, battle.time, 0.1, battle.bodies)
	app.world.invalidate()
	await capture("battle-casualty-gaps")
	check(app.world.sprite_count == count - 5 and app.world.body_count == 5, "casualties remove five stable figures and render five bodies")
	var vertices: PackedVector3Array = app.world.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var grounded = true
	for p in vertices: grounded = grounded and p.y > app.model.terrain.height_at(Vector2(p.x, p.z))
	check(grounded, "body mesh follows terrain without clipping")
	var wagon: Dictionary = battle.wagons[0]
	wagon.x = 500
	wagon.y = 490
	wagon.facing = 0.0
	app.world.center = Vector2(500, 490)
	app.world.zoom = 6
	app.world.update_camera()
	app.model.select_supply()
	check(app.model.move_units(Vector2(620, 490)), "wagon receives march order")
	await advance(2)
	check(app.world.campaign_gaits[wagon.id].moving > 0 and int(app.world.batches[7].multimesh.get_instance_custom_data(0).b / 10) in [3, 4], "moving wagon selects a painted walking frame")
	await capture("battle-wagon-moving")
	var phase: float = app.world.campaign_gaits[wagon.id].phase
	await frames(10)
	check(app.world.campaign_gaits[wagon.id].phase == phase, "wagon stride freezes while paused")
	app.model.halt()
	await advance(8)
	check(app.world.campaign_gaits[wagon.id].moving == 0, "halted wagon returns to idle")
	var crossing_y: float = app.model.terrain.crossings[1]
	var bridge_point = Vector2(app.model.terrain.channel_x(crossing_y), crossing_y)
	app.world.center = bridge_point
	app.world.zoom = 5
	app.world.update_camera()
	await capture("battle-bridge-deck")
	check(absf(app.model.terrain.height_at(bridge_point) - 6.5) < 0.01 and absf(app.world.road_height(bridge_point) - 7.85) < 0.01, "bridge road uses level deck height with surface clearance")
	app.world.show_ranges = true
	app.world.show_fog = true
	expansion_completed = true

func melee_checks() -> void:
	for type in 4:
		var texture = FieldArt.melee_texture(type)
		check(texture == FieldArt.melee_texture(type), "melee atlas is cached " + str(type))
		var pixels = texture.get_image()
		var cell = Vector2i(pixels.get_width() / 3, pixels.get_height() / 3)
		var complete = true
		for row in 3:
			var first = pixels.get_region(Rect2i(Vector2i(0, row) * cell, cell))
			var strike = pixels.get_region(Rect2i(Vector2i(1, row) * cell, cell))
			complete = complete and first.get_used_rect().size.y > 250 and strike.get_used_rect().size.y > 250 and first.get_data() != strike.get_data()
		check(complete, "painted guard and strike exist in all directions " + str(type))
	for kind in ["infantry", "cavalry"]:
		app.start_skirmish("village")
		clear_drill_buildings()
		var battle: Dictionary = app.model.state.battle
		battle.aiClock = -10000
		for u in battle.units: u.arrival = 99999
		var a: Dictionary = battle.units.filter(func(u): return u.kind == kind and u.side == "player")[0]
		var b: Dictionary = battle.units.filter(func(u): return u.kind == kind and u.side == "enemy")[0]
		var center = Vector2(400, 500)
		for pair in [[a, -1.0], [b, 1.0]]:
			var u: Dictionary = pair[0]
			u.merge({"x": center.x + pair[1] * 25, "y": center.y, "men": 270.0, "startMen": 270.0, "arrival": 0.0, "facing": 0.0 if pair[1] < 0 else PI * 0.65, "holdFire": true, "visible": true, "reload": 0.0}, true)
			u.perk = "steadfast"
			u.skills.discipline = 100.0
			app.model.formations.reset_roster(u)
			app.model.formations.positions(u)
		app.model.select([a.id])
		app.model.move_units(FieldData.pos(b), b.id)
		app.world.zoom = 6
		app.world.center = center
		app.world.show_ranges = false
		app.world.show_fog = false
		app.world.update_camera()
		await advance(12)
		check(a.get("meleeTargetId") == b.id, kind + " reaches melee in graphical scene")
		var type = 0 if kind == "infantry" else 2
		var first_pose = app.world.batches[type].multimesh.get_instance_custom_data(0)
		var all_melee = int(first_pose.b / 10) >= 5
		for side_type in [type, type + 1]:
			var batch: MultiMesh = app.world.batches[side_type].multimesh
			for i in batch.visible_instance_count: all_melee = all_melee and int(batch.get_instance_custom_data(i).b / 10) >= 5
		check(all_melee, kind + " on both sides uses dedicated melee atlas for every living soldier")
		var body_vertices: PackedVector3Array = app.world.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var above_roads = true
		for p in body_vertices:
			if app.world.road_clearance(Vector2(p.x, p.z)) < 5: above_roads = above_roads and p.y > app.world.road_height(Vector2(p.x, p.z))
		check(above_roads, kind + " melee bodies are not buried beneath raised roads")
		var first = await capture("battle-" + kind + "-melee-a")
		var area = Rect2()
		for id in [a.id, b.id]:
			for rect in app.world.selection_regions[id]: area = rect if area.size == Vector2.ZERO else area.merge(rect)
		var crop = Rect2i(area).intersection(Rect2i(Vector2i.ZERO, first.get_size()))
		battle.time += 0.45
		app.world.invalidate()
		var second = await capture("battle-" + kind + "-melee-b")
		check(first.get_region(crop).get_data() != second.get_region(crop).get_data(), kind + " melee animation changes actual troop pixels")
		var paused = second.get_data()
		await frames(12)
		check(paused == get_viewport().get_texture().get_image().get_data(), kind + " melee animation freezes with simulation pause")
		if kind == "infantry":
			var old_bodies: int = app.world.body_count
			a.men -= 18
			app.model.formations.advance(battle.units, battle.time, 0.05, battle.bodies)
			app.world.invalidate()
			await capture("battle-melee-rank-replacement")
			check(app.world.body_count == old_bodies + 2, "melee replacements leave two new grounded bodies")
			get_window().size = Vector2i(390, 844)
			await frames(12)
			await capture("battle-melee-mobile")
			get_window().size = Vector2i(1440, 900)
			await frames(12)
		app.model.select([a.id])
		app.model.fall_back()
		await advance(8)
		app.world.invalidate()
		await frames()
		check(a.get("meleeTargetId") == null and int(app.world.batches[type].multimesh.get_instance_custom_data(0).b / 10) < 5, kind + " leaves melee pose on withdrawal")
	melee_completed = true

func battle_order_checks() -> void:
	app.start_skirmish("village")
	clear_drill_buildings()
	var m: FieldModel = app.model
	var battle: Dictionary = m.state.battle
	battle.aiClock = -10000
	for u in battle.units: u.arrival = 99999
	var a: Dictionary = battle.units[0]
	var b: Dictionary = battle.units[5]
	var guns: Dictionary = battle.units.filter(func(u): return u.side == "player" and u.kind == "artillery")[0]
	a.merge({"x": 440.0, "y": 400.0, "arrival": 0.0, "facing": 0.0, "men": 270.0, "startMen": 270.0, "holdFire": true}, true)
	b.merge({"x": 650.0, "y": 400.0, "arrival": 0.0, "facing": PI, "men": 600.0, "startMen": 600.0, "holdFire": true, "visible": true}, true)
	guns.merge({"x": 220.0, "y": 750.0, "arrival": 0.0, "holdFire": true}, true)
	for u in [a, b, guns]:
		m.formations.reset_roster(u)
		m.formations.positions(u)
	m.tactics.update_visibility(m)
	m.select([guns.id])
	await frames()
	check(button(app.hud.root, "Charge").disabled, "charge toolbar disabled for artillery")
	m.select([a.id])
	app.world.center = Vector2(540, 400)
	app.world.zoom = 4
	app.world.show_fog = false
	app.world.show_ranges = true
	app.world.update_camera()
	await press("Charge")
	await advance(2)
	check(a.charging and FieldCharge.momentum(a) > 0 and not button(app.hud.root, "Retreat unit").disabled, "charge builds momentum while retreat remains available")
	await capture("battle-charge-run-up")
	await press("Halt")
	check(not a.charging and a.chargeDistance == 0, "Halt toolbar cancels active charge")
	m.move_units(Vector2(400, 330))
	await advance(3)
	await capture("battle-steady-wheel")
	m.halt()
	a.merge({"x": 520.0, "y": 400.0, "facing": PI, "holdFire": true, "morale": 100.0}, true)
	b.merge({"x": 650.0, "y": 400.0, "facing": PI, "holdFire": false, "reload": 0.0}, true)
	m.formations.reset(a)
	m.formations.reset(b)
	m.tactics.update_visibility(m)
	await advance(0.2)
	check(a.get("firePressure") == "rear" and app.hud.unit_status(a) == "Rear attack!", "rear-fire morale warning reaches HUD")
	await capture("battle-rear-fire-morale")
	b.holdFire = true
	a.facing = 0.0
	var blocker: Dictionary = battle.units[1]
	blocker.merge({"x": 580.0, "y": 425.0, "facing": 0.0, "arrival": 0.0, "holdFire": true}, true)
	m.formations.reset(blocker)
	m.move_units(FieldData.pos(b), b.id)
	await advance(0.2)
	check(a.blocked == "Obstructed" and not m.tactics.clear_shot(m, a, b), "friendly frontage produces obstructed shot state")
	await capture("battle-blocked-fire-line")
	await press("Retreat unit")
	check(a.retreating and a.attackId == null and a.goal.x == 45, "individual retreat toolbar routes to friendly edge")
	await capture("battle-retreat-desktop")
	get_window().size = Vector2i(390, 844)
	await frames(12)
	await capture("battle-retreat-mobile")
	var control = button(app.hud.root, "Retreat unit")
	check(control != null and control.size.x >= 28 and control.size.y >= 28, "retreat remains a compact reachable mobile action")
	check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).encloses(control.get_global_rect()), "retreat button fits inside narrow viewport without scrolling")
	get_window().size = Vector2i(1440, 900)
	await frames(12)
	m.halt()
	var key = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	key.pressed = false
	Input.parse_input_event(key)
	check(a.retreating, "R key gives an individual retreat order")
	a.x = 45
	a.target = null
	await advance(0.2)
	check(a.withdrawn and not app.world.selection_regions.has(a.id) and app.hud.roster_labels[a.id].button.disabled, "withdrawn figures leave map picking and become disabled roster cards")
	orders_completed = true

func ai_checks() -> void:
	var saved = JSON.stringify(app.model.state)
	app.hud.skirmish_dialog()
	await frames()
	await press("Coordinated Defense")
	var m: FieldModel = app.model
	var b: Dictionary = m.state.battle
	check(app.exercise and not m.save_enabled and b.name == "Coordinated Defense", "defensive drill is isolated from the campaign")
	check(b.ai.personality == "cautious", "defensive drill selects its defensive commander")
	var enemies = FieldTactics.active(b, "enemy")
	check(enemies.all(func(u): return u.has("ai") and not u.ai.reason.is_empty()), "every enemy formation has a decision and explanation")
	app.world.center = Vector2(780, 450)
	app.world.zoom = 1.4
	app.world.update_camera()
	app.hud.settings_dialog()
	await frames()
	var toggle: CheckBox = app.hud.modal.find_child("AIDiagnostics", true, false)
	check(toggle != null, "battle settings expose the AI diagnostic toggle")
	if toggle != null: toggle.button_pressed = true
	await press("Return to map")
	check(app.world.show_ai and app.hud.objective_label.text.contains("Enemy plan:"), "diagnostics expose the shared plan without changing simulation")
	await advance(12)
	for u in enemies: u.visible = true
	app.world.invalidate()
	await frames()
	await capture("ai-defense-desktop")
	app.world.inspect_entity(enemies[0])
	await frames()
	check(is_instance_valid(app.hud.inspector), "enemy inspector opens with AI decision details")
	await capture("ai-decision-desktop")
	await press("Close unit information")
	get_window().size = Vector2i(390, 844)
	for attempt in 120:
		await frames(2)
		if app.hud.width == 390 and app.world.viewport_size == Vector2(390, 844): break
	await frames(12)
	await capture("ai-defense-mobile")
	check(app.hud.objective.get_global_rect().end.x <= 390 and app.hud.objective.get_global_rect().end.y < 688, "AI plan details fit the narrow battle HUD")
	app.world.inspect_entity(enemies[0])
	await frames()
	check(app.hud.inspector.get_global_rect().end.y <= 844 - app.world.ui_bottom, "AI decision inspector fits above the narrow-screen roster")
	await capture("ai-decision-mobile")
	await press("Close unit information")
	get_window().size = Vector2i(1440, 900)
	await get_tree().create_timer(0.3).timeout
	await frames(12)
	var player: Dictionary = b.units[0]
	var probe = FieldData.pos(enemies[0].ai.station) - Vector2(90, 0)
	var observed = false
	for point in FieldBattleAI.candidates(probe):
		var trial = player.duplicate()
		trial.x = point.x
		trial.y = point.y
		if m.terrain.passable(point, true, 2) and enemies.slice(1).any(func(u): return m.terrain.line_of_sight(u, trial)):
			player.x = point.x
			player.y = point.y
			observed = true
			break
	check(observed, "reserve-response drill uses a genuinely visible approach through the village")
	player.holdFire = true
	m.formations.reset(player)
	enemies[0].routed = true
	for u in enemies: u.ai.until = -1
	m.tactics.plan_enemy(m)
	check(enemies[2].ai.committed, "native reserve responds when an observed infantry sector breaks")
	await advance(4)
	for u in enemies: u.visible = true
	app.world.invalidate()
	await capture("ai-reserve-response")
	for u in enemies:
		u.men = u.startMen * 0.3
		u.morale = 60
	b.time = maxf(20, b.time)
	m.tactics.plan_enemy(m)
	check(b.ai.stance == "withdraw" and enemies.filter(func(u): return not u.routed).all(func(u): return u.retreating), "native army gives withdrawal orders after losing cohesion")
	m.publish(false)
	app.world.invalidate()
	await capture("ai-army-withdrawal")
	app.resume_campaign()
	await frames()
	check(JSON.stringify(app.model.state) == saved, "AI exercise leaves the campaign unchanged")
	print("NATIVE AI: maximum scheduled decision %.2fms" % (m.tactics.ai_max_micros / 1000.0))
	ai_completed = true

func fortification_gallery_checks() -> void:
	var m: FieldModel = app.model
	var u: Dictionary = m.state.battle.units[0]
	u.men = 540
	m.formations.reset_roster(u)
	for cover in m.terrain.defenses:
		m.stop_unit(u)
		var entry = FieldCover.entry(cover)
		u.x = entry.x
		u.y = entry.y
		u.facing = cover.facing
		m.formations.reset(u)
		m.select([u.id])
		app.world.center = FieldData.pos(cover)
		app.world.zoom = 5.0
		app.world.update_camera()
		await frames(8)
		var point: Vector2 = app.world.cover_marker_rect(cover).get_center()
		await click(point, MOUSE_BUTTON_RIGHT)
		check(u.coverOrderId == cover.id, cover.id + " real marker click orders shaped occupation")
		await advance(35)
		check(u.coverId == cover.id and u.coverDeploy == 4, cover.id + " graphical garrison fills all ranks")
		var slots = FieldFormations.offsets(u)
		check(slots.size() > FieldCover.garrison(u, slots.size()).columns, cover.id + " has multiple visible ranks")
		check(app.world.scenery.get_node("Defense-" + cover.id).get_child_count() >= 3, cover.id + " renders layered defensive scenery")
		app.world.pointer = Vector2.ZERO
		app.world.invalidate()
		await capture("fortification-" + cover.id + "-desktop")
		get_window().size = Vector2i(390, 844)
		await frames(16)
		check(app.world.cover_marker_rect(cover).has_area(), cover.id + " marker remains accessible on narrow viewport")
		await capture("fortification-" + cover.id + "-mobile")
		get_window().size = Vector2i(1440, 900)
		await frames(16)
		m.leave_cover()
		check(u.coverId == null, cover.id + " leave command releases shaped garrison")

func polish_checks() -> void:
	app.start_skirmish("village")
	var m: FieldModel = app.model
	var battle: Dictionary = m.state.battle
	battle.aiClock = -10000
	for u in battle.units: u.arrival = 99999
	var u: Dictionary = battle.units[0]
	var cover: Dictionary = m.terrain.defenses[0]
	u.x = cover.x - 145
	u.y = cover.y
	u.facing = 0.0
	u.arrival = 0
	u.holdFire = true
	m.formations.reset(u)
	m.select([u.id])
	app.world.center = FieldData.pos(cover) - Vector2(40, 0)
	app.world.zoom = 4
	app.world.show_fog = false
	app.world.update_camera()
	await frames()
	var ground_point = app.world.project(FieldData.pos(cover))
	app.world.issue_order(ground_point, ground_point, false)
	check(u.coverOrderId == null and u.target != null, "ordinary ground beside a defense remains a move order")
	m.halt()
	var p = app.world.cover_marker_rect(cover).get_center()
	app.world.pointer = p
	await click(p, MOUSE_BUTTON_RIGHT)
	check(u.coverOrderId == cover.id, "right-click shield gives an occupation order")
	check(FieldCover.protection(m, u, {"x": cover.x + 100, "y": cover.y}, false) == 0, "marker order gives no protection on approach")
	check(app.world.cover_status(u) == "Approaching", "marker shows reserved approach status")
	check(app.world.scenery.has_node("Defense-farm-wall") and app.world.scenery.has_node("Defense-orchard-hedge"), "wall and painted hedge render as batched scenery")
	await capture("battle-cover-approach")
	await advance(40)
	check(u.coverId == cover.id and u.coverDeploy == 4, "graphical regiment reaches and occupies wall")
	check(app.world.cover_status(u) == "Occupied / protected", "marker shows completed occupation")
	check(app.world.labels.all(func(label): return not label.rect.intersects(app.world.cover_marker_rect(cover)) and not label.rect.intersects(app.world.cover_tooltip_rect)), "unit labels avoid the fortification marker and details")
	var deployed = u.coverDeploy
	await click(p, MOUSE_BUTTON_RIGHT)
	check(u.coverDeploy == deployed and u.target == null, "clicking an occupied shield keeps its garrison in place")
	check(not button(app.hud.root, "Leave defensive position").disabled, "occupied unit exposes its leave command")
	await capture("battle-cover-occupied")
	get_window().size = Vector2i(390, 844)
	for attempt in 120:
		await frames(2)
		if app.hud.width == 390 and app.world.viewport_size == Vector2(390, 844): break
	await frames(12)
	p = app.world.cover_marker_rect(cover).get_center()
	app.world.pointer = p
	app.world.invalidate()
	await frames()
	if app.world.hit_cover(p).get("id") != cover.id:
		print("COVER NARROW: anchor=", app.world.project(FieldData.pos(cover), 8), " marker=", app.world.cover_marker_rect(cover), " obstacles=", app.world.label_obstacles)
	check(app.world.hit_cover(p).get("id") == cover.id, "fortification marker remains clickable on a narrow screen")
	check(app.world.cover_tooltip_rect.has_area() and get_viewport().get_visible_rect().encloses(app.world.cover_tooltip_rect), "fortification details remain visible within the narrow viewport")
	await click(p, MOUSE_BUTTON_RIGHT)
	check(u.coverDeploy == 4 and u.target == null, "narrow-screen marker accepts right-click without moving the garrison")
	await capture("battle-cover-mobile")
	get_window().size = Vector2i(1440, 900)
	await frames(12)
	await press("Leave defensive position")
	check(u.coverId == null and u.coverOrderId == null, "leave toolbar relinquishes cover")
	await fortification_gallery_checks()
	if "--verify-cover" in OS.get_cmdline_user_args():
		polish_completed = true
		return
	var name = "infantry-walk-french-v1"
	var key = name + ":registered"
	var original = FieldArt.infantry_texture(0).get_image()
	FieldArt.textures.erase(key)
	var hits = FieldArt.cache_hits
	var restored = FieldArt.infantry_texture(0).get_image()
	check(FieldArt.cache_hits > hits and original.get_data() == restored.get_data(), "prepared sprite disk cache restores identical pixels")
	app.audio.play("musket", app.world.center.x - 300)
	var left = app.audio.voices.find_custom(func(voice): return voice.playing and voice.get_meta("kind", "") == "musket")
	check(left >= 0 and app.audio.pans[left].pan < 0, "left battlefield event is panned left of the camera")
	app.audio.play("cannon", app.world.center.x + 300)
	var right = app.audio.voices.find_custom(func(voice): return voice.playing and voice.get_meta("kind", "") == "cannon")
	check(right >= 0 and app.audio.pans[right].pan > 0, "right battlefield event is panned right of the camera")
	for voice in app.audio.voices: voice.stop()
	for i in 12: app.audio.play("march", 0)
	app.audio.play("cannon", 1200)
	check(app.audio.voices.any(func(voice): return voice.get_meta("kind", "") == "cannon" and voice.playing), "cannon preempts low-priority marching")
	m.state.settings.sound = false
	app.audio._process(0.1)
	check(app.audio.voices.all(func(voice): return not voice.playing), "muting stops existing voices")
	m.state.settings.sound = true
	m.state.paused = true
	app.audio.play("order")
	app.audio._process(0.1)
	check(app.audio.voices.any(func(voice): return voice.playing), "paused commands retain their acknowledgement")
	app.resume_campaign()
	var regiment: Dictionary = app.model.state.units[0]
	regiment.men -= 80
	regiment.experience = 2.0
	app.hud.open_headquarters()
	await frames()
	var hq = app.hud.hq
	var quote: Label = hq.find_child("ReplacementQuote", true, false)
	var quality: OptionButton = hq.find_child("ReplacementQuality", true, false)
	var amount: SpinBox = hq.find_child("ReplacementAmount", true, false)
	check(quote != null and quality != null and amount != null, "headquarters exposes replacement quantity, quality and quote")
	if quote != null and quality != null and amount != null:
		amount.value = 40
		quality.select(1)
		quality.item_selected.emit(1)
		var expected = app.model.replacement_quote(regiment, "veterans", 40)
		check(quote.text.contains("%d F" % expected.cost) and quote.text.contains("2.00 -> 2.00"), "veteran UI preview updates total cost and preserved experience")
		scroll_to(quote)
		await capture("headquarters-replacements-desktop")
		get_window().size = Vector2i(390, 844)
		await frames(12)
		quote = hq.find_child("ReplacementQuote", true, false)
		scroll_to(quote)
		await capture("headquarters-replacements-mobile")
		check(quote.size.x <= 390 and quote.get_minimum_size().x <= quote.size.x, "replacement preview text fits narrow headquarters")
		get_window().size = Vector2i(1440, 900)
		await frames(12)
	await press("Armory")
	var buy = button(app.hud.hq, "Buy reserve weapons")
	var purchase = app.model.trade_quote("musket", "buy", FieldData.weapons().musket.lot)
	check(buy.text == "Buy / %d F" % purchase.cost, "armory button shows the batch total rather than the single-weapon price")
	await press("Return to map")
	polish_completed = true

func scroll_to(control: Control) -> void:
	var parent = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()

func campaign_checks() -> void:
	app.new_campaign("mantua")
	await frames(12)
	var m: FieldModel = app.model
	check(m.state.armies.size() == 1, "native demo starts with one army")
	check(not m.save_enabled, "campaign visual tests cannot overwrite player save")
	await capture("operation-desktop")
	app.world.overview()
	await capture("operation-overview")
	check(app.world.ground_material.get_shader_parameter("river_vertical"), "Mincio shader uses vertical channel")
	check(app.world.entities.any(func(u): return u.id == "army"), "player army renders on campaign map")
	await press("Split army")
	var name: LineEdit = app.hud.modal.find_child("DetachmentName", true, false)
	check(name != null, "split dialog exposes force name")
	if name != null: name.text = "Southern column"
	for id in ["u4", "u5"]:
		var box: CheckBox = app.hud.modal.find_child("Detach_" + id, true, false)
		check(box != null, "split dialog has regiment " + id)
		if box != null: box.button_pressed = true
	await capture("operation-split")
	await press("Create detachment")
	check(m.state.armies.size() == 2 and m.army_units().size() == 2, "native split creates independent force")
	await frames(8)
	check(app.world.entities.filter(func(u): return u.side == "player").size() == 2, "both player armies render")
	check(app.hud.roster_labels.size() == 2, "compact army strip contains both forces")
	await press("Army headquarters")
	await capture("operation-headquarters")
	check(button(app.hud.hq, "Inspect 4th Hussars") != null and button(app.hud.hq, "Inspect 1st Line Regiment") == null, "headquarters shows only selected army's regiments")
	await press("Return to map")
	app.world.zoom = 1.2
	app.world.center_entity(m.state.army)
	await frames(8)
	var troop = app.world.entities.filter(func(u): return u.side == "player" and u.id == m.state.army.id)[0]
	app.world.inspect_entity(troop)
	await frames()
	await capture("operation-army-inspector")
	check(app.hud.inspector.get_global_rect().end.y <= 900 - app.world.ui_bottom, "army inspector fits above desktop roster")
	app.hud.remove_node(app.hud.inspector)
	var center: Vector2 = app.world.center
	var p0: Vector2 = app.world.project(FieldData.pos(m.state.armies[0]))
	var p1: Vector2 = app.world.project(FieldData.pos(m.state.armies[1]))
	map_drag(p0.min(p1) - Vector2(40, 75), p0.max(p1) + Vector2(40, 25))
	await frames()
	check(m.state.armySelection.size() == 2 and app.world.center == center, "campaign drag selects both armies without panning")
	var destination: Vector2 = app.world.project(FieldData.pos(m.state.army) + Vector2(280, 140))
	var order = InputEventMouseButton.new()
	order.button_index = MOUSE_BUTTON_RIGHT
	order.position = destination
	order.pressed = true
	app.world._unhandled_input(order)
	check(app.world.campaign_preview.size() == 2 and app.world.campaign_preview[0].hours > 0, "campaign route preview includes both armies and arrival estimates")
	await capture("operation-route-preview")
	order.pressed = false
	app.world._unhandled_input(order)
	check(m.state.armies.all(func(a): return not a.path.is_empty()), "right click commands both selected armies")
	var original: Vector2 = FieldData.pos(m.state.armies[0])
	await advance(2)
	check(FieldData.pos(m.state.armies[0]) != original, "campaign army moves visibly")
	m.halt()
	m.select_armies([m.state.armies[1].id])
	await press("Merge armies")
	await capture("operation-merge")
	await press("Merge into Army of Italy")
	check(m.state.armies.size() == 1, "native merge reunites forces")
	await press("Operational objectives")
	await capture("operation-objectives")
	await press("Close")
	get_window().size = Vector2i(390, 844)
	await frames(15)
	app.world.home()
	await capture("operation-mobile")
	check(app.hud.bottom.get_global_rect().end.x <= 390, "campaign bottom strip fits narrow viewport")
	check(app.world.ui_bottom == 156 and app.hud.bottom.size.y <= 156, "campaign rail matches the compact battle inset")
	check(app.hud.objective.size.y < 190, "campaign dispatch shrinks after wrapping at mobile width")
	check(app.hud.title.get_global_rect().end.x <= 390, "campaign title fits narrow viewport")
	await press("Split army")
	await capture("operation-split-mobile")
	var create = button(app.hud.modal, "Create detachment")
	check(create != null and create.get_global_rect().end.x <= 390, "split controls fit narrow viewport")
	await press("Close")
	await press("Army headquarters")
	await capture("operation-headquarters-mobile")
	await press("Return to map")
	var mobile_army: Dictionary = app.world.gather_entities().filter(func(u): return u.side == "player")[0]
	app.world.inspect_entity(mobile_army)
	await frames()
	await capture("operation-inspector-mobile")
	check(app.hud.inspector.get_global_rect().end.y <= 844 - app.world.ui_bottom, "army inspector fits above narrow roster")
	app.hud.remove_node(app.hud.inspector)
	get_window().size = Vector2i(1440, 900)
	await frames(12)
	check(m.split_army(["u4"], "Relief column"), "native encounter detaches supporting army")
	var support: Dictionary = m.state.army
	support.x = 3510.0
	support.y = 1920.0
	m.select_armies(["army"])
	m.state.army.x = 3740.0
	m.state.army.y = 1960.0
	m.state.enemies[0].x = 3810.0
	m.state.enemies[0].y = 1960.0
	m.state.army.morale = 35.0
	check(m.start_battle("e1"), "native campaign enters an operational battle")
	await frames(15)
	await capture("operation-battle")
	check(app.world.sprite_count > 100, "operational battle renders persistent regiments")
	var general = m.find_id(m.state.battle.commanders, "general-" + support.id)
	check(not general.is_empty() and general.arrival > 0, "native battle schedules reinforcing general")
	check(not app.world.gather_entities().any(func(u): return u.id == general.id), "unarrived general is not drawn on battlefield")
	var general_button = button(app.hud.roster, general.name)
	check(general_button != null and general_button.disabled, "reinforcing general control disabled before arrival")
	m.state.battle.time = general.arrival - 0.01
	m.tactics.update(m, 0.02)
	m.publish(false)
	await frames(15)
	check(app.world.gather_entities().any(func(u): return u.id == general.id), "arrived army general renders on battlefield")
	check(general_button != null and not general_button.disabled, "arrived general control enabled")
	if general_button != null: general_button.pressed.emit()
	check(m.state.selectedCommander == general.id, "reinforcing general selected from roster")
	await capture("operation-reinforcements")
	check(m.finish_battle(true), "native battle returns to campaign")
	await frames(15)
	await capture("operation-report")
	check(is_instance_valid(app.hud.modal), "campaign battle report opens")
	await press("Return to campaign")
	check(m.state.mode == "campaign" and m.state.report == null, "report dismissal restores campaign controls")
	await campaign_regrouping_checks()
	await saved_campaign_movement_checks()

func saved_campaign_movement_checks() -> void:
	var path = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
	if path.is_empty(): return
	var original = FileAccess.get_file_as_string(path)
	app.new_campaign("mantua")
	var m: FieldModel = app.model
	check(not m.save_enabled and m.load_campaign(path), "native saved-campaign replay loads without enabling writes")
	var army: Dictionary = m.state.army
	var before = FieldData.pos(army)
	var recovery: float = army.retreatUntil
	var morale: float = army.morale
	app.world.center = before + Vector2(160, 0)
	app.world.zoom = 1.2
	app.world.update_camera()
	await frames(15)
	await click(app.world.project(before + Vector2(195, -12)), MOUSE_BUTTON_RIGHT)
	check(not army.path.is_empty() and army.get("pendingOrder") == null, "player's saved army accepts an immediate march after completed withdrawal")
	var play = button(app.hud.root, "Resume time")
	check(play != null, "saved campaign exposes Play control")
	if play != null: await click(play.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	for i in 20: await get_tree().physics_frame
	check(not m.state.paused and FieldData.pos(army).distance_to(before) > 2, "actual right-click and Play move the saved army in native physics")
	m.state.paused = true
	m.publish(false)
	check(army.retreatUntil == recovery and army.morale == morale, "saved army movement retains recovery and morale")
	check(FileAccess.get_file_as_string(path) == original, "native saved-campaign replay leaves the real save untouched")
	await capture("operation-saved-march")

func campaign_regrouping_checks() -> void:
	app.new_campaign("mantua")
	await frames(12)
	var m: FieldModel = app.model
	var army: Dictionary = m.state.army
	army.retreatUntil = m.state.hours + 4.0
	army["withdrawing"] = true
	army.path = FieldOperations.route(m.terrain, army, FieldData.pos(army) - Vector2(70, 0))
	app.world.center = FieldData.pos(army) + Vector2(160, 0)
	app.world.zoom = 1.2
	app.world.update_camera()
	m.publish(false)
	await frames()
	var destination = FieldData.pos(army) + Vector2(240, 40)
	var point: Vector2 = app.world.project(destination)
	check(app.world.map_input(point), "queued campaign destination is inside the playable map")
	await click(point, MOUSE_BUTTON_RIGHT)
	check(army.get("pendingOrder") != null and FieldData.pos(army.pendingOrder).distance_to(destination) < 1, "real right-click input queues a regrouping army's march")
	check(FieldOperations.forced_retreat(m.state, army) and m.state.paused, "queued input preserves withdrawal and paused time")
	check(app.hud.roster_labels[army.id].status.text.contains("Withdrawing") and app.hud.roster_labels[army.id].status.text.contains("Queued"), "campaign card shows forced withdrawal and queued state")
	check(app.hud.clock_label.text.contains("Paused"), "campaign clock exposes paused time")
	check(is_instance_valid(app.hud.toast) and app.hud.toast.text.contains("queued"), "right-click confirms the queued order")
	await capture("operation-regrouping-desktop")
	app.world.right_start = destination
	app.world.prepare_campaign_preview()
	check(app.world.campaign_preview.size() == 1 and app.world.campaign_preview[0].wait_hours > 0 and app.world.campaign_preview[0].wait_hours < 4, "route preview waits for remaining withdrawal rather than entire recovery")
	app.world.right_start = null
	app.world.campaign_preview.clear()
	get_window().size = Vector2i(390, 844)
	await frames(15)
	await capture("operation-regrouping-mobile")
	var status: Label = app.hud.roster_labels[army.id].status
	check(status.get_theme_font("font").get_string_size(status.text, HORIZONTAL_ALIGNMENT_LEFT, -1, status.get_theme_font_size("font_size")).x <= status.size.x, "recovery and queued status fit the compact army card")
	check(app.hud.clock_label.get_global_rect().end.x <= 390, "paused campaign clock fits the narrow viewport")
	await press("Halt army")
	check(army.get("pendingOrder") == null, "campaign halt cancels queued march")
	get_window().size = Vector2i(1440, 900)
	await frames(12)
	army.path = []
	army["withdrawing"] = false
	await click(app.world.project(destination), MOUSE_BUTTON_RIGHT)
	var before = FieldData.pos(army)
	check(not army.path.is_empty() and army.get("pendingOrder") == null and m.state.paused, "real right-click after withdrawal orders a march without cancelling manual pause")
	check(is_instance_valid(app.hud.toast) and app.hud.toast.text.contains("time paused"), "paused movement order gives explicit feedback")
	await press("Resume time")
	check(not m.state.paused, "campaign Play control resumes actual simulation time")
	for i in 15: await get_tree().physics_frame
	check(FieldData.pos(army) != before, "native physics moves recovering army after right-click and Play")
	m.state.paused = true
	await advance(2.0)
	check(FieldData.pos(army) != before and army.retreatUntil > m.state.hours, "marching proceeds while post-battle recovery remains in force")
	check(app.hud.roster_labels[army.id].status.text == "Marching / recovery", "recovering army card reflects active movement")
	await capture("operation-regrouping-resumed")
	m.halt()
	army["pursuitUntil"] = m.state.hours + 2 * FieldOperations.HOURS_PER_SECOND
	await click(app.world.project(destination), MOUSE_BUTTON_RIGHT)
	check(army.get("pendingOrder") != null and app.hud.roster_labels[army.id].status.text == "Reforming / Queued", "victorious army shows its short pursuit pause")
	check(app.hud.toast.text.contains("reforming"), "queued pursuit has distinct feedback from withdrawal")
	await advance(5)
	check(army.get("pendingOrder") == null and not army.path.is_empty(), "native queued pursuit begins after short reforming pause")

func theme_checks() -> void:
	app.new_campaign("mantua")
	await frames(12)
	check(not app.model.save_enabled, "theme test cannot overwrite player campaign")
	await press("Army headquarters")
	check(app.hud.hq.find_child("HeadquartersAtlas", true, false) != null, "headquarters displays original atlas artwork")
	await capture("theme-headquarters-desktop")
	await commander_checks()
	var tile = button(app.hud.hq, "Inspect 4th Hussars")
	check(tile != null and tile.theme_type_variation == "FieldRecord", "regiments use themed record controls")
	await press("Inspect 4th Hussars")
	check(app.hud.hq.selected_id == "u4", "painted cavalry record selects regiment")
	await press("Change commander: 4th Hussars")
	check(is_instance_valid(app.hud.hq.commander_dialog), "commander portrait opens assignment dialog")
	await capture("theme-commander-dialog")
	app.hud.hq.commander_dialog.hide()
	app.hud.hq.build()
	await press("Armory")
	await capture("theme-armory-desktop")
	await press("Officers")
	await capture("theme-officers-desktop")
	await press("Army")
	for dimensions in [Vector2i(1024, 768), Vector2i(390, 844)]:
		get_window().size = dimensions
		await frames(18)
		await capture("theme-headquarters-" + str(dimensions.x))
		var viewport = Rect2(Vector2.ZERO, Vector2(dimensions))
		check(viewport.encloses(app.hud.hq.get_global_rect()), "headquarters fits viewport " + str(dimensions.x))
		for title in ["Army", "Armory", "Officers", "Return to map"]:
			var control = button(app.hud.hq, title)
			check(control != null and viewport.encloses(control.get_global_rect()), "headquarters navigation reachable %s/%d" % [title, dimensions.x])
		check(app.hud.hq.detail.get_global_rect().end.x <= dimensions.x, "regimental details do not overflow horizontally")
	await press("Armory")
	await capture("theme-armory-mobile")
	await press("Officers")
	await capture("theme-officers-mobile")
	await press("Return to map")
	get_window().size = Vector2i(1440, 900)
	await frames(16)
	await press("Operational objectives")
	await capture("theme-dispatch-desktop")
	await press("Center on Valeggio")
	check(not is_instance_valid(app.hud.modal), "dispatch objective remains an actionable map link")
	app.start_skirmish("bridge")
	await frames(16)
	app.model.select(["u1"])
	await press("Column formation")
	check(app.model.state.battle.units[0].formationChange != null, "themed formation control still gives order")
	await press("Run / walk")
	check(app.model.state.battle.units[0].running, "themed running control retains toggle behavior")
	check(app.hud.action_row.get_children().any(func(child): return child is VSeparator), "battle commands have functional grouping")
	await command_rail_checks()
	await capture("theme-battle-desktop")
	for i in app.world.labels.size():
		var rect: Rect2 = app.world.labels[i].rect
		check(not app.world.label_obstacles.any(func(obstacle): return rect.intersects(obstacle)), "pennant label avoids HUD " + str(i))
		check(not app.world.labels.slice(i + 1).any(func(label): return rect.intersects(label.rect)), "pennant labels do not overlap " + str(i))
	get_window().size = Vector2i(390, 844)
	await frames(18)
	await capture("theme-battle-mobile")
	check(app.hud.bottom.get_global_rect().end.x <= 390, "compact battle controls fit narrow viewport")
	check(app.world.ui_bottom == 156, "theme does not enlarge battlefield command strip")
	get_window().size = Vector2i(1440, 900)
	await frames(12)
	app.model.finish_battle(true)
	await frames(12)
	await capture("theme-report-desktop")
	check(app.hud.modal.find_child("RegimentalReturns", true, false) != null, "battle report has aligned casualty returns")
	await press("Close")
	app.resume_campaign()
	await frames(12)
	app.model.start_battle("e1")
	app.model.finish_battle(false, true)
	await frames(12)
	get_window().size = Vector2i(390, 844)
	await frames(16)
	await capture("theme-report-mobile")
	var returns = app.hud.modal.find_child("RegimentalReturns", true, false)
	check(returns != null and returns.get_global_rect().end.x <= 390, "casualty table fits mobile report")
	await press("Return to campaign")
	check(app.model.state.mode == "campaign", "themed report returns to live campaign")
	get_window().size = Vector2i(1440, 900)
	await frames(12)

func command_rail_checks() -> void:
	var m: FieldModel = app.model
	var hud: FieldHud = app.hud
	check(hud.bottom.find_child("CommandAtlas", true, false) != null, "command rail reuses original atlas material")
	var first: Button = hud.roster_labels.u1.button
	check(first.theme_type_variation == "RegimentCard" and first.find_child("RegimentArtwork", true, false) != null, "roster has illustrated regimental controls")
	m.select(["u2"])
	await frames()
	await click(first.get_global_rect().position + Vector2(30, 25), MOUSE_BUTTON_LEFT)
	check(m.state.selected == ["u1"], "painted figure remains part of the unit-card click target")
	var shift = InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	await frames(1)
	await click(hud.roster_labels.u2.button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	shift.pressed = false
	Input.parse_input_event(shift)
	await frames(1)
	check(m.state.selected.size() == 2 and "u1" in m.state.selected and "u2" in m.state.selected, "illustrated cards preserve additive selection")
	check(hud.command_caption.text == "2 regiments selected", "order heading reflects a mixed selection")
	await press("Select I Corps")
	var corps_control = button(hud.bottom, "Select I Corps")
	check(corps_control != null and corps_control.button_pressed, "whole-corps selection has a persistent highlight")
	m.select([])
	check(button(hud.bottom, "Charge").disabled and button(hud.bottom, "Line formation").disabled, "empty selection disables inapplicable orders")
	await press("Select supply train")
	check(m.state.selectedSupply and hud.roster_labels.supply.button.button_pressed, "supply card shows its selection")
	check(hud.roster_labels.supply.stock.text == "%d stores" % m.state.battle.wagons[0].stock, "supply card excludes enemy stores")
	check(not button(hud.bottom, "Halt").disabled and button(hud.bottom, "Charge").disabled, "supply selection retains only applicable orders")
	var general = m.state.battle.commanders[0]
	await press(general.name)
	check(m.state.selectedCommander == general.id and not button(hud.bottom, "General follows army").disabled, "commander portrait selects the general and enables following")
	for speed in [1.0, 0.5]:
		await press(str(speed).trim_suffix(".0") + "x")
		check(m.state.speed == speed, "engraved time control selects " + str(speed))
	m.select(["u1"])
	check(hud.roster_labels.u1.status.text == "Reforming", "compact status keeps the actual reforming state readable")
	var unit = m.state.battle.units[0]
	var men: float = unit.men
	unit.men = 1500
	m.publish(false)
	var strength: Label = hud.roster_labels.u1.strength
	var status: Label = hud.roster_labels.u1.status
	check(strength.get_theme_font("font").get_string_size(strength.text, HORIZONTAL_ALIGNMENT_LEFT, -1, strength.get_theme_font_size("font_size")).x <= strength.size.x, "four-digit regiment strength fits its readout")
	check(not strength.get_rect().intersects(status.get_rect()), "strength and order status have separate bounds")
	unit.men = men
	m.publish(false)
	for dimensions in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(740, 700), Vector2i(739, 700), Vector2i(390, 844), Vector2i(320, 640)]:
		get_window().size = dimensions
		await frames(14)
		var viewport = Rect2(Vector2.ZERO, Vector2(dimensions))
		check(viewport.encloses(hud.bottom.get_global_rect()), "command rail stays inside viewport " + str(dimensions.x))
		check(hud.bottom.size.y <= app.world.ui_bottom, "command rail preserves map height " + str(dimensions.x))
		check(hud.header.size.y <= app.world.ui_top, "header fits the reserved map inset " + str(dimensions.x))
		check(viewport.encloses(hud.header.get_global_rect()), "header stays inside viewport " + str(dimensions.x))
		check(viewport.encloses(button(hud.header, "Settings and saves").get_global_rect()), "header settings stay reachable " + str(dimensions.x))
		check(not hud.title.get_global_rect().intersects(hud.objective.get_global_rect()), "wrapped map title clears the objective " + str(dimensions.x))
		check(hud.objective.size.y < 190, "objective remains content-sized after resize " + str(dimensions.x))
		var scroll: ScrollContainer = hud.action_row.get_parent()
		var last = button(hud.action_row, "Withdraw from battle")
		scroll.ensure_control_visible(last)
		await frames()
		check(viewport.encloses(last.get_global_rect()), "last command can be reached by scrolling " + str(dimensions.x))
		scroll.scroll_horizontal = 0
		var strip: ScrollContainer = hud.roster.get_parent()
		var supply: Button = hud.roster_labels.supply.button
		strip.ensure_control_visible(supply)
		await frames()
		check(viewport.encloses(supply.get_global_rect()), "support cards remain reachable " + str(dimensions.x))
		strip.scroll_horizontal = 0
		if dimensions.x in [1280, 1024, 320]: await capture("command-rail-battle-" + str(dimensions.x))
	var corps = m.state.corps.duplicate(true)
	var unit_count = m.state.battle.units.size()
	for i in 6:
		var extra_corps = corps[0].duplicate(true)
		extra_corps.id = "theme-corps-" + str(i)
		extra_corps.name = "Reserve %d Corps" % (i + 1)
		m.state.corps.append(extra_corps)
		var incoming = unit.duplicate(true)
		incoming.id = "theme-unit-" + str(i)
		incoming.corpsId = extra_corps.id
		incoming.arrival = 99999.0
		m.state.battle.units.append(incoming)
	hud.build()
	await frames(12)
	check(hud.corps_row.get_child_count() == 8 and hud.bottom.size.x <= 320 and hud.bottom.size.y <= app.world.ui_bottom, "eight-corps command rail still fits a narrow viewport")
	var corps_scroll: ScrollContainer = hud.corps_row.get_parent()
	var last_corps: Button = hud.corps_row.get_child(7)
	corps_scroll.ensure_control_visible(last_corps)
	await frames()
	check(Rect2(Vector2.ZERO, Vector2(320, 640)).encloses(last_corps.get_global_rect()), "last corps remains reachable in a large army")
	m.state.corps = corps
	m.state.battle.units.resize(unit_count)
	m.select(["u1"])
	hud.build()
	get_window().size = Vector2i(1440, 900)
	await frames(14)

func slope_checks() -> void:
	app.start_skirmish("ridge")
	var m: FieldModel = app.model
	var offset = m.terrain.battle_offset
	for u in m.state.battle.units:
		u.arrival = 99999.0
	var unit = m.state.battle.units[0]
	unit.arrival = 0.0
	unit.x = 560.0 + offset.x
	unit.y = 400.0 + offset.y
	unit.facing = PI / 2.0
	m.formations.reset(unit)
	m.tactics.update_visibility(m)
	m.publish(false)
	app.world.center = FieldData.pos(unit)
	app.world.zoom = 4.0
	app.world.update_camera()
	await capture("slope-infantry-standing")
	# Crops now shade the terrain itself, so they cannot float above or cut
	# through hills as separate field planes could.
	var arrays = app.world.ground_mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var surface_agrees = true
	for i in range(0, vertices.size(), 37):
		var point = vertices[i]
		surface_agrees = surface_agrees and absf(point.y - m.terrain.height_at(Vector2(point.x, point.z))) < 0.001
	check(surface_agrees and app.world.ground_material.get_shader_parameter("cultivated_map") != null, "cultivated material uses the exact hillside surface")
	var started = Time.get_ticks_usec()
	for i in 500: app.world.figure_footing(Vector2(410 + i * 0.25, 430) + offset, 13.5, 0)
	print("FOOTING COST: 500 moving figures %.2fms" % ((Time.get_ticks_usec() - started) / 1000.0))
	for type in [0, 1, 2, 4, 6, 7]:
		var size_value = 13.5 if type < 2 else 25.0
		var previous = -INF
		var smooth = true
		var grounded = true
		var shadows_grounded = true
		var bounded_tilt = true
		for i in 60:
			var p = Vector2(605 + i * 0.5, 440) + offset
			var foot: Dictionary = app.world.figure_footing(p, size_value, type)
			var radius = size_value * (0.20 if type < 2 else 0.38)
			for dx in [-radius, 0.0, radius]:
				grounded = grounded and foot.height + tan(foot.tilt) * dx >= m.terrain.height_at(p + Vector2(dx, 0))
			bounded_tilt = bounded_tilt and (foot.tilt == 0 if type < 2 else absf(foot.tilt) <= 0.14)
			if is_finite(previous): smooth = smooth and absf(foot.height - previous) < 0.7
			previous = foot.height
			for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(-0.5, 0, 0.5), Vector3(0.5, 0, 0.5)]:
				var point: Vector3 = foot.shadow * corner
				shadows_grounded = shadows_grounded and point.y >= m.terrain.height_at(Vector2(point.x, point.z))
		check(grounded, "boots and wheels clear slope type " + str(type))
		check(bounded_tilt, "slope tilt remains restrained type " + str(type))
		check(smooth, "footing moves continuously across hill triangles type " + str(type))
		check(shadows_grounded, "contact shadow follows hillside type " + str(type))
	var actual = app.world.batches[0].multimesh.get_instance_transform(0)
	var soldier: FieldFormations.Soldier = m.formations.positions(unit)[0]
	var foot_position = actual * Vector3(0, 0.5 - 0.92, 0)
	var support = app.world.figure_footing(soldier.p, 13.5, 0)
	check(absf(foot_position.y - support.height) < 0.001, "painted infantry feet are registered to support height")
	check(support.height - m.terrain.height_at(soldier.p) < 2.5, "infantry is not lifted by the full sprite width")
	m.select([unit.id])
	check(m.move_units(Vector2(610, 420) + offset), "regiment accepts hillside movement")
	await advance(2)
	await capture("slope-infantry-moving")
	var positions = m.formations.positions(unit)
	check(positions.any(func(p): return p.moving > 0), "individual infantry animates while crossing hillside")
	for spec in [["u4", Vector2(645, 455) + offset], ["u5", Vector2(600, 560) + offset]]:
		var member = m.find_id(m.state.battle.units, spec[0])
		member.arrival = 0.0
		member.x = spec[1].x
		member.y = spec[1].y
		member.facing = 0.0
		m.formations.reset(member)
	m.state.battle.wagons[0].x = 630.0 + offset.x
	m.state.battle.wagons[0].y = 530.0 + offset.y
	m.publish(false)
	app.world.center = Vector2(610, 470) + offset
	app.world.zoom = 3.0
	app.world.update_camera()
	await capture("slope-mixed-units")
	for type in [0, 2, 4, 7]: check(app.world.batches[type].multimesh.visible_instance_count > 0, "slope fixture draws unit type " + str(type))
	var shot = get_viewport().get_texture().get_image().get_data()
	await advance(0.8)
	await frames(6)
	check(shot != get_viewport().get_texture().get_image().get_data(), "hillside formation produces moving rendered pixels")
	get_window().size = Vector2i(390, 844)
	app.world.center_entity(unit)
	await frames(16)
	await capture("slope-mobile")
	get_window().size = Vector2i(1440, 900)
	app.resume_campaign()
	await frames(16)
	app.model.state.army.x = 600.0
	app.model.state.army.y = 580.0
	app.world.center_entity(app.model.state.army)
	app.world.zoom = 4.0
	app.world.update_camera()
	await capture("slope-campaign")
	check(app.world.sprite_count > 0, "campaign escorts also use terrain footing")

func map_drag(start: Vector2, end: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = start
	event.pressed = true
	app.world._unhandled_input(event)
	var motion = InputEventMouseMotion.new()
	motion.position = end
	motion.relative = end - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	app.world._unhandled_input(motion)
	event.position = end
	event.pressed = false
	app.world._unhandled_input(event)

func large_map_checks() -> void:
	for theater in ["italy", "mantua"]:
		app.new_campaign(theater)
		await frames(10)
		check(not app.model.save_enabled, "map verification cannot overwrite campaign save")
		app.world.overview()
		await capture("large-" + theater + "-overview")
		check(app.model.terrain.map_size == Vector2(17280, 11520), theater + " expanded campaign installed")
		check(app.world.camera.far > 10000, theater + " overview has sufficient depth range")
		await large_camera_checks(theater)
		app.world.home()
		await capture("large-" + theater + "-army")
		var before = FieldData.pos(app.model.state.army)
		await click(app.world.project(before + Vector2(200, 0)), MOUSE_BUTTON_RIGHT)
		check(not app.model.state.army.path.is_empty(), theater + " right click still issues campaign march")
		await advance(1)
		check(FieldData.pos(app.model.state.army) != before, theater + " expanded campaign army moves")
	for scenario in ["bridge", "village", "ridge"]:
		app.start_skirmish(scenario)
		await frames(10)
		var m: FieldModel = app.model
		check(m.terrain.map_size == Vector2(5760, 3840), scenario + " expanded battle installed")
		app.world.overview()
		await capture("large-" + scenario + "-overview")
		check(app.world.fog_texture.get_width() == 120 and app.world.fog_texture.get_height() == 80, scenario + " fog texture covers whole battlefield")
		await large_camera_checks(scenario)
		app.world.home()
		await capture("large-" + scenario + "-center")
		if scenario == "bridge":
			for y in m.terrain.crossings:
				app.world.center = Vector2(m.terrain.channel_x(y), y)
				app.world.zoom = 1.8
				app.world.update_camera()
				await capture("large-crossing-" + str(int(y)))
				check(absf(app.world.road_height(app.world.center) - 7.85) < 0.01, "expanded crossing road aligns with bridge deck")
		var u: Dictionary = m.state.battle.units[0]
		u.x = 2480
		u.y = 1730
		m.formations.reset(u)
		m.select([u.id])
		app.world.center_entity(u)
		app.world.zoom = 1.5
		app.world.update_camera()
		await frames()
		await click(app.world.project(Vector2(2700, 1730)), MOUSE_BUTTON_RIGHT)
		check(u.goal != null and FieldData.pos(u.goal).distance_to(Vector2(2700, 1730)) < 1.0, scenario + " native right click targets new outer flank")
		var before = FieldData.pos(u)
		await advance(1)
		check(u.x > before.x, scenario + " outer-flank troop actually moves")
		m.state.battle.bodies.append({"x": 2580.0, "y": 1730.0, "kind": "infantry", "side": "enemy", "facing": 0.0, "mounted": false, "time": m.state.battle.time})
		app.world.invalidate()
		await capture("large-" + scenario + "-flank")
		check(is_instance_valid(app.world.body_mesh) and app.world.body_material.get_shader_parameter("map_size") == m.terrain.map_size, scenario + " casualty fog uses expanded map coordinates")
	get_window().size = Vector2i(390, 844)
	await frames(12)
	await large_camera_checks("battle-mobile")
	app.world.home()
	await capture("large-battle-mobile")
	app.new_campaign("mantua")
	await frames(12)
	await large_camera_checks("campaign-mobile")
	app.world.home()
	await capture("large-campaign-mobile")

func large_camera_checks(label: String) -> void:
	var size_value = get_viewport().get_visible_rect().size
	for corner in [Vector2.ZERO, app.model.terrain.map_size]:
		app.world.center = corner
		app.world.zoom = 0.001
		app.world.update_camera()
		await frames(2)
		for screen in [Vector2(4, app.world.ui_top + 4), Vector2(size_value.x - 4, size_value.y - app.world.ui_bottom - 4)]:
			var ground = app.world.ground(screen)
			check(ground != null and app.model.terrain.render_bounds.has_point(ground), label + " zoom-out never exposes unrendered ground")
		check(not app.world.camera.is_position_behind(Vector3(app.world.center.x, 0, app.world.center.y)), label + " camera keeps terrain in front of near plane")
	app.world.overview()
	await capture("large-" + label + "-wide")

func camera_checks() -> void:
	var center = app.world.center
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.position = Vector2(620, 390)
	press.pressed = true
	Input.parse_input_event(press)
	var drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(650, 410)
	drag.relative = Vector2(30, 20)
	Input.parse_input_event(drag)
	await frames(2)
	check(app.world.center != center, "native touch drag pans campaign")
	var second = InputEventScreenTouch.new()
	second.index = 1
	second.position = Vector2(750, 410)
	second.pressed = true
	Input.parse_input_event(second)
	var zoom = app.world.zoom
	drag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(810, 410)
	drag.relative = Vector2(60, 0)
	Input.parse_input_event(drag)
	await frames(2)
	check(app.world.zoom > zoom, "native pinch zoom changes camera scale")
	press.pressed = false
	second.pressed = false
	Input.parse_input_event(press)
	Input.parse_input_event(second)
	app.world.center = Vector2(-100000, -100000)
	app.world.zoom = 0.01
	app.world.update_camera()
	await frames()
	var p = app.world.ground(Vector2(4, 100))
	check(p.x >= -1401 and p.y >= -1401, "zoom-out camera remains inside padded terrain")
	await capture("campaign-wide-boundary")
	app.world.home()
	app.world.zoom = 6
	app.world.center_entity(app.model.state.army)
	await capture("campaign-6x")
	check(app.world.zoom == 6, "campaign reaches 6x zoom")
	app.world.home()
	await frames()

func performance_check() -> void:
	app.start_skirmish("bridge")
	app.model.select_corps("c1")
	app.model.move_units(Vector2(660, 480))
	await advance(12)
	await frames(20)
	app.model.terrain.profile_enabled = "--profile" in OS.get_cmdline_user_args()
	app.model.state.paused = false
	var started_battle_time: float = app.model.state.battle.time
	var timings: Array[float] = []
	var physics_times: Array[float] = []
	var process_times: Array[float] = []
	var draw_times: Array[float] = []
	var previous = Time.get_ticks_usec()
	var began = previous
	var i = 0
	while Time.get_ticks_usec() - began < 5000000 or i < 240:
		await get_tree().process_frame
		var now = Time.get_ticks_usec()
		if i >= 20:
			timings.append(float(now - previous) / 1000.0)
			physics_times.append(app.physics_micros / 1000.0)
			process_times.append(app.world.process_micros / 1000.0)
			draw_times.append(app.world.draw_micros / 1000.0)
		app.physics_micros = 0
		previous = now
		i += 1
	app.model.state.paused = true
	app.model.terrain.profile_enabled = false
	print("TERRAIN QUERY PROFILE (usec/calls): ", app.model.terrain.profile_usec, " / ", app.model.terrain.profile_calls)
	print("SIMULATION PROFILE (usec): ", app.model.profile_usec)
	timings.sort()
	physics_times.sort()
	process_times.sort()
	draw_times.sort()
	performance = {"medianFrameMs": timings[timings.size() / 2], "p95FrameMs": timings[int(timings.size() * 0.95)], "worstFrameMs": timings.back(), "samples": timings.size(), "troops": app.world.sprite_count}
	print("GODOT PERFORMANCE: ", performance)
	print("PROFILE MEDIAN MS: physics ", physics_times[physics_times.size() / 2], " world ", process_times[process_times.size() / 2], " overlay ", draw_times[draw_times.size() / 2])
	check(app.model.state.battle.time - started_battle_time > 1.0, "performance sample runs active battle")
	check(performance.medianFrameMs < 20, "active battle median frame time below 20ms on test hardware")
	check(performance.p95FrameMs < 33.4, "active battle p95 frame time below 33.4ms on test hardware")

func run_profile(main) -> void:
	app = main
	seed(2741796)
	await frames(10)
	get_window().size = Vector2i(1440, 900)
	await frames(10)
	await performance_check()
	get_tree().quit(0 if failures.is_empty() else 1)
