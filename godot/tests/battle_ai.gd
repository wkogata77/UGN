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

func fixture() -> FieldModel:
	var m = FieldModel.new(false)
	# Controlled AI drills retain their known standard-map stations. The real
	# expanded layouts are covered by scenario_checks and grand_landscape.gd.
	m.start_battle("e1", true, 2)
	var b: Dictionary = m.state.battle
	b.scenario = "village"
	b.aiClock = -10000
	b["aiPersonality"] = "cautious"
	m.terrain.configure(m.state)
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	m.terrain.buildings.clear()
	m.terrain.defenses.clear()
	m.terrain.relief = 0
	for u in b.units:
		u.arrival = 0 if u.side == "enemy" or u.id == b.units[0].id else 99999
		u.holdFire = true
		u.x = 950.0 if u.side == "enemy" else 100.0
		u.y = 240.0 + int(str(u.id).right(1)) * 120 if u.side == "enemy" else 430.0
		u.men = 600.0 if u.kind == "infantry" else 240.0 if u.kind == "cavalry" else 90.0
		u.maxMen = u.men
		u.startMen = u.men
		m.formations.reset_roster(u)
	FieldBattleAI.initialize(m)
	return m

func enemies(m: FieldModel) -> Array:
	return m.state.battle.units.filter(func(u): return u.side == "enemy")

