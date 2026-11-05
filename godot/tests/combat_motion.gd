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
	handedness_checks()
	rank_checks()
	contact_checks()
	small_unit_checks()
	animation_checks()
	print("GODOT COMBAT MOTION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func duel(angle: float = PI) -> FieldModel:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.terrain.configure(m.state)
	# These are isolated contact/formation drills; scenery is covered by polish.gd.
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	m.terrain.relief = 0
	m.terrain.buildings.clear()
	m.terrain.defenses.clear()
	m.terrain.grids.clear()
	m.state.battle.aiClock = -10000
	for u in m.state.battle.units: u.arrival = 99999
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	a.merge({"x": 500.0, "y": 360.0, "facing": 0.0, "arrival": 0.0, "reload": 0.0}, true)
	b.merge({"x": 750.0, "y": 360.0, "facing": angle, "arrival": 0.0, "reload": 0.0, "visible": true}, true)
	m.formations.reset(a)
	m.formations.reset(b)
	for wagon in m.state.battle.wagons: wagon.stock = 0
	return m

func animation_checks() -> void:
	var m = duel()
	var u: Dictionary = m.state.battle.units[0]
	var soldiers = m.formations.positions(u)
	for tick in 12:
		var previous: float = soldiers[0].moving
		u.x += 0.8
		m.formations.advance([u], tick / 30.0, 1.0 / 30.0)
		check(soldiers[0].previousMoving == previous and absf(soldiers[0].moving - previous) <= 0.101, "gait weight retains its previous tick and eases into motion")
	for rank in [0, 1, 3]:
		check(FieldFormations.melee_frame(TAU * 0.5, rank) == 0, "melee returns to guard after the thrust")
		check(FieldFormations.melee_frame(TAU * 0.7, rank) == 2, "melee has a separate parry beat")
		check(FieldFormations.melee_frame(TAU * 0.9, rank) == 0, "melee recovers from the parry before restarting")

func step(m: FieldModel, seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		m.tactics.update(m, 0.05)
		if m.state.battle == null: return
		m.formations.advance(m.state.battle.units, m.state.battle.time, 0.05, m.state.battle.bodies)

func handedness_checks() -> void:
	var m = duel()
	for kind in ["infantry", "cavalry"]:
		var u: Dictionary = m.state.battle.units[0].duplicate(true)
		u.kind = kind
		for heading in [0.0, PI * 0.25, PI * 0.5, PI, PI * 1.5, -PI * 0.25]:
			u.facing = heading
			m.formations.reset_roster(u)
			var points = m.formations.positions(u)
			var slots = FieldFormations.offsets(u)
			var front = 0.0
			for slot in slots: front = maxf(front, slot.y)
			var flow = {"looseness": 1.0, "distance": 100.0, "trail": [{"p": FieldData.pos(u), "facing": heading}]}
			var correct = true
			for i in slots.size():
				if absf(slots[i].x) < 5: continue
				var goal = m.formations.movement_goal(u, slots[i], i, flow, front)
				correct = correct and (goal - FieldData.pos(u)).dot(Vector2.from_angle(heading).orthogonal()) * slots[i].x > 0
			check(correct, "%s preserves left/right at heading %.2f" % [kind, heading])
			for tick in 80:
				var delta = Vector2.from_angle(heading) * 24.0 * 0.05
				u.x += delta.x
				u.y += delta.y
				m.formations.advance([u], tick * 0.05, 0.05)
			correct = true
			for i in slots.size():
				if absf(slots[i].x) < 8: continue
				correct = correct and (points[i].p - FieldData.pos(u)).dot(Vector2.from_angle(heading).orthogonal()) * slots[i].x > 0
			check(correct, kind + " does not cross its own files during straight marching")

func rank_checks() -> void:
	var m = duel()
	var u: Dictionary = m.state.battle.units[0]
	var group = m.formations.positions(u)
	var front = m.formations.casualty_order(u, group)[0]
	var location = group[front].p
	u.men -= 9
	m.formations.advance([u], 0.1, 0.1, m.state.battle.bodies)
	for i in 100: m.formations.advance([u], 0.2 + i * 0.05, 0.05, m.state.battle.bodies)
	var replacement = group.filter(func(p): return p.alive and p.slot == front)
	check(replacement.size() == 1 and replacement[0].p.distance_to(location) < 0.1, "rear soldier settles into fallen front soldier's position")
	check(FieldData.pos(m.state.battle.bodies[0]) == location and not group[front].alive, "advancing ranks neither move bodies nor resurrect identities")
	u.men -= 9
	m.formations.advance([u], 6, 0.05, m.state.battle.bodies)
	check(not replacement[0].alive, "successive front casualties use current positions, not original identities")
	var invalid = u.duplicate(true)
	invalid.visualSlots[0] = invalid.visualSlots[1]
	check(not m.valid_regiment(invalid), "duplicate visual assignments are rejected on import")
	var paused = group[1].p
	m.formations.advance([u], 10, 0, m.state.battle.bodies)
	check(group[1].p == paused, "pause freezes rank replacements")

func contact_checks() -> void:
	for angle in [PI, PI * 0.65, PI * 0.5, 0.0]:
		var m = duel(angle)
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		# Isolate contact geometry from the separately tested rear-attack rout rule.
		for u in [a, b]:
			u.perk = "steadfast"
			u.skills.discipline = 100.0
		a.holdFire = true
		b.holdFire = true
		m.select([a.id])
		m.move_units(FieldData.pos(b), b.id)
		for i in 400:
			step(m, 0.05)
			if a.get("meleeTargetId") != null: break
		check(a.get("meleeTargetId") == b.id and b.get("meleeTargetId") == a.id, "both regiments detect angled contact %.2f" % angle)
		check(FieldContact.gap(FieldContact.shape(a), FieldContact.shape(b)) > -0.5, "advance stops at enemy edge without center overlap %.2f" % angle)
		var ammunition = a.ammo + b.ammo
		var strength = a.men + b.men
		var fatigue = a.condition + b.condition
		a.holdFire = false
		b.holdFire = false
		step(m, 5)
		check(a.ammo + b.ammo == ammunition and a.get("shotKind") == "melee" and b.get("shotKind") == "melee", "engaged infantry never shoot, even when fire is enabled %.2f" % angle)
		check(a.men + b.men < strength and a.condition + b.condition < fatigue, "both sides fight and tire regardless of firing arc %.2f" % angle)
		var aa = m.formations.positions(a).filter(func(p): return p.alive)
		var bb = m.formations.positions(b).filter(func(p): return p.alive)
		var adjacent = 0
		var facing = true
		var nearest = INF
		var normal: Vector2 = FieldContact.front(a, b).normal
		for p in aa:
			facing = facing and absf(angle_difference(p.facing, normal.angle())) < 0.3
			var distance = INF
			for q in bb: distance = minf(distance, p.p.distance_to(q.p))
			if distance < 13: adjacent += 1
			nearest = minf(nearest, distance)
		check(adjacent >= 5 and nearest >= 6.5, "opposed front ranks meet without interpenetration %.2f" % angle)
		check(facing, "individual infantry turn toward their melee opponent %.2f" % angle)
		m.select([a.id])
		m.fall_back()
		step(m, 4)
		check(a.get("meleeTargetId") == null and b.get("meleeTargetId") == null, "withdrawal releases melee contact %.2f" % angle)
	check(FieldFormations.melee_frame(0) != FieldFormations.melee_frame(TAU * 0.3), "melee cycles painted guard and strike frames")
	check(FieldFormations.melee_frame(TAU * 0.3, 3) != 1, "rear ranks guard and parry instead of thrusting through comrades")
	var m = duel()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	b.x = a.x + 35
	m.tactics.update_contacts(m)
	m.select([a.id])
	m.move_units(FieldData.pos(a) - Vector2(100, 0))
	step(m, 0.3)
	check(absf(a.facing) > 0.001, "ordinary move-away order can turn out of melee instead of locking movement")

func small_unit_checks() -> void:
	for kind in ["infantry", "cavalry"]:
		var m = duel()
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		for u in [a, b]:
			u.kind = kind
			u.weapon = "sabre" if kind == "cavalry" else "musket"
			u.men = 36
			u.startMen = 36
			u.holdFire = kind == "infantry"
			m.formations.reset_roster(u)
			m.formations.positions(u)
		b.x = a.x + 38
		step(m, 0.05)
		check(a.get("shotKind", "") != "musket" and b.get("shotKind", "") != "musket", kind + " does not fire across a physical melee gap")
		m.select([a.id])
		m.move_units(FieldData.pos(b), b.id)
		for i in 200:
			step(m, 0.05)
			if a.get("meleeTargetId") != null: break
		check(a.get("meleeTargetId") == b.id, "small " + kind + " reaches actual contact instead of old center-distance stop")
	var m = duel()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	b.kind = "artillery"
	b.weapon = "cannon"
	b.men = 120
	b.startMen = 120
	b.x = a.x + 20
	m.formations.reset_roster(b)
	step(m, 0.1)
	check(b.get("shotKind") == "melee" and b.ammo == 100 and m.state.battle.artilleryImpacts.is_empty(), "contacted gun crew fights without firing cannon or spending ammunition")
	m = duel()
	a = m.state.battle.units[0]
	b = m.state.battle.units[5]
	for u in [a, b]:
		u.kind = "cavalry"
		u.weapon = "sabre"
		u.men = 270
		u.startMen = 270
		m.formations.reset_roster(u)
		m.formations.positions(u)
	b.x = a.x + 35
	m.formations.reset(b)
	step(m, 5)
	var left = m.formations.positions(a).filter(func(p): return p.alive)
	var right = m.formations.positions(b).filter(func(p): return p.alive)
	var adjacent = 0
	for p in left:
		if right.any(func(q): return p.p.distance_to(q.p) < 18): adjacent += 1
	check(adjacent >= 5, "cavalry closes fallen front-rank gaps during sustained melee")
