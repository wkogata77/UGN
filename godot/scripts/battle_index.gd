class_name FieldBattleIndex
extends RefCounted

# Runtime-only broad phase. Large formations occupy every cell their bounds
# touch, so a nearby query cannot miss a flank just across a cell boundary.
const CELL = 160.0
var enabled = false
var units: Dictionary = {}
var shapes: Dictionary = {}
var cells: Dictionary = {}
var occupied: Dictionary = {}
var players: Array = []
var enemies: Array = []

func rebuild(battle: Dictionary) -> void:
	units.clear()
	shapes.clear()
	cells.clear()
	occupied.clear()
	players.clear()
	enemies.clear()
	for u in battle.units:
		units[u.id] = u
		if u.arrival > battle.time or u.men <= 0 or u.routed or u.withdrawn: continue
		if u.side == "player": players.append(u)
		else: enemies.append(u)
		update_unit(u)

func update_unit(u: Dictionary) -> void:
	var shape = FieldContact.shape(u)
	shapes[u.id] = shape
	var extent = Vector2(FieldContact.extent(shape, Vector2.RIGHT), FieldContact.extent(shape, Vector2.DOWN))
	var first = Vector2i(((shape.p - extent) / CELL).floor())
	var last = Vector2i(((shape.p + extent) / CELL).floor())
	var region = Rect2i(first, last - first + Vector2i.ONE)
	if occupied.get(u.id) == region: return
	if occupied.has(u.id):
		var old: Rect2i = occupied[u.id]
		for y in range(old.position.y, old.end.y):
			for x in range(old.position.x, old.end.x): cells[Vector2i(x, y)].erase(u.id)
	occupied[u.id] = region
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell = Vector2i(x, y)
			if not cells.has(cell): cells[cell] = []
			cells[cell].append(u.id)

func nearby(p: Vector2, radius: float, side: String) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var first = Vector2i(((p - Vector2.ONE * radius) / CELL).floor())
	var last = Vector2i(((p + Vector2.ONE * radius) / CELL).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for id in cells.get(Vector2i(x, y), []):
				if seen.has(id): continue
				seen[id] = true
				var u: Dictionary = units[id]
				if u.side == side: result.append(u)
	return result