func run() -> void:
	plan_checks()
	reserve_checks()
	intelligence_checks()
	charge_checks()
	battery_checks()
	retreat_checks()
	cover_checks()
	save_checks()
	scenario_checks()
	print("GODOT BATTLE AI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func plan_checks() -> void:
	var m = fixture()
	var b: Dictionary = m.state.battle
	var units = enemies(m)
	m.tactics.plan_enemy(m)
	check(b.ai.stance == "defend", "cautious commander starts by defending the objective")
	check(units[0].ai.state == "line" and units[1].ai.state == "line", "infantry receive shared line assignments")
	check(units[0].ai.station.x == units[1].ai.station.x and absf(units[0].ai.station.y - units[1].ai.station.y) > FieldFormations.bounds(units[0]).size.x, "infantry stations have connected but nonoverlapping frontage")
	check(units[2].ai.state == "reserve" and units[2].ai.station.x > units[0].ai.station.x, "fresh reserve stays behind the infantry line")
	check(units[3].ai.state == "screen", "uncommitted cavalry screen without an observed target")
	check(units[4].ai.state == "battery" and units[4].ai.station.x > units[0].ai.station.x, "battery supports the line from behind")
	var paths = units.map(func(u): return [u.target, u.waypoints, u.ai.orders]).duplicate(true)
	b.time = 2
	m.tactics.plan_enemy(m)
	check(paths == units.map(func(u): return [u.target, u.waypoints, u.ai.orders]), "short planning ticks preserve committed routes and orders")
	b.time = 65
	m.tactics.plan_enemy(m)
	check(units[2].ai.state == "reserve" and not units[2].ai.committed, "reserves do not advance merely because forty seconds elapsed")
	b.objective.owner = "player"
	b.time = 80
	m.tactics.plan_enemy(m)
	check(b.ai.stance == "advance", "even cautious commanders contest an enemy-held objective")
	for personality in ["aggressive", "opportunist", "cautious"]:
		var drill = fixture()
		drill.state.battle.ai.personality = personality
		var p: Dictionary = drill.state.battle.units[0]
		p.x = 700
		p.y = 430
		p.men = 180
		drill.tactics.plan_enemy(drill)
		check(drill.state.battle.ai.stance == ("advance" if personality == "aggressive" else "flank" if personality == "opportunist" else "defend"), personality + " changes army planning, not weapon damage")

func reserve_checks() -> void:
	var m = fixture()
	m.tactics.plan_enemy(m)
	var units = enemies(m)
	var p: Dictionary = m.state.battle.units[0]
	p.x = units[0].ai.station.x - 110
	p.y = units[0].ai.station.y
	units[0].routed = true
	m.state.battle.time = 10
	m.tactics.plan_enemy(m)
	check(units[2].ai.committed and units[2].ai.state in ["reinforce", "fire"], "reserve responds to a broken sector under observed pressure")
	check(units[2].ai.station == units[0].ai.station, "reserve fills the actual gap, not the nearest enemy center")
	var assigned = units[2].ai.station.duplicate()
	m.state.battle.time = 30
	m.tactics.plan_enemy(m)
	check(units[2].ai.station == assigned, "committed reserve retains its sector when the army reassesses")

func intelligence_checks() -> void:
	var m = fixture()
	var b: Dictionary = m.state.battle
	var p: Dictionary = b.units[0]
	p.x = 750
	p.y = 420
	m.tactics.plan_enemy(m)
	check(b.ai.contacts.size() == 1 and b.ai.contacts[0].x == 750, "visible contacts create a dated observation")
	p.x = 50
	p.y = 50
	b.time = 2
	m.tactics.plan_enemy(m)
	check(b.ai.contacts.size() == 1 and b.ai.contacts[0].x == 750 and b.ai.contacts[0].y == 420, "lost contacts retain old coordinates rather than tracking hidden movement")
	b.time = 20
	m.tactics.plan_enemy(m)
	check(b.ai.contacts.is_empty(), "old battlefield intelligence expires")
	check(enemies(m).all(func(u): return u.attackId == null), "expired unseen enemies are not assigned as attack targets")
	p.x = 700
	p.y = 400
	m.terrain.buildings = [{"p": Vector2(820, 480), "rect": Rect2(810, 0, 20, 960), "height": 100.0}]
	b.time = 40
	m.tactics.plan_enemy(m)
	check(b.ai.contacts.is_empty(), "solid terrain blocks AI observation as well as player vision")

func charge_checks() -> void:
	var m = fixture()
	var units = enemies(m)
	var cav: Dictionary = units[3]
	var p: Dictionary = m.state.battle.units[0]
	cav.x = 900
	cav.y = 430
	p.x = 770
	p.y = 430
	p.morale = 35
	check(FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "cavalry recognizes an isolated wavering target with run-up space")
	p.formation = "square"
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "cavalry reject squares")
	p.formation = "line"
	FieldFormations.order(p, "square")
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "cavalry recognize a square forming before it is complete")
	p.formationChange = null
	cav.condition = 30
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "fatigued cavalry conserve their remaining condition")
	cav.condition = 100
	p.x = 865
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "cavalry do not claim a full charge from point-blank range")
	p.x = 770
	p.morale = 100
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "unsupported cavalry avoid fresh infantry head-on")
	p.morale = 35
	units[0].x = 835
	units[0].y = 430
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav, units[0]]), "charge lanes cannot pass through friendly formations")
	units[0].y = 650
	m.terrain.field.forests = [{"x": 770.0, "y": 430.0, "rx": 90.0, "ry": 90.0}]
	check(not FieldBattleAI.charge_safe(m, cav, p, [p], [cav]), "cavalry avoid charging into woodland")
	m.terrain.field.forests = []
	m.tactics.plan_enemy(m)
	check(cav.charging and cav.ai.state == "charge", "planner issues a real charge through the existing stamina and impact system")
	var ready_at = cav.chargeReadyAt
	m.state.battle.time = 2
	m.tactics.plan_enemy(m)
	check(cav.charging and cav.chargeReadyAt == ready_at, "planning preserves charge momentum and cooldown instead of restarting it")
	p.formation = "square"
	m.state.battle.time = 4
	m.tactics.plan_enemy(m)
	check(not cav.charging, "newly observed square cancels an unsafe charge immediately")
	var square_drill = fixture()
	var foot: Dictionary = enemies(square_drill)[0]
	var horse: Dictionary = square_drill.state.battle.units[0]
	horse.kind = "cavalry"
	horse.weapon = "sabre"
	horse.charging = true
	horse.x = foot.x - 170
	horse.y = foot.y
	foot.ai.state = "line"
	foot.ai.until = 100
	square_drill.tactics.plan_enemy(square_drill)
	check(foot.ai.state == "square" and foot.formationChange != null and foot.formationChange.to == "square", "immediate cavalry danger interrupts routine commitments with a timed square order")

