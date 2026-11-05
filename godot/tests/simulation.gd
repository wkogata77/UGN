extends SceneTree

var failures: Array[String] = []
var count = 0

func check(value: bool, label: String) -> void:
	count += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func advance(model: FieldModel, seconds: float) -> void:
	model.state.paused = false
	for i in ceili(seconds * 60):
		model.tick(1.0 / 60.0)
	model.state.paused = true

func duel() -> FieldModel:
	var model = FieldModel.new(false)
	model.start_battle("e1", true)
	var b: Dictionary = model.state.battle
	b.aiClock = -10000.0
	for u in b.units:
		u.arrival = 99999.0
	var u: Dictionary = b.units[0]
	var enemy: Dictionary = b.units.filter(func(p): return p.side == "enemy")[0]
	u.merge({"x": 550.0, "y": 400.0, "facing": 0.0, "arrival": 0.0, "reload": 0.0, "morale": 100.0, "condition": 70.0}, true)
	enemy.merge({"x": 660.0, "y": 400.0, "facing": PI, "arrival": 0.0, "reload": 0.0, "morale": 100.0, "condition": 70.0, "visible": true}, true)
	model.select([u.id])
	return model

func run() -> void:
	infantry_stride_checks()
	var m = FieldModel.new(false)
	check(m.state.mode == "campaign" and m.state.paused and m.state.speed == 0.5, "new campaign paused at half speed")
	check(FieldData.men(m.state.units) == 2460, "starting army strength matches browser")
	check(m.state.officers.size() == 12 and FieldData.weapons().size() == 22, "officer and expanded weapon catalogs loaded")
	var hours: float = m.state.hours
	m.tick(0.1)
	check(m.state.hours == hours, "pause freezes time")
	advance(m, 2)
	check(absf(m.state.hours - hours - 0.08) < 0.0001, "half speed advances campaign time correctly")
	check(not m.trade("musket", "buy", -1), "negative trade rejected")
	var cash: float = m.state.cash
	check(m.trade("musket", "buy", 50), "buy weapons")
	check(m.state.cash == cash - 400 and m.state.inventory.musket == 450, "buy conserves inventory and money")
	check(m.trade("musket", "sell", 50), "sell weapons")
	check(not m.equip("u1", "sabre"), "incompatible weapons rejected")
	m.state.inventory.improved = 800
	check(m.equip("u1", "improved") and m.state.inventory.musket == 1200, "equipping returns old arms")
	var unit: Dictionary = m.state.units[0]
	unit.men = 700.0
	unit.experience = 2.0
	m.state.inventory.improved = 200
	check(m.replenish("u1", "veterans", 50) and unit.experience == 2.0, "veterans preserve experience")
	check(m.replenish("u1", "recruits", 50) and unit.experience < 2.0 and unit.men == 800, "recruits dilute experience")
	check(m.choose_perk("u1", "volley") and not m.choose_perk("u1", "march"), "earned perk selected only once")
	check(m.train("u1", "firearms") and not m.train("u1", "firearms"), "training obeys cooldown")
	check(m.rename_regiment("u1", "Guard of Italy") and unit.name == "Guard of Italy", "regiment rename")
	check(m.set_unit_size("u1", 1000) and not m.set_unit_size("u1", 1500), "regiment size bounds")
	m.state.cash = 20000
	check(m.hire_officer("reserve-0"), "officer recruitment")
	check(m.assign_officer("c1", "reserve-0") and m.state.corps[0].officerId == "reserve-0", "officer assignment")
	check(not m.assign_officer("c2", "reserve-2"), "unhired officer cannot be assigned")
	check(m.assign_corps("u1", "c2"), "corps reassignment")
	check(m.recruit("infantry") and m.state.units.size() == 6, "regiment recruitment")
	m.state.units[0].ammo = 50.0
	check(m.resupply() and m.state.units[0].ammo == 100, "ammunition resupply")
	check(m.scout() and not m.scout(), "scouting charges once and obeys cooldown")
	var route = m.terrain.route(Vector2(280, 727), Vector2(550, 250))
	check(not route.is_empty() and FieldData.pos(route.back()).distance_to(Vector2(550, 250)) < 0.01, "campaign path ends at exact destination")
	var previous = Vector2(280, 727)
	var legal = true
	for p in route:
		for i in 100:
			legal = legal and m.terrain.passable(previous.lerp(FieldData.pos(p), float(i) / 100.0))
		previous = FieldData.pos(p)
	check(legal, "campaign river path stays on legal crossings")
	check(m.start_battle("e1", true), "enter battle")
	check(m.state.battle.scenario == "bridge" and m.state.battle.units.size() == 11, "battle rosters and scenario")
	check(m.state.battle.commanders[1].get("hostId") != null, "corps officer embedded in regiment")
	m.select(["u1"])
	unit = m.state.battle.units[0]
	m.formation("column")
	check(unit.formation == "line" and unit.formationChange != null, "formation changes are not instant")
	m.formation("square")
	check(unit.queuedFormation == "square", "formation changes queue")
	advance(m, 1)
	check(unit.formationChange.elapsed > 0 and unit.formation == "line", "formation advances on simulation clock")
	m.select_supply()
	check(m.move_units(Vector2(300, 550)) and m.state.battle.wagons[0].target != null, "supply moves independently")
	m.halt()
	check(m.state.battle.wagons[0].target == null, "supply halt")
	m.select_commander("general")
	check(m.move_units(Vector2(300, 470)), "general receives independent order")
	m.select(["u4"])
	m.state.battle.units.filter(func(u): return u.id == "u4")[0].weapon = "carbine"
	m.dismount()
	check(m.selected_units()[0].dismounted, "carbine cavalry dismounts")
	m.select(["u5"])
	m.limber()
	check(m.selected_units()[0].limberChange == 5, "limbering takes time")
	check(not m.trade("musket", "buy", 1), "battle prevents headquarters purchases")
	check(m.save_campaign("user://test-campaign.json"), "native save writes")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-campaign.json") and restored.state.paused and restored.state.battle != null, "ongoing battle reloads paused")
	check(restored.state.battle.units[0].formationChange.to == "column", "formation order persists")
	var reward = restored.state.battle.reward
	var money: float = restored.state.cash
	restored.state.battle.units.filter(func(u): return u.side == "enemy")[0].men -= 100
	check(restored.finish_battle(true), "victory resolves")
	check(restored.state.cash == money + reward and restored.state.report.loot > 0, "battle reward and loot")
	check(not restored.finish_battle(true) and restored.state.cash == money + reward, "reward cannot be paid twice")
	check(restored.state.units[0].history.size() == 1, "service record persists")
	var d = duel()
	var b: Dictionary = d.state.battle
	unit = b.units[0]
	var enemy: Dictionary = b.units.filter(func(u): return u.side == "enemy")[0]
	enemy.x = 440.0
	enemy.holdFire = true
	advance(d, 2)
	check(unit.facing == 0 and unit.ammo == 100 and unit.target == null, "no passive turn or fire toward rear enemy")
	enemy.x = 660.0
	var own_before: float = unit.condition
	var enemy_before: float = enemy.condition
	advance(d, 1)
	check(unit.ammo < 100 and unit.fireTargetId == enemy.id, "automatic fire within arc")
	check(unit.condition < own_before and enemy.condition < enemy_before, "combat fatigue for source and recipient")
	var facing: float = unit.facing
	enemy.y += 20
	advance(d, 1)
	check(unit.facing == facing, "engaged unit holds facing")
	d.halt()
	enemy.x = 440
	enemy.y = 400
	check(d.engage_enemy() == 1, "explicit engage acquires rear target")
	advance(d, 25)
	check(unit.aimComplete and d.tactics.inside_arc(unit, enemy), "explicit engage turns only into arc")
	check(absf(angle_difference(unit.facing, PI)) > 0.5, "acquisition does not face target center")
	d = duel()
	unit = d.state.battle.units[0]
	detachment_checks(d, unit)
	var rifle = duel()
	unit = rifle.state.battle.units[0]
	unit.holdFire = true
	advance(rifle, 2)
	check(unit.ammo == 100, "hold fire suppresses ranged volleys")
	var smoke = FieldModel.new(false)
	for id in ["e1", "e2", "e3"]:
		check(smoke.start_battle(id), "start encounter " + id)
		check(smoke.finish_battle(true), "finish encounter " + id)
		smoke.dismiss_report()
	check(smoke.state.victories == 3 and smoke.state.enemies.all(func(e): return e.defeated), "campaign can be completed")
	save_checks()
	combat_checks()
	placement_checks()
	print("GODOT SIMULATION: %d checks, %d failures" % [count, failures.size()])
	for failure in failures:
		print("FAIL: " + failure)
	DirAccess.remove_absolute("user://test-campaign.json")
	quit(0 if failures.is_empty() else 1)

