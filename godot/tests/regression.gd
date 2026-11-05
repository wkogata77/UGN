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

func run() -> void:
	map_checks()
	marching_checks()
	casualty_checks()
	movement_checks()
	print("GODOT EXPANSION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func map_checks() -> void:
	var m = FieldModel.new(false)
	check(m.terrain.map_size == Vector2(17280, 11520), "Italy has four times the previous playable area")
	check(m.terrain.towns.size() == 18 and m.terrain.crossings.size() == 5, "expanded campaign has settlements and crossings")
	check(m.terrain.passable(Vector2(8520, 5640)), "far corner is traversable")
	var route = m.terrain.route(Vector2(300, 4800), Vector2(8200, 600))
	check(not route.is_empty() and FieldData.pos(route.back()) == Vector2(8200, 600), "route reaches distant northern bank")
	var previous = Vector2(300, 4800)
	var legal = true
	for p in route:
		legal = legal and m.terrain.direct_route(previous, FieldData.pos(p))
		previous = FieldData.pos(p)
	check(legal, "long campaign route uses legal crossings")
	m.start_battle("e1", true)
	check(m.terrain.map_size == Vector2(5760, 3840), "battlefields also have four times the area")
	var old = m.state.duplicate(true)
	old.campaignMapVersion = 1
	old.army.x = 280
	old.army.y = 727
	old.army.path = [{"x": 400, "y": 700}]
	old.battle.origin = {"x": 280, "y": 727}
	var tactical: String = JSON.stringify(old.battle.units)
	FieldCampaign.migrate(old)
	check(FieldData.pos(old.army) == Vector2(3360, 8724) and FieldData.pos(old.army.path[0]) == Vector2(4800, 8400), "legacy strategic army and orders migrate")
	check(FieldData.pos(old.battle.origin) == Vector2(3360, 8724) and JSON.stringify(old.battle.units) == tactical, "battle origin migrates without moving tactical soldiers")
	var once = JSON.stringify(old)
	FieldCampaign.migrate(old)
	check(JSON.stringify(old) == once, "map migration is idempotent")
	m.state = old
	check(m.save_campaign("user://test-expanded-map.json"), "expanded map save writes")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-expanded-map.json") and restored.state.army.x == 3360, "expanded JSON map version reloads without doubling")
	m.new_campaign("danube")
	check(m.terrain.map_size == Vector2(5760, 3840), "Danube campaign also expands")
	var legacy = FieldModel.new(false)
	legacy.state.campaignMapVersion = 1
	legacy.state.army.x = 280
	legacy.state.army.y = 727
	legacy.save_campaign("user://test-migration-backup.json")
	check(restored.load_campaign("user://test-migration-backup.json") and FileAccess.file_exists("user://test-migration-backup.json.pre-expanded-map.bak"), "legacy native save backed up before migration")

func marching_checks() -> void:
	var distances: Array[float] = []
	var fatigue: Array[float] = []
	for mode in ["slow", "normal", "route"]:
		var m = FieldModel.new(false)
		for e in m.state.enemies: e.defeated = true
		var before = FieldData.pos(m.state.army)
		m.move_army(before + Vector2(500, 0))
		check(m.march_mode(mode) and m.state.speed == 0.5, mode + " marching independent of time speed")
		for i in 200: m.update_campaign(0.05)
		distances.append(FieldData.pos(m.state.army).distance_to(before))
		fatigue.append(100 - m.state.army.condition)
		var tired: float = m.state.army.condition
		m.halt()
		m.update_campaign(1.0)
		check(m.state.army.condition > tired, mode + " stationary army recovers")
	check(distances[0] < distances[1] and distances[1] < distances[2], "slow normal route pace ordering")
	check(fatigue[0] < fatigue[1] and fatigue[1] < fatigue[2], "slow normal route fatigue ordering")
	var m = FieldModel.new(false)
	m.state.immunity = 10000
	var enemy: Dictionary = m.state.enemies[0]
	enemy.path = [{"x": enemy.x + 100, "y": enemy.y}]
	var before = FieldData.pos(enemy)
	m.update_campaign(1.0)
	check(enemy.condition < 100 and FieldData.pos(enemy) != before, "enemy movement accumulates fatigue")
	enemy.condition = 12
	before = FieldData.pos(enemy)
	m.update_campaign(1.0)
	check(enemy.resting and enemy.condition > 12 and FieldData.pos(enemy) == before, "exhausted enemy rests instead of marching forever")
	enemy.x = m.state.army.x + 100
	enemy.y = m.state.army.y
	enemy.condition = 100
	enemy.resting = false
	check(m.attack_army(enemy.id), "campaign intercept command")
	enemy.x += 50
	m.update_campaign(1.0)
	check(m.state.army.attackId == enemy.id and FieldData.pos(m.state.army.path.back()).distance_to(Vector2(enemy.x, enemy.y)) < 20, "campaign attack follows visible moving target")
	m.halt()
	check(m.state.army.attackId == null and m.state.army.path.is_empty(), "halt cancels interception")
	check(not m.march_mode("invalid"), "invalid march mode rejected")

func casualty_checks() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	var u: Dictionary = m.state.battle.units[0]
	var soldiers = m.formations.positions(u)
	var previous: Array[Vector2] = []
	for p in soldiers: previous.append(p.p)
	var expected = m.formations.casualty_order(u, soldiers).slice(0, 4)
	u.men -= 36
	m.formations.advance(m.state.battle.units, 0.1, 0.1, m.state.battle.bodies)
	check(u.deadSlots == expected, "casualties remove front rank slots first")
	check(m.state.battle.bodies.size() == 4, "representative casualties create persistent bodies")
	var stable = true
	var advanced = 0
	var slots = FieldFormations.offsets(u)
	for i in soldiers.size():
		if not soldiers[i].alive: continue
		var step = soldiers[i].p - previous[i]
		if soldiers[i].slot == i:
			stable = stable and step.length() < 0.001
		else:
			advanced += 1
			stable = stable and is_equal_approx(slots[soldiers[i].slot].x, slots[i].x) and step.length() > 0 and step.length() < 2.0
	check(stable and advanced > 0, "only affected files step forward gradually after casualties")
	check(soldiers.size() == m.formations.offsets(u).size(), "formation slot count stays fixed after losses")
	var bodies = JSON.stringify(m.state.battle.bodies)
	u.x += 20
	m.formations.advance(m.state.battle.units, 0.2, 0.1, m.state.battle.bodies)
	check(JSON.stringify(m.state.battle.bodies) == bodies, "bodies stay at death location when regiment moves")
	check(m.save_campaign("user://test-casualties.json"), "casualty save writes")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-casualties.json"), "casualties and stable slots reload")
	var after = restored.formations.positions(restored.state.battle.units[0])
	check(after.filter(func(p): return not p.alive).size() == 4 and restored.state.battle.bodies.size() == 4, "reloaded casualties do not resurrect")
	check(restored.state.battle.units[0].visualSlots == u.visualSlots, "rank replacement assignments survive save and load")
	u.men = 0
	m.formations.advance(m.state.battle.units, 0.3, 0.1, m.state.battle.bodies)
	check(soldiers.all(func(p): return not p.alive) and m.state.battle.bodies.size() == soldiers.size(), "final casualties remain after regiment destruction")

func movement_checks() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	# This drill measures an open-ground resting block; street narrowing has
	# its own obstacle fixture in battle_polish.gd and town_movement.gd.
	m.terrain.buildings.clear()
	m.terrain.water = false
	var u: Dictionary = m.state.battle.units.filter(func(p): return p.kind == "cavalry" and p.side == "player")[0]
	var group = m.formations.positions(u)
	var initial: float = group[0].p.distance_to(group[7].p)
	var changed = false
	var largest_step = 0.0
	for i in 200:
		u.facing = i * 0.004
		var delta = Vector2.from_angle(u.facing) * 49 * 0.05
		u.x += delta.x
		u.y += delta.y
		var before = group[0].p
		m.formations.advance([u], i * 0.05, 0.05)
		largest_step = maxf(largest_step, group[0].p.distance_to(before))
		changed = changed or absf(group[0].p.distance_to(group[7].p) - initial) > 1.0
	check(changed, "mounted riders do not remain a rigid translated block")
	check(largest_step < 4.1, "mounted soldiers steer without teleporting")
	check(group[0].phase != group[7].phase and group[0].moving > 0, "individual riders retain different stride phases")
	var paused = group[0].p
	m.formations.advance([u], 10, 0)
	check(group[0].p == paused, "zero-time update freezes cavalry")
	for i in 300: m.formations.advance([u], 10 + i * 0.05, 0.05)
	var settled = true
	var slots = FieldFormations.offsets(u)
	for i in group.size():
		settled = settled and group[i].p.distance_to(FieldFormations.world_point(u, slots[i])) < 0.1 and group[i].moving < 0.08
	check(settled, "halted cavalry reforms a stable resting block")
