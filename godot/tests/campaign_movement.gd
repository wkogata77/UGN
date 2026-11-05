extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = FieldModel.new(false)
	var path = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save="): path = argument.trim_prefix("--save=")
	if path.is_empty():
		model.new_campaign("mantua")
		model.state.hours = 29.089333333332
		model.state.army.retreatUntil = 30.4573333333322
		model.state.army.condition = 77.7
	elif not model.load_campaign(path):
		push_error("Could not load campaign for read-only movement replay")
		quit(1)
		return
	model.save_enabled = false
	var army: Dictionary = model.state.army
	var before = FieldData.pos(army)
	if army.get("pendingOrder") == null and army.path.is_empty():
		model.move_army(before + Vector2(195, -12))
	model.state.speed = 4.0
	model.state.paused = false
	print("CAMPAIGN REPLAY start: ", {"hours": model.state.hours, "position": before, "recovery": army.retreatUntil, "order": army.get("pendingOrder")})
	for i in 1800:
		model.tick(1.0 / 60.0)
		if model.state.mode != "campaign" or FieldData.pos(army).distance_to(before) > 30: break
	var moved = FieldData.pos(army).distance_to(before) > 30
	print("CAMPAIGN REPLAY end: ", {"hours": model.state.hours, "position": FieldData.pos(army), "order": army.get("pendingOrder"), "path": army.path, "mode": model.state.mode, "paused": model.state.paused, "moved": moved})
	quit(0 if moved else 1)
