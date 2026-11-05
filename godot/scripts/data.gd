class_name FieldData
extends RefCounted

static var source: Dictionary = {}

static func load_data() -> Dictionary:
	if source.is_empty():
		source = JSON.parse_string(FileAccess.get_file_as_string("res://data/browser.json"))
		source.weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/arsenal.json"))
	return source

static func fresh(theater: String = "italy") -> Dictionary:
	if theater == "mantua":
		var operational = fresh("italy")
		FieldOperations.initialize(operational)
		return operational
	var s: Dictionary = load_data().state.duplicate(true)
	s["theater"] = theater
	s["portVersion"] = 1
	s.speed = 0.5
	if theater == "italy":
		s.army.name = "Army of Italy"
		s.units[3].corpsId = "c2"
		s.enemies[0].x = 700.0
		s.enemies[0].y = river_y(700.0) + 65.0
		s.enemies[0].home = {"x": s.enemies[0].x, "y": s.enemies[0].y}
		s.log = [{"text": "Army of Italy assembled at the forward depot.", "hours": 6.0}, {"text": "Austrian advance guard reported near the crossing.", "hours": 6.0}]
		for e in s.enemies:
			e.intel.x = e.x
			e.intel.y = e.y
	FieldCampaign.migrate(s)
	FieldCampaign.march_defaults(s)
	for key in weapons(): s.market[key] = weapons()[key].stock
	FieldArsenal.initialize(s)
	return s

static func weapons() -> Dictionary:
	return load_data().weapons

static func pos(entity: Dictionary) -> Vector2:
	return Vector2(entity.get("x", 0.0), entity.get("y", 0.0))

static func point(p: Vector2) -> Dictionary:
	return {"x": p.x, "y": p.y}

static func distance(a: Dictionary, b: Dictionary) -> float:
	return pos(a).distance_to(pos(b))

static func men(units: Array) -> int:
	var amount = 0.0
	for u in units:
		amount += maxf(0.0, u.men)
	return roundi(amount)

static func weapon_count(u: Dictionary, amount: float = -1.0) -> int:
	if amount < 0:
		amount = u.men
	return ceili(amount / 30.0) if u.kind == "artillery" else ceili(amount)

static func river_y(x: float) -> float:
	return 455.0 + sin(x / 175.0) * 46.0 + x * 0.045

static func channel_x(y: float) -> float:
	return 720.0 + sin((y - 480.0) / 190.0) * 35.0

static func ellipse(p: Vector2, e: Dictionary) -> float:
	var dx: float = (p.x - e.x) / e.rx
	var dy: float = (p.y - e.y) / e.ry
	return dx * dx + dy * dy

static func rank_of(officer: Dictionary) -> int:
	if officer.is_empty():
		return -1
	var rank = 0
	for xp in load_data().rankXp:
		if officer.xp >= xp:
			rank += 1
	return rank - 1

static func ready(officer: Dictionary, hours: float) -> bool:
	return not officer.is_empty() and officer.hired and not officer.dead and officer.woundedUntil <= hours

static func base_skills(kind: String) -> Dictionary:
	return {"firearms": 44.0 if kind == "artillery" else 32.0, "melee": 48.0 if kind == "cavalry" else 30.0, "stamina": 42.0, "discipline": 38.0}

static func officer(id: String, name: String, portrait: int, xp: float = 60.0, hired: bool = true) -> Dictionary:
	return {"id": id, "name": name, "portrait": portrait, "xp": xp, "hired": hired, "specialty": "Drill" if portrait % 2 else "Resolve", "woundedUntil": 0.0, "wounds": 0, "dead": false, "cost": 1400 if xp >= 120 else 900 if xp >= 60 else 500}

static func regiment_defaults(u: Dictionary) -> void:
	var defaults = {"skills": base_skills(u.kind), "perk": null, "history": [], "condition": 100.0, "ammo": 100.0, "trainedUntil": 0.0, "experience": 0.0, "officerId": null, "corpsId": null, "target": null, "goal": null, "waypoints": [], "orderQueue": [], "attackId": null, "fireTargetId": null, "aimOrderId": null, "aimComplete": false, "desiredFacing": null, "turnVelocity": 0.0, "running": false, "fallingBack": false, "limbered": false, "limberChange": 0.0, "dismounted": false, "formation": "line", "formationChange": null, "queuedFormation": null, "holdFire": false, "charging": false, "routed": false, "arrival": 0.0, "reload": 0.0, "flash": 0.0, "kills": 0.0, "facing": 0.0, "morale": 100.0, "blocked": "", "fightingUntil": 0.0, "meleeUntil": 0.0, "restAfter": 0.0, "visible": u.get("side", "player") == "player"}
	defaults.merge({"retreating": false, "withdrawn": false, "chargeDistance": 0.0, "chargeReadyAt": 0.0, "chargeExpires": 0.0, "chargeImpactUntil": 0.0, "chargeTargetId": null})
	defaults.merge({"coverId": null, "coverOrderId": null, "coverWidth": 0.0, "coverDeploy": 0.0, "movementBlocked": ""})
	for key in defaults:
		if not u.has(key):
			u[key] = defaults[key]
