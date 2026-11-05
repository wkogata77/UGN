class_name FieldBattlefield
extends RefCounted

const VERSION = 3
const LEGACY_SIZE = Vector2(1440, 960)
const STANDARD_SIZE = Vector2(2880, 1920)
const STANDARD_OFFSET = Vector2(720, 480)
const SIZE = Vector2(5760, 3840)
const OFFSET = Vector2(2160, 1440)
static var layouts: Dictionary = {}

static func size_for(battle: Dictionary) -> Vector2:
	return SIZE if battle.get("mapVersion", 1) >= 3 else STANDARD_SIZE if battle.get("mapVersion", 1) == 2 else LEGACY_SIZE

static func offset_for(battle: Dictionary) -> Vector2:
	return OFFSET if battle.get("mapVersion", 1) >= 3 else STANDARD_OFFSET if battle.get("mapVersion", 1) == 2 else Vector2.ZERO

static func crossings_for(battle: Dictionary) -> Array:
	return [420.0, 1260.0, 1920.0, 2590.0, 3420.0] if battle.get("mapVersion", 1) >= 3 else [300.0, 960.0, 1630.0] if battle.get("mapVersion", 1) == 2 else [480.0]

static func prepare(battle: Dictionary, version: int = VERSION) -> void:
	if battle.get("mapVersion", 1) >= version: return
	var previous_offset = offset_for(battle)
	battle["mapVersion"] = version
	var shift = offset_for(battle) - previous_offset
	for entity in battle.units + battle.commanders + battle.wagons:
		entity.x += shift.x
		entity.y += shift.y
	# Reinforcements enter at the real perimeter, not the old central map edge.
	for entry in battle.get("campaignForces", []):
		if entry.arrival <= 0: continue
		for entity in battle.units + battle.commanders:
			if entity.get("armyId") != entry.armyId: continue
			match entry.edge:
				"west": entity.x = 90.0
				"east": entity.x = size_for(battle).x - 90
				"north": entity.y = 90.0
				"south": entity.y = size_for(battle).y - 90

static func layout(battle: Dictionary) -> Dictionary:
	if battle.get("battlePolish", false): return FieldBattleExercises.layout(int(battle.get("mapVersion", VERSION)))
	var scenario: String = battle.scenario
	if battle.get("mapVersion", 1) < 2: return FieldData.load_data().fields[scenario]
	var key = scenario + ":" + str(battle.get("mapVersion", 1))
	if layouts.has(key): return layouts[key]
	var offset = offset_for(battle)
	var shift = offset - STANDARD_OFFSET
	var size_value = size_for(battle)
	var field: Dictionary = FieldData.load_data().fields[scenario].duplicate(true)
	for point in [field.objective] + field.forests + field.hills + field.towns:
		point.x += offset.x
		point.y += offset.y
	for road in field.roads:
		for point in road:
			point.x += offset.x
			point.y += offset.y
	for forest in [Vector4(340, 300, 210, 150), Vector4(600, 1490, 230, 170), Vector4(1170, 230, 170, 120), Vector4(2090, 1660, 230, 140), Vector4(2520, 380, 200, 190), Vector4(2650, 1470, 160, 190)]:
		field.forests.append({"x": forest.x + shift.x, "y": forest.y + shift.y, "rx": forest.z, "ry": forest.w})
	for hill in [Vector4(650, 290, 260, 210), Vector4(2450, 1320, 240, 250), Vector4(1070, 1650, 260, 170)]:
		field.hills.append({"x": hill.x + shift.x, "y": hill.y + shift.y, "rx": hill.z, "ry": hill.w})
	for town in [Vector2(570, 1200), Vector2(2290, 590)]:
		field.towns.append(FieldData.point(town + shift))
	for x in [620.0, 2260.0]:
		field.roads.append([{"x": x + shift.x, "y": 0.0}, {"x": x - 80 + shift.x, "y": 650.0 + shift.y}, {"x": x + 30 + shift.x, "y": 1250.0 + shift.y}, {"x": x + shift.x, "y": size_value.y}])
	for y in [300.0, 1630.0]:
		var crossing = FieldData.channel_x(y - STANDARD_OFFSET.y) + offset.x
		field.roads.append([{"x": 0.0, "y": y + shift.y + 60}, {"x": 620.0 + shift.x, "y": y + shift.y}, {"x": crossing - 110, "y": y + shift.y}, {"x": crossing + 110, "y": y + shift.y}, {"x": 2260.0 + shift.x, "y": y + shift.y}, {"x": size_value.x, "y": y + shift.y - 60}])
	if battle.get("mapVersion", 1) >= 3:
		grand_flanks(field, scenario)
	layouts[key] = field
	return field

static func grand_flanks(field: Dictionary, scenario: String) -> void:
	# Whole districts surround the original action: approach valleys, wooded
	# ridges, linked farm villages and crossings well beyond artillery range.
	field.hills.append_array([
		{"x": 2380.0, "y": 1610.0, "rx": 440.0, "ry": 590.0, "height": 96.0},
		{"x": 3490.0, "y": 2220.0, "rx": 430.0, "ry": 610.0, "height": 116.0}
	])
	for wood in [Vector4(520, 550, 310, 270), Vector4(1050, 1200, 330, 260), Vector4(550, 2810, 280, 440), Vector4(1550, 3430, 430, 200), Vector4(2320, 300, 260, 180), Vector4(3630, 380, 410, 230), Vector4(5070, 750, 350, 280), Vector4(5050, 1780, 280, 470), Vector4(4880, 3200, 440, 300), Vector4(3660, 3480, 290, 190)]:
		field.forests.append({"x": wood.x, "y": wood.y, "rx": wood.z, "ry": wood.w})
	for hill in [Vector4(1000, 600, 620, 340), Vector4(770, 2140, 470, 610), Vector4(2030, 3310, 650, 330), Vector4(3980, 570, 660, 350), Vector4(4960, 2360, 530, 670), Vector4(4200, 3300, 620, 310)]:
		var shoulder = 1.65 if scenario != "ridge" else 1.90
		field.hills.append({"x": hill.x, "y": hill.y, "rx": hill.z * shoulder, "ry": hill.w * shoulder, "height": 175.0 if scenario != "ridge" else 220.0})
	for town in [Vector2(920, 690), Vector2(4640, 950), Vector2(820, 2910), Vector2(4880, 3020), Vector2(3480, 3450), Vector2(1850, 430)]:
		field.towns.append(FieldData.point(town))
	for x in [850.0, 4900.0]:
		field.roads.append([FieldData.point(Vector2(x + 100, 0)), FieldData.point(Vector2(x - 90, 800)), FieldData.point(Vector2(x + 50, 1750)), FieldData.point(Vector2(x - 70, 2850)), FieldData.point(Vector2(x + 100, SIZE.y))])
	for y in [420.0, 3420.0]:
		var crossing = FieldData.channel_x(y - OFFSET.y) + OFFSET.x
		field.roads.append([FieldData.point(Vector2(0, y + 110)), FieldData.point(Vector2(850, y + 40)), FieldData.point(Vector2(1900, y - 90)), FieldData.point(Vector2(crossing - 110, y)), FieldData.point(Vector2(crossing + 110, y)), FieldData.point(Vector2(3800, y + 40)), FieldData.point(Vector2(4900, y - 100)), FieldData.point(Vector2(SIZE.x, y - 70))])
