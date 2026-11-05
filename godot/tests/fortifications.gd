extends SceneTree

var count = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	count += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func run() -> void:
	var model = FieldModel.new(false)
	model.start_battle("e1", true)
	for unit in model.state.battle.units: unit.arrival = 99999
	var u: Dictionary = model.state.battle.units[0]
	u.arrival = 0
	u.holdFire = true
	u.men = 540
	model.select([u.id])
	for scenario in ["bridge", "village", "ridge"]:
		model.state.battle.scenario = scenario
		model.terrain.configure(model.state)
		check(model.terrain.defenses.size() == 3, scenario + " has three distinct defenses")
		for cover in model.terrain.defenses:
			var shape = FieldCover.outline(cover)
			check(shape.size() >= 4 and shape[0].y < shape[1].y, cover.id + " has side returns and an open rear")
			for figures in [4, 30, 80, 100]:
				var specimen = u.duplicate(true)
				specimen.coverId = cover.id
				specimen.coverWidth = cover.width
				specimen.visualCount = figures
				var layout = FieldCover.garrison(specimen, figures)
				var points: Array = layout.offsets
				var columns: int = layout.columns
				check(points.size() == figures and columns <= ceili(figures / 2.0), cover.id + " preserves figure count in multiple ranks")
				var minimum = INF
				for i in points.size():
					for j in range(i + 1, points.size()): minimum = minf(minimum, points[i].distance_to(points[j]))
				check(minimum >= 3.1, cover.id + " garrison slots do not overlap: " + str(figures))
				check(points.all(func(p): return model.terrain.passable(FieldCover.entry(cover) + p.rotated(cover.facing - PI / 2), true, 1)), scenario + " " + cover.id + " all garrison slots are traversable")
			FieldCover.leave(u)
			model.stop_unit(u)
			var entry = FieldCover.entry(cover)
			u.x = entry.x
			u.y = entry.y
			u.facing = cover.facing
			model.formations.reset_roster(u)
			model.formations.reset(u)
			check(model.occupy_cover(cover.id) == 1, cover.id + " accepts occupation")
			for i in 800:
				model.state.battle.time += 0.05
				model.tactics.walk(model, u, 0.05, 24)
				FieldCover.update(model, u, 0.05)
				model.formations.advance([u], model.state.battle.time, 0.05, model.state.battle.bodies, model.terrain)
				if u.coverDeploy >= 4: break
			check(u.coverDeploy == 4, scenario + " " + cover.id + " fully mans its shaped positions")
			for i in 60: model.formations.advance([u], model.state.battle.time + i * 0.05, 0.05)
			var layout = FieldCover.garrison(u, FieldFormations.offsets(u).size())
			check(model.formations.positions(u).all(func(soldier): return absf(angle_difference(soldier.facing, u.facing + layout.headings[soldier.slot])) < 0.05), cover.id + " garrison faces outward on each occupied wall")
			check(FieldCover.protection(model, u, FieldData.point(entry + Vector2.from_angle(u.facing) * 100), false) == cover.protection, cover.id + " front protection retained")
			check(FieldCover.protection(model, u, FieldData.point(entry - Vector2.from_angle(u.facing) * 100), false) == 0, cover.id + " open rear stays vulnerable")
			check(FieldCover.protection(model, u, FieldData.point(entry + Vector2.from_angle(u.facing + PI / 2) * 100), false) > 0, cover.id + " returning flanks give partial protection")
			check(model.save_campaign("user://test-fortifications.json"), cover.id + " garrison saves")
			var restored = FieldModel.new(false)
			check(restored.load_campaign("user://test-fortifications.json"), cover.id + " saved garrison validates and reloads")
			var loaded = restored.find_id(restored.state.battle.units, u.id)
			check(FieldFormations.offsets(loaded) == FieldFormations.offsets(u), cover.id + " shaped layout survives reload")
			var points = model.formations.positions(u)
			var body_position = points[0].p
			var bodies = model.state.battle.bodies.size()
			u.men -= 9
			model.formations.advance([u], model.state.battle.time, 0.05, model.state.battle.bodies)
			check(model.state.battle.bodies.size() == bodies + 1 and FieldData.pos(model.state.battle.bodies.back()).is_equal_approx(body_position), cover.id + " casualty stays at its defensive slot")
			var rear = points.filter(func(soldier): return soldier.alive and soldier.slot == 0)
			check(rear.size() == 1 and rear[0] != points[0], cover.id + " next rank fills casualty within its own defensive file")
			check(model.move_units(entry - Vector2.from_angle(u.facing) * 70) and u.coverId == null, cover.id + " move order leaves shaped cover")
	print("GODOT FORTIFICATION MODEL: %d checks, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