func battery_checks() -> void:
	var m = fixture()
	var units = enemies(m)
	var gun: Dictionary = units[4]
	var p: Dictionary = m.state.battle.units[0]
	p.x = 650
	p.y = 400
	gun.x = 950
	gun.y = 400
	units[0].x = 810
	units[0].y = 400
	FieldBattleAI.choose_plan(m, units, [p])
	gun.ai.station = {"x": 920.0, "y": 510.0}
	check(not m.tactics.clear_shot(m, gun, p), "battery drill starts with a friendly formation obstructing its guns")
	var point = FieldBattleAI.battery_position(m, gun, p, units)
	check(point != null, "battery finds an alternate supporting position")
	if point != null:
		var trial = gun.duplicate()
		trial.x = point.x
		trial.y = point.y
		check(m.tactics.clear_shot(m, trial, p), "selected battery position has a clear firing lane")
		check(FieldData.distance(trial, p) >= 145 and FieldData.distance(trial, p) <= FieldData.weapons()[gun.weapon].range, "battery stays within range without crowding the enemy")
		FieldBattleAI.issue(m, gun, "battery", "Test battery relocation", point, p)
		check(not gun.charging and (gun.limberChange > 0 or gun.target != null), "artillery relocates normally and never charges")
	p.x = gun.x - 80
	p.y = gun.y
	gun.ai.state = "battery"
	gun.ai.until = 100
	m.tactics.plan_enemy(m)
	check(gun.ai.state == "displace" and gun.target != null and gun.attackId == null, "close threats interrupt a battery's firing order")
	check(FieldData.pos(gun.goal).distance_to(FieldData.pos(p)) > FieldData.distance(gun, p), "threatened battery displaces away from the observed enemy")

func retreat_checks() -> void:
	var m = fixture()
	var b: Dictionary = m.state.battle
	var units = enemies(m)
	var tired: Dictionary = units[0]
	tired.condition = 10
	m.tactics.plan_enemy(m)
	check(tired.ai.state == "recover" and tired.fallingBack and tired.attackId == null, "exhausted infantry disengage toward a recovery position")
	tired.condition = 30
	b.time = 10
	m.tactics.plan_enemy(m)
	check(tired.ai.state == "recover", "recovery hysteresis prevents immediate return while still tired")
	tired.condition = 70
	b.time = 20
	m.tactics.plan_enemy(m)
	check(tired.ai.state != "recover", "rested infantry can return to duty")
	tired.morale = 25
	b.time = 22
	m.tactics.plan_enemy(m)
	check(tired.retreating and tired.fallingBack and tired.goal.x == m.terrain.map_size.x - 45, "shaken regiment receives an actual withdrawal order")
	tired.x = m.terrain.map_size.x - 50
	tired.y = tired.goal.y
	tired.target = null
	tired.waypoints = []
	tired.ai.until = -1
	b.time = 24
	m.tactics.plan_enemy(m)
	for i in 10: m.tactics.update(m, 0.1)
	check(tired.withdrawn, "withdrawing units finish the final meters and leave the battlefield")
	for u in units:
		u.men = u.startMen * 0.3
		u.morale = 40
	b.time = 40
	m.tactics.plan_enemy(m)
	check(b.ai.stance == "withdraw" and units.filter(func(u): return not u.withdrawn).all(func(u): return u.retreating), "army-wide collapse triggers coordinated withdrawal")
	var east = fixture()
	east.state.battle.playerEdge = "east"
	east.state.battle.erase("ai")
	var enemy: Dictionary = enemies(east)[0]
	enemy.morale = 25
	east.tactics.plan_enemy(east)
	check(enemy.goal.x == 45, "withdrawal uses the enemy's own edge on mirrored battles")

func cover_checks() -> void:
	var m = fixture()
	var units = enemies(m)
	FieldBattleAI.choose_plan(m, units, [])
	var station = FieldData.pos(units[0].ai.station)
	m.terrain.defenses = [{"id": "orchard-hedge", "name": "Hedge", "kind": "hedge", "x": station.x, "y": station.y, "facing": PI, "width": 94.0, "depth": 24.0, "capacity": 720, "protection": 0.25}]
	m.tactics.plan_enemy(m)
	check(units[0].coverOrderId == "orchard-hedge" and units[0].ai.state == "cover", "defensive infantry reserve useful cover through the shared occupation system")
	check(FieldCover.protection(m, units[0], {"x": 600, "y": 400}, false) == 0, "AI infantry receive no instant protection while approaching")
	check(units[1].coverOrderId == null, "AI respects one-regiment fortification reservations")

