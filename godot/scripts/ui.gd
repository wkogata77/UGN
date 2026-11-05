class_name FieldUI
extends RefCounted

const INK = Color("202226")
const SURFACE = Color("303237")
const TEXT = Color("efeee5")
const MUTED = Color("b5b8b9")
const GOLD = Color("ceb881")
const BLUE = Color("90bdd7")
const RED = Color("d99086")
const RULE = Color("5b5c5b")
const FRENCH = Color("466d8b")
const AUSTRIAN = Color("905951")
const FATIGUE = Color("c9ab78")
const MORALE = Color("a6b981")
static var icons: Dictionary = {}

static func icon(name: String) -> Texture2D:
	if not icons.has(name):
		icons[name] = load("res://assets/icons/" + name + ".svg")
	return icons[name]

static func box(color: Color, border: Color = Color.TRANSPARENT, margin: int = 8) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	return style

static func plate(color: Color = INK, edge: Color = RULE, margin_value: int = 10) -> StyleBoxFlat:
	var style = box(color, edge, margin_value)
	style.set_corner_radius_all(1)
	style.border_blend = true
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style

static func theme() -> Theme:
	var t = Theme.new()
	t.default_font = load("res://assets/fonts/Inter.woff2")
	t.default_font_size = 13
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "TextEdit", "PopupMenu", "TabBar"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, TEXT)
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_disabled_color", type, Color("85878a"))
	t.set_stylebox("normal", "Button", plate(SURFACE, RULE, 9))
	t.set_stylebox("hover", "Button", plate(Color("3c4248"), Color("98a8ae"), 9))
	t.set_stylebox("pressed", "Button", plate(Color("354856"), GOLD, 9))
	t.set_stylebox("disabled", "Button", box(Color("27292c"), Color("424448"), 9))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, BLUE, 9))
	t.set_stylebox("panel", "PanelContainer", plate(INK, RULE, 14))
	t.set_stylebox("panel", "PopupMenu", plate(INK, RULE, 8))
	t.set_stylebox("panel", "TooltipPanel", plate(Color("171a1e"), GOLD, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 12)
	for type in ["LineEdit", "TextEdit", "OptionButton"]:
		t.set_stylebox("normal", type, box(Color("181c21"), RULE, 8))
		t.set_stylebox("focus", type, box(Color.TRANSPARENT, BLUE, 8))
		t.set_stylebox("hover", type, box(Color("303b44"), BLUE, 8))
		t.set_stylebox("pressed", type, box(Color("354856"), GOLD, 8))
	for variation in ["FieldTool", "FieldTab", "FieldRecord"]:
		t.set_type_variation(variation, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var selected = state == "pressed"
			var color = Color("344651") if selected else Color("353c43") if state == "hover" else Color("24282d") if variation == "FieldRecord" else Color.TRANSPARENT
			var style = box(color, GOLD if selected else RULE if variation == "FieldRecord" else Color.TRANSPARENT, 7)
			style.set_corner_radius_all(1)
			style.set_border_width_all(0)
			if variation == "FieldRecord": style.border_width_left = 3
			else: style.border_width_bottom = 2
			t.set_stylebox(state, variation, style)
		t.set_color("icon_normal_color", variation, TEXT)
		t.set_color("icon_pressed_color", variation, GOLD)
		t.set_color("icon_disabled_color", variation, Color("757b80"))
	t.set_font("font", "FieldTab", load("res://assets/fonts/Cormorant.woff2"))
	t.set_font_size("font_size", "FieldTab", 20)
	for variation in ["CommandTool", "RegimentCard"]:
		t.set_type_variation(variation, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill = {"normal": Color("282721"), "hover": Color("444034"), "pressed": Color("54452d"), "disabled": Color("22231f")}[state]
			var edge = GOLD if state == "pressed" else Color("a49c7e") if state == "hover" else Color("636555") if state == "normal" else Color("41463f")
			var style = plate(fill, edge, 4)
			style.set_corner_radius_all(0)
			style.border_width_bottom = 3 if state == "pressed" else 2
			style.shadow_size = 1
			style.shadow_offset = Vector2(0, 1)
			t.set_stylebox(state, variation, style)
		t.set_color("icon_normal_color", variation, Color("d4ccb1"))
		t.set_color("icon_hover_color", variation, TEXT)
		t.set_color("icon_pressed_color", variation, Color("ffe1a0"))
		t.set_color("icon_disabled_color", variation, Color("72796e"))
		t.set_font_size("font_size", variation, 11)
		t.set_stylebox("focus", variation, box(Color.TRANSPARENT, BLUE, 0))
	var rail = box(Color("151a17"), Color.TRANSPARENT, 0)
	rail.set_border_width_all(0)
	var grip = box(Color("777e68"), Color.TRANSPARENT, 0)
	grip.set_border_width_all(0)
	t.set_stylebox("scroll", "HScrollBar", rail)
	t.set_stylebox("grabber", "HScrollBar", grip)
	t.set_stylebox("grabber_highlight", "HScrollBar", box(GOLD, Color.TRANSPARENT, 0))
	t.set_stylebox("grabber_pressed", "HScrollBar", box(GOLD, Color.TRANSPARENT, 0))
	t.set_constant("minimum_grab_size", "HScrollBar", 24)
	var rule = StyleBoxLine.new()
	rule.color = Color("545859")
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	var vertical_rule = rule.duplicate()
	vertical_rule.vertical = true
	t.set_stylebox("separator", "VSeparator", vertical_rule)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 8)
	t.set_stylebox("background", "ProgressBar", box(Color("494d51"), Color.TRANSPARENT, 0))
	t.set_stylebox("fill", "ProgressBar", box(BLUE, Color.TRANSPARENT, 0))
	t.set_constant("icon_max_width", "Button", 19)
	return t

static func label(text: String, size_value: int = 13, color: Color = TEXT, display: bool = false) -> Label:
	var item = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_value)
	item.add_theme_color_override("font_color", color)
	if display:
		item.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func button(text: String, icon_name: String, action: Callable, hint: String = "", disabled: bool = false) -> Button:
	var item = Button.new()
	item.text = text
	if not icon_name.is_empty():
		item.icon = icon(icon_name)
		item.expand_icon = true
		item.add_theme_constant_override("icon_max_width", 18)
		if text.is_empty(): item.theme_type_variation = "FieldTool"
	item.tooltip_text = hint if not hint.is_empty() else text
	item.custom_minimum_size = Vector2(38, 36)
	item.disabled = disabled
	item.pressed.connect(action)
	return item

static func branch_icon(kind: String) -> String:
	return {"infantry": "Shield", "cavalry": "Swords", "artillery": "Target", "army": "Flag", "general": "Star", "wagon": "Truck"}.get(kind, "Shield")

static func pennant(canvas: CanvasItem, rect: Rect2, kind: String, side: String = "player", selected: bool = false) -> void:
	var p = rect.position
	var s = rect.size
	var points = PackedVector2Array([p, p + Vector2(s.x, 0), p + Vector2(s.x, s.y - 5), p + Vector2(s.x * 0.5, s.y), p + Vector2(0, s.y - 5)])
	canvas.draw_colored_polygon(points, FRENCH if side == "player" else AUSTRIAN)
	var outline = points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, GOLD if selected else Color("b8b4a4"), 1.0, true)
	var padding = maxf(3, s.x * 0.18)
	canvas.draw_texture_rect(icon(branch_icon(kind)), Rect2(p + Vector2(padding, padding), Vector2(s.x - padding * 2, s.x - padding * 2)), false, TEXT)

