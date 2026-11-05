extends SceneTree

var count = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	count += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for theater in ["italy", "mantua", "danube"]:
		var m = FieldModel.new(false)
		m.new_campaign(theater)
		check(m.terrain.map_size == FieldCampaign.layout(theater, 2).size * 4, theater + " quadruples both original campaign dimensions")
		check(m.valid_state(m.state), theater + " expanded campaign validates")
		var target = m.terrain.map_size - Vector2(120, 120)
		check(m.move_army(target), theater + " distant corner accepts march orders")
		check(FieldData.pos(m.state.army.path.back()).is_equal_approx(target), theater + " march ends at exact expanded destination")
		check(m.save_campaign("user://test-large-" + theater + ".json"), theater + " expanded orders save")
		var restored = FieldModel.new(false)
		check(restored.load_campaign("user://test-large-" + theater + ".json") and restored.terrain.map_size == m.terrain.map_size, theater + " enlarged map reloads")
		var old = m.state.duplicate(true)
		FieldCampaign.resize_state(old, 0.25)
		old.campaignMapVersion = 2
		var position = FieldData.pos(old.army)
		old.army["pendingOrder"] = {"x": position.x + 20, "y": position.y, "attackId": null}
		old.army["lastSighting"] = {"x": 900, "y": 800, "at": old.hours, "strength": 1000}
		old.army["redeployAt"] = {"x": 600, "y": 800}
		var units = JSON.stringify(old.units)
		FieldCampaign.migrate(old)
		check(FieldData.pos(old.army) == position * 4, theater + " old army coordinates migrate once")
		check(FieldData.pos(old.army.pendingOrder) == (position + Vector2(20, 0)) * 4, theater + " queued march migrates")
		check(FieldData.pos(old.army.lastSighting) == Vector2(3600, 3200) and FieldData.pos(old.army.redeployAt) == Vector2(2400, 3200), theater + " intelligence and redeployment migrate")
		check(JSON.stringify(old.units) == units, theater + " migration preserves soldiers and progression")
		var once = JSON.stringify(old)
		FieldCampaign.migrate(old)
		check(JSON.stringify(old) == once, theater + " reload cannot double map coordinates again")
		if theater == "mantua":
			check(is_same(old.army, old.armies[0]), "operational migration retains canonical selected army")
			check(FieldData.pos(old.operation.sites[0]) == FieldData.pos(m.state.operation.sites[0]), "operational sites retain geographic placement")
	for scenario in ["bridge", "village", "ridge"]:
		battle_checks(scenario)
	legacy_battle_checks()
	print("GODOT LARGE MAPS: %d checks, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)

func battle_checks(scenario: String) -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	var b: Dictionary = m.state.battle
	b.scenario = scenario
	m.terrain.configure(m.state)
	var terrain = m.terrain
	var original: Dictionary = FieldData.load_data().fields[scenario]
	check(terrain.map_size == Vector2(5760, 3840), scenario + " battlefield covers sixteen original map areas")
	check(FieldData.pos(terrain.field.objective) == FieldData.pos(original.objective) + FieldBattlefield.OFFSET, scenario + " original objective stays in central battlefield")
	check(terrain.field.forests.size() == original.forests.size() + 16 and terrain.field.towns.size() == original.towns.size() + 8, scenario + " flanks have woodland and settlements")
	check(terrain.defenses[0].width == FieldCover.TYPES["farm-wall"].width, scenario + " fortifications keep their original physical scale")
	check(b.visibleCells.size() == 9600, scenario + " fog covers full expanded battlefield at original resolution")
	var u: Dictionary = b.units[0]
	u.x = 2490
	u.y = 1730
	m.select([u.id])
	check(m.move_units(Vector2(2700, 1730)) and FieldData.pos(u.goal) == Vector2(2700, 1730), scenario + " orders reach beyond both old map boundaries")
	var before = FieldData.pos(u)
	m.tactics.walk(m, u, 0.1, 25.0)
	check(u.x > before.x and is_equal_approx(u.y, before.y), scenario + " troop actually moves on outer flank")
	FieldBattleAI.initialize(m)
	check(is_finite(FieldBattleAI.position_score(m, u, Vector2(2700, 1730), Vector2(2700, 1730), [])), scenario + " AI can evaluate outer terrain")
	for edge in ["west", "east"]:
		b.playerEdge = edge
		u.x = 150 if edge == "west" else 5610
		u.y = 1780
		check(m.deploy(Vector2(u.x, u.y)), scenario + " deployment reaches " + edge + " perimeter")
		check(m.retreat_units() == 1 and u.goal.x == (45 if edge == "west" else 5715), scenario + " retreat uses " + edge + " expanded edge")
		u.retreating = false
	if scenario == "bridge":
		for y in terrain.crossings:
			var p = Vector2(terrain.channel_x(y), y)
			check(terrain.on_bridge(p) and terrain.height_at(p) == 6.5, "crossing %.0f aligns deck and walk surface" % y)
			var start = p - Vector2(160, 0)
			var end = p + Vector2(160, 0)
			var path = terrain.route(start, end)
			check(not path.is_empty() and FieldData.pos(path.back()) == end, "crossing %.0f routes to exact endpoint" % y)
			for point in path:
				check(terrain.direct_route(start, FieldData.pos(point)), "crossing route never fords water")
				start = FieldData.pos(point)
		check(not terrain.ground_passable(Vector2(terrain.channel_x(1200), 1200)), "river remains impassable between expanded crossings")
	m.tactics.update_visibility(m)
	var cell = Vector2i(FieldData.pos(u) / 48)
	check(b.visibleCells[cell.y * terrain.fog_size().x + cell.x], scenario + " outer flank fog reveals around troops")

func legacy_battle_checks() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true, 1)
	var b: Dictionary = m.state.battle
	b.erase("mapVersion")
	FieldCampaign.resize_state(m.state, 0.25)
	m.state.campaignMapVersion = 2
	b.bodies = [{"x": 490.0, "y": 310.0, "kind": "infantry", "side": "player", "facing": 0.0, "mounted": false, "time": 1.0}]
	var troops = b.units.map(func(u): return [FieldData.pos(u), u.facing, u.men])
	var bodies = JSON.stringify(b.bodies)
	check(m.save_campaign("user://test-large-legacy-battle.json"), "old in-progress battle saves")
	var restored = FieldModel.new(false)
	check(restored.load_campaign("user://test-large-legacy-battle.json"), "old in-progress battle loads")
	check(restored.terrain.map_size == Vector2(1440, 960), "existing battle retains original dimensions")
	if restored.state.battle == null: return
	var unchanged = true
	for i in troops.size():
		var unit: Dictionary = restored.state.battle.units[i]
		unchanged = unchanged and FieldData.pos(unit).is_equal_approx(troops[i][0]) and is_equal_approx(unit.facing, troops[i][1]) and unit.men == troops[i][2]
	check(unchanged and JSON.stringify(restored.state.battle.bodies) == bodies, "existing battle preserves soldiers and casualty locations within JSON precision")
	check(restored.state.campaignMapVersion == 4 and restored.state.battle.visibleCells.size() == 600, "strategic migration leaves legacy tactical fog unchanged")
	check(FileAccess.file_exists("user://test-large-legacy-battle.json.pre-large-maps.bak"), "original native save backed up before map migration")