func save_checks() -> void:
	var m = fixture()
	m.tactics.plan_enemy(m)
	check(m.valid_state(m.state), "battle decisions and contact memory pass save validation")
	var path = "user://test-battle-ai.json"
	check(m.save_campaign(path), "AI battle saves to a separate test file")
	var restored = FieldModel.new(false)
	check(restored.load_campaign(path), "AI battle reloads")
	var saved: Dictionary = restored.state.battle.ai
	var original: Dictionary = m.state.battle.ai
	check(saved.stance == original.stance and saved.personality == original.personality and is_equal_approx(saved.until, original.until) and FieldData.pos(saved.anchor).distance_to(FieldData.pos(original.anchor)) < 0.001 and saved.contacts.size() == original.contacts.size(), "save preserves army stance, personality, intelligence and decision deadline")
	var reserve: Dictionary = enemies(restored)[2].ai
	var before: Dictionary = enemies(m)[2].ai
	check(reserve.state == before.state and reserve.committed == before.committed and FieldData.pos(reserve.station).distance_to(FieldData.pos(before.station)) < 0.001 and is_equal_approx(reserve.until, before.until), "save preserves reserve commitment and assigned sector")
	var old = m.state.duplicate(true)
	old.battle.erase("ai")
	for u in old.battle.units: u.erase("ai")
	check(m.valid_state(old), "older saves without planner metadata remain valid")
	var bad = m.state.duplicate(true)
	bad.battle.ai.contacts = "bad"
	check(not m.valid_state(bad), "malformed observation state is rejected safely")
	bad = m.state.duplicate(true)
	bad.battle.units[5].ai.station.x = "bad"
	check(not m.valid_state(bad), "malformed unit assignment is rejected safely")
	var scheduled = fixture()
	scheduled.state.battle.aiClock = 2
	scheduled.tactics.update(scheduled, 0.05)
	check(scheduled.tactics.ai_queue.size() == enemies(scheduled).size() - 1, "live simulation staggers unit planning across physics ticks")
	check(enemies(scheduled).filter(func(u): return u.ai.orders > 0).size() == 1, "only one regiment receives its new order on the first planning tick")
	for i in 4: scheduled.tactics.update(scheduled, 0.05)
	check(scheduled.tactics.ai_queue.is_empty() and enemies(scheduled).all(func(u): return u.ai.orders > 0), "scheduled planning reaches every regiment without waiting another cycle")
	scheduled.tactics.ai_queue.append("old-unit")
	check(scheduled.load_campaign(path) and scheduled.tactics.ai_queue.is_empty(), "loading a battle discards pending orders from the old simulation")

func scenario_checks() -> void:
	var durations: Array[float] = []
	var warm: Array[float] = []
	for scenario in ["bridge", "village", "ridge"]:
		for edge in ["west", "east"]:
			var m = FieldModel.new(false)
			m.start_battle("e1", true)
			m.state.battle.scenario = scenario
			m.state.battle.playerEdge = edge
			m.terrain.configure(m.state)
			m.prepare_deployment()
			var started = Time.get_ticks_usec()
			m.tactics.plan_enemy(m)
			durations.append((Time.get_ticks_usec() - started) / 1000.0)
			check(enemies(m).all(func(u): return u.has("ai") and not u.ai.reason.is_empty()), scenario + " / " + edge + " assigns every arrived unit an intention")
			check(enemies(m).all(func(u): return u.goal == null or m.terrain.passable(FieldData.pos(u.goal))), scenario + " / " + edge + " orders have legal destinations")
			check(m.valid_state(m.state), scenario + " / " + edge + " keeps a valid save state")
			for i in 5:
				m.state.battle.time += 8
				started = Time.get_ticks_usec()
				m.tactics.plan_enemy(m)
				warm.append((Time.get_ticks_usec() - started) / 1000.0)
	durations.sort()
	warm.sort()
	print("AI PLAN COST: cold median %.2fms / warm median %.2fms / warm maximum %.2fms" % [durations[durations.size() / 2], warm[warm.size() / 2], warm.back()])