func detachment_checks(model: FieldModel, u: Dictionary) -> void:
	var total: float = u.men
	model.detach_skirmishers()
	var detached: Dictionary = model.selected_units()[0]
	check(detached.has("parentId") and detached.men + u.men == total, "detachment conserves manpower")
	model.detach_skirmishers()
	check(u.men == total and model.state.selected == [u.id], "recalling detachment conserves manpower")

func placement_checks() -> void:
	var model = FieldModel.new(false)
	model.start_battle("e1", true)
	# Frontage geometry is tested on open ground; building routes have their own suite.
	model.terrain.buildings.clear()
	model.terrain.grids.clear()
	model.select(["u1", "u2"])
	var anchor = Vector2(450, 400)
	for angle in [0.0, PI / 2.0, PI, -PI / 3.0]:
		var before = JSON.stringify(model.state)
		var placements = model.move_placements(anchor, angle)
		check(placements.size() == 2 and before == JSON.stringify(model.state), "group preview is read-only at " + str(angle))
		var a: Vector2 = (placements[0].point - anchor).rotated(PI / 2.0 - angle)
		var b: Vector2 = (placements[1].point - anchor).rotated(PI / 2.0 - angle)
		var first = FieldFormations.bounds(placements[0].unit)
		var second = FieldFormations.bounds(placements[1].unit)
		check(absf(a.y) < 0.001 and absf(b.y) < 0.001 and is_equal_approx(b.x + second.position.x - a.x - first.end.x, 12.0), "rotated frontage has separate footprints at " + str(angle))
		check(absf(a.x + first.position.x + b.x + second.end.x) < 0.001, "frontage stays centered on press at " + str(angle))
		check(model.move_units(anchor, null, false, angle), "group facing order accepted")
		check(placements.all(func(p): return FieldData.pos(p.unit.goal).is_equal_approx(p.point) and is_equal_approx(p.unit.desiredFacing, angle)), "released destinations match every preview")
	var queued = model.move_placements(Vector2(550, 450), 0.8)
	model.move_units(Vector2(550, 450), null, true, 0.8)
	check(queued.all(func(p): return FieldData.pos(p.unit.orderQueue.back().point).is_equal_approx(p.point) and is_equal_approx(p.unit.orderQueue.back().facing, p.facing)), "queued group destinations match preview")
	model.select(["u1", "u4", "u5"])
	var mixed = model.move_placements(anchor, PI / 2.0)
	check(mixed.size() == 3 and FieldFormations.bounds(mixed[0].unit).size != FieldFormations.bounds(mixed[2].unit).size, "mixed troops use their actual formation sizes")
	var edge = model.move_placements(Vector2(45, 45), 0.0)
	model.move_units(Vector2(45, 45), null, false, 0.0)
	check(edge.all(func(p): return FieldData.pos(p.unit.goal).is_equal_approx(p.point)), "edge clamping matches preview")
	var a = Vector2(420, 320)
	var b = Vector2(520, 550)
	var front = model.frontline_placements(a, b)
	model.frontline(a, b)
	check(front.all(func(p): return FieldData.pos(p.unit.goal).is_equal_approx(p.point) and is_equal_approx(p.unit.desiredFacing, p.facing)), "frontline destinations match preview")
	model.select(["u1"])
	check(model.move_placements(anchor, 0.3)[0].point == anchor, "single unit remains exactly at press")
	model.select(["u1", "u2", "u3"])
	model.state.battle.units[1].routed = true
	model.state.battle.units[2].arrival = 9999
	check(model.move_placements(anchor, 0.0).size() == 1, "preview excludes routed and absent units")
	model.select([])
	check(model.move_placements(anchor, 0.0).is_empty(), "empty selection has no preview")
	for support in ["general", "supply"]:
		if support == "general": model.select_commander("general")
		else: model.select_supply()
		var preview = model.move_placements(anchor, 0.4)
		check(preview.size() == 1 and preview[0].point == anchor and model.move_units(anchor, null, false, 0.4), support + " retains single-unit facing order")

