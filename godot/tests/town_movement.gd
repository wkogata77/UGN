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

func run() -> void:
	for scenario in ([] if "--group" in OS.get_cmdline_user_args() else ["bridge"] if "--flank" in OS.get_cmdline_user_args() else ["ridge"] if "--ridge" in OS.get_cmdline_user_args() else ["bridge", "village", "ridge"]):
		var m = FieldModel.new(false)
		m.start_battle("e1", true)
		m.state.battle.scenario = scenario
		m.terrain.configure(m.state)
		m.prepare_deployment()
		var u: Dictionary = m.state.battle.units[0]
		for town in m.terrain.towns:
			if "--flank" in OS.get_cmdline_user_args() and FieldData.pos(town) != Vector2(570, 1200): continue
			m.stop_unit(u)
			var destination = FieldData.pos(town)
			# Exercise entry through each town's actual streets. Crossing the
			# entire larger map is covered by route/bridge tests, not this drill.
			for offset in [Vector2(-240, -70), Vector2(240, 70), Vector2(0, -250)]:
				var staging = m.terrain.open_point(destination + offset, 2)
				if staging == null: continue
				u.x = staging.x
				u.y = staging.y
				break
			u.facing = (destination - FieldData.pos(u)).angle()
			m.formations.reset(u)
			for other in m.state.battle.units:
				if other.side == "enemy": other.arrival = 99999
			var accepted = m.path_unit(u, destination)
			check(accepted, scenario + " regiment accepts town street order: " + str(destination))
			if not accepted: continue
			var goal = FieldData.pos(u.goal)
			check(goal.distance_to(destination) <= 24, scenario + " town order stays at click or nearest building edge")
			var clear = true
			var max_step = 0.0
			var max_figure_step = 0.0
			for i in 4000:
				m.state.battle.time += 0.05
				var previous = FieldData.pos(u)
				m.tactics.walk(m, u, 0.05, 24)
				max_step = maxf(max_step, previous.distance_to(FieldData.pos(u)))
				m.formations.advance([u], m.state.battle.time, 0.05, [], m.terrain)
				for soldier in m.formations.positions(u):
					max_figure_step = maxf(max_figure_step, soldier.previous.distance_to(soldier.p))
					if m.terrain.buildings.any(func(b): return b.rect.has_point(soldier.p)): clear = false
				if u.target == null:
					for settle in 60:
						m.state.battle.time += 0.05
						m.formations.advance([u], m.state.battle.time, 0.05, [], m.terrain)
					break
			if u.target != null:
				print("STUCK ", u.target, " ", u.waypoints, " facing ", u.facing, " blocked ", u.movementBlocked, " turning ", u.turnVelocity)
				for building in m.terrain.buildings:
					if building.rect.grow(8).has_point(FieldData.pos(u)): print("NEAR HOUSE ", building.rect)
				var trial = u.duplicate()
				var direction = (FieldData.pos(u.target) - FieldData.pos(u)).normalized()
				trial.x += direction.x * 0.5
				trial.y += direction.y * 0.5
				for other in m.tactics.active(m.state.battle, u.side): print("FRIEND ", other.id, " ", FieldData.pos(other), " angle ", other.facing, " gap ", FieldContact.gap(FieldContact.shape(u), FieldContact.shape(other)), " next ", FieldContact.gap(FieldContact.shape(trial), FieldContact.shape(other)))
			check(u.target == null and FieldData.pos(u).distance_to(goal) < 0.1, scenario + " actual town march completes with friendly formations present")
			check(clear, scenario + " individual soldiers go around houses")
			check(m.formations.positions(u).all(func(soldier): return not m.terrain.buildings.any(func(b): return b.rect.has_point(soldier.p))), scenario + " settled soldiers remain outside houses")
			check(max_step <= 24 * 1.08 * 0.05 + 0.01, scenario + " formation movement stays speed capped")
			check(max_figure_step <= 24 * 1.08 * 0.05 + 0.01, scenario + " individual movement stays speed capped")
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.terrain.configure(m.state)
	# Isolate cache invalidation from the outer district's actual hills/woods.
	m.terrain.relief = 0
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.forests = []
	m.terrain.buildings = [{"p": Vector2(500, 400), "rect": Rect2(480, 375, 40, 50), "height": 40.0}]
	var destination = Vector2(650, 402)
	var route = m.terrain.route(Vector2(350, 400), destination, 30)
	check(not route.is_empty(), "house detour is reachable")
	var previous = Vector2(350, 400)
	for p in route:
		check(not m.terrain.direct_route(previous, destination, 30) or FieldData.pos(p) == destination, "detour goes directly to exact destination once visible")
		previous = FieldData.pos(p)
	check(m.terrain.route(Vector2(350, 250), Vector2(651, 253), 2) == [FieldData.point(Vector2(651, 253))], "unobstructed movement has one exact non-grid destination")
	group_checks()
	geometry_checks()
	print("GODOT TOWN MOVEMENT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func group_checks() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "ridge"
	m.terrain.configure(m.state)
	for u in m.state.battle.units: u.arrival = 99999
	var units = m.state.battle.units.slice(0, 2)
	for i in units.size():
		units[i].merge({"x": 200.0, "y": 200.0 + i * 150, "facing": 0.0, "arrival": 0.0}, true)
	m.select(units.map(func(u): return u.id))
	check(m.move_units(Vector2(350, 275)), "simple group move is accepted")
	check(FieldData.pos(units[1].goal) - FieldData.pos(units[0].goal) == Vector2(0, 150), "simple group move preserves spacing instead of overlapping frontages")
	var straight = true
	for i in 500:
		m.state.battle.time += 0.05
		for j in units.size():
			m.tactics.walk(m, units[j], 0.05, 24)
			straight = straight and absf(units[j].y - (200 + j * 150)) < 0.01
	check(straight, "open-ground group move stays straight")
	for u in units:
		check(u.target == null and FieldData.pos(u).distance_to(FieldData.pos(u.goal)) < 0.01, "group member arrives at exact translated destination: " + u.id)
	units[0].merge({"x": 350.0, "y": 400.0, "target": {"x": 500, "y": 400}, "goal": {"x": 350, "y": 250}, "waypoints": [{"x": 350, "y": 250}], "passageRetryAt": -1.0}, true)
	units[1].merge({"x": 500.0, "y": 400.0, "target": null}, true)
	check(FieldPassage.detour(m, units[0], units[1]), "occupied intermediate waypoint can be skipped to a clear final leg")
	check(FieldData.pos(units[0].target).is_equal_approx(FieldData.pos(units[0].goal)) and units[0].waypoints.is_empty(), "skipping an occupied waypoint preserves the exact final destination")

func geometry_checks() -> void:
	var occupied = Rect2(100, 100, 100, 100)
	check(not FieldPassage.clear_segment(Vector2(190, 110), Vector2(90, 110), [occupied]), "clearance overlap cannot cross a regiment tangentially")
	check(FieldPassage.clear_segment(Vector2(190, 110), Vector2(190, 90), [occupied]), "clearance overlap can escape toward the near upper edge")
	check(FieldPassage.clear_segment(Vector2(190, 110), Vector2(210, 110), [occupied]), "clearance overlap can escape toward the near right edge")
	check(not FieldPassage.clear_segment(Vector2(190, 110), Vector2(190, 210), [occupied]), "clearance escape cannot cross through the far side")
	var rect = Rect2(10, 20, 30, 40)
	for sample in [[Vector2(0, 30), Vector2(50, 30), Vector2(10, 30)], [Vector2(50, 30), Vector2(0, 30), Vector2(40, 30)], [Vector2(25, 0), Vector2(25, 80), Vector2(25, 20)], [Vector2(25, 80), Vector2(25, 0), Vector2(25, 60)], [Vector2(25, 30), Vector2(25, 30), Vector2(25, 30)], [Vector2(0, 10), Vector2(10, 20), Vector2(10, 20)]]:
		var hit = FieldLandscape.segment_hit(sample[0], sample[1], rect)
		check(hit != null and hit.is_equal_approx(sample[2]), "rectangle trace returns nearest contact: " + str(sample[0]))
	check(FieldLandscape.segment_hit(Vector2(0, 0), Vector2(0, 90), rect) == null, "parallel ray outside building misses")
	check(FieldLandscape.segment_hit(Vector2(0, 25), Vector2(15, 0), rect) == null, "diagonal ray can miss despite overlapping segment bounds")
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.terrain.configure(m.state)
	m.terrain.buildings = [{"p": Vector2(500, 400), "rect": Rect2(480, 375, 40, 50), "height": 40.0}]
	# Keep this a house-obstruction drill, independent of the real hill beyond it.
	m.terrain.relief = 0
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.forests = []
	var a = {"x": 350.0, "y": 400.0, "kind": "infantry"}
	var b = {"x": 650.0, "y": 400.0, "kind": "infantry"}
	check(not m.terrain.line_of_sight(a, b, true), "sight retains house obstruction")
	b.x = 350.0
	b.y = 401.0
	check(m.terrain.line_of_sight(a, b, true), "sight follows a moved target")
	m.terrain.buildings.clear()
	b.x = 650.0
	b.y = 400.0
	check(m.terrain.line_of_sight(a, b, true), "sight follows changed building layout")