static func insignia(kind: String, size_value: int = 26, side: String = "player") -> Control:
	var item = Control.new()
	item.custom_minimum_size = Vector2(size_value, size_value + 5)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.draw.connect(func(): pennant(item, Rect2(Vector2.ONE, Vector2(size_value - 2, size_value + 2)), kind, side))
	return item

static func portrait_frame(index: int, size_value: int = 64) -> PanelContainer:
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", plate(Color("10151a"), Color("8b8b7c"), 3))
	frame.add_child(portrait(index, size_value))
	return frame

static func troop_art(kind: String, width: int = 38, height: int = 58) -> TextureRect:
	var type: int = {"infantry": 0, "cavalry": 2, "artillery": 4, "wagon": 7}.get(kind, 0)
	var atlas = AtlasTexture.new()
	atlas.atlas = FieldArt.motion_texture(type)
	atlas.region = Rect2(0, 0, 384, 512 if type == 0 else 384)
	var item = TextureRect.new()
	item.texture = atlas
	item.custom_minimum_size = Vector2(width, height)
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func command_surface(panel: PanelContainer, margin_value: int = 6) -> void:
	var style = plate(Color(0.12, 0.12, 0.115, 0.93), Color("817b66"), margin_value)
	style.set_corner_radius_all(0)
	style.border_width_top = 2
	panel.add_theme_stylebox_override("panel", style)
	var grain = atlas_background()
	grain.name = "CommandAtlas"
	var atlas = AtlasTexture.new()
	atlas.atlas = grain.texture
	atlas.region = Rect2(240, 180, 1200, 660)
	grain.texture = atlas
	grain.modulate = Color(0.77, 0.72, 0.59, 0.13)
	panel.add_child(grain)
	var edge = Control.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.draw.connect(func():
		edge.draw_line(Vector2.ZERO, Vector2(edge.size.x, 0), Color("4f584a"), 1.0)
		edge.draw_line(Vector2(0, edge.size.y), edge.size, Color("101511"), 1.0)
	)
	edge.resized.connect(edge.queue_redraw)
	panel.add_child(edge)

