extends SceneTree

# Drive the same fixed 30 Hz simulation as main.gd. Sampling once per rendered
# frame would make simulation frequency depend on the renderer's speed.
class Driver:
	extends Node
	var model: FieldModel
	var world: FieldWorld
	var expose = false
	var ticks: Array[float] = []
	var slow: Array = []
	func _physics_process(dt: float) -> void:
		if model == null or model.state.paused: return
		var started = Time.get_ticks_usec()
		var sections = model.tactics.profile_sections.duplicate() if model.terrain.profile_enabled else {}
		var figures: int = model.profile_usec.figures
		world.remember_transforms()
		model.tick(dt)
		if expose:
			for u in model.state.battle.units: u.visible = true
		var elapsed = (Time.get_ticks_usec() - started) / 1000.0
		ticks.append(elapsed)
		if elapsed > 25 and not sections.is_empty() and slow.size() < 12:
			var entry = {"totalMs": elapsed, "figuresMs": (model.profile_usec.figures - figures) / 1000.0, "at": model.state.battle.time}
			for key in sections: entry[key + "Ms"] = (model.tactics.profile_sections[key] - sections[key]) / 1000.0
			slow.append(entry)

var results: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for value in values: total += value
	return {"samples": sorted.size(), "medianMs": sorted[sorted.size() / 2], "p95Ms": sorted[mini(sorted.size() - 1, floori(sorted.size() * 0.95))], "worstMs": sorted.back(), "meanMs": total / sorted.size()}

func run() -> void:
	if "--inspect" in OS.get_cmdline_user_args():
		for method in ClassDB.class_get_method_list("RenderingServer"):
			if "profil" in method.name or "time" in method.name: print(method.name)
		quit()
		return
	root.size = Vector2i(1440, 900)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Disable VSync only for profiling so throughput isn't hidden by display waits.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if "--limit-60" in OS.get_cmdline_user_args(): Engine.max_fps = 60
	for size_value in [12, 20]:
		await measure(size_value)
	# Preserve the archived baseline unless explicitly capturing a new one.
	var label = "before" if "--baseline" in OS.get_cmdline_user_args() else "after"
	if "--long" in OS.get_cmdline_user_args(): label += "-long"
	if "--combat" in OS.get_cmdline_user_args(): label += "-combat"
	if "--limit-60" in OS.get_cmdline_user_args(): label += "-60fps"
	var prefix = "performance-grand-legacy-" if "--legacy-maps" in OS.get_cmdline_user_args() else "performance-grand-"
	if "--all-visible" in OS.get_cmdline_user_args(): label += "-exposed"
	var output = FileAccess.open("res://test-results/" + prefix + label + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "  "))
	print("FIXED RATE BENCHMARK saved to test-results/" + prefix + label + ".json")
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	FieldAudio.prepared.clear()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	quit()

