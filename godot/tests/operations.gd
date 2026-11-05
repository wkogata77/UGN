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

func demo() -> FieldModel:
	var model = FieldModel.new(false)
	model.new_campaign("mantua")
	return model

func supply(s: Dictionary) -> float:
	var total: float = s.operation.reserveSupply
	for a in s.armies: total += a.supply
	return total

func freeze_enemies(m: FieldModel) -> void:
	for a in m.state.enemies:
		a.defeated = true
		a.path = []

func run() -> void:
	var m = demo()
	var s: Dictionary = m.state
	check(s.armies.size() == 1 and s.selectedArmyId == "army", "demo starts with one selected army")
	check(s.units.size() == 5 and s.enemyUnits.size() == 15, "both sides have persistent rosters")
	check(s.paused and s.speed == 0.5, "operation starts paused at half speed")
	check(m.valid_state(s), "fresh operation validates")
	check(m.terrain.map_size == Vector2(17280, 11520) and m.terrain.river_vertical, "expanded Mincio map uses north-south river")
	check(m.terrain.river_point(3920).is_equal_approx(Vector2(8500, 3920)), "Valeggio crossing matches map data")
	check(not m.terrain.passable(Vector2(8280, 3080)), "river blocks movement away from crossings")
	check(m.terrain.passable(Vector2(8500, 3920)), "bridge is traversable")
	var route = FieldOperations.route(m.terrain, s.army, Vector2(9920, 3920))
	check(not route.is_empty() and FieldData.pos(route.back()) == Vector2(9920, 3920), "cross-river route reaches exact endpoint")
	var previous = FieldData.pos(s.army)
	var legal = true
	for point in route:
		legal = legal and m.terrain.direct_route(previous, FieldData.pos(point))
		previous = FieldData.pos(point)
	check(legal, "route does not ford the Mincio")
	var normal = FieldOperations.travel_hours(m.terrain, s.army, route)
	s.army.marchMode = "route"
	check(FieldOperations.travel_hours(m.terrain, s.army, route) < normal, "route marching reduces ETA")
	s.army.marchMode = "slow"
	check(FieldOperations.travel_hours(m.terrain, s.army, route) > normal, "slow marching increases ETA")
	s.army.marchMode = "normal"
	var troops = FieldData.men(s.units)
	var stores = supply(s)
	s.army.morale = 35.0
	s.units[3].ammo = 61.0
	s.units[3].experience = 1.7
	check(not m.split_army([]) and not m.split_army(s.units.map(func(u): return u.id)), "empty and whole-army splits rejected")
	check(not m.split_army(["u4", "u4"]), "duplicate split IDs rejected")
	check(m.split_army(["u4", "u5"], "Southern column"), "detach cavalry and artillery")
	check(s.armies.size() == 2 and s.army.name == "Southern column", "new detachment selected")
	check(FieldData.men(s.units) == troops and is_equal_approx(supply(s), stores), "split conserves troops and stores")
	check(s.army.morale == 35 and s.armies[0].morale == 35, "split preserves poor morale")
	check(s.units[3].ammo == 61 and s.units[3].experience == 1.7, "split preserves ammunition and veterans")
	check(m.army_units().size() == 2 and m.army_corps().size() == 1, "headquarters scopes roster and corps to selected force")
	check(m.valid_state(s), "split operation validates")
	check(not m.assign_corps("u4", "c1"), "regiment cannot transfer corps across distant force ownership")
	s.army.x += 300
	check(not m.merge_army("army"), "remote merge rejected")
	s.army.x -= 300
	s.army.morale = 90.0
	s.armies[0].morale = 30.0
	var expected = (90.0 * 360 + 30.0 * 2100) / troops
	check(m.merge_army("army"), "nearby armies merge")
	check(s.armies.size() == 1 and s.army.id == "army", "source removed and target selected")
	check(is_equal_approx(s.army.morale, expected), "merge uses troop-weighted morale")
	check(FieldData.men(s.units) == troops and is_equal_approx(supply(s), stores), "merge conserves troops and stores")
	check(m.valid_state(s), "merged campaign validates")
	check(m.split_army(["u1"], "First column"), "partial corps can detach")
	check(m.army_corps()[0].officerId == null, "partial corps does not duplicate its officer")
	check(m.valid_state(s), "partial corps split validates")
	check(m.merge_army("army"), "partial corps merges back")
	check(m.valid_state(s), "partial merge validates")
	check(m.split_army(["u4"], "Horse column"), "second split")
	s.armies[0].supply = 500.0
	s.army.supply = 500.0
	check(m.merge_army("army"), "merge full trains")
	check(s.army.supply == 500 and s.operation.reserveSupply == 500, "overflow supply retained in depot reserve")
	check(m.save_campaign("user://test-operation.json"), "save operation")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-operation.json"), "reload operation")
	restored.state.army.morale = 22.0
	check(restored.state.armies[0].morale == 22, "loaded active army aliases canonical record")
	for corruption in ["morale", "ownership", "selection", "site", "units", "force", "operation"]:
		var bad = s.duplicate(true)
		match corruption:
			"morale": bad.armies[0].morale = -1
			"ownership": bad.units[0].armyId = "missing"
			"selection": bad.selectedArmyId = "missing"
			"site": bad.operation.sites[0].owner = "unknown"
			"units": bad.enemyUnits.append(bad.units[0])
			"force": bad.armies.append(bad.armies[0])
			"operation": bad.operation = "bad"
		check(not m.valid_state(bad), "reject malformed operation: " + corruption)
	check(FieldOperations.morale_factor(90) < 1 and FieldOperations.morale_factor(20) > 1, "victory confidence resists morale damage, low confidence worsens it")
	check(FieldOperations.morale_factor(60) == 1, "normal confidence preserves baseline tactical balance")
	movement_checks()
	queued_order_checks()
	pursuit_delay_checks()
	objective_checks()
	encounter_checks()
	reinforcement_checks()
	commander_checks()
	var shaken = morale_volley(20.0)
	var confident = morale_volley(90.0)
	check(shaken.loss > 0 and confident.loss > 0 and shaken.loss > confident.loss, "same volley causes more morale loss in a demoralized army")
	check(is_equal_approx(shaken.casualties, confident.casualties), "army resolve changes morale resilience, not incoming physical damage")
	print("GODOT OPERATIONS: %d checks, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)

func queued_order_checks() -> void:
	var m = demo()
	freeze_enemies(m)
	var s: Dictionary = m.state
	var a: Dictionary = s.army
	a.retreatUntil = s.hours + 4.0
	var before = FieldData.pos(a)
	var destination = before + Vector2(240, 40)
	a["withdrawing"] = true
	a.path = FieldOperations.route(m.terrain, a, before - Vector2(70, 0))
	var retreat_path = JSON.stringify(a.path)
	check(m.move_army(destination), "withdrawing army accepts a queued march")
	check(JSON.stringify(a.path) == retreat_path and FieldData.pos(a.pendingOrder) == destination, "queued march does not interrupt forced withdrawal")
	check(FieldOperations.regroup_time(s, a) == "4h 00m", "regrouping countdown is explicit")
	m.tick(0.1)
	check(FieldData.pos(a) == before and s.paused, "orders do not unpause campaign time")
	check(not m.move_army(Vector2(8280, 3080)) and FieldData.pos(a.pendingOrder) == destination, "unreachable order preserves the existing queued destination")
	destination += Vector2(20, 0)
	check(m.move_army(destination) and FieldData.pos(a.pendingOrder) == destination, "new right-click destination replaces the queued march")
	check(m.valid_state(s) and m.save_campaign("user://test-operation-queued.json"), "queued march saves in a valid campaign")
	var loaded = FieldModel.new(false)
	check(loaded.load_campaign("user://test-operation-queued.json") and FieldData.pos(loaded.state.army.pendingOrder) == destination, "queued destination survives campaign reload")
	for bad_order in [[], {"x": NAN, "y": 100.0, "attackId": null}, {"x": 18000.0, "y": 100.0, "attackId": null}, {"x": 900.0, "y": 800.0, "attackId": "missing"}, {"x": 900.0, "y": 800.0}]:
		var bad = s.duplicate(true)
		bad.armies[0].pendingOrder = bad_order
		check(not m.valid_state(bad), "malformed queued marching order rejected")
	m.halt()
	check(a.get("pendingOrder") == null and JSON.stringify(a.path) == retreat_path, "halt cancels queued orders without cancelling the forced retreat")
	check(m.move_army(destination) and JSON.stringify(a.path) == retreat_path, "queued march preserves the forced retreat route")
	s.paused = false
	s.speed = 1.0
	m.tick(0.1)
	check(FieldData.pos(a).x < before.x and a.get("pendingOrder") != null, "army continues retreating while a future march is queued")
	a.path = []
	before = FieldData.pos(a)
	var recovery_deadline: float = a.retreatUntil
	var morale: float = a.morale
	m.tick(0.1)
	check(FieldData.pos(a) != before and a.retreatUntil > s.hours, "completed withdrawal permits marching during remaining recovery")
	check(a.get("pendingOrder") == null and not a.path.is_empty(), "queued march starts automatically at the end of withdrawal")
	check(a.retreatUntil == recovery_deadline and a.morale == morale, "marching neither skips recovery nor clears morale penalties")
	check(not FieldOperations.can_admin(s, a), "marching during recovery does not enable army administration")
	check(FieldData.pos(a.path.back()) == destination, "activated march preserves its exact destination")
	m.halt()
	check(a.path.is_empty(), "halt stops an active march even during recovery")
	check(m.move_army(destination) and not a.path.is_empty() and a.get("pendingOrder") == null, "new movement order during recovery starts without another queue")
	var legacy = demo()
	freeze_enemies(legacy)
	legacy.state.army.intent = "Regrouping"
	legacy.state.army.retreatUntil = legacy.state.hours + 4
	legacy.state.army["pendingOrder"] = {"x": 895.0, "y": 808.0, "attackId": null}
	var legacy_before = FieldData.pos(legacy.state.army)
	legacy.state.paused = false
	legacy.tick(0.1)
	check(FieldData.pos(legacy.state.army) != legacy_before and legacy.state.army.get("pendingOrder") == null, "old saves resume stranded queued orders without waiting out the recovery clock")
	var mixed = demo()
	freeze_enemies(mixed)
	check(mixed.split_army(["u4"], "Ready column"), "mixed readiness test detaches a force")
	var ready: Dictionary = mixed.state.army
	mixed.state.armies[0].retreatUntil = mixed.state.hours + 1.0
	mixed.state.armies[0]["withdrawing"] = true
	mixed.state.armies[0].path = FieldOperations.route(mixed.terrain, mixed.state.armies[0], Vector2(600, 820))
	mixed.select_armies(["army", ready.id])
	check(mixed.move_army(Vector2(1050, 900)), "multi-army order accepts ready and regrouping forces together")
	check(mixed.state.armies[0].get("pendingOrder") != null and FieldOperations.forced_retreat(mixed.state, mixed.state.armies[0]) and not ready.path.is_empty(), "ready army marches immediately while withdrawing army queues")
	var pursuit = demo()
	var hunter: Dictionary = pursuit.state.army
	var enemy: Dictionary = pursuit.state.enemies[0]
	enemy.x = hunter.x + 200
	enemy.y = hunter.y
	hunter.retreatUntil = pursuit.state.hours + 0.02
	hunter["withdrawing"] = true
	hunter.path = FieldOperations.route(pursuit.terrain, hunter, FieldData.pos(hunter) - Vector2(70, 0))
	var last_seen = FieldData.pos(enemy)
	check(pursuit.attack_army(enemy.id) and hunter.pendingOrder.attackId == enemy.id, "visible enemy can be queued for interception")
	enemy.x = 3900
	enemy.y = 2600
	check(not pursuit.enemy_visible(enemy), "queued pursuit fixture loses sight of its target")
	pursuit.state.enemyClock = -1000
	FieldOperations.update(pursuit, 0.4)
	check(hunter.attackId == null and FieldData.pos(hunter.path.back()) == last_seen, "expired queued interception uses last known destination without hidden tracking")

func pursuit_delay_checks() -> void:
	var m = demo()
	freeze_enemies(m)
	var s: Dictionary = m.state
	var a: Dictionary = s.army
	a.retreatUntil = s.hours + 0.5
	a["pursuitUntil"] = s.hours + FieldOperations.PURSUIT_PAUSE_SECONDS * FieldOperations.HOURS_PER_SECOND
	var before = FieldData.pos(a)
	var destination = before + Vector2(200, 0)
	check(m.move_army(destination) and a.get("pendingOrder") != null and a.path.is_empty(), "victor queues pursuit while reforming")
	check(m.save_campaign("user://test-operation-pursuit.json"), "pursuit pause persists in saves")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-operation-pursuit.json") and FieldOperations.pursuit_paused(restored.state, restored.state.army), "reloading cannot bypass pursuit pause")
	for value in [-1.0, NAN, "bad"]:
		var bad = s.duplicate(true)
		bad.armies[0].pursuitUntil = value
		check(not m.valid_state(bad), "invalid pursuit delay is rejected")
	m.tick(0.1)
	check(FieldData.pos(a) == before and FieldOperations.pursuit_paused(s, a), "paused campaign freezes pursuit delay")
	s.paused = false
	s.speed = 1.0
	for i in 19: m.tick(0.1)
	check(FieldData.pos(a) == before and a.get("pendingOrder") != null, "victor waits two simulation seconds before pursuing")
	for i in 2: m.tick(0.1)
	check(FieldData.pos(a) != before and a.get("pendingOrder") == null, "queued pursuit starts automatically after short pause")
	var slow = FieldOperations.recovery_pace(s, a)
	check(slow == 0.7, "recovering army marches at seventy percent of normal pace")
	var normal_eta = FieldOperations.travel_hours(m.terrain, a, a.path)
	var recovering_eta = FieldOperations.travel_hours(m.terrain, a, a.path, slow)
	check(is_equal_approx(recovering_eta, normal_eta / slow), "march ETA includes recovery slowdown")
	var ordinary = demo()
	freeze_enemies(ordinary)
	var recovering = demo()
	freeze_enemies(recovering)
	recovering.state.army.retreatUntil = recovering.state.hours + 4
	for game in [ordinary, recovering]:
		game.move_army(Vector2(950, 820))
		game.update_campaign(0.1)
	var distance_ratio = FieldData.pos(recovering.state.army).distance_to(before) / FieldData.pos(ordinary.state.army).distance_to(before)
	check(absf(distance_ratio - 0.7) < 0.0001, "actual recovery march moves thirty percent slower on identical terrain")
	recovering.state.army.retreatUntil = recovering.state.hours
	check(FieldOperations.recovery_pace(recovering.state, recovering.state.army) == 1.0, "full marching pace returns when recovery finishes")
	var enemy_model = demo()
	var e: Dictionary = enemy_model.state.enemies[0]
	for other in enemy_model.state.enemies.slice(1): other.defeated = true
	for unit in FieldOperations.roster(enemy_model.state, e):
		unit.men *= 3
		unit.maxMen *= 3
	e.x = enemy_model.state.army.x + 200.0
	e.y = enemy_model.state.army.y
	e.morale = 90.0
	e.personality = "aggressive"
	e.strength = FieldData.men(FieldOperations.roster(enemy_model.state, e))
	e.retreatUntil = enemy_model.state.hours + 0.5
	e["pursuitUntil"] = enemy_model.state.hours + 2 * FieldOperations.HOURS_PER_SECOND
	enemy_model.state.army.retreatUntil = enemy_model.state.hours + 4
	var enemy_before = FieldData.pos(e)
	FieldOperations.decide(enemy_model, e)
	enemy_model.update_campaign(1.9)
	check(e.path.is_empty() and FieldData.pos(e) == enemy_before, "victorious enemy also pauses before pursuit")
	enemy_model.update_campaign(0.2)
	check(e.intent == "Intercepting" and FieldData.pos(e) != enemy_before, "enemy can pursue a recovering opponent after its short pause")
	check(FieldOperations.recovery_pace(enemy_model.state, e) == 0.7, "enemy has the same reorganization movement penalty")

func movement_checks() -> void:
	var m = demo()
	freeze_enemies(m)
	var s: Dictionary = m.state
	s.army.morale = 30.0
	s.army.supply = 100.0
	var morale: float = s.army.morale
	m.update_campaign(1)
	check(s.army.morale > morale and s.army.supply > 100, "rest at friendly depot restores low confidence and supply")
	check(m.split_army(["u4"], "Patrol column"), "split before movement")
	var parent = s.armies[0]
	parent.condition = 60.0
	check(m.move_army(Vector2(1100, 1050)), "selected detachment gets a march order")
	check(parent.path.is_empty(), "unselected army does not receive order")
	var position = FieldData.pos(s.army)
	var rested: float = parent.condition
	var stamina: float = s.army.condition
	m.update_campaign(1)
	check(FieldData.pos(s.army) != position and s.army.condition < stamina, "moving army changes position and fatigues")
	check(parent.condition > rested, "stationary other army rests independently")
	check(not m.split_army(["u4"]), "moving army cannot split")
	m.halt()
	check(m.select_armies(["army", s.army.id]), "multi-army selection")
	check(m.march_mode("slow") and s.armies.all(func(a): return a.marchMode == "slow"), "march mode applies to all selected armies")
	check(m.move_army(Vector2(1300, 1050)) and s.armies.all(func(a): return not a.path.is_empty()), "group order moves both armies")
	m.halt()
	check(s.armies.all(func(a): return a.path.is_empty()), "group halt")
	var enemy: Dictionary = s.enemies[0]
	enemy.defeated = false
	enemy.x = 1500.0
	enemy.y = 750.0
	enemy.path = [{"x": 1600.0, "y": 750.0}]
	enemy.condition = 80.0
	m.update_campaign(0.5)
	check(enemy.condition < 80, "enemy marching generates fatigue")
	enemy.morale = 12.0
	FieldOperations.decide(m, enemy)
	check(enemy.intent == "Recovering at depot", "demoralized enemy chooses recovery")
	s.army.scoutReady = 0.0
	check(m.scout() and not m.scout(), "army-local scouting charges and obeys cooldown")
	check(s.army.scoutUntil > s.hours, "scouting duration belongs to the selected army")
	var hours: float = s.hours
	s.paused = true
	m.tick(1)
	check(s.hours == hours, "pause freezes operational time")

func objective_checks() -> void:
	var m = demo()
	freeze_enemies(m)
	var s: Dictionary = m.state
	var site = m.find_id(s.operation.sites, "solferino")
	s.army.x = site.x
	s.army.y = site.y
	var cash: float = s.cash
	FieldOperations.update_sites(m, 0.2)
	check(site.owner == "neutral" and site.progress > 0, "occupation takes campaign time")
	FieldOperations.update_sites(m, 0.21)
	check(site.owner == "player" and s.cash == cash + 150, "sustained occupation captures site and awards once")
	FieldOperations.update_sites(m, 0.5)
	check(s.cash == cash + 150, "occupation does not repeatedly award money")
	var e: Dictionary = s.enemies[0]
	e.defeated = false
	e.x = site.x + 10
	e.y = site.y
	FieldOperations.update_sites(m, 0.5)
	check(site.contested and site.owner == "player", "both sides contest an objective")
	e.defeated = true
	var fort = m.find_id(s.operation.sites, "mantua")
	s.army.x = fort.x
	s.army.y = fort.y
	FieldOperations.update_sites(m, 7.9)
	check(fort.owner == "enemy", "fort requires sustained blockade")
	FieldOperations.update_sites(m, 0.11)
	check(fort.owner == "player", "blockade captures Mantua")
	m.find_id(s.operation.sites, "valeggio").owner = "player"
	FieldOperations.update_sites(m, 1.9)
	check(s.operation.status == "active", "final objectives require hold time")
	FieldOperations.update_sites(m, 0.11)
	check(s.operation.status == "victory" and s.paused, "operation victory pauses time")

func encounter_checks() -> void:
	var m = demo()
	var s: Dictionary = m.state
	check(m.split_army(["u4", "u5"], "Support column"), "split supporting column")
	var support: Dictionary = s.army
	support.x = 7480.0 - 220.0
	support.y = 3920.0 + 170.0
	m.select_armies(["army"])
	s.army.x = 7480.0
	s.army.y = 3920.0
	s.army.morale = 30.0
	s.enemies[0].x = 7620.0
	s.enemies[0].y = 3920.0
	s.enemies[0].morale = 90.0
	s.enemies[1].x = 10400.0
	s.enemies[1].y = 3920.0
	s.enemies[2].x = 15440.0
	s.enemies[2].y = 10400.0
	var distant_before = JSON.stringify(s.enemyUnits.filter(func(u): return u.armyId == "e3"))
	var original_enemy: Dictionary = s.enemyUnits[0]
	original_enemy.ammo = 47.0
	original_enemy.men -= 35.0
	var hours: float = s.hours
	check(m.start_battle("e1"), "operational encounter starts")
	var b: Dictionary = s.battle
	check(b.scenario == "bridge" and b.has("campaignForces"), "crossing encounter records force schedule")
	var friendly = b.campaignForces.filter(func(entry): return entry.armyId == support.id)
	check(friendly.size() == 1 and friendly[0].arrival > 0, "friendly reinforcements scheduled from route time")
	check(not b.campaignForces.any(func(entry): return entry.armyId == "e3"), "distant force excluded")
	var unit = m.find_id(b.units, "u1")
	check(unit.morale < 100 and unit.armyMorale == 30, "low campaign confidence lowers starting resolve")
	var enemy = m.find_id(b.units, original_enemy.id)
	check(enemy.men == original_enemy.men and enemy.ammo == 47, "enemy roster and ammunition not regenerated")
	check(enemy.armyMorale == 90, "enemy campaign confidence reaches tactical battle")
	check(m.valid_state(s), "operational battle validates")
	check(m.save_campaign("user://test-operation-battle.json"), "save battle with reinforcement schedule")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-operation-battle.json"), "load operational battle")
	var schedules_match = restored.state.battle.campaignForces.size() == b.campaignForces.size()
	for entry in b.campaignForces:
		var matches = restored.state.battle.campaignForces.filter(func(item): return item.armyId == entry.armyId)
		schedules_match = schedules_match and matches.size() == 1 and is_equal_approx(matches[0].arrival, entry.arrival) and matches[0].edge == entry.edge
	check(schedules_match, "arrival schedule survives reload without recalculation")
	var bad = s.duplicate(true)
	bad.battle.campaignForces[0].arrival = -1
	check(not m.valid_state(bad), "reject invalid reinforcement arrival")
	b.aiClock = -1000.0
	m.tactics.update(m, 0.1)
	check(s.hours == hours, "campaign clock frozen during tactical battle")
	enemy.men -= 100.0
	enemy.ammo = 20.0
	unit.men -= 50.0
	var support_morale: float = support.morale
	var support_supply: float = support.supply
	check(m.finish_battle(true), "resolve operational victory")
	check(is_equal_approx((s.army.pursuitUntil - s.hours) / FieldOperations.HOURS_PER_SECOND, 2.0) and s.enemies[0].pursuitUntil == 0, "battle outcome pauses the victor but lets defeated troops withdraw immediately")
	check(s.army.morale > 30 and s.enemies[0].morale < 90, "victory buffs and defeat debuffs respective armies")
	check(not s.enemies[0].defeated and not s.enemies[0].path.is_empty(), "defeated enemy survivors march away")
	check(s.enemyUnits[0].men == original_enemy.maxMen - 135 and s.enemyUnits[0].ammo == 20, "enemy losses and spent ammunition persist")
	check(s.report.loot == 18, "captured arms derive from actual enemy losses")
	check(support.morale == support_morale and support.supply == support_supply, "unarrived support gets no morale award or supply deduction")
	check(s.report.casualties == 50, "report counts participating troops, not entire theater")
	check(JSON.stringify(s.enemyUnits.filter(func(u): return u.armyId == "e3")) == distant_before, "uninvolved enemy roster unchanged")
	check(m.valid_state(s), "post-battle operation validates")
	check(not m.finish_battle(true), "battle cannot pay reward twice")
	m.dismiss_report()
	check(not m.start_battle("e1"), "retreating armies cannot immediately be re-engaged")
	s.army.retreatUntil = 0.0
	s.enemies[0].retreatUntil = 0.0
	check(m.start_battle("e1"), "surviving enemy can be fought again")
	check(m.find_id(s.battle.units, original_enemy.id).men == original_enemy.maxMen - 135, "rematch retains casualties")
	var position = FieldData.pos(s.army)
	var before: float = s.army.morale
	check(m.finish_battle(false, true), "player army can withdraw")
	check(s.army.morale < before and s.army.retreatUntil > s.hours, "player withdrawal reduces army morale and grants regrouping period")
	check(FieldData.pos(s.army) == position, "withdrawal does not teleport the army")
	check(not s.army.path.is_empty(), "withdrawn player army has strategic retreat route")
	check(m.valid_state(s), "withdrawal save validates")

func reinforcement_checks() -> void:
	var m = demo()
	var s: Dictionary = m.state
	check(m.split_army(["u4"], "Relief force"), "detach arrival-test force")
	var support: Dictionary = s.army
	check(m.hire_officer("reserve-0") and m.assign_officer(support.id, "reserve-0"), "commission reinforcing army general")
	support.x = 1640.0
	support.y = 940.0
	m.select_armies(["army"])
	s.army.x = 1850.0
	s.army.y = 980.0
	s.enemies[0].x = 1910.0
	s.enemies[0].y = 980.0
	s.enemies[1].x = 3800.0
	s.enemies[1].y = 500.0
	s.enemies[2].x = 3800.0
	s.enemies[2].y = 2600.0
	check(m.start_battle("e1"), "arrival-test encounter starts")
	var b: Dictionary = s.battle
	var entry: Dictionary = b.campaignForces.filter(func(item): return item.armyId == support.id)[0]
	var u = m.find_id(b.units, "u4")
	var general = m.find_id(b.commanders, "general-" + support.id)
	check(not general.is_empty() and general.officerId == support.officerId and general.arrival == entry.arrival, "reinforcing army brings its own scheduled general")
	m.select_commander(general.id)
	check(s.selectedCommander == null, "unarrived army general cannot be selected")
	check(not m.rally(general.id), "unarrived general cannot rally")
	var enemy: Dictionary = b.units.filter(func(item): return item.side == "enemy" and item.arrival == 0)[0]
	var enemy_position = FieldData.pos(enemy)
	enemy.x = general.x
	enemy.y = general.y
	var officer = m.find_id(s.officers, general.officerId)
	var wounds: float = officer.wounds
	m.tactics.update_commanders(m, 20.0)
	check(general.unavailable and general.shaken == 0 and officer.wounds == wounds, "off-map general cannot be threatened or wounded")
	enemy.x = enemy_position.x
	enemy.y = enemy_position.y
	check(m.save_campaign("user://test-operation-generals.json"), "battle with reinforcing generals saves")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-operation-generals.json"), "battle with reinforcing generals reloads")
	check(is_equal_approx(m.find_id(restored.state.battle.commanders, general.id).arrival, entry.arrival), "reloaded general retains arrival schedule")
	check(not u in FieldTactics.active(b, "player"), "unarrived regiment cannot fight")
	m.select([u.id])
	check(m.selected_units().is_empty(), "unarrived regiment cannot receive player orders")
	var supply_before: float = b.wagons[0].stock
	for regiment in b.units: regiment.holdFire = true
	b.aiClock = -10000.0
	b.time = entry.arrival - 0.01
	m.tactics.update(m, 0.02)
	check(u in FieldTactics.active(b, "player"), "reinforcement becomes active at scheduled arrival")
	check(is_equal_approx(b.wagons[0].stock, supply_before + entry.supply), "reinforcement train supply enters once")
	var joined: float = b.wagons[0].stock
	m.tactics.update(m, 0.02)
	check(is_equal_approx(b.wagons[0].stock, joined), "following ticks cannot duplicate reinforcement supplies")
	check(m.terrain.passable(FieldData.pos(u)), "reinforcement spawns on legal tactical ground")
	check(not general.unavailable, "arrived general becomes available")
	m.select_commander(general.id)
	check(s.selectedCommander == general.id, "arrived general can receive orders")
	var primary = m.find_id(b.units, "u1")
	for regiment in [u, primary]:
		regiment.x = 600.0
		regiment.y = 500.0
		regiment.morale = 40.0
	general.x = 600.0
	general.y = 500.0
	general.shaken = 0.0
	check(general in m.command_support(u) and not general in m.command_support(primary), "general command support stays within own army")
	check(m.rally(general.id), "arrived army general rallies nearby troops")
	check(u.morale == 58 and primary.morale == 40, "army rally excludes other army's regiments")
	var start_position = FieldData.pos(support)
	var origin = FieldData.pos(b.origin)
	var confidence: float = support.morale
	check(m.finish_battle(true), "resolve after reinforcement joined")
	check(support.morale > confidence, "arrived supporting army earns victory confidence")
	check(FieldData.pos(support).distance_to(origin) <= 81 and FieldData.pos(support) != start_position, "arrived force returns near encounter, not its old campaign position")
	check(m.valid_state(s), "reinforced battle result validates")
	m.dismiss_report()
	s.army.retreatUntil = 0.0
	var depot = m.find_id(s.operation.sites, "castiglione")
	s.army.x = depot.x
	s.army.y = depot.y
	s.army.supply = 200.0
	s.operation.reserveSupply = 300.0
	FieldOperations.bind_selection(s)
	for regiment in m.army_units(): regiment.ammo = 100.0
	var cash: float = s.cash
	check(m.resupply_cost() == 0 and m.resupply(), "depot reserve can refill an army without a cash purchase")
	check(s.army.supply == 500 and s.operation.reserveSupply == 0 and s.cash == cash, "reserve refill conserves supply and money")

func commander_checks() -> void:
	var m = demo()
	var s: Dictionary = m.state
	check(m.find_id(s.officers, s.army.officerId).name == s.general.name, "starting army commander has a persistent officer record")
	check(m.split_army(["u4"], "Cavalry detachment"), "detach force for commander assignment")
	check(s.army.officerId == null and s.armies[0].officerId != null, "splitting does not duplicate army commander")
	check(m.hire_officer("reserve-0"), "commission new army commander")
	check(m.assign_officer(s.army.id, "reserve-0"), "assign available brigadier to independent army")
	check(s.army.commander.contains("Delmas") and m.valid_state(s), "army commander assignment persists and validates")
	s.army.x = 1600.0
	s.army.y = 850.0
	s.enemies[0].x = 1660.0
	s.enemies[0].y = 850.0
	var commander = m.find_id(s.officers, "reserve-0")
	var xp: float = commander.xp
	check(m.start_battle("e1") and s.battle.commanders[0].officerId == commander.id, "selected army commander leads tactical encounter")
	check(m.finish_battle(true) and commander.xp > xp, "participating army commander gains experience")
	check(m.valid_state(s), "commander progression validates after battle")

func morale_volley(confidence: float) -> Dictionary:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	var b: Dictionary = m.state.battle
	b.aiClock = -10000.0
	for u in b.units: u.arrival = 99999.0
	var attacker: Dictionary = b.units[0]
	var defender: Dictionary = b.units.filter(func(u): return u.side == "enemy")[0]
	attacker.merge({"x": 550.0, "y": 400.0, "facing": 0.0, "arrival": 0.0, "reload": 0.0}, true)
	defender.merge({"x": 660.0, "y": 400.0, "facing": PI, "arrival": 0.0, "reload": 9999.0, "visible": true, "holdFire": true, "armyMorale": confidence}, true)
	m.tactics.update(m, 0.1)
	return {"loss": 100.0 - defender.morale, "casualties": defender.startMen - defender.men}
