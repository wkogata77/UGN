class_name FieldCharge
extends RefCounted

static func mounted(u: Dictionary) -> bool:
	return u.kind == "cavalry" and not u.dismounted

static func pace_multiplier(u: Dictionary) -> float:
	return 1.8 if mounted(u) else 1.65

static func exertion(u: Dictionary) -> float:
	return 1.2 if mounted(u) else 2.2

static func eligible(u: Dictionary, time: float) -> bool:
	return u.kind in ["infantry", "cavalry"] and not u.routed and not u.get("withdrawn", false) and not u.get("retreating", false) and not u.charging and u.get("meleeTargetId") == null and u.formationChange == null and u.formation != "square" and u.condition >= 25 and time >= u.get("chargeReadyAt", 0.0)

static func cancel(u: Dictionary) -> void:
	u.charging = false
	u["chargeDistance"] = 0.0
	u["chargeTargetId"] = null

static func start(u: Dictionary, target: Dictionary, time: float) -> bool:
	if not eligible(u, time) or target.is_empty(): return false
	u.charging = true
	u["chargeDistance"] = 0.0
	u["chargeTargetId"] = target.id
	u["chargeExpires"] = time + 18.0
	u["chargeReadyAt"] = time + 12.0
	return true

static func momentum(u: Dictionary) -> float:
	return clampf((u.get("chargeDistance", 0.0) - 12.0) / (65.0 if mounted(u) else 42.0), 0, 1)

static func advance(u: Dictionary, before: Dictionary, target: Dictionary, time: float, dt: float) -> void:
	if not u.charging:
		u["chargeDistance"] = 0.0
		return
	if u.kind == "artillery" or u.routed or u.condition < 12 or u.formationChange != null or target.is_empty() or target.id != u.get("chargeTargetId") or time > u.get("chargeExpires", 0.0):
		cancel(u)
		return
	var delta = FieldData.pos(u) - before.p
	var bearing = (FieldData.pos(target) - before.p).normalized()
	if delta.length() > dt * 10.0 and Vector2.from_angle(u.facing).dot(bearing) > 0.85:
		u.chargeDistance = minf(100, u.chargeDistance + maxf(0, delta.dot(bearing)))
	else:
		u.chargeDistance = maxf(0, u.chargeDistance - dt * 14.0)

static func impact(u: Dictionary, target: Dictionary, time: float) -> float:
	if not u.charging: return 1.0
	var strength = momentum(u) if target.id == u.get("chargeTargetId") else 0.0
	var bonus = 1.0 + strength * (1.5 if mounted(u) else 0.65)
	cancel(u)
	u["chargeReadyAt"] = maxf(u.get("chargeReadyAt", 0.0), time + 12.0)
	if strength > 0:
		u["chargeImpactUntil"] = time + 2.0
	return bonus
