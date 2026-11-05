extends SceneTree

var checks = 0
var failures: Array[String] = []
var ui_completed = false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	sight_checks()
	morale_checks()
	charge_checks()
	retreat_checks()
	pace_checks()
	await ui_lifecycle_checks()
	check(ui_completed, "inspector lifecycle checks finish without script errors")
	print("GODOT BATTLE ORDERS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func fixture(kind: String = "infantry") -> FieldModel:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.state.battle.aiClock = -10000
	m.terrain.configure(m.state)
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	# Isolate combat rules from village obstacles; polish.gd exercises scenery LOS.
	m.terrain.buildings.clear()
	m.terrain.defenses.clear()
	m.terrain.grids.clear()
	m.terrain.heights.clear()
	for u in m.state.battle.units: u.arrival = 99999
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	a.merge({"x": 450.0, "y": 400.0, "kind": kind, "weapon": "sabre" if kind == "cavalry" else "cannon" if kind == "artillery" else "musket", "arrival": 0.0, "facing": 0.0, "men": 270.0, "startMen": 270.0, "holdFire": true, "reload": 0.0}, true)
	b.merge({"x": 650.0, "y": 400.0, "arrival": 0.0, "facing": PI, "men": 600.0, "maxMen": 600.0, "startMen": 600.0, "holdFire": true, "reload": 100.0, "visible": true}, true)
	for c in m.state.battle.commanders:
		c.x = 50
		c.y = 50
		c.following = false
		c.hostId = null
	for w in m.state.battle.wagons: w.stock = 0
	m.formations.reset_roster(a)
	m.formations.reset_roster(b)
	m.tactics.update_visibility(m)
	m.select([a.id])
	return m

func step(m: FieldModel, seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		m.tactics.update(m, 0.05)
		if m.state.battle == null: return
		m.formations.advance(m.state.battle.units, m.state.battle.time, 0.05, m.state.battle.bodies)

func sight_checks() -> void:
	var m = fixture()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	check(m.terrain.line_of_sight(a, b, true), "open ground allows a direct shot")
	m.terrain.field.hills = [{"x": 550, "y": 400, "rx": 100, "ry": 160}]
	m.terrain.heights.clear()
	check(not m.terrain.line_of_sight(a, b, true), "rendered hill crest blocks shots")
	m.tactics.update_visibility(m)
	check(not b.visible and not m.tactics.visible_target(m, b, a), "terrain conceals both armies rather than granting AI omniscience")
	a.x = 510
	b.x = 568
	# The rounded knoll must still rise above the six-unit firing eye height.
	m.terrain.field.hills = [{"x": 538, "y": 400, "rx": 35, "ry": 100}]
	m.terrain.heights.clear()
	check(m.terrain.height_at(Vector2(538, 400)) > (m.terrain.height_at(FieldData.pos(a)) + m.terrain.height_at(FieldData.pos(b))) * 0.5 + 6.0, "nearby LOS fixture has an obstructing crest")
	check(not m.terrain.line_of_sight(a, b, true), "nearby crest has no 65-unit LOS bypass")
	m.terrain.field.hills = []
	m.terrain.field.forests = [{"x": 550, "y": 400, "rx": 150, "ry": 160}]
	m.terrain.heights.clear()
	a.x = 450
	b.x = 650
	check(not m.terrain.line_of_sight(a, b, true), "deep woodland blocks fire")
	m.terrain.field.forests = []
	var friendly: Dictionary = m.state.battle.units[1]
	friendly.merge({"x": 550.0, "y": 425.0, "facing": 0.0, "arrival": 0.0}, true)
	check(not m.tactics.clear_shot(m, a, b), "off-center friendly frontage blocks shooting through its edge")
	b.x = 580
	friendly.x = 510
	friendly.holdFire = true
	a.holdFire = false
	a.attackId = b.id
	m.tactics.update_visibility(m)
	var before: float = b.men
	m.tactics.update(m, 0.05)
	check(a.ammo == 100 and b.men == before, "obstructed volley spends no ammunition and deals no damage")
	friendly.y = 600
	check(m.tactics.clear_shot(m, a, b), "moving friendly frontage aside clears the shot")
	m.tactics.update(m, 0.05)
	check(a.ammo < 100 and b.men < before, "clearing friendly frontage permits the actual volley")
	friendly.y = 400
	friendly.routed = true
	check(not m.tactics.clear_shot(m, a, b), "routing friendlies still physically obstruct fire before leaving")
	friendly.withdrawn = true
	check(m.tactics.clear_shot(m, a, b), "withdrawn units no longer obstruct firing")
	b.x = 1350
	m.tactics.update_visibility(m)
	check(not m.tactics.visible_target(m, b, a), "enemy cannot target unseen distant regiments")

func morale_checks() -> void:
	var losses: Array[float] = []
	for angle in [PI, PI * 0.5, 0.0, -PI * 0.5]:
		var m = fixture()
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		b.x = 560
		b.facing = angle
		a.holdFire = false
		m.tactics.update(m, 0.05)
		losses.append(100 - b.morale)
		check(b.morale < 100 and a.ammo < 100, "valid volley applies morale damage at angle %.2f" % angle)
		if angle == 0: check(b.get("firePressure") == "rear", "rear-hit warning records actual facing")
	check(losses[1] > losses[0] * 1.9, "side fire inflicts twice the frontal morale pressure")
	check(losses[2] > losses[1], "rear fire inflicts the largest morale loss")
	check(absf(losses[1] - losses[3]) < 0.001, "left and right flank penalties are symmetric")
	var m = fixture()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	b.x = 560
	b.facing = 0.0
	b.morale = 20.2
	a.holdFire = false
	m.tactics.update(m, 0.05)
	check(b.routed, "rear fire can break a wavering regiment")
	check(FieldTactics.morale_multiplier("rear") > FieldTactics.morale_multiplier("side") and FieldTactics.morale_multiplier("side") > FieldTactics.morale_multiplier("front"), "morale sector scaling is independent of casualty multiplier")

func charge_checks() -> void:
	var impacts: Array[float] = []
	var fatigue: Array[float] = []
	for kind in ["infantry", "cavalry"]:
		var m = fixture(kind)
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		var walk_pace = FieldFormations.march_pace(a)
		check(m.charge() == 1 and a.charging, kind + " can receive charge order")
		check(FieldFormations.march_pace(a) > walk_pace * 1.45, kind + " charges faster than ordinary running")
		check(m.charge() == 0, kind + " repeated charge cannot reset run-up")
		var frozen = JSON.stringify(a)
		m.state.paused = true
		m.tick(1.0)
		check(JSON.stringify(a) == frozen, kind + " pause freezes charge state")
		for i in 250:
			step(m, 0.05)
			if a.get("meleeTargetId") != null: break
		check(a.get("meleeTargetId") == b.id and not a.charging and a.chargeImpactUntil > m.state.battle.time, kind + " run-up becomes one contact impact")
		check(a.ammo == 100, kind + " never shoots while charging or in melee")
		check(m.charge() == 0, kind + " cannot re-charge from standing melee")
		var until: float = a.chargeImpactUntil
		step(m, 1)
		check(a.chargeImpactUntil == until, kind + " sustained melee does not renew impact")
		var sample: Dictionary = a.duplicate(true)
		sample.charging = true
		sample.chargeDistance = 100.0
		sample.chargeTargetId = b.id
		impacts.append(FieldCharge.impact(sample, b, 10))
		check(FieldCharge.impact(sample, b, 10.1) == 1.0, kind + " impact is consumed exactly once")
		sample.condition = 100
		sample.fightingUntil = 0
		sample.meleeUntil = 0
		sample.running = false
		m.tactics.condition(sample, {"p": FieldData.pos(sample) - Vector2(20, 0), "facing": sample.facing, "working": false, "charging": true}, 20, 1)
		fatigue.append(100 - sample.condition)
	check(impacts[1] > impacts[0] and impacts[0] > 1, "cavalry has the largest charge impact bonus")
	check(fatigue[1] < fatigue[0] and fatigue[1] > 0.9, "cavalry charge costs less stamina than infantry but more than normal running")
	var m = fixture("artillery")
	var a: Dictionary = m.state.battle.units[0]
	check(m.charge() == 0 and not a.charging, "artillery cannot charge through the model API")
	m = fixture()
	a = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	m.charge()
	check(FieldCharge.impact(a, b, 1) == 1.0, "standing contact earns no run-up bonus")
	a.chargeReadyAt = 0
	m.charge()
	m.halt()
	check(not a.charging and a.chargeDistance == 0, "Halt cancels charge momentum")
	a.chargeReadyAt = 0
	m.charge()
	m.formation("column")
	step(m, 0.05)
	check(not a.charging and a.chargeDistance == 0, "reforming cancels charge momentum")
	var bad = a.duplicate(true)
	bad.chargeDistance = -1
	check(not m.valid_regiment(bad), "invalid saved charge momentum rejected")
	check(m.save_campaign("user://test-battle-orders.json"), "battle order state saves")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-battle-orders.json"), "battle order state reloads")

func retreat_checks() -> void:
	for edge in ["west", "east"]:
		var m = fixture()
		m.state.battle.playerEdge = edge
		var a: Dictionary = m.state.battle.units[0]
		a.x = 90 if edge == "west" else m.terrain.map_size.x - 90
		a.facing = PI if edge == "west" else 0
		check(m.retreat_units() == 1 and a.retreating and not a.withdrawn, edge + " retreat starts a real route, not instant removal")
		check(a.goal.x == (45 if edge == "west" else m.terrain.map_size.x - 45), edge + " retreat uses own deployment edge")
		step(m, 3)
		check(a.withdrawn and not a.visible and m.selected_units().is_empty(), edge + " reaching edge removes unit from play and selection")
		check(not FieldTactics.active(m.state.battle, "player").has(a), edge + " withdrawn unit cannot hold objectives or observe")
		var survivors: float = a.men
		m.finish_battle(false, true)
		check(m.state.units[0].men == floorf(survivors), edge + " withdrawal preserves campaign survivors")
	var m = fixture("artillery")
	var a: Dictionary = m.state.battle.units[0]
	var start = FieldData.pos(a)
	m.retreat_units()
	step(m, 2)
	check(a.limberChange > 0 and FieldData.pos(a) == start, "retreating artillery packs before moving")
	step(m, 4)
	check(a.limbered and a.retreating, "artillery completes packing during withdrawal")
	m.limber()
	check(a.limberChange == 0 and a.limbered, "retreat order cannot accidentally unpack artillery")
	m.halt()
	check(not a.retreating and a.target == null, "retreat can be cancelled before the edge")
	m = fixture()
	a = m.state.battle.units[0]
	m.charge()
	m.retreat_units()
	check(a.retreating and not a.charging and a.attackId == null, "retreat cancels attacks and charge")
	m.move_units(Vector2(400, 300))
	check(not a.retreating, "new ground order cancels withdrawal")
	m.state.battle.units = [a, m.state.battle.units[5]]
	a.x = 46
	a.facing = PI
	m.retreat_units()
	step(m, 1)
	check(m.state.battle == null and m.state.report.retreat and not m.state.report.won, "withdrawing final unit ends battle without a victory reward")

func pace_checks() -> void:
	for kind in ["infantry", "cavalry", "artillery"]:
		var m = fixture(kind)
		var u: Dictionary = m.state.battle.units[0]
		u.limbered = kind == "artillery"
		m.formations.reset(u)
		var pace = FieldFormations.march_pace(u)
		var speeds_ok = true
		var equal_cruise = true
		for tick in 180:
			u.x += pace * 0.05
			m.formations.advance([u], tick * 0.05, 0.05)
			for p in m.formations.positions(u):
				speeds_ok = speeds_ok and p.velocity.length() <= pace + 0.001
				if tick > 30: equal_cruise = equal_cruise and absf(p.velocity.length() - pace) < 0.05
		check(speeds_ok and equal_cruise, kind + " every marching model shares one cruise speed without catch-up bursts")
		var flow: Dictionary = m.formations.motion[u.id]
		var bounded = true
		var slots = FieldFormations.offsets(u)
		for i in slots.size():
			bounded = bounded and m.formations.movement_goal(u, slots[i], i, flow, 10).distance_to(FieldFormations.world_point(u, slots[i])) < 3.5
		check(bounded, kind + " moving slots do not fan out or expand frontage")
		for i in 400: m.formations.advance([u], 10 + i * 0.05, 0.05)
		check(m.formations.positions(u).all(func(p): return p.p.distance_to(FieldFormations.world_point(u, slots[p.slot])) < 0.1), kind + " settles accurately after stopping")
		m.formations.reset(u)
		u.x = 450
		m.formations.reset(u)
		m.path_unit(u, Vector2(250, 400))
		var legal_steps = true
		for tick in 400:
			u["marchPace"] = pace
			m.state.battle.time += 0.05
			m.tactics.walk(m, u, 0.05, pace)
			m.formations.advance([u], 30 + tick * 0.05, 0.05)
			for p in m.formations.positions(u): legal_steps = legal_steps and p.p.distance_to(p.previous) <= pace * 0.05 + 0.001
		check(legal_steps, kind + " turning and reversing never exceed the assigned walking speed")

func ui_lifecycle_checks() -> void:
	var hud = FieldHud.new()
	var panel = PanelContainer.new()
	root.add_child(panel)
	hud.remove_node(panel)
	hud.remove_node(panel)
	check(panel.is_queued_for_deletion() and panel.get_parent() == null, "closing an inspector twice in one frame is harmless")
	await process_frame
	hud.remove_node(panel)
	check(not is_instance_valid(panel), "closing an already freed inspector is harmless")
	hud.free()
	ui_completed = true
