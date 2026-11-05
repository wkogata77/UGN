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
	check(FieldTerrain.hill_profile(Vector2.ZERO, Vector2.ONE) == 1.0, "hill center retains elevation")
	check(FieldTerrain.hill_profile(Vector2(1, 0), Vector2.ONE) == 0.0, "hill shoulder meets the plain")
	check(FieldTerrain.hill_profile(Vector2(0.999, 0), Vector2.ONE) < 0.000001, "hill shoulder eases to a flat gradient")
	var model = FieldModel.new(false)
	model.start_battle("e1", true)
	for scenario in ["village", "bridge", "ridge"]:
		model.state.battle.scenario = scenario
		model.terrain.configure(model.state)
		surface_checks(model.terrain, scenario, 0.65)
		for hill in model.terrain.field.hills:
			check(model.terrain.height_at(FieldData.pos(hill), false) > 28.0, scenario + " retains a meaningful hill crest")
		if scenario == "bridge":
			check(is_equal_approx(model.terrain.height_at(Vector2(720, 480) + model.terrain.battle_offset), 6.5), "tactical bridge deck is unchanged")
	for theater in ["italy", "mantua", "danube"]:
		model.new_campaign(theater)
		surface_checks(model.terrain, theater, 0.45)
		for crossing in model.terrain.crossings:
			check(is_equal_approx(model.terrain.height_at(model.terrain.river_point(crossing)), 4.9), theater + " crossing deck is unchanged")
	var terrain = model.terrain
	var p = Vector2(230, 195) * terrain.campaign_scale
	var elevated = terrain.height_at(p)
	terrain.relief = 0.0
	check(is_zero_approx(terrain.height_at(p)), "relief toggle rebuilds a level surface")
	check(terrain.vertex_normal(Vector2i(60, 60)).is_equal_approx(Vector3.UP), "level terrain has upright normals")
	terrain.relief = 1.0
	check(is_equal_approx(terrain.height_at(p), elevated), "relief toggle restores elevation exactly")
	print("GODOT TERRAIN RELIEF: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func surface_checks(terrain: FieldTerrain, label: String, slope_limit: float) -> void:
	var spacing = terrain.render_bounds.size / Vector2(terrain.surface_cells)
	var steepest = 0.0
	var normal_step = 0.0
	var interpolation_error = 0.0
	for y in terrain.surface_cells.y:
		for x in terrain.surface_cells.x:
			var cell = Vector2i(x, y)
			var p = terrain.surface_point(cell)
			if not Rect2(Vector2.ZERO, terrain.map_size).has_point(p): continue
			var h00 = terrain.vertex_height(cell)
			var h10 = terrain.vertex_height(cell + Vector2i.RIGHT)
			var h01 = terrain.vertex_height(cell + Vector2i.DOWN)
			var h11 = terrain.vertex_height(cell + Vector2i.ONE)
			steepest = maxf(steepest, Vector2((h10 - h00) / spacing.x, (h01 - h00) / spacing.y).length())
			steepest = maxf(steepest, Vector2((h11 - h01) / spacing.x, (h11 - h10) / spacing.y).length())
			var n = terrain.vertex_normal(cell)
			normal_step = maxf(normal_step, n.angle_to(terrain.vertex_normal(cell + Vector2i.RIGHT)))
			normal_step = maxf(normal_step, n.angle_to(terrain.vertex_normal(cell + Vector2i.DOWN)))
			var lower = terrain.height_at(p + spacing * 0.25, false)
			var upper = terrain.height_at(p + spacing * 0.75, false)
			interpolation_error = maxf(interpolation_error, absf(lower - (h00 * 0.5 + h10 * 0.25 + h01 * 0.25)))
			interpolation_error = maxf(interpolation_error, absf(upper - (h11 * 0.5 + h10 * 0.25 + h01 * 0.25)))
	print("RELIEF %s: maximum grade %.3f, normal step %.3f, triangle error %.6f" % [label, steepest, normal_step, interpolation_error])
	check(steepest < slope_limit, label + " limits adjacent-rank height differences")
	check(normal_step < 0.35, label + " lighting changes gradually between ground vertices")
	check(interpolation_error < 0.001, label + " both rendered triangles match troop and LOS heights")