func save_checks() -> void:
	var model = FieldModel.new(false)
	for speed in [0.5, 1.0, 2.0, 4.0]:
		model.speed(speed)
		check(model.save_campaign("user://test-campaign.json"), "save replacement at speed " + str(speed))
		var restored = FieldModel.new(false)
		check(restored.load_campaign("user://test-campaign.json") and restored.state.speed == speed, "reload speed " + str(speed))
	for name in ["campaign", "battle", "report"]:
		var ok = model.load_campaign("res://tests/fixtures/browser-" + name + ".json", true)
		check(ok, "import actual browser " + name)
		if ok:
			check(model.state.paused and model.state.theater == "danube", "browser " + name + " retains theater and pauses")
			if name == "battle":
				advance(model, 2)
				check(model.state.battle.time > 3, "imported browser battle continues simulation")
	var mutations = [
		func(s): s.army = {},
		func(s): s.officers[0] = "invalid",
		func(s): s.corps[0] = {},
		func(s): s.units[0].skills.firearms = "invalid",
		func(s): s.units[0].men = -5,
		func(s): s.units[1].id = s.units[0].id,
		func(s): s.army.path = ["invalid"],
		func(s): s.inventory.musket = "invalid",
		func(s): s.settings.sound = 1,
		func(s): s.settings.volume = 12,
		func(s): s.version = 99,
		func(s): s.report = {},
		func(s): s.units[0].orderQueue = "invalid",
		func(s): s.units[0].formationChange = {"from": "line", "to": "square", "duration": 0, "elapsed": 0}
	]
	for i in mutations.size():
		var invalid = FieldData.fresh()
		mutations[i].call(invalid)
		check(not model.valid_state(invalid), "reject malformed save field " + str(i))
	var before = JSON.stringify(model.state)
	var file = FileAccess.open("user://test-invalid.json", FileAccess.WRITE)
	file.store_string('{"format":"field-command-godot","version":1,"state":{}}')
	file.close()
	check(not model.load_campaign("user://test-invalid.json") and before == JSON.stringify(model.state), "invalid import preserves current campaign")
	DirAccess.remove_absolute("user://test-invalid.json")

