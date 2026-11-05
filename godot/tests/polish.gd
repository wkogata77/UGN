extends SceneTree

var checks = 0
var failures: Array[String] = []
var audio_completed = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func fixture() -> FieldModel:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.state.battle.aiClock = -10000
	m.terrain.configure(m.state)
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	m.terrain.buildings.clear()
	m.terrain.relief = 0
	for u in m.state.battle.units: u.arrival = 99999
	var a: Dictionary = m.state.battle.units[0]
	a.merge({"x": 350.0, "y": 400.0, "facing": 0.0, "arrival": 0.0, "holdFire": true, "men": 270.0, "startMen": 270.0}, true)
	m.formations.reset_roster(a)
	m.select([a.id])
	return m

func run() -> void:
	layout_checks()
	route_checks()
	passage_checks()
	cover_checks()
	campaign_checks()
	replacement_checks()
	save_checks()
	await audio_checks()
	check(audio_completed, "audio lifecycle checks complete without script errors")
	print("GODOT POLISH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func layout_checks() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	for scenario in ["bridge", "village", "ridge"]:
		m.state.battle.scenario = scenario
		m.terrain.configure(m.state)
		m.prepare_deployment()
		var buildings = m.terrain.buildings.duplicate(true)
		check(buildings.size() >= 4, scenario + " retains a populated village")
		check(buildings.all(func(b): return not m.terrain.passable(b.p) and m.terrain.ground_passable(b.p, true)), scenario + " houses block units, not the shared ground surface")
		m.terrain.configure(m.state)
		check(buildings == m.terrain.buildings, scenario + " layout is deterministic across reloads")
		for cover in m.terrain.defenses:
			var entry = FieldData.pos(cover) - Vector2.from_angle(cover.facing) * 18
			check(m.terrain.passable(entry, true, 65), scenario + " defensive position has formation clearance: " + cover.id)
		for u in m.state.battle.units:
			if u.arrival > 0: continue
			var destination = Vector2(100 if u.side == "player" else 1340, u.y)
			var accepted = m.path_unit(u, destination)
			check(m.terrain.passable(FieldData.pos(u), true, FieldFormations.bounds(u).size.length() * 0.5), scenario + " initial deployment clears houses: " + u.id)
			check(accepted, scenario + " initial deployment can leave village: " + u.id)

func route_checks() -> void:
	var m = fixture()
	var t = m.terrain
	t.buildings = [{"p": Vector2(500, 400), "rect": Rect2(480, 375, 40, 50), "height": 40.0}]
	var a: Dictionary = m.state.battle.units[0]
	var b = {"x": 650.0, "y": 400.0, "kind": "infantry"}
	check(not t.line_of_sight(a, b, true), "house blocks a volley through its footprint")
	b.y = 250
	check(t.line_of_sight(a, b, true), "open flank beside house remains visible")
	check(not t.direct_route(Vector2(350, 400), Vector2(650, 400), 30), "direct route cannot cross a building")
	var route = t.route(Vector2(350, 400), Vector2(650, 400), 30)
	check(route.size() > 1 and FieldData.pos(route.back()) == Vector2(650, 400), "building detour preserves exact destination")
	var previous = Vector2(350, 400)
	var legal = not route.is_empty()
	for p in route:
		legal = legal and t.direct_route(previous, FieldData.pos(p), 30)
		previous = FieldData.pos(p)
	check(legal, "every smoothed route segment clears the building")
	check(t.route(Vector2(350, 400), Vector2(500, 400), 30).is_empty(), "order into a house is rejected")
	check(not t.route(Vector2(450, 400), Vector2(350, 400), 40).is_empty(), "old deployment can escape a clearance overlap")
	check(not t.direct_route(Vector2(450, 400), Vector2(550, 400), 40), "escaping overlap cannot walk through the house")
	check(not t.route(Vector2(350, 400), Vector2(440, 402), 35).is_empty(), "exact endpoint near an inflated grid cell stays reachable")
	t.field.hills = [{"x": 700, "y": 400, "rx": 150, "ry": 150}]
	t.relief = 1
	t.roads = []
	check(t.movement_factor(Vector2(600, 400), Vector2(612, 400)) < 0.8, "steep slope reduces march speed")
	t.relief = 0
	t.roads = [[{"x": 0, "y": 400}, {"x": 1000, "y": 400}]]
	check(is_equal_approx(t.movement_factor(Vector2(350, 400), Vector2(362, 400)), 1.08), "level road provides a modest speed benefit")

func passage_checks() -> void:
	var m = fixture()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[1]
	b.merge({"x": 500.0, "y": 400.0, "facing": 0.0, "arrival": 0.0, "men": 270.0, "startMen": 270.0}, true)
	m.formations.reset_roster(b)
	check(m.path_unit(a, Vector2(700, 400)), "passage test receives an exact movement order")
	var goal = a.goal.duplicate()
	check(FieldPassage.detour(m, a, b), "stationary friendly formation gets a local detour")
	check(a.goal == goal and a.waypoints.size() >= 2, "detour preserves the final order and inserts waypoints")
	var legal = true
	var max_step = 0.0
	for i in 1600:
		m.state.battle.time += 0.05
		var previous = FieldData.pos(a)
		m.tactics.walk(m, a, 0.05, 24)
		max_step = maxf(max_step, previous.distance_to(FieldData.pos(a)))
		legal = legal and FieldContact.gap(FieldContact.shape(a), FieldContact.shape(b)) >= 2.9
		if a.target == null: break
	check(legal, "friendly detour never advances into occupied frontage")
	check(a.target == null and FieldData.pos(a).distance_to(Vector2(700, 400)) < 0.1, "friendly detour completes rather than waiting forever")
	check(max_step <= 24 * 1.08 * 0.05 + 0.001, "avoidance never accelerates the formation to catch up")
	check(not FieldPassage.clear_approach(Vector2(350, 400), Vector2(650, 400), a, [b]), "final approach cannot cut through a friendly formation")
	check(FieldPassage.clear_approach(Vector2(350, 650), Vector2(650, 650), a, [b]), "clear final approach remains available outside the turning circle")

func cover_checks() -> void:
	var m = fixture()
	var a: Dictionary = m.state.battle.units[0]
	var cover = m.terrain.defenses[0]
	cover.x = 500.0
	cover.y = 400.0
	var b: Dictionary = m.state.battle.units[1]
	b.arrival = 0
	b.x = 250
	b.y = 600
	check(m.occupy_cover(cover.id) == 1 and a.coverOrderId == cover.id and a.coverId == null, "cover order reserves capacity before arrival")
	check(FieldCover.protection(m, a, {"x": 600, "y": 400}, false) == 0, "approaching unit receives no cover bonus")
	check(not FieldCover.order(m, b, cover), "second regiment cannot reserve the same position")
	var guns: Dictionary = m.state.battle.units[4]
	check(not FieldCover.eligible(guns, cover), "guns cannot enter infantry positions")
	var oversized = a.duplicate()
	oversized.men = 1200
	check(not FieldCover.eligible(oversized, cover), "capacity rejects oversized regiments")
	m.leave_cover()
	check(a.coverOrderId == null and FieldCover.occupant(m.state.battle, cover.id).is_empty(), "leave cancels an approaching reservation")
	m.stop_unit(a)
	check(m.occupy_cover(cover.id) == 1, "cancelled position can be reserved again")
	for i in 1000:
		m.state.battle.time += 0.05
		FieldFormations.advance_order(a, 0.05)
		m.tactics.walk(m, a, 0.05, 24)
		if a.target == null: m.tactics.turn(m, a, cover.facing, 0.05)
		FieldCover.update(m, a, 0.05)
		m.formations.advance([a], m.state.battle.time, 0.05)
		if a.coverDeploy >= 4: break
	check(a.coverId == cover.id and a.coverDeploy == 4, "unit reaches wall, faces it, and deploys over time")
	check(m.occupy_cover(cover.id) == 1 and a.coverDeploy == 4 and a.target == null, "repeating occupation does not restart deployment")
	check(FieldFormations.bounds(a).size.x >= cover.width - 1, "garrison spreads along the full defensive frontage")
	check(FieldFormations.bounds(a).size.x <= cover.width, "defensive troop slots fit the available frontage")
	var full = a.duplicate(true)
	full.visualCount = 100
	check(FieldFormations.bounds(full).size.x <= cover.width, "largest permitted garrison leaves room for its outer figures")
	var source = {"x": 650, "y": 400}
	check(is_equal_approx(FieldCover.protection(m, a, source, false), 0.45), "stone wall protects against front fire")
	check(FieldCover.protection(m, a, source, true) < 0.2, "wall provides less protection in melee")
	check(FieldCover.protection(m, a, {"x": 300, "y": 400}, false) == 0, "rear fire bypasses a front wall")
	var soldier = m.formations.positions(a)[0]
	var position = soldier.p
	soldier.p += Vector2(30, 0)
	a.coverDeploy = 0
	FieldCover.update(m, a, 10)
	check(a.coverDeploy < 4 and FieldCover.protection(m, a, source, false) == 0, "deployment cannot complete while a soldier is still approaching its slot")
	soldier.p = position
	FieldCover.update(m, a, 4)
	check(a.coverDeploy == 4, "deployment completes once soldiers fill the defensive slots")
	a.x -= 30
	check(FieldCover.protection(m, a, source, false) == 0, "stale cover state cannot protect a displaced unit")
	a.x += 30
	check(m.move_units(Vector2(350, 400)) and a.coverId == null, "ordinary move relinquishes cover")
	m.occupy_cover(cover.id)
	a.routed = true
	FieldCover.update(m, a, 0.1)
	check(a.coverOrderId == null and a.coverId == null, "routing relinquishes the position")
	a.routed = false
	check(FieldCover.order(m, b, cover), "vacated position accepts another regiment")
	var enemy: Dictionary = m.state.battle.units[5]
	enemy.arrival = 0
	FieldCover.leave(b)
	check(FieldCover.order(m, enemy, cover), "opposing army can capture a vacated position")

func campaign_checks() -> void:
	var m = FieldModel.new(false)
	var e: Dictionary = m.state.enemies[0]
	e.x = 1200
	e.y = 900
	m.state.army.x = 1320
	m.state.army.y = 900
	m.state.immunity = 0
	m.terrain.forests = []
	e.strength = FieldData.men(m.state.units) * 0.85
	e.personality = "aggressive"
	check(FieldCampaign.decision(m.state, m.terrain, e) == FieldData.pos(m.state.army) and e.intent == "Intercepting", "aggressive commander accepts a modest disadvantage")
	e.personality = "cautious"
	check(FieldCampaign.decision(m.state, m.terrain, e) != FieldData.pos(m.state.army) and e.intent == "Guarding approaches", "cautious commander refuses the same fight")
	e.personality = "aggressive"
	var sighting = FieldData.pos(e.lastSighting)
	m.state.army.x += 900
	check(FieldCampaign.decision(m.state, m.terrain, e) == sighting and e.intent == "Investigating last report", "AI investigates stale intelligence rather than tracking hidden player")
	m.state.hours += 3
	check(FieldCampaign.decision(m.state, m.terrain, e) != sighting, "expired sightings stop directing pursuit")
	e.condition = 20
	check(FieldCampaign.decision(m.state, m.terrain, e) == FieldData.pos(e.home), "exhausted enemy withdraws toward reserve")
	check(m.state.enemies.map(func(enemy): return enemy.personality).size() == 3, "old saves receive personality defaults")

func replacement_checks() -> void:
	var m = FieldModel.new(false)
	for direction in ["buy", "sell"]:
		var quote = m.trade_quote("musket", direction, 25)
		var cash: float = m.state.cash
		var reserve: float = m.state.inventory.musket
		var sign_value = 1 if direction == "buy" else -1
		check(quote.available and m.trade("musket", direction, 25), direction + " quote permits a valid trade")
		check(m.state.cash == cash - quote.cost * sign_value and m.state.inventory.musket == reserve + quote.count * sign_value, direction + " quote exactly matches total transaction price")
	m.state.market.rifle = 3
	check(m.trade_quote("rifle", "buy", 100).count == 3, "trade preview exposes available stock rather than requested amount")
	check(not m.trade_quote("musket", "buy", -1).available, "negative trade quote is unavailable")
	var u: Dictionary = m.state.units[0]
	u.men = 700
	u.experience = 2
	for quality in ["recruits", "veterans"]:
		var before = JSON.stringify(m.state)
		var quote = m.replacement_quote(u, quality, 40)
		check(before == JSON.stringify(m.state), quality + " quote does not change the army")
		var cash: float = m.state.cash
		var weapons: float = m.state.inventory[u.weapon]
		check(m.replenish(u.id, quality, 40), quality + " purchase succeeds")
		check(m.state.cash == cash - quote.cost and m.state.inventory[u.weapon] == weapons - quote.weapons and is_equal_approx(u.experience, quote.experience), quality + " quote exactly matches the purchase")

func save_checks() -> void:
	var path = "user://test-polish-recovery.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	var m = FieldModel.new(false)
	check(m.save_campaign(path), "first save writes without a backup")
	var original_cash: float = m.state.cash
	m.state.cash -= 100
	check(m.save_campaign(path) and FileAccess.file_exists(path + ".bak"), "second save retains last validated snapshot")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var restored = FieldModel.new(false)
	check(restored.load_recoverable(path) and restored.state.cash == original_cash, "corrupt primary recovers validated previous save")
	check(restored.state.log[0].text.contains("Recovered"), "recovery is recorded for the player")
	check(restored.save_campaign(path), "recovered state can be saved normally")
	DirAccess.remove_absolute(path)
	check(restored.load_recoverable(path), "missing primary also permits backup recovery")
	var battle = fixture()
	battle.occupy_cover(battle.terrain.defenses[0].id)
	check(battle.save_campaign(path) and restored.load_campaign(path), "cover orders survive validated battle save/load")
	check(restored.state.battle.units[0].coverOrderId != null, "loaded cover reservation remains pending")
	for suffix in ["", ".bak"]:
		file = FileAccess.open(path + suffix, FileAccess.WRITE)
		file.store_string("{broken")
		file.close()
	restored.save_enabled = true
	check(not restored.load_recoverable(path) and not restored.save_enabled and restored.save_failed, "two invalid saves disable automatic overwriting")
	check(FileAccess.get_file_as_string(path) == "{broken", "failed recovery preserves the original file")
	check(restored.save_campaign(path) and restored.save_enabled and not restored.save_suspended, "explicit successful save resumes suspended autosaving")
	restored.save_enabled = false
	restored.save_suspended = true
	check(restored.load_campaign(path) and restored.save_enabled and not restored.save_suspended, "explicit successful load resumes suspended autosaving")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

func audio_checks() -> void:
	var m = FieldModel.new(false)
	m.state.settings.sound = true
	m.state.settings.volume = 0.5
	var buses = AudioServer.bus_count
	var sound = FieldAudio.new()
	root.add_child(sound)
	sound.setup(m)
	check(sound.streams.size() == 21 and sound.voices.size() == 24, "bounded audio pool includes three variants for seven events")
	check(sound.streams.musket0.data != sound.streams.musket1.data, "musket variants contain different waveforms")
	# Real playback is exercised by the graphical suite; the headless dummy
	# driver does not drain playback objects on shutdown.
	sound.queue_free()
	await process_frame
	FieldAudio.prepared.clear()
	await create_timer(0.2).timeout
	check(AudioServer.bus_count == buses, "audio buses are released when changing scenes")
	audio_completed = true
