extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var started = Time.get_ticks_usec()
	var model = FieldModel.new(false)
	print("LOAD MODEL %.2fs" % ((Time.get_ticks_usec() - started) / 1000000.0))
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(model)
	print("LOAD WORLD %.2fs / %d trees / %d buildings" % [(Time.get_ticks_usec() - started) / 1000000.0, world.scenery_trees.size(), world.scenery_buildings.size()])
	world.queue_free()
	await process_frame
	FieldArt.textures.clear()
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	quit()
