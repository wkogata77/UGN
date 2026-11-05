extends SceneTree

var checks = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func fixture(kind: String = "infantry") -> FieldModel:
	var m = FieldModel.new(false)
	# This suite also replays the existing save and its version-2 crossings.
	# The five new version-3 crossings are exercised in grand_landscape.gd.
	m.start_battle("e1", true, 2)
	for other in m.state.battle.units: other.arrival = 99999
	m.state.battle.aiClock = -10000
	m.terrain.buildings.clear()
	var u: Dictionary = m.state.battle.units[0]
	u.merge({"kind": kind, "men": 1200.0 if kind == "infantry" else 400.0 if kind == "cavalry" else 180.0, "startMen": 1200.0 if kind == "infantry" else 400.0 if kind == "cavalry" else 180.0, "arrival": 0.0, "formation": "line", "formationChange": null, "target": null, "holdFire": true, "routed": false, "dismounted": false, "turnVelocity": 0.0}, true)
	u.weapon = "cannon" if kind == "artillery" else "sabre" if kind == "cavalry" else "musket"
	m.formations.reset_roster(u)
	return m

func run() -> void:
	if "--rout-only" in OS.get_cmdline_user_args():
		rout_checks()
		print("GODOT BRIDGE ROUT: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if "--visual" in OS.get_cmdline_user_args():
		await visual_checks()
		print("GODOT BRIDGE VISUAL: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	for kind in ["infantry", "cavalry", "artillery"]:
		for crossing in [300.0, 960.0, 1630.0]:
			for direction in [1.0, -1.0]: crossing_check(kind, crossing, direction)
	stationary_check()
	rout_checks()
	saved_check()
	print("GODOT BRIDGE MOVEMENT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func crossing_check(kind: String, y: float, direction: float) -> void:
	var m = fixture(kind)
	var u: Dictionary = m.state.battle.units[0]
	var bridge = Vector2(m.terrain.channel_x(y), y)
	var label = "%s crossing %.0f direction %.0f" % [kind, y, direction]
	u.x = bridge.x - direction * 210
	u.y = y + 12
	u.facing = 0.0 if direction > 0 else PI
	m.formations.reset(u)
	var destination = bridge + Vector2(direction * 230, -9)
	check(m.path_unit(u, destination), label + " accepts the crossing order")
	var dry = true
	var capped = true
	var interpolation_safe = true
	var radius = FieldFormations.figure_radius(u)
	for tick in 1800:
		m.state.battle.time += 0.05
		m.tactics.walk(m, u, 0.05, 24.0)
		m.formations.advance([u], m.state.battle.time, 0.05, [], m.terrain)
		for soldier in m.formations.positions(u):
			if not soldier.alive: continue
			dry = dry and m.terrain.figure_ground_clear(soldier.p, radius)
			interpolation_safe = interpolation_safe and m.terrain.figure_ground_clear(soldier.previous.lerp(soldier.p, 0.5), radius)
			capped = capped and soldier.previous.distance_to(soldier.p) <= float(u.get("marchPace", 24)) * 0.05 + 0.001
	var points = m.formations.positions(u)
	var far_bank = points.all(func(soldier): return not soldier.alive or (soldier.p.x - bridge.x) * direction > 80)
	var settled = points.all(func(soldier): return not soldier.alive or soldier.p.distance_to(FieldFormations.world_point(u, FieldFormations.offsets(u)[soldier.slot])) < 1)
	if not far_bank or not settled:
		print(label, " center=", FieldData.pos(u), " target=", u.target, " blend=", m.formations.motion[u.id].get("bridgeBlend"), " left=", points.filter(func(soldier): return soldier.alive and (soldier.p.x - bridge.x) * direction <= 80).size())
	check(dry, label + " every figure stays on land or the deck")
	check(interpolation_safe, label + " displayed movement never crosses water")
	check(capped, label + " no figure teleports or exceeds marching speed")
	check(u.target == null and FieldData.pos(u).distance_to(destination) < 0.1, label + " regiment reaches the exact ordered point")
	check(far_bank, label + " every surviving figure finishes crossing")
	check(settled and u.formation == "line", label + " original formation reforms on the far bank")

func stationary_check() -> void:
	var m = fixture()
	var u: Dictionary = m.state.battle.units[0]
	var bridge = Vector2(m.terrain.channel_x(960), 960)
	u.x = bridge.x + 12
	u.y = 978
	u.facing = 0.0
	var raw = FieldFormations.offsets(u)
	check(raw.any(func(slot): return not m.terrain.figure_ground_clear(FieldFormations.world_point(u, slot))), "fixture reproduces a line extending beyond the deck")
	m.formations.reset(u)
	check(m.formations.positions(u).all(func(soldier): return m.terrain.figure_ground_clear(soldier.p)), "stopped bridge regiment is safe immediately after load")
	var dry = true
	for tick in 300:
		u.facing += 0.01
		m.formations.advance([u], tick * 0.05, 0.05, [], m.terrain)
		for soldier in m.formations.positions(u): dry = dry and m.terrain.figure_ground_clear(soldier.p)
	check(dry, "turning on the bridge never swings soldiers into the river")
	check(not m.terrain.ground_passable(bridge + Vector2(0, 32)), "ground orders cannot target the water beyond the parapet")
	for forest in m.terrain.forests:
		var p = FieldData.pos(forest)
		if absf(p.x - m.terrain.channel_x(p.y)) > 60: check(m.terrain.figure_ground_clear(p), "forest ground remains traversable")
	for cover in m.terrain.defenses: check(m.terrain.figure_ground_clear(FieldCover.entry(cover)), cover.id + " entry remains traversable")

func saved_check() -> void:
	var source = "user://mantua-operation.json"
	if not FileAccess.file_exists(source): return
	var original = FileAccess.get_file_as_bytes(source)
	var file = FileAccess.open("res://test-results/bridge-save-replay.json", FileAccess.WRITE)
	file.store_buffer(original)
	file.close()
	var m = FieldModel.new(false)
	check(m.load_campaign("res://test-results/bridge-save-replay.json"), "copy of the player's campaign loads")
	if m.state.battle == null or m.state.battle.scenario != "bridge": return
	var dry = true
	var alive = 0
	for u in m.state.battle.units:
		if u.arrival > m.state.battle.time: continue
		for soldier in m.formations.positions(u):
			if not soldier.alive: continue
			alive += 1
			dry = dry and m.terrain.figure_ground_clear(soldier.p, FieldFormations.figure_radius(u))
	check(dry and alive > 0, "all live figures in the actual saved battle start on safe ground")
	for tick in 60:
		m.formations.advance(m.state.battle.units, m.state.battle.time + tick * 0.05, 0.05, [], m.terrain)
		for u in m.state.battle.units:
			if u.arrival > m.state.battle.time: continue
			for soldier in m.formations.positions(u): dry = dry and (not soldier.alive or m.terrain.figure_ground_clear(soldier.p, FieldFormations.figure_radius(u)))
	check(dry, "saved battle figures remain safe while settling")
	check(FileAccess.get_file_as_bytes(source) == original, "saved-battle replay preserves the original file")

func rout_checks() -> void:
	for direction in [-1.0, 1.0]:
		var m = fixture()
		var u: Dictionary = m.state.battle.units[0]
		var y = 1090.0
		var river = m.terrain.channel_x(y)
		u.x = river - direction * 180
		u.y = y
		u.facing = 0.0 if direction > 0 else PI
		u.side = "player" if direction < 0 else "enemy"
		u.routed = true
		m.formations.reset(u)
		var dry = true
		var checked_saved_path = false
		for tick in 1800:
			m.state.battle.time += 0.05
			m.tactics.rout_walk(m, u, 0.05)
			if not checked_saved_path and not u.get("routPath", []).is_empty():
				checked_saved_path = true
				check(m.valid_orders(u), "routing waypoints validate for campaign saves")
				var saved: Dictionary = JSON.parse_string(JSON.stringify(u))
				check(m.valid_orders(saved) and saved.routPath.size() == u.routPath.size(), "routing waypoints survive JSON save/load")
				saved.routPath = "invalid"
				check(not m.valid_orders(saved), "invalid routing path cannot load")
				saved.routPath = []
				saved.routRetryAt = INF
				check(not m.valid_orders(saved), "nonfinite routing retry time cannot load")
			m.formations.advance([u], m.state.battle.time, 0.05, [], m.terrain)
			var center_dry = m.terrain.figure_ground_clear(FieldData.pos(u), 0)
			if dry and not center_dry: print("ROUT CENTER ", direction, " ", FieldData.pos(u), " path ", u.get("routPath"))
			dry = dry and center_dry
			for soldier in m.formations.positions(u): dry = dry and (not soldier.alive or m.terrain.figure_ground_clear(soldier.p))
		check(dry, "routing force uses a bridge instead of fleeing through water: " + str(direction))
		check((u.x - m.terrain.channel_x(u.y)) * direction > 100, "routing force and its figures escape across the river: " + str(direction))
		check(checked_saved_path, "routing force planned a real saved bridge route")

func visual_frames() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw

func visual_capture(name: String, world: FieldWorld, m: FieldModel) -> void:
	world.invalidate()
	await visual_frames()
	var pixels = root.get_texture().get_image()
	pixels.save_png("res://test-results/bridge-safe-" + name + ".png")
	var colors: Dictionary = {}
	for y in range(150, pixels.get_height() - 160, 8):
		for x in range(5, pixels.get_width(), 8): colors[pixels.get_pixel(x, y).to_html()] = true
	check(colors.size() > 150 and world.sprite_count > 0, name + " renders terrain and live figures")
	for u in m.state.battle.units:
		if u.arrival > m.state.battle.time: continue
		check(m.formations.positions(u).all(func(soldier): return not soldier.alive or m.terrain.figure_ground_clear(soldier.p, FieldFormations.figure_radius(u))), name + " rendered figure anchors stay off water: " + u.id)

func visual_checks() -> void:
	root.size = Vector2i(1440, 900)
	var m = FieldModel.new(false)
	check(m.load_campaign("res://test-results/bridge-save-replay.json"), "native replay loads the isolated saved-battle copy")
	if m.state.battle == null or m.state.battle.scenario != "bridge": return
	m.state.paused = true
	m.select(["u3"])
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	world.show_fog = false
	world.center = Vector2(m.terrain.channel_x(960), 960)
	world.zoom = 3.0
	world.update_camera()
	var hud = FieldHud.new()
	root.add_child(hud)
	hud.setup(m, world, true)
	await visual_capture("saved-battle", world, m)
	var unit = m.find_id(m.state.battle.units, "u3")
	check(not unit.is_empty(), "saved regiment on the bridge is present")
	if not unit.is_empty():
		var points = m.formations.positions(unit)
		var middle = points.filter(func(soldier): return soldier.alive and m.terrain.on_bridge(soldier.p))
		check(not middle.is_empty() and middle.all(func(soldier): return absf(soldier.p.y - 960) <= FieldTerrain.BRIDGE_HALF_WIDTH - 3), "saved bridge regiment fits between the parapets")
	for tick in 90:
		m.state.battle.time += 0.05
		m.formations.advance(m.state.battle.units, m.state.battle.time, 0.05, [], m.terrain)
	m.publish(false)
	await visual_capture("settled", world, m)
	root.size = Vector2i(390, 900)
	await visual_frames()
	world.zoom = 2.0
	world.update_camera()
	hud.build()
	await visual_capture("narrow", world, m)
	hud.queue_free()
	world.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	await process_frame
