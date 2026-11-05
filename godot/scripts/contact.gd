class_name FieldContact
extends RefCounted

const REACH = 5.0

static func shape(u: Dictionary) -> Dictionary:
	var bounds = FieldFormations.bounds(u)
	return {"p": FieldFormations.world_point(u, bounds.get_center()), "right": Vector2.from_angle(u.facing - PI / 2.0), "forward": Vector2.from_angle(u.facing), "half": bounds.size * 0.5, "radius": bounds.size.length() * 0.5}

static func near(a: Dictionary, b: Dictionary, padding: float = 0) -> bool:
	var radius: float = a.radius + b.radius + padding
	return a.p.distance_squared_to(b.p) <= radius * radius

static func extent(shape: Dictionary, axis: Vector2) -> float:
	return absf(shape.right.dot(axis)) * shape.half.x + absf(shape.forward.dot(axis)) * shape.half.y

static func gap(a: Dictionary, b: Dictionary) -> float:
	var distance = -INF
	# Separating axes keep flank and oblique contact independent of regiment centers.
	for axis in [a.right, a.forward, b.right, b.forward]:
		distance = maxf(distance, absf((b.p - a.p).dot(axis)) - extent(a, axis) - extent(b, axis))
	return distance

static func touching(a: Dictionary, b: Dictionary) -> bool:
	return gap(shape(a), shape(b)) <= REACH

static func sweep_hit(a: Dictionary, step: Vector2, b: Dictionary, padding: float) -> bool:
	# Continuous separating axes for a translated oriented rectangle. This
	# replaces scores of sampled trial formations on a straight approach.
	var enter = 0.0
	var leave = 1.0
	var offset: Vector2 = a.p - b.p
	for axis in [a.right, a.forward, b.right, b.forward]:
		var distance: float = offset.dot(axis)
		var velocity: float = step.dot(axis)
		var radius = extent(a, axis) + extent(b, axis) + padding
		if absf(velocity) < 0.000001:
			if absf(distance) >= radius: return false
			continue
		var t0 = (-radius - distance) / velocity
		var t1 = (radius - distance) / velocity
		enter = maxf(enter, minf(t0, t1))
		leave = minf(leave, maxf(t0, t1))
		if enter >= leave: return false
	return leave > 0 and enter < 1

static func front(u: Dictionary, enemy: Dictionary) -> Dictionary:
	var a = shape(u)
	var b = shape(enemy)
	var delta: Vector2 = b.p - a.p
	var normal = delta.normalized() if delta.length_squared() > 0.001 else Vector2.RIGHT if str(u.id) < str(enemy.id) else Vector2.LEFT
	var tangent = normal.orthogonal()
	var point: Vector2 = (a.p + normal * extent(a, normal) + b.p - normal * extent(b, normal)) * 0.5
	var low = maxf(a.p.dot(tangent) - extent(a, tangent), b.p.dot(tangent) - extent(b, tangent))
	var high = minf(a.p.dot(tangent) + extent(a, tangent), b.p.dot(tangent) + extent(b, tangent))
	point += tangent * ((low + high) * 0.5 - point.dot(tangent))
	return {"normal": normal, "tangent": tangent, "p": point, "width": maxf(10, high - low - 8)}
