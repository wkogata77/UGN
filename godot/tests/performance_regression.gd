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

func run() -> void:
	spatial_checks()
	geometry_checks()
	clock_checks()
	contact_checks()
	sweep_checks()
	firing_checks()
	if "--visual" in OS.get_cmdline_user_args(): await visual_checks()
	print("GODOT PERFORMANCE REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func spatial_checks() -> void:
	var m = FieldBattleExercises.create(20)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1796
	for u in m.state.battle.units:
		u.arrival = 0
		u.x = 640.0 + rng.randf_range(-180, 180)
		u.y = 640.0 + rng.randf_range(-180, 180)
		u.facing = rng.randf_range(-PI, PI)
		if u.kind == "infantry":
			u.formation = ["line", "column", "square"][rng.randi_range(0, 2)]
			if rng.randf() > 0.5: u.role = "skirmishers"
	var index = FieldBattleIndex.new()
	index.rebuild(m.state.battle)
	for u in m.state.battle.units:
		var side = "enemy" if u.side == "player" else "player"
		var shape: Dictionary = index.shapes[u.id]
		var expected: Array = []
		var actual: Array = []
		for other in m.tactics.active(m.state.battle, side):
			if FieldContact.gap(shape, FieldContact.shape(other)) <= FieldContact.REACH: expected.append(other.id)
		for other in index.nearby(shape.p, shape.radius + FieldContact.REACH, side):
			if FieldContact.gap(shape, index.shapes[other.id]) <= FieldContact.REACH: actual.append(other.id)
		expected.sort()
		actual.sort()
		check(expected == actual, "spatial contacts match full search for " + u.id)
	var u: Dictionary = m.state.battle.units[0]
	var old = FieldData.pos(u)
	u.x += 1200
	index.update_unit(u)
	check(index.nearby(FieldData.pos(u), 1, u.side).any(func(other): return other.id == u.id), "moving regiment is inserted in its new cells")
	check(not index.nearby(old, 1, u.side).any(func(other): return other.id == u.id), "moving regiment leaves its old spatial cells")

func geometry_checks() -> void:
	var m = FieldBattleExercises.create()
	var u: Dictionary = m.state.battle.units[0]
	FieldFormations.order(u, "column")
	u.formationChange.elapsed = 1.0
	var before = FieldFormations.offsets(u).duplicate()
	var old_bounds = FieldFormations.bounds(u)
	u.formationChange.elapsed = 3.0
	var after = FieldFormations.offsets(u)
	check(before != after and old_bounds != FieldFormations.bounds(u), "changing elapsed time invalidates cached transition geometry")
	u.visualCount = 40
	check(FieldFormations.offsets(u).size() == 40, "changing roster size invalidates cached transition geometry")
	u.role = "skirmishers"
	check(FieldFormations.bounds(u).size.x > old_bounds.size.x * 0.4, "role scale participates in geometry cache")
	var clone: Dictionary = u.duplicate(true)
	clone.formationChange.to = "square"
	var square = FieldFormations.offsets(clone).duplicate()
	check(square != FieldFormations.offsets(u), "same unit ID in separate models cannot reuse a different transition")

func clock_fixture(interval: float) -> FieldModel:
	var m = FieldBattleExercises.create()
	m.figure_interval = interval
	m.terrain.water = false
	m.terrain.buildings.clear()
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.forests = []
	m.terrain.forests = []
	m.terrain.field.hills = []
	m.terrain.relief = 0
	m.state.battle.aiClock = -10000
	for u in m.state.battle.units: u.arrival = 99999
	var u: Dictionary = m.state.battle.units[0]
	u.arrival = 0
	u.x = 500
	u.y = 500
	u.facing = 0
	m.formations.reset(u)
	m.path_unit(u, Vector2(750, 500))
	m.state.paused = false
	return m

func clock_checks() -> void:
	var a = clock_fixture(1.0 / 30.0)
	var b = clock_fixture(1.0 / 15.0)
	var revisions = Vector2i(a.figure_revision, b.figure_revision)
	for i in 90:
		a.tick(1.0 / 30.0)
		b.tick(1.0 / 30.0)
	var ua: Dictionary = a.state.battle.units[0]
	var ub: Dictionary = b.state.battle.units[0]
	check(FieldData.pos(ua).is_equal_approx(FieldData.pos(ub)), "presentation rate preserves tactical movement exactly")
	check(is_equal_approx(ua.condition, ub.condition) and ua.ammo == ub.ammo and ua.men == ub.men, "presentation rate preserves fatigue, ammunition and casualties")
	check(a.figure_revision - revisions.x == 90 and b.figure_revision - revisions.y == 45, "15 Hz figures are independent of 30 Hz tactical updates")
	var difference = 0.0
	for i in a.formations.positions(ua).size(): difference = maxf(difference, a.formations.positions(ua)[i].p.distance_to(b.formations.positions(ub)[i].p))
	check(difference < 2, "interpolated visual rate retains equivalent marching positions")
	var saved_clock = b.visual_clock
	b.reset_presentation()
	check(b.figure_commands.is_empty() and b.figure_sample_clock == saved_clock and b.figure_clock == 0, "save/battle transitions reset presentation snapshots")

func contact_checks() -> void:
	var m = clock_fixture(1.0 / 15.0)
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[12]
	a.target = null
	a.waypoints = []
	b.x = a.x + 35
	b.y = a.y
	b.arrival = 0
	b.facing = PI
	a.meleeTargetId = b.id
	b.meleeTargetId = a.id
	a.meleeContacts = [b.id]
	b.meleeContacts = [a.id]
	m.formations.reset(a)
	m.formations.reset(b)
	for i in 180: m.formations.advance([a, b], i / 30.0, 1.0 / 30.0)
	check(m.formations.motion[a.id].get("sleeping", false), "settled melee ranks sleep while shader continues their action cycle")
	b.y += 8
	m.formations.advance([a, b], 7, 1.0 / 30.0)
	check(not m.formations.motion[a.id].sleeping, "moving enemy contact line wakes settled melee figures")
	for i in 180: m.formations.advance([a, b], 8 + i / 30.0, 1.0 / 30.0)
	a.men -= 18
	m.formations.advance([a, b], 15, 1.0 / 30.0, m.state.battle.bodies)
	check(not m.formations.motion[a.id].sleeping and not m.state.battle.bodies.is_empty(), "casualties wake melee ranks and preserve fallen bodies")
	a.meleeTargetId = null
	a.meleeContacts = []
	m.formations.advance([a], 16, 1.0 / 30.0)
	check(not m.formations.motion[a.id].sleeping, "ending melee wakes figures to restore ordinary formation")

func sweep_checks() -> void:
	var m = clock_fixture(1.0 / 15.0)
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = a.duplicate(true)
	b.x = a.x + 200
	var shape = FieldContact.shape(a)
	check(FieldContact.sweep_hit(shape, Vector2(400, 0), FieldContact.shape(b), 3), "continuous sweep catches an obstacle between clear endpoints")
	check(not FieldContact.sweep_hit(shape, Vector2(-100, 0), FieldContact.shape(b), 3), "continuous sweep permits movement away from distant troops")
	b.y += 300
	check(not FieldContact.sweep_hit(shape, Vector2(400, 0), FieldContact.shape(b), 3), "continuous sweep permits a separated parallel lane")
	b.x = a.x
	b.y = a.y
	check(FieldContact.sweep_hit(shape, Vector2.ZERO, FieldContact.shape(b), 3), "continuous sweep detects existing overlap")

func firing_checks() -> void:
	var m = clock_fixture(1.0 / 15.0)
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[12]
	var friend: Dictionary = m.state.battle.units[1]
	a.target = null
	a.waypoints = []
	a.attackId = b.id
	a.holdFire = false
	a.reload = 1
	b.merge({"arrival": 0.0, "x": a.x + 140, "y": a.y, "facing": PI, "visible": true, "holdFire": true}, true)
	friend.merge({"arrival": 0.0, "x": a.x + 70, "y": a.y, "facing": 0.0, "holdFire": true}, true)
	check(m.tactics.automatic_target(m, a, b), "reloading troops may track a visible target without tracing a volley")
	var ammo: float = a.ammo
	var strength: float = b.men
	a.reload = 0
	m.tactics.update(m, 0.01)
	check(a.ammo == ammo and b.men == strength, "ready volley rechecks friendly obstruction before ammo or damage")
	friend.arrival = 99999
	a.reload = 0
	m.tactics.update(m, 0.01)
	check(a.ammo < ammo and b.men < strength, "ready volley fires after friendly obstruction clears")

func frames() -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw

func centroid(pixels: Image, empty: Image, region: Rect2i) -> Vector2:
	var sum = Vector2.ZERO
	var weight = 0.0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var a = pixels.get_pixel(x, y)
			var b = empty.get_pixel(x, y)
			var delta = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if delta < 0.1: continue
			sum += Vector2(x, y) * delta
			weight += delta
	return sum / maxf(weight, 0.0001)

func different_pixels(a: Image, b: Image, region: Rect2i) -> int:
	var count = 0
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var ca = a.get_pixel(x, y)
			var cb = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.15: count += 1
	return count

func visual_checks() -> void:
	var m = clock_fixture(1.0 / 15.0)
	m.state.paused = true
	root.size = Vector2i(1440, 900)
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	world.center = Vector2(510, 500)
	world.zoom = 6
	world.update_camera()
	await frames()
	world.set_process(false)
	world.overlay.hide()
	for batch in world.batches: batch.multimesh.visible_instance_count = 0
	world.shadow_batch.multimesh.visible_instance_count = 0
	world.smoke_batch.multimesh.visible_instance_count = 0
	await frames()
	var empty = root.get_texture().get_image()
	var u: Dictionary = m.state.battle.units[0]
	u.x = 520
	u.y = 500
	world.entities = [u]
	world.placing_entity = u.id
	world.selection_regions[u.id] = []
	world.selection_visuals[u.id] = []
	var counts = [0, 0, 0, 0, 0, 0, 0, 0]
	world.sprite_count = 0
	world.place(counts, 0, Vector2(520, 500), 13.5, 0, 0, 0, 100, "", 0, 0, 2.8, 0, Vector2(500, 500), 0, 0)
	world.batches[0].multimesh.visible_instance_count = 1
	var stored = world.batches[0].multimesh.get_instance_color(0)
	var transform = world.batches[0].multimesh.get_instance_transform(0)
	check(absf((transform.basis * Vector3(stored.r, stored.g, stored.b)).x + 20) < 0.01, "GPU buffer retains previous position without losing signed motion")
	var centers: Array[Vector2] = []
	var region = Rect2i(470, 230, 500, 380)
	for fraction in [0.0, 0.5, 1.0]:
		world.batches[0].material_override.set_shader_parameter("interpolation_fraction", fraction)
		await frames()
		var pixels = root.get_texture().get_image()
		pixels.save_png("res://test-results/performance-interpolation-" + str(fraction) + ".png")
		centers.append(centroid(pixels, empty, region))
	check(centers[0].x + 35 < centers[1].x and centers[1].x + 35 < centers[2].x, "native pixels move between simulation ticks")
	check(absf(centers[1].x - (centers[0].x + centers[2].x) * 0.5) < 2.0, "native GPU interpolation has a linear midpoint")
	m.state.paused = false
	for fraction in [0.0, 0.5, 1.0]:
		world.render_fraction = fraction
		var hit = world.hit_entity(world.drawn_regions(u.id)[0].get_center())
		check(hit.get("id") == u.id, "selection follows interpolated soldier at " + str(fraction))
	# Reuse one live instance across the shader clock's wrap boundary. These
	# frames must keep reloading without further CPU custom-data uploads.
	world.placing_entity = ""
	counts.fill(0)
	world.sprite_count = 0
	world.place(counts, 0, Vector2(520, 500), 13.5, 0, 0, 0, 0.1, "musket", 0, 0, 2.8, 0, Vector2(520, 500), 0, 0, 30.0)
	var custom = world.batches[0].multimesh.get_instance_custom_data(0)
	var reload_images: Array[Image] = []
	for clock in [30.1, 31.3, 32.3, 33.0]:
		world.batches[0].material_override.set_shader_parameter("simulation_time", clock)
		await frames()
		var pixels = root.get_texture().get_image()
		pixels.save_png("res://test-results/performance-reload-" + str(clock) + ".png")
		reload_images.append(pixels)
	check(floori(custom.b / 10.0) == 10, "live firing instance carries shader-driven reload state")
	check(different_pixels(reload_images[0], reload_images[1], region) > 50, "live shader advances from firing to ramrod animation")
	check(different_pixels(reload_images[1], reload_images[2], region) > 50, "live shader continues reloading across its clock wrap")
	check(different_pixels(reload_images[2], reload_images[3], region) > 50, "live shader returns to ready after reloading")
	check(custom == world.batches[0].multimesh.get_instance_custom_data(0), "live reload advances without uploading the figure again")
	counts.fill(0)
	world.sprite_count = 0
	world.place(counts, 0, Vector2(520, 500), 13.5, 0, 0, 0, 100, "melee", 0)
	var melee_images: Array[Image] = []
	for clock in [0.1, 0.55, 1.25]:
		world.batches[0].material_override.set_shader_parameter("simulation_time", clock)
		await frames()
		var pixels = root.get_texture().get_image()
		pixels.save_png("res://test-results/performance-melee-" + str(clock) + ".png")
		melee_images.append(pixels)
	check(different_pixels(melee_images[0], melee_images[1], region) > 50 and different_pixels(melee_images[1], melee_images[2], region) > 50, "settled melee continues guard, thrust and parry without CPU movement")
	world.populate()
	var cached: FieldWorld.FigureVisual = world.support_cache[Vector2i(0, 0)]
	world.populate()
	check(not world.manual_buffer_change and world.support_cache[Vector2i(0, 0)] == cached, "production placement preserves render caches between populations")
	m.state.paused = true
	world.queue_free()
	await process_frame
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