func combat_checks() -> void:
	var model = duel()
	var unit: Dictionary = model.state.battle.units[0]
	var enemy: Dictionary = model.state.battle.units[5]
	var blocker: Dictionary = model.state.battle.units[1]
	blocker.merge({"arrival": 0.0, "x": 605.0, "y": 400.0}, true)
	check(not model.tactics.clear_shot(model, unit, enemy), "friendly regiment blocks center firing lane")
	blocker.y = 600
	check(model.tactics.clear_shot(model, unit, enemy), "clear firing lane permits volley")
	unit.kind = "artillery"
	unit.weapon = "cannon"
	unit.men = 120
	unit.maxMen = 120
	model.tactics.artillery_volley(model, unit, enemy, 20)
	var first = model.state.battle.artilleryImpacts.duplicate(true)
	check(first.size() == 4, "one impact per firing gun")
	check(first.any(func(p): return FieldData.pos(p).distance_to(FieldData.pos(enemy)) > 1), "cannon impacts scatter away from target center")
	model.tactics.artillery_volley(model, unit, enemy, 20)
	check(FieldData.pos(first[0]) != FieldData.pos(model.state.battle.artilleryImpacts[4]), "successive volleys have different scatter")
	unit.artilleryShots = 0
	model.state.battle.artilleryImpacts = []
	model.tactics.artillery_volley(model, unit, enemy, 20)
	check(first == model.state.battle.artilleryImpacts, "artillery scatter is deterministic from shot counter")
	model = duel()
	unit = model.state.battle.units[0]
	enemy = model.state.battle.units[5]
	unit.holdFire = true
	enemy.holdFire = true
	enemy.x = 570
	var strength: float = unit.men + enemy.men
	advance(model, 3)
	check(unit.men + enemy.men < strength and unit.get("shotKind") == "melee", "melee inflicts casualties and emits animation event")
	unit.fightingUntil = 0
	unit.meleeUntil = 0
	unit.restAfter = 12
	var before: float = unit.condition
	model.tactics.condition(unit, {"p": FieldData.pos(unit), "facing": unit.facing, "working": false}, 11, 1)
	check(unit.condition == before, "condition does not recover before rest delay")
	model.tactics.condition(unit, {"p": FieldData.pos(unit), "facing": unit.facing, "working": false}, 13, 1)
	check(unit.condition > before, "stationary noncombat unit recovers after delay")
	model = duel()
	unit = model.state.battle.units[0]
	unit.morale = 50
	model.state.battle.commanders[0].x = unit.x
	model.state.battle.commanders[0].y = unit.y
	check(model.rally() and unit.morale == 68 and not model.rally(), "general rally restores morale and consumes cooldown")
	var wagon: Dictionary = model.state.battle.wagons[0]
	wagon.x = unit.x - 40
	wagon.y = unit.y
	unit.ammo = 30
	var stock: float = wagon.stock
	model.tactics.update_wagons(model, 1)
	check(unit.ammo > 30 and wagon.stock < stock, "supply train consumes stock to replenish nearby ammunition")
	model = FieldModel.new(false)
	model.state.enemies[1].x = model.state.enemies[0].x + 80
	model.state.enemies[1].y = model.state.enemies[0].y
	model.start_battle("e1")
	check(model.state.battle.enemyIds.size() == 2 and model.state.battle.units.any(func(u): return u.arrival > 0), "nearby army joins as delayed reinforcements")
	for u in model.state.battle.units:
		if u.side == "enemy" and u.arrival == 0: u.men = 0
	advance(model, 1)
	check(model.state.battle != null and model.state.report == null, "pending reinforcements prevent premature victory")
	for scenario in ["bridge", "village", "ridge"]:
		model = FieldModel.new(false)
		model.start_battle("e1")
		model.state.battle.scenario = scenario
		model.terrain.configure(model.state)
		advance(model, 50)
		check(model.valid_state(model.state), "sustained " + scenario + " battle retains valid state")
	var a = duel()
	var b = duel()
	for game in [a, b]:
		for u in game.state.battle.units: u.holdFire = true
		game.move_units(Vector2(600, 430))
		game.state.paused = false
	for i in 300: a.tick(1.0 / 30.0)
	for i in 600: b.tick(1.0 / 60.0)
	check(absf(a.state.battle.time - b.state.battle.time) < 0.00001, "30Hz and 60Hz clocks advance equal simulation time")
	check(FieldData.distance(a.state.battle.units[0], b.state.battle.units[0]) < 1.0, "fixed-rate movement remains consistent across 30Hz and 60Hz")
	var terrain = FieldTerrain.new()
	terrain.configure(FieldData.fresh())
	var point = Vector2(230, 195)
	var hill = terrain.height_at(point)
	terrain.relief = 0
	check(terrain.height_at(point) == 0, "relief toggle invalidates cached ground heights")
	terrain.relief = 1
	check(is_equal_approx(terrain.height_at(point), hill), "restoring relief rebuilds matching cached surface")