func measure(size_value: int) -> void:
	var m = FieldBattleExercises.create(size_value, 2 if "--legacy-maps" in OS.get_cmdline_user_args() else FieldBattlefield.VERSION)
	m.figure_interval = 1.0 / 15.0
	if "--combat" in OS.get_cmdline_user_args(): combat_fixture(m)
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	world.input_blocked = true
	world.detailed_profile = "--detailed" in OS.get_cmdline_user_args()
	world.center = Vector2(1440, 960) if "--combat" in OS.get_cmdline_user_args() else m.terrain.map_size * 0.5 - Vector2(320, 0)
	world.zoom = 0.65
	world.update_camera()
	if size_value == 20:
		world.show_fog = false
		for u in m.state.battle.units: u.visible = true
		if not "--combat" in OS.get_cmdline_user_args(): world.overview()
	var hud = FieldHud.new()
	root.add_child(hud)
	hud.setup(m, world, true)
	var sound = FieldAudio.new()
	root.add_child(sound)
	sound.setup(m, world)
	var driver = Driver.new()
	driver.model = m
	driver.world = world
	driver.expose = "--all-visible" in OS.get_cmdline_user_args()
	root.add_child(driver)
	for i in 12: await process_frame
	m.state.settings.sound = false
	m.state.paused = false
	# Warm-up includes initial AI orders and shader work, kept outside the sample.
	var warmup = Time.get_ticks_msec() + 1800
	while Time.get_ticks_msec() < warmup: await process_frame
	m.terrain.profile_enabled = true
	for key in m.profile_usec: m.profile_usec[key] = 0
	for key in m.tactics.profile_sections: m.tactics.profile_sections[key] = 0
	for key in m.formations.profile_sections: m.formations.profile_sections[key] = 0
	for key in world.profile_sections: world.profile_sections[key] = 0
	driver.ticks.clear()
	var frames: Array[float] = []
	var drawing: Array[float] = []
	var preparing: Array[float] = []
	var gpu: Array[float] = []
	var render_cpu: Array[float] = []
	var started = Time.get_ticks_usec()
	var previous = started
	var deadline = Time.get_ticks_msec() + (12000 if "--long" in OS.get_cmdline_user_args() else 6000)
	var count = 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var now = Time.get_ticks_usec()
		frames.append((now - previous) / 1000.0)
		preparing.append(world.process_micros / 1000.0)
		drawing.append(world.draw_micros / 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		previous = now
		count += 1
	var elapsed = (Time.get_ticks_usec() - started) / 1000000.0
	m.state.paused = true
	var result = {"frames": stats(frames), "simulation": stats(driver.ticks), "worldPreparation": stats(preparing), "overlay": stats(drawing), "fps": count / elapsed, "ticksPerSecond": driver.ticks.size() / elapsed, "troops": world.sprite_count, "drawCalls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "tacticsUsec": m.tactics.profile_sections.duplicate(), "formationUsec": m.formations.profile_sections.duplicate(), "tacticsTotalUsec": m.profile_usec.tactics, "formationTotalUsec": m.profile_usec.figures}
	result["gpu"] = stats(gpu)
	result["renderSubmission"] = stats(render_cpu)
	result["worldSectionsUsec"] = world.profile_sections.duplicate()
	result["sampleSeconds"] = elapsed
	result["speed"] = m.state.speed
	result["slowTicks"] = driver.slow.duplicate(true)
	result["center"] = [world.center.x, world.center.y]
	result["zoom"] = world.zoom
	result["mapSize"] = [m.terrain.map_size.x, m.terrain.map_size.y]
	result["cameraPitch"] = rad_to_deg(world.camera_pitch)
	result["allVisible"] = driver.expose
	result["settledRegiments"] = m.formations.motion.values().filter(func(flow): return flow.get("sleeping", false)).size()
	result["meleeErrors"] = []
	for u in m.state.battle.units:
		if u.get("meleeTargetId") != null: result.meleeErrors.append({"id": u.id, "error": m.formations.motion[u.id].get("goalError", 0), "count": m.formations.positions(u).size()})
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/performance-" + str(size_value) + ("-combat" if "--combat" in OS.get_cmdline_user_args() else "-field") + ".png")
	results[str(size_value)] = result
	print("FIXED %dv%d: %.1f FPS; median %.2fms, p95 %.2fms, worst %.2fms; %.1f simulation ticks/sec; %d sprites" % [size_value, size_value, result.fps, result.frames.medianMs, result.frames.p95Ms, result.frames.worstMs, result.ticksPerSecond, result.troops])
	sound.queue_free()
	driver.queue_free()
	hud.queue_free()
	world.queue_free()
	await process_frame

func combat_fixture(m: FieldModel) -> void:
	# Exercise every real regiment in an isolated open-ground fire/melee drill;
	# normal scenery and river behavior remain covered by the Mincio benchmark.
	m.terrain.water = false
	m.terrain.relief = 0
	m.terrain.buildings.clear()
	m.terrain.defenses.clear()
	m.terrain.grids.clear()
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	m.terrain.forests = []
	m.terrain.roads = []
	m.state.battle.aiClock = -10000
	for side in ["player", "enemy"]:
		var infantry = 0
		var cavalry = 0
		var artillery = 0
		for u in m.state.battle.units:
			if u.side != side: continue
			u.arrival = 0
			u.visible = true
			u.facing = 0.0 if side == "player" else PI
			u.reload = 0
			u.holdFire = false
			if u.kind == "infantry":
				u.x = (500.0 if infantry < 8 else 1900.0) + (0 if side == "player" else 150.0 if infantry < 8 else 35.0)
				u.y = 250.0 + (infantry % 8) * 200
				infantry += 1
			elif u.kind == "cavalry":
				u.x = 800.0 + (0 if side == "player" else 180.0)
				u.y = 550.0 + cavalry * 800
				cavalry += 1
			else:
				u.x = 300.0 + (0 if side == "player" else 550.0)
				u.y = 450.0 + artillery * 800
				artillery += 1
			m.formations.reset_roster(u)
	m.tactics.update_visibility(m)
	m.state.paused = true
