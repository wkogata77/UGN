class_name FieldMinimap
extends Control

var world: FieldWorld
var image: Texture2D

func _ready() -> void:
	image = FieldArt.texture("terrain-v2")
	custom_minimum_size = Vector2(174, 116)
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	gui_input.connect(on_input)

func on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		world.center = event.position / size * world.model.terrain.map_size
		world.update_camera()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		world.center = event.position / size * world.model.terrain.map_size
		world.update_camera()
		accept_event()

func _draw() -> void:
	if world == null or image == null:
		return
	draw_texture_rect(image, Rect2(Vector2.ZERO, size), false, Color("d0d6b6"))
	var scale_value = size / world.model.terrain.map_size
	if FieldValeggio.enabled(world.model.terrain):
		draw_rect(Rect2(Vector2.ZERO, size), Color("747e57"))
		for parcel in world.scenery_fields:
			var polygon = PackedVector2Array()
			for p in parcel.polygon: polygon.append(p * scale_value)
			draw_colored_polygon(polygon, [Color("72634b"), Color("a69b69"), Color("62784c")][parcel.crop])
		for forest in world.model.terrain.forests:
			var polygon = PackedVector2Array()
			for i in 24: polygon.append((FieldData.pos(forest) + Vector2(cos(i * TAU / 24.0) * forest.rx, sin(i * TAU / 24.0) * forest.ry)) * scale_value)
			draw_colored_polygon(polygon, Color("475c3e"))
	for road in world.model.terrain.roads:
		var line = PackedVector2Array()
		for point in road: line.append(FieldData.pos(point) * scale_value)
		if line.size() > 1: draw_polyline(line, Color("b3ab85"), 1, true)
	for town in world.model.terrain.towns: draw_rect(Rect2(FieldData.pos(town) * scale_value - Vector2(1, 1), Vector2(3, 3)), Color("e6d9b0"))
	if world.model.terrain.water:
		var river = PackedVector2Array()
		for i in 101:
			var terrain = world.model.terrain
			var n = float(i) / 100 * (terrain.map_size.x if terrain.campaign and not terrain.river_vertical else terrain.map_size.y)
			var p = terrain.river_point(n) if terrain.campaign else Vector2(terrain.channel_x(n), n)
			river.append(p * scale_value)
		draw_polyline(river, Color("649798"), 4, true)
	for u in world.entities:
		var p = FieldData.pos(u) * scale_value
		draw_circle(p, 2, Color("e6c07c") if u.get("uncertain", false) else FieldUI.BLUE if u.side == "player" else FieldUI.RED)
	var v = world.get_viewport().get_visible_rect().size
	var corners = PackedVector2Array()
	for p in [Vector2(0, world.ui_top), Vector2(v.x, world.ui_top), Vector2(v.x, v.y - world.ui_bottom), Vector2(0, v.y - world.ui_bottom), Vector2(0, world.ui_top)]:
		var point = world.ground(p)
		if point != null:
			corners.append(point * scale_value)
	if corners.size() > 1:
		draw_polyline(corners, Color("f1dca4"), 1, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("83906c"), false)