static func command_controls(control: Control) -> void:
	for child in control.get_children():
		if child is Button:
			child.theme_type_variation = "CommandTool"
			child.custom_minimum_size = Vector2(maxf(32, child.custom_minimum_size.x if not child.text.is_empty() else 32), 32)
			child.add_theme_constant_override("icon_max_width", 18)
		elif child is Control:
			command_controls(child)

static func roster_button(action: Callable, hint: String, width: int = 152) -> Button:
	var item = button("", "", action, hint)
	item.custom_minimum_size = Vector2(width, 60)
	item.theme_type_variation = "RegimentCard"
	item.toggle_mode = true
	item.clip_contents = true
	item.draw.connect(func():
		var size_value = item.size
		item.draw_line(Vector2(3, 3), Vector2(size_value.x - 3, 3), Color(0.8, 0.77, 0.60, 0.18), 1.0)
		item.draw_line(Vector2(3, 3), Vector2(3, size_value.y - 4), Color(0.8, 0.77, 0.60, 0.18), 1.0)
		item.draw_rect(Rect2(7, 7, 3, 44), FRENCH)
		item.draw_rect(Rect2(10, 7, 2, 44), Color("c8c4ac"))
		item.draw_rect(Rect2(12, 7, 2, 44), AUSTRIAN)
	)
	return item

static func card_label(parent: Control, text: String, rect: Rect2, size_value: int = 12, color: Color = TEXT, display: bool = false) -> Label:
	var item = label(text, size_value, color, display)
	item.position = rect.position
	item.size = rect.size
	item.clip_text = true
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(item)
	return item

static func atlas_background() -> TextureRect:
	var item = TextureRect.new()
	item.texture = load("res://assets/headquarters-atlas-v1.png")
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

static func paper_grain() -> TextureRect:
	var item = atlas_background()
	var paper = AtlasTexture.new()
	paper.atlas = item.texture
	paper.region = Rect2(950, 300, 450, 380)
	item.texture = paper
	item.modulate = Color(1, 1, 1, 0.08)
	return item

static func section(text: String, icon_name: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	if not icon_name.is_empty():
		var symbol = TextureRect.new()
		symbol.texture = icon(icon_name)
		symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol.custom_minimum_size = Vector2(18, 18)
		symbol.modulate = GOLD
		row.add_child(symbol)
	row.add_child(label(text, 20, TEXT, true))
	var line = HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row

static func weapon_art(key: String, height: float = 90) -> TextureRect:
	key = FieldData.weapons()[key].art
	var regions = {"musket": Vector2(0, 215), "improved": Vector2(215, 195), "rifle": Vector2(376, 188), "sabre": Vector2(555, 145), "cannon": Vector2(700, 324), "carbine": Vector2(376, 188), "howitzer": Vector2(700, 324)}
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/weapons.png")
	atlas.region = Rect2(0, regions[key].x, 1536, regions[key].y)
	var rect = TextureRect.new()
	rect.texture = atlas
	rect.custom_minimum_size.y = height
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

static func spacer(horizontal: bool = true) -> Control:
	var control = Control.new()
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control

static func margin(child: Control, amount: int = 16) -> MarginContainer:
	var container = MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		container.add_theme_constant_override("margin_" + edge, amount)
	container.add_child(child)
	return container

static func portrait(index: int, size_value: int = 72) -> TextureRect:
	var texture: Texture2D = load("res://assets/officers.png")
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	var cell = Vector2(texture.get_width() / 4.0, texture.get_height() / 4.0)
	atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
	var rect = TextureRect.new()
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.custom_minimum_size = Vector2(size_value, size_value)
	return rect

static func bar(value: float, color: Color = BLUE) -> ProgressBar:
	var item = ProgressBar.new()
	item.show_percentage = false
	item.value = clampf(value, 0, 100)
	item.custom_minimum_size.y = 4
	item.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 0))
	return item

static func wrapped(text: String, size_value: int = 12, color: Color = MUTED) -> Label:
	var item = label(text, size_value, color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

static func select(options: Array, selected: int, action: Callable) -> OptionButton:
	var item = OptionButton.new()
	for text in options:
		item.add_item(str(text))
	item.selected = selected
	item.fit_to_longest_item = false
	item.custom_minimum_size.y = 36
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.item_selected.connect(action)
	return item
