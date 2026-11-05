class_name FieldArsenal
extends RefCounted

const VERSION = 1

static func initialize(s: Dictionary) -> void:
	var legacy = s.get("arsenalVersion", 0) < VERSION
	if not s.has("damagedWeapons"): s["damagedWeapons"] = {}
	for key in FieldData.weapons():
		if not s.inventory.has(key): s.inventory[key] = 0
		if not s.market.has(key): s.market[key] = FieldData.weapons()[key].stock
		if not s.damagedWeapons.has(key): s.damagedWeapons[key] = 0
	if legacy:
		# Keep every owned legacy item; only untouched enemy issue is nationalized.
		for u in s.get("enemyUnits", []): migrate_enemy(u)
		if s.get("battle") is Dictionary:
			for u in s.battle.units:
				if u.side == "enemy": migrate_enemy(u)
		s["arsenalVersion"] = VERSION

static func migrate_enemy(u: Dictionary) -> void:
	if u.weapon == "musket": u.weapon = "austrian_1784"
	elif u.weapon == "improved": u.weapon = "austrian_selected"
	elif u.weapon == "rifle": u.weapon = "jager_rifle"
	elif u.weapon == "cannon": u.weapon = "austrian_6pdr"
	elif u.weapon == "carbine": u.weapon = "austrian_carbine"
	elif u.weapon == "howitzer": u.weapon = "austrian_howitzer"

static func enemy_issue(index: int, army: int) -> String:
	if index == 0: return "austrian_selected" if army == 1 else "austrian_1784"
	if index == 1: return "austrian_1784"
	if index == 2: return "austrian_reserve"
	if index == 3: return "austrian_carbine"
	return ["austrian_6pdr", "austrian_12pdr", "austrian_3pdr"][army % 3]

static func melee_power(u: Dictionary) -> float:
	return 0.65 if u.kind == "artillery" else 1.1 if u.kind == "cavalry" else 1.0

static func ammunition(u: Dictionary, distance: float) -> String:
	if u.kind != "artillery": return "ball"
	return "canister" if distance < 120 else "shell" if FieldData.weapons()[u.weapon].get("shell", false) else "roundshot"

static func fire_factor(u: Dictionary, distance: float) -> float:
	var w: Dictionary = FieldData.weapons()[u.weapon]
	var fraction = clampf(distance / w.range, 0, 1)
	var accuracy = w.accuracy * (1.0 - w.falloff * fraction * fraction)
	if u.kind == "cavalry" and not u.dismounted: accuracy *= 0.7
	return accuracy

static func salvage(s: Dictionary, captured: Dictionary) -> Dictionary:
	var damaged: Dictionary = {}
	for key in captured:
		var broken = floori(captured[key] * 0.25)
		s.inventory[key] += captured[key] - broken
		s.damagedWeapons[key] += broken
		if broken > 0: damaged[key] = broken
	return damaged

static func capture_count(kind: String, losses: float) -> int:
	return ceili(floorf(maxf(0, losses) / 30.0) * 0.4) if kind == "artillery" else floori(maxf(0, losses) * 0.18)

static func summary(w: Dictionary) -> String:
	return "Range %d / Reload %.1fs / Accuracy %d" % [w.range, w.reload, roundi(w.accuracy * 100)]

static func loadout(u: Dictionary) -> String:
	return "Crew sidearms" if u.kind == "artillery" else "Cavalry sabre retained" if u.kind == "cavalry" else "Infantry close-combat equipment"
