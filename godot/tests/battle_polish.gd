extends SceneTree

var checks = 0
var failures: Array[String] = []
var performance: Dictionary = {"method": "Manually stepped render exercise; simulation advances once per frame. Use tests/performance.gd for fixed-rate runtime measurements."}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for size_value in [12, 20]:
		var m = FieldBattleExercises.create(size_value, 2)
		check(m.state.battle.units.size() == size_value * 2, "exercise has two complete armies: " + str(size_value))
		check(m.state.units.size() == size_value and m.state.corps.size() == size_value / 4, "player regiments have corps of four")
		check(m.valid_state(m.state), "exercise state validates: " + str(size_value))
		check(not m.save_enabled and m.state.paused, "exercise opens paused without campaign writes")
		check(not m.save_campaign("user://exercise-must-not-save.json"), "explicit exercise save cannot overwrite campaign slot")
		var malformed: Dictionary = m.state.duplicate(true)
		malformed.battle["bridgeTraffic"] = {"player:960": 42}
		check(not m.valid_state(malformed), "invalid crossing reservation is rejected on import")
		malformed = m.state.duplicate(true)
		malformed.battle.units[0]["meleeContacts"] = [12]
		check(not m.valid_state(malformed), "invalid melee contact list is rejected on import")
		check(m.state.battle.units.filter(func(u): return u.arrival > 0).size() == 2, "both sides have arriving reserves")
		check(m.terrain.buildings.filter(func(b): return b.variant == 2).size() == 1, "authored villages share one church landmark")
		var before = Time.get_ticks_usec()
		var path = m.terrain.route(Vector2(1250, 810), Vector2(1700, 1100), 2)
		print("POLISH ROUTE %.2fms / %d points" % [(Time.get_ticks_usec() - before) / 1000.0, path.size()])
		check(not path.is_empty(), "authored village and crossing remain navigable")
	mechanics()
	save_compatibility()
	if "--profile-only" in OS.get_cmdline_user_args(): profile_simulation()
	if "--visual" in OS.get_cmdline_user_args(): await visuals()
	var filename = "res://test-results/battle-polish-verification.json" if "--visual" in OS.get_cmdline_user_args() else "res://test-results/battle-polish-headless-verification.json"
	var report = FileAccess.open(filename, FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "performance": performance}, "  "))
	print("GODOT BATTLE POLISH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func frames(count: int = 5) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func save_compatibility() -> void:
	var filename = "user://mantua-operation.json"
	if not FileAccess.file_exists(filename): return
	var m = FieldModel.new(false)
	m.new_campaign("mantua")
	check(m.load_campaign(filename), "existing campaign snapshot remains readable")
	check(m.valid_state(m.state), "existing campaign retains its validated state")
	check(not m.save_enabled, "read-only compatibility check cannot write campaign")

func mechanics() -> void:
	var m = FieldBattleExercises.create(12, 2)
	check(FieldValeggio.gardens(m.terrain).size() >= 4, "villages have cultivated gardens")
	check(m.terrain.forests.filter(func(f): return f.get("orchard", false)).size() == 2, "orchards use authored planting rows")
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[1]
	var crossing: float = m.terrain.crossings[m.terrain.crossings.size() / 2]
	var bridge = Vector2(m.terrain.channel_x(crossing), crossing)
	for u in [a, b]:
		u.x = bridge.x - 160
		u.y = bridge.y
		u.target = FieldData.point(bridge + Vector2(200, 0))
		u.goal = u.target.duplicate()
		m.formations.reset(u)
	check(not FieldPassage.bridge_wait(m, a), "first regiment reserves narrow crossing")
	check(FieldPassage.bridge_wait(m, b) and b.movementBlocked == "Waiting for bridge", "following regiment queues before crossing")
	a.x = bridge.x + 220
	a.target = null
	m.formations.reset(a)
	check(not FieldPassage.bridge_wait(m, b), "last file clearing releases crossing to next regiment")
	# A street flanked by two real obstacle rectangles must narrow and then reopen.
	m.terrain.water = false
	m.terrain.buildings = [{"p": Vector2(500, 459), "size": 35.0, "rect": Rect2(470, 440, 65, 35)}, {"p": Vector2(500, 541), "size": 35.0, "rect": Rect2(470, 525, 65, 35)}]
	a.merge({"x": 500.0, "y": 500.0, "facing": 0.0, "target": null}, true)
	m.formations.reset(a)
	var flow: Dictionary = m.formations.motion[a.id]
	for i in 30: m.formations.update_street(a, flow, 0.05)
	check(flow.streetBlend > 0.9 and flow.streetWidth < FieldFormations.bounds(a).size.x, "street passage gradually compresses frontage")
	a.x += 200
	flow.distance += 200
	for i in 30: m.formations.update_street(a, flow, 0.05)
	check(flow.streetBlend < 0.01, "formation reforms after clearing street")
	m.terrain.buildings.clear()
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.forests = []
	m.terrain.field.hills = []
	m.terrain.relief = 0
	for u in m.state.battle.units: u.arrival = 99999
	var enemies = m.state.battle.units.filter(func(u): return u.side == "enemy")
	var east: Dictionary = enemies[0]
	var south: Dictionary = enemies[1]
	for u in [a, east, south]:
		u.merge({"x": 500.0, "y": 500.0, "arrival": 0.0, "facing": 0.0, "reload": 100.0, "holdFire": true, "target": null, "visible": true}, true)
		m.formations.reset(u)
	east.facing = PI
	east.x += FieldContact.shape(a).half.y + FieldContact.shape(east).half.y + FieldContact.REACH
	south.facing = -PI / 2
	south.y += FieldContact.shape(a).half.x + FieldContact.shape(south).half.y + FieldContact.REACH
	m.formations.reset(east)
	m.formations.reset(south)
	m.tactics.update_contacts(m)
	check(a.meleeContacts.size() == 2, "regiment detects simultaneous front and flank contacts")
	m.formations.advance(m.state.battle.units, 0.1, 0.05)
	var fronts: Dictionary = m.formations.motion[a.id]
	var ids: Dictionary = {}
	for slot in fronts.contactSlots.values(): ids[slot.enemyId] = true
	check(ids.size() == 2 and fronts.contactSlots.size() == m.formations.positions(a).size(), "stable soldier slots are allocated across both contact fronts")
	var strength = east.men + south.men
	var ammunition = a.ammo
	a.reload = 0
	m.state.battle.aiClock = -10000
	var start_east: float = east.men
	var start_south: float = south.men
	var shared_power = (m.tactics.melee_power(m, a, east) + m.tactics.melee_power(m, a, south)) * 0.5
	m.tactics.update(m, 0.05)
	check(east.men < start_east and south.men < start_south and east.men + south.men < strength, "melee attack affects both fronts")
	check(a.ammo == ammunition and a.shotKind == "melee", "multi-front infantry use bayonets without ammunition")
	check(absf(strength - east.men - south.men - shared_power) < 0.01, "two-front damage shares one regiment's attack strength")
	# Sleeping render formations must wake for movement and front-rank replacements.
	a.meleeTargetId = null
	a.meleeContacts = []
	a.x = 700
	a.y = 700
	m.formations.reset(a)
	for i in 50: m.formations.advance([a], 1 + i * 0.05, 0.05)
	check(m.formations.motion[a.id].get("sleeping", false), "settled formations avoid redundant per-figure simulation")
	var location = m.formations.positions(a)[0].p
	a.x += 10
	m.formations.advance([a], 4, 0.05)
	check(not m.formations.motion[a.id].sleeping and m.formations.positions(a)[0].p != location, "formation wakes when its center moves")

func profile_simulation() -> void:
	for size_value in [12, 20]: profile_size(size_value)

func profile_size(size_value: int) -> void:
	var m = FieldBattleExercises.create(size_value, 2)
	m.state.paused = false
	m.terrain.profile_enabled = true
	var samples: Array[float] = []
	for tick in 300:
		var before = m.profile_usec.duplicate()
		var routes: int = m.terrain.profile_usec.route
		var start = Time.get_ticks_usec()
		m.tick(1.0 / 30.0)
		var elapsed = (Time.get_ticks_usec() - start) / 1000.0
		samples.append(elapsed)
		if elapsed > 80: print("SLOW TICK %.2fms tactics %.2fms figures %.2fms routes %.2fms AIpeak %.2fms" % [elapsed, (m.profile_usec.tactics - before.tactics) / 1000.0, (m.profile_usec.figures - before.figures) / 1000.0, (m.terrain.profile_usec.route - routes) / 1000.0, m.tactics.ai_max_micros / 1000.0])
	samples.sort()
	print("POLISH SIMULATION %dv%d median %.2fms p95 %.2fms worst %.2fms; tactics avg %.2fms figures avg %.2fms sight avg %.2fms (%d calls) routes avg %.2fms" % [size_value, size_value, samples[150], samples[285], samples.back(), m.profile_usec.tactics / 300000.0, m.profile_usec.figures / 300000.0, m.terrain.profile_usec.sight / 300000.0, m.terrain.profile_calls.sight, m.terrain.profile_usec.route / 300000.0])
	print("TACTICS SECTIONS ", m.tactics.profile_sections, " FORMATION SECTIONS ", m.formations.profile_sections)

func visuals() -> void:
	var m = FieldBattleExercises.create(12, 2)
	root.size = Vector2i(1440, 900)
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	var hud = FieldHud.new()
	root.add_child(hud)
	hud.setup(m, world, true)
	world.center = Vector2(1440, 960)
	world.zoom = 0.85
	world.update_camera()
	await frames(10)
	await capture("command", world)
	world.center = Vector2(1170, 890)
	world.zoom = 3.2
	world.update_camera()
	await capture("close", world)
	world.center = Vector2(1665, 875)
	world.zoom = 2.0
	world.update_camera()
	await capture("village", world)
	world.overview()
	await capture("overview", world)
	world.center = Vector2(1440, 960)
	world.zoom = 0.85
	world.update_camera()
	var samples: Array[float] = []
	var simulation: Array[float] = []
	m.state.paused = false
	for i in 180:
		var start = Time.get_ticks_usec()
		world.remember_transforms()
		m.tick(1.0 / 30.0)
		simulation.append((Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	m.state.paused = true
	samples.sort()
	simulation.sort()
	print("POLISH FRAME median %.2fms p95 %.2fms worst %.2fms; simulation median %.2fms p95 %.2fms worst %.2fms" % [samples[90], samples[171], samples.back(), simulation[90], simulation[171], simulation.back()])
	performance["12v12"] = {"frames": 180, "frameMedianMs": samples[90], "frameP95Ms": samples[171], "worstMs": samples.back(), "simulationMedianMs": simulation[90], "simulationP95Ms": simulation[171]}
	await capture("active", world)
	await effects(world)
	await motion_gallery(world, hud)
	root.size = Vector2i(390, 900)
	await frames()
	world.home()
	hud.build()
	await capture("narrow", world)
	hud.queue_free()
	world.queue_free()
	await process_frame
	await large_battle()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	await process_frame

func motion_gallery(world: FieldWorld, hud: FieldHud) -> void:
	hud.hide()
	world.set_process(false)
	world.entities = []
	world.show_ranges = false
	world.show_fog = false
	world.center = Vector2(1165, 900)
	world.zoom = 4.0
	world.update_camera()
	world.overlay.hide()
	var images: Dictionary = {}
	for pose in [
		{"name": "idle", "phase": 0.0, "moving": 0.0},
		{"name": "stride-a", "phase": TAU * 0.02, "moving": 1.0},
		{"name": "passing", "phase": TAU * 0.27, "moving": 1.0},
		{"name": "stride-b", "phase": TAU * 0.52, "moving": 1.0},
		{"name": "charge-a", "phase": TAU * 0.02, "moving": 1.0, "gait": 2},
		{"name": "charge-b", "phase": TAU * 0.27, "moving": 1.0, "gait": 2},
		{"name": "fire", "phase": 0.0, "moving": 0.0, "age": 0.1},
		{"name": "swab", "phase": 0.0, "moving": 0.0, "age": 1.3},
		{"name": "ram", "phase": 0.0, "moving": 0.0, "age": 3.0},
		{"name": "prime", "phase": 0.0, "moving": 0.0, "age": 4.5},
		{"name": "diagonal-away", "phase": 0.0, "moving": 1.0, "facing": -PI / 4},
		{"name": "diagonal-toward", "phase": 0.0, "moving": 1.0, "facing": PI / 4},
		{"name": "melee", "phase": TAU * 0.3, "moving": 0.0, "action": "melee"}
	]:
		var counts = [0, 0, 0, 0, 0, 0, 0, 0]
		world.sprite_count = 0
		for type in 8:
			world.place(counts, type, Vector2(1100 + (type % 4) * 45, 850 + (type / 4) * 60), 13.5 if type < 2 else 19.0 if type < 4 else 25.0 if type < 6 else 31.0, pose.get("facing", 0.0), pose.phase, pose.moving, pose.get("age", 100.0), pose.get("action", "musket" if type < 4 else "cannon"), 0, 0, 5.0, pose.get("gait", 0) if type in [2, 3] else 0)
		for type in 8: world.batches[type].multimesh.visible_instance_count = counts[type]
		world.shadow_batch.multimesh.visible_instance_count = 8
		await frames(2)
		var pixels = root.get_texture().get_image()
		pixels.save_png("res://test-results/battle-motion-" + pose.name + ".png")
		images[pose.name] = pixels
	for pair in [["stride-a", "passing"], ["stride-a", "stride-b"], ["charge-a", "charge-b"], ["swab", "ram"], ["ram", "prime"], ["diagonal-away", "diagonal-toward"]]:
		check(images[pair[0]].get_data() != images[pair[1]].get_data(), "native painted frames differ: " + str(pair))
	world.overlay.show()
	world.set_process(true)
	hud.show()
	world.show_ranges = true
	world.show_fog = true

func effects(world: FieldWorld) -> void:
	var m: FieldModel = world.model
	var u: Dictionary = m.state.battle.units[0]
	world.center = FieldData.pos(u)
	world.zoom = 3.2
	world.update_camera()
	u.shotTime = m.state.battle.time - 0.07
	u.shotKind = "musket"
	u.shotReload = 5.0
	await capture("volley", world)
	check(world.muzzle_flashes.size() > 4, "volley flashes are distributed across actual front-rank figures")
	var origin: Dictionary = world.smoke_emissions[u.id]
	check(origin.origins.size() > 10, "volley smoke records the individual firing line")
	var points = origin.origins.duplicate()
	u.x += 50
	m.state.battle.time += 1.0
	m.state.battle.artilleryImpacts.append({"x": u.x + 80, "y": u.y, "time": m.state.battle.time - 0.4, "hit": false, "visible": true})
	await capture("smoke-impact", world)
	check(world.smoke_emissions[u.id].origins == points, "smoke stays at the firing line when its regiment moves")
	check(world.smoke_count > 0, "smoke and impact dust render in native scene")
	var sound = FieldAudio.new()
	root.add_child(sound)
	sound.setup(m, world)
	m.state.settings.sound = true
	m.state.settings.volume = 0.3
	sound.play("musket", world.center.x, world.center.y)
	var near_voice = sound.voices.filter(func(v): return v.playing).back()
	var near_level: float = near_voice.volume_db
	var near_filter: float = sound.filters[sound.voices.find(near_voice)].cutoff_hz
	sound.play("musket", world.center.x + 1600, world.center.y + 1200)
	var far_voice = sound.voices.filter(func(v): return v.playing).back()
	check(far_voice.volume_db < near_level - 6 and sound.filters[sound.voices.find(far_voice)].cutoff_hz < near_filter, "distant shots become quieter and less sharp in two dimensions")
	m.state.paused = false
	sound._process(0.05)
	check(sound.ambience_voice.playing, "outdoor ambience starts during play")
	m.state.paused = true
	sound._process(0.05)
	check(not sound.ambience_voice.playing and sound.voices.all(func(v): return not v.playing), "pause stops ambient and combat audio")
	sound.queue_free()
	await process_frame

func large_battle() -> void:
	var m = FieldBattleExercises.create(20, 2)
	root.size = Vector2i(1440, 900)
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	world.show_fog = false
	for u in m.state.battle.units: u.visible = true
	world.overview()
	await capture("grand", world)
	check(m.valid_state(m.state), "20 versus 20 state remains valid after rendering")
	var samples: Array[float] = []
	var simulation: Array[float] = []
	m.state.paused = false
	for i in 180:
		var started = Time.get_ticks_usec()
		world.remember_transforms()
		m.tick(1.0 / 30.0)
		simulation.append((Time.get_ticks_usec() - started) / 1000.0)
		await process_frame
		samples.append((Time.get_ticks_usec() - started) / 1000.0)
	m.state.paused = true
	samples.sort()
	simulation.sort()
	performance["20v20"] = {"frames": 180, "frameMedianMs": samples[90], "frameP95Ms": samples[171], "worstMs": samples.back(), "simulationMedianMs": simulation[90], "simulationP95Ms": simulation[171]}
	print("GRAND FRAME median %.2fms p95 %.2fms worst %.2fms; simulation median %.2fms p95 %.2fms" % [samples[90], samples[171], samples.back(), simulation[90], simulation[171]])
	# Force a faction beyond the previous 1,600-sprite ceiling, all in view.
	var infantry: Array = m.state.battle.units.filter(func(u): return u.side == "player" and u.kind == "infantry")
	for i in 2:
		var u: Dictionary = infantry[0].duplicate(true)
		u.id = "overflow-" + str(i)
		m.state.battle.units.append(u)
		infantry.append(u)
	for i in infantry.size():
		infantry[i].merge({"x": 600.0 + (i % 6) * 170, "y": 400.0 + (i / 6) * 300, "men": 900.0, "startMen": 900.0, "arrival": 0.0, "visible": true}, true)
		m.formations.reset_roster(infantry[i])
	world.overview()
	await capture("capacity", world)
	check(world.batches[0].multimesh.visible_instance_count >= 1800, "renderer retains every figure beyond old faction ceiling")
	check(world.shadow_batch.multimesh.visible_instance_count == world.sprite_count, "every rendered figure retains its contact shadow")
	for i in 150: m.state.battle.bodies.append({"x": 650.0 + (i % 25) * 8, "y": 650.0 + (i / 25) * 8, "side": "player", "kind": "infantry", "mounted": false, "facing": 0.0, "time": 0.0})
	world.invalidate()
	await frames()
	check(world.body_count == 150 and world.body_mesh.mesh.get_surface_count() == 2, "casualty rendering divides large fields into bounded chunks")
	check(world.body_geometry.size() == 150 and world.body_geometry[149].size() == 9, "casualty ground samples are retained once per fallen figure")
	var settled_vertices: PackedVector3Array = world.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	m.state.battle.bodies.append(m.state.battle.bodies.back().duplicate())
	world.invalidate()
	await frames()
	check(world.body_count == 151 and world.body_mesh.mesh.get_surface_count() == 2 and world.body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == settled_vertices, "new casualties preserve settled body geometry")
	world.queue_free()
	await process_frame

func capture(name: String, world: FieldWorld) -> void:
	world.invalidate()
	await frames()
	var pixels = root.get_texture().get_image()
	pixels.save_png("res://test-results/battle-polish-" + name + ".png")
	var colors: Dictionary = {}
	var magenta = 0
	for y in range(100, pixels.get_height() - 180, 5):
		for x in range(5, pixels.get_width(), 5):
			var color = pixels.get_pixel(x, y)
			colors[color.to_html()] = true
			if color.r > 0.7 and color.b > 0.6 and color.g < 0.35: magenta += 1
	check(colors.size() > 200, name + " renders landscape")
	if name != "village": check(world.sprite_count > 0, name + " renders live troops")
	check(magenta < 20, name + " has no chroma leaks")