func infantry_stride_checks() -> void:
	check(FieldFormations.infantry_frame(PI / 2, 0) == 0, "stationary infantry uses idle art")
	check(FieldFormations.infantry_frame(PI / 2, 1) == 1 and FieldFormations.infantry_frame(PI * 1.5, 1) == 2, "opposite stride phases select different painted frames")
	var phase = 0.4
	check(is_equal_approx(FieldFormations.infantry_phase(phase, 0), phase), "no displacement freezes infantry phase")
	check(is_equal_approx(FieldFormations.infantry_phase(phase, 27), phase), "slower infantry cycle spans 27 map units without changing travel speed")
	check(FieldFormations.infantry_frame(FieldFormations.infantry_phase(phase, 13.5), 1) == 2, "half stride swaps the planted foot")
	var a = phase
	var b = phase
	for i in 30: a = FieldFormations.infantry_phase(a, 24.0 / 30.0)
	for i in 60: b = FieldFormations.infantry_phase(b, 24.0 / 60.0)
	check(absf(angle_difference(a, b)) < 0.00001, "infantry cadence is independent of update frequency")
	check(is_equal_approx(FieldFormations.infantry_phase(phase, 24.0 * 0.5 * 2.25), phase), "half-speed marching completes a slower 2.25-second cycle at normal pace")
	for pair in [["cavalry", 39.0], ["artillery", 24.0], ["wagon", 36.0]]:
		check(is_equal_approx(FieldFormations.stride_phase(phase, pair[1], pair[0]), phase), pair[0] + " shares the one-third slower walking cadence")
	var frames: Dictionary = {}
	for i in 8: frames[FieldFormations.infantry_frame(i * 1.71, 1)] = true
	check(frames.size() == 2, "individual soldier phase offsets stagger painted steps")
