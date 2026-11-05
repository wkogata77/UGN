class_name FieldHud
extends CanvasLayer

signal skirmish_requested(scenario: String)
signal campaign_requested
signal new_campaign_requested(theater: String)

var model: FieldModel
var world: FieldWorld
var root: Control
var header: PanelContainer
var bottom: PanelContainer
var title: VBoxContainer
var objective: PanelContainer
var tools: VBoxContainer
var time_button: Button
var cash_label: Label
var clock_label: Label
var objective_label: Label
var mission_label: Label
var roster: HBoxContainer
var action_row: HBoxContainer
var corps_row: HBoxContainer
var minimap: FieldMinimap
var march_buttons: Array[Button] = []
var inspector: PanelContainer
var inspected_id = ""
var hq: FieldHeadquarters
var modal: Control
var toast: Label
var toast_time = 0.0
var refresh_clock = 0.0
var width = 0.0
var height = 0.0
var signature = ""
var roster_labels: Dictionary = {}
var command_caption: Label
var exercise = false
var loading = false
var save_warning_shown = false

func setup(game: FieldModel, map: FieldWorld, is_exercise: bool = false) -> void:
	model = game
	world = map
	exercise = is_exercise
	layer = 2
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = FieldUI.theme()
	add_child(root)
	world.inspect_requested.connect(inspect)
	world.order_failed.connect(notify)
	world.order_queued.connect(notify)
	model.changed.connect(refresh)
	build()

func remove_node(node) -> void:
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		if node.get_parent() != null: node.get_parent().remove_child(node)
		node.queue_free()

func build() -> void:
	for node in [header, bottom, title, objective, tools, minimap, toast]:
		remove_node(node)
	width = get_viewport().get_visible_rect().size.x
	height = get_viewport().get_visible_rect().size.y
	var narrow = width < 740
	var compact_header = width < 1000
	world.ui_top = 60 if narrow else 52
	world.ui_bottom = 156 if narrow and model.state.mode == "battle" else 114 if model.state.mode == "battle" or narrow else 76
	if model.state.mode == "campaign" and FieldOperations.enabled(model.state): world.ui_bottom = 156 if narrow else 114
	header = PanelContainer.new()
	FieldUI.command_surface(header, 4)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = world.ui_top
	root.add_child(header)
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4 if compact_header else 8)
	header.add_child(head)
	var branding = VBoxContainer.new()
	branding.custom_minimum_size.x = 132 if compact_header else 204
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	branding.add_theme_constant_override("separation", 0)
	var brand_name = FieldUI.label("Field Command", 23 if compact_header else 25, FieldUI.TEXT, true)
	brand_name.clip_text = true
	brand_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	branding.add_child(brand_name)
	if not compact_header:
		branding.add_child(FieldUI.label("ITALIAN THEATER / FIELD OPERATIONS", 9, FieldUI.GOLD))
	head.add_child(branding)
	var campaign_button = FieldUI.button("" if compact_header else "Campaign", "Map", return_campaign, "Campaign map")
	campaign_button.theme_type_variation = "FieldTool" if compact_header else "FieldTab"
	campaign_button.toggle_mode = true
	campaign_button.button_pressed = model.state.mode == "campaign"
	head.add_child(campaign_button)
	var battle_button = FieldUI.button("" if compact_header else "Battlefield", "Swords", skirmish_dialog, "Battle exercises", model.state.mode == "battle")
	battle_button.theme_type_variation = "FieldTool" if compact_header else "FieldTab"
	head.add_child(battle_button)
	cash_label = FieldUI.label("", 12, FieldUI.GOLD)
	cash_label.visible = not compact_header
	head.add_child(cash_label)
	head.add_child(FieldUI.button("", "Tent", open_headquarters, "Army headquarters"))
	if not compact_header:
		head.add_child(FieldUI.button("", "Save", save_game, "Save campaign", exercise))
	head.add_child(FieldUI.button("", "Settings", settings_dialog, "Settings and saves"))
	if compact_header:
		for control in head.get_children():
			if control is Button: control.custom_minimum_size.x = 32
	title = VBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.position = Vector2(22, world.ui_top + 22)
	title.size.x = minf(width - (94 if narrow else 330), 560)
	root.add_child(title)
	if model.state.mode != "battle":
		title.add_child(FieldUI.label("NORTHERN ITALY / OPERATIONAL DEMO" if FieldOperations.enabled(model.state) else "NORTHERN ITALY / ILLUSTRATIVE SECTOR" if model.state.theater == "italy" else "DANUBE THEATER", 9, FieldUI.TEXT))
	var name = model.state.battle.name if model.state.battle != null else "The Mantua Operation" if FieldOperations.enabled(model.state) else "The Po Valley" if model.state.theater == "italy" else "The Danube"
	var title_label = FieldUI.wrapped(name, (22 if narrow else 26) if model.state.mode == "battle" else (29 if narrow else 38), FieldUI.TEXT)
	title_label.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	title.add_child(title_label)
	clock_label = FieldUI.label("", 10, FieldUI.TEXT)
	title.add_child(clock_label)
	for label in title.get_children():
		label.add_theme_color_override("font_shadow_color", Color(0.04, 0.08, 0.06, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.add_theme_constant_override("shadow_outline_size", 2)
	objective = PanelContainer.new()
	var dispatch_style = FieldUI.plate(Color(0.12, 0.14, 0.17, 0.88), FieldUI.RULE, 10 if model.state.mode == "battle" else 14)
	dispatch_style.border_width_top = 2
	dispatch_style.border_color = FieldUI.GOLD
	objective.add_theme_stylebox_override("panel", dispatch_style)
	objective.position = Vector2(22 if narrow else width - 285, world.ui_top + ((82 if model.state.mode == "battle" else 128) if narrow else 26))
	objective.size = Vector2(200 if narrow else 260, 82 if model.state.mode == "battle" else 102)
	root.add_child(objective)
	var mission = VBoxContainer.new()
	objective.add_child(mission)
	var dispatch_heading = HBoxContainer.new()
	dispatch_heading.add_child(FieldUI.insignia("army", 17))
	dispatch_heading.add_child(FieldUI.label("BATTLE ORDERS" if model.state.mode == "battle" else "FIELD DISPATCH", 10, FieldUI.GOLD))
	mission.add_child(dispatch_heading)
	mission_label = FieldUI.wrapped("", 18 if model.state.mode == "battle" else 20, FieldUI.TEXT)
	mission_label.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	mission.add_child(mission_label)
	objective_label = FieldUI.wrapped("", 10, FieldUI.MUTED)
	mission.add_child(objective_label)
	tools = VBoxContainer.new()
	tools.position = Vector2(width - 54, world.ui_top + (130 if narrow else 148 if model.state.mode == "battle" else 176))
	tools.add_theme_constant_override("separation", 4)
	root.add_child(tools)
	tools.add_child(FieldUI.button("", "Plus", func(): world.set_zoom(1.2), "Zoom in"))
	tools.add_child(FieldUI.button("", "Minus", func(): world.set_zoom(1.0 / 1.2), "Zoom out"))
	tools.add_child(FieldUI.button("", "Maximize", world.home, "Reset camera"))
	tools.add_child(FieldUI.button("", "ArrowDownToLine", func(): world.adjust_pitch(-5), "Lower camera angle / Q"))
	tools.add_child(FieldUI.button("", "ArrowUpFromLine", func(): world.adjust_pitch(5), "Raise camera angle / E"))
	if model.state.mode == "campaign": tools.add_child(FieldUI.button("", "Map", world.overview, "Campaign overview"))
	tools.add_child(FieldUI.button("", "Mountain", func(): world.model.terrain.relief = 0.0 if world.model.terrain.relief > 0 else 1.0; world.invalidate(), "Toggle terrain relief"))
	tools.add_child(FieldUI.button("", "Crosshair", func(): world.show_ranges = not world.show_ranges; world.invalidate(), "Toggle firing ranges"))
	tools.add_child(FieldUI.button("", "MousePointer2", func(): world.touch_orders = not world.touch_orders; notify("Order mode" if world.touch_orders else "Inspect mode"), "Toggle touch order mode"))
	for button in tools.get_children():
		button.theme_type_variation = "CommandTool"
	minimap = FieldMinimap.new()
	minimap.world = world
	minimap.position = Vector2(width - 202, get_viewport().get_visible_rect().size.y - world.ui_bottom - 140)
	minimap.size = Vector2(180, 120)
	minimap.visible = not narrow
	root.add_child(minimap)
	build_bottom(narrow)
	toast = FieldUI.wrapped("", 12, FieldUI.GOLD)
	toast.position = Vector2(22, get_viewport().get_visible_rect().size.y - world.ui_bottom - 40)
	toast.size = Vector2(minf(width - 44, 550), 38)
	root.add_child(toast)
	for popup in [inspector, hq, modal]:
		if is_instance_valid(popup):
			root.move_child(popup, -1)
	signature = ""
	refresh()
	call_deferred("update_map_obstacles")

func update_map_obstacles() -> void:
	# Wrapped labels can briefly report a tall minimum during a window resize.
	if is_instance_valid(objective):
		objective.size = Vector2(200 if width < 740 else 260, maxf(82 if model.state.mode == "battle" else 102, objective.get_combined_minimum_size().y))
	if width < 740 and is_instance_valid(title) and is_instance_valid(objective):
		title.size.y = title.get_combined_minimum_size().y
		objective.position.y = maxf(world.ui_top + (82 if model.state.mode == "battle" else 128), title.get_global_rect().end.y + 12)
	var rectangles: Array[Rect2] = []
	for control in [title, objective, tools, minimap, inspector]:
		if is_instance_valid(control) and control.visible:
			rectangles.append(control.get_global_rect().grow(4))
	if world.label_obstacles != rectangles:
		world.label_obstacles = rectangles
		world.invalidate()

func scroll_row(height: float) -> Array:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = height
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.get_h_scroll_bar().custom_minimum_size.y = 4
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	scroll.add_child(row)
	return [scroll, row]

func build_bottom(narrow: bool) -> void:
	march_buttons.clear()
	command_caption = null
	bottom = PanelContainer.new()
	bottom.name = "CommandRail"
	FieldUI.command_surface(bottom, 4)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -world.ui_bottom
	root.add_child(bottom)
	var rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(rows)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	rows.add_child(top)
	time_button = FieldUI.button("", "Play", model.pause, "Resume time")
	top.add_child(time_button)
	for speed in [0.5, 1.0, 2.0, 4.0]:
		var button = FieldUI.button(str(speed).trim_suffix(".0") + "x", "", func(): model.speed(speed), "Simulation speed")
		button.custom_minimum_size = Vector2(32, 32)
		button.theme_type_variation = "FieldTool"
		button.add_theme_font_size_override("font_size", 10)
		button.toggle_mode = true
		button.button_pressed = model.state.speed == speed
		button.set_meta("speed", speed)
		top.add_child(button)
	top.add_child(VSeparator.new())
	if model.state.mode == "battle":
		if not narrow and width >= 1180:
			command_caption = FieldUI.label("", 16, FieldUI.GOLD, true)
			command_caption.custom_minimum_size.x = 160
			command_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			command_caption.clip_text = true
			command_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			top.add_child(command_caption)
		if narrow: top.add_child(FieldUI.spacer())
		var corps_strip = scroll_row(36)
		corps_row = corps_strip[1]
		corps_row.add_theme_constant_override("separation", 4)
		corps_strip[0].size_flags_horizontal = Control.SIZE_FILL
		top.add_child(corps_strip[0])
		for c in model.state.corps:
			if not model.state.battle.units.any(func(u): return u.side == "player" and u.corpsId == c.id): continue
			var button = FieldUI.button(c.name.trim_suffix(" Corps"), "", func(): model.select_corps(c.id), "Select " + c.name)
			button.theme_type_variation = "FieldTool"
			button.clip_text = true
			button.custom_minimum_size.x = 32
			button.toggle_mode = true
			button.set_meta("corps", c.id)
			if c.name.begins_with("Detachment"): button.text = str(int(model.state.corps.find(c)) + 1)
			corps_row.add_child(button)
		corps_strip[0].custom_minimum_size.x = clampf(corps_row.get_child_count() * 36 - 4, 32, 68 if narrow else 104)
		var actions = scroll_row(36)
		action_row = actions[1]
		action_row.add_theme_constant_override("separation", 3)
		if narrow:
			rows.add_child(actions[0])
		else:
			top.add_child(actions[0])
		build_actions()
		var strip = scroll_row(64)
		roster = strip[1]
		rows.add_child(strip[0])
	else:
		top.add_child(FieldUI.spacer())
		var marching = HBoxContainer.new()
		if narrow: rows.add_child(marching)
		else: top.add_child(marching)
		for mode in ["route", "normal", "slow"]:
			var button = FieldUI.button("" if narrow and FieldOperations.enabled(model.state) else mode.capitalize(), {"route": "Gauge", "normal": "Footprints", "slow": "Shield"}[mode], func(): model.march_mode(mode), mode.capitalize() + " marching")
			button.toggle_mode = true
			button.theme_type_variation = "FieldTool"
			button.set_meta("march_mode", mode)
			button.button_pressed = model.state.army.marchMode == mode
			marching.add_child(button)
			march_buttons.append(button)
		if FieldOperations.enabled(model.state):
			marching.add_child(FieldUI.button("", "Users", split_dialog, "Split army"))
			marching.add_child(FieldUI.button("", "ArrowDownToLine", merge_dialog, "Merge armies"))
			marching.add_child(FieldUI.button("", "Flag", objectives_dialog, "Operational objectives"))
		top.add_child(FieldUI.button("" if narrow else "Scouts", "Binoculars", func():
			if not model.scout(): notify("Patrol unavailable: cooldown or insufficient funds.")
		, "Send scouts / 100 F"))
		top.add_child(FieldUI.button("" if narrow else "Halt", "Square", model.halt, "Halt army"))
		top.add_child(FieldUI.button("" if narrow else "Army camp", "Tent", open_headquarters, "Army headquarters"))
		if FieldOperations.enabled(model.state):
			var strip = scroll_row(64)
			roster = strip[1]
			rows.add_child(strip[0])
	FieldUI.command_controls(rows)

func build_army_roster() -> void:
	if not is_instance_valid(roster): return
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	roster_labels.clear()
	for a in model.state.armies:
		var button = FieldUI.roster_button(func():
			model.select_armies([a.id])
			world.center_entity(a)
		, "Select " + a.name, 232)
		button.disabled = a.defeated
		roster.add_child(button)
		var officer = model.find_id(model.state.officers, a.get("officerId"))
		var portrait = FieldUI.portrait(officer.get("portrait", 0), 0)
		portrait.position = Vector2(18, 8)
		portrait.size = Vector2(40, 43)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(portrait)
		FieldUI.card_label(button, a.name, Rect2(65, 4, 159, 19), 17, FieldUI.TEXT, true)
		var status = FieldUI.card_label(button, "", Rect2(65, 25, 159, 15), 10, FieldUI.MUTED)
		var morale = roster_bar(button, a.morale, FieldUI.MORALE, Vector2(65, 46), 158)
		var condition = roster_bar(button, a.condition, FieldUI.FATIGUE, Vector2(65, 52), 158)
		roster_labels[a.id] = {"button": button, "status": status, "morale": morale, "condition": condition}

func split_dialog() -> void:
	var a: Dictionary = model.state.army
	var column = begin_modal("Split Army")
	column.add_child(FieldUI.wrapped(a.name + " / " + FieldOperations.morale_name(a.morale), 16, FieldUI.GOLD))
	var name = LineEdit.new()
	name.name = "DetachmentName"
	name.text = "Detachment " + str(int(model.state.operation.nextForce))
	name.max_length = 32
	column.add_child(name)
	var ids: Array = []
	for u in model.army_units():
		var check = CheckBox.new()
		check.name = "Detach_" + u.id
		check.text = "%s / %d men" % [u.name, u.men]
		check.disabled = u.men <= 0
		check.add_theme_font_size_override("font_size", 12)
		check.toggled.connect(func(value):
			if value: ids.append(u.id)
			else: ids.erase(u.id)
		)
		column.add_child(check)
	var warning = FieldUI.wrapped("", 12, FieldUI.GOLD)
	column.add_child(warning)
	column.add_child(FieldUI.button("Create detachment", "Users", func():
		if model.split_army(ids, name.text): close_modal()
		else: warning.text = "Both forces need a living regiment. Halt and finish regrouping before splitting; maximum four forces."
	))

func merge_dialog() -> void:
	var column = begin_modal("Merge Armies")
	var source: Dictionary = model.state.army
	column.add_child(FieldUI.wrapped(source.name, 18, FieldUI.GOLD))
	for target in model.state.armies:
		if target.id == source.id: continue
		var can_merge = FieldOperations.can_merge(model, source, target)
		var a = float(FieldData.men(FieldOperations.roster(model.state, source)))
		var b = float(FieldData.men(FieldOperations.roster(model.state, target)))
		var morale = (source.morale * a + target.morale * b) / maxf(1, a + b)
		column.add_child(FieldUI.button("%s / %d men / %d morale" % [target.name, a + b, morale], "Users", func():
			if model.merge_army(target.id): close_modal()
			else: notify("Armies must be halted, nearby, and finished regrouping. Maximum eight regiments.")
		, "Merge into " + target.name if can_merge else "Requires nearby halted armies, a clear route, and at most eight regiments", not can_merge))
	if model.state.armies.size() < 2: column.add_child(FieldUI.wrapped("No other player army in the theater.", 13, FieldUI.MUTED))

func objectives_dialog() -> void:
	var column = begin_modal("Operational Orders")
	column.add_child(FieldUI.label("HEADQUARTERS / ARMY OF ITALY", 10, FieldUI.GOLD))
	column.add_child(FieldUI.wrapped("Secure Valeggio and Mantua, retain a depot, then hold for two campaign hours.", 16, FieldUI.GOLD))
	column.add_child(HSeparator.new())
	for site in model.state.operation.sites:
		var status = "Contested" if site.contested else site.owner.capitalize()
		var progress = " / %d%%" % roundi(site.progress / (8 if site.kind == "fort" else 0.4) * 100) if site.progress > 0 else ""
		var row = HBoxContainer.new()
		var order = FieldUI.button("%s\n%s / %s%s" % [site.name, site.kind.capitalize(), status, progress], "Shield" if site.kind == "fort" else "Truck" if site.kind == "depot" else "Flag", func(): close_modal(); world.center_entity(site), "Center on " + site.name)
		order.theme_type_variation = "FieldRecord"
		order.alignment = HORIZONTAL_ALIGNMENT_LEFT
		order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order.add_theme_color_override("icon_normal_color", FieldUI.BLUE if site.owner == "player" else FieldUI.RED if site.owner == "enemy" else FieldUI.GOLD)
		row.add_child(order)
		column.add_child(row)
	column.add_child(FieldUI.wrapped("Occupation: 24 minutes. Mantua blockade: 8 hours, 600 troops. Depot reserve: %d." % model.state.operation.reserveSupply, 12, FieldUI.MUTED))

func build_actions() -> void:
	for name in ["line", "column", "square"]:
		action_row.add_child(FieldUI.button("", {"line": "Rows3", "column": "Columns3", "square": "Square"}[name], func(): model.formation(name), name.capitalize() + " formation"))
	for spec in [["Gauge", "Run / walk", func(): model.toggle_order("running")], ["Crosshair", "Engage enemy", func():
		if model.engage_enemy() == 0: notify("No visible enemy can be engaged.")
	], ["Swords", "Charge", func():
		if model.charge() == 0: notify("No ready unit with a visible charge target.")
	], ["Shield", "Melee only / fire at will", func(): model.toggle_order("holdFire")], ["ArrowDownToLine", "Retreat unit", func():
		if model.retreat_units() == 0: notify("No withdrawal route available.")
	], ["Undo2", "Fall back", model.fall_back], ["ArrowUpFromLine", "Leave defensive position", model.leave_cover], ["Square", "Halt", model.halt], ["Flag", "Rally", func():
		if not model.rally(): notify("No eligible troops in the general's rally radius.")
	], ["Truck", "Limber / deploy guns", model.limber], ["Footprints", "Dismount / mount", model.dismount], ["Users", "Detach / recall skirmishers", model.detach_skirmishers], ["Move", "Draw a frontline", func(): model.state.orderMode = "frontline"; model.publish(false)], ["Landmark", "Deployment mode", func(): model.state.orderMode = "deploy"; model.publish(false)], ["UserRound", "General follows army", model.follow_command], ["ArrowLeft", "Withdraw from battle", return_campaign]]:
		if spec[1] in ["Run / walk", "Retreat unit", "Rally", "Limber / deploy guns", "Deployment mode"]:
			var separator = VSeparator.new()
			separator.custom_minimum_size.x = 5
			action_row.add_child(separator)
		action_row.add_child(FieldUI.button("", spec[0], spec[2], spec[1]))

func build_roster() -> void:
	if not is_instance_valid(roster) or model.state.battle == null:
		return
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	roster_labels.clear()
	var own = model.state.battle.units.filter(func(u): return u.side == "player")
	for u in own:
		var button = FieldUI.roster_button(func():
			var ids: Array = model.state.selected.duplicate() if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL) else []
			if u.id in ids: ids.erase(u.id)
			else: ids.append(u.id)
			model.select(ids)
		, u.name, 112)
		button.custom_minimum_size.y = 62
		button.button_pressed = u.id in model.state.selected
		button.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
				world.center_entity(u)
		)
		roster.add_child(button)
		var art = FieldUI.troop_art(u.kind, 29, 43)
		art.name = "RegimentArtwork"
		art.position = Vector2(14, 5)
		art.size = Vector2(29, 43)
		button.add_child(art)
		FieldUI.card_label(button, u.name.trim_suffix(" Regiment").replace("Infantry", "Inf.").replace("Line Regiment", "Line").replace("Field Battery", "Battery"), Rect2(43, 3, 62, 14), 11, FieldUI.TEXT, true)
		var strength = FieldUI.card_label(button, "", Rect2(43, 17, 62, 22), 18, FieldUI.TEXT, true)
		var status_y = maxf(39, strength.get_rect().end.y)
		var status = FieldUI.card_label(button, "", Rect2(43, status_y, 62, 11), 8, FieldUI.MUTED)
		var morale = roster_bar(button, u.morale, FieldUI.MORALE, Vector2(15, 55), 90)
		var fatigue = roster_bar(button, u.condition, FieldUI.FATIGUE, Vector2(15, 59), 90)
		roster_labels[u.id] = {"button": button, "status": status, "strength": strength, "morale": morale, "condition": fatigue}
	for c in model.state.battle.commanders:
		if c.get("hostId") == null:
			var button = FieldUI.roster_button(func(): model.select_commander(c.id), c.name)
			button.set_meta("commander", c.id)
			roster.add_child(button)
			var officer = model.find_id(model.state.officers, c.get("officerId"))
			var portrait = FieldUI.portrait(officer.get("portrait", 0), 0)
			portrait.position = Vector2(18, 9)
			portrait.size = Vector2(36, 42)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(portrait)
			FieldUI.card_label(button, c.name, Rect2(60, 9, 84, 21), 15, FieldUI.TEXT, true)
			FieldUI.card_label(button, "Army command", Rect2(60, 34, 84, 16), 9, FieldUI.GOLD)
	var supply = FieldUI.roster_button(model.select_supply, "Select supply train")
	supply.set_meta("supply", true)
	roster.add_child(supply)
	var wagon = FieldUI.troop_art("wagon", 38, 44)
	wagon.position = Vector2(16, 8)
	supply.add_child(wagon)
	FieldUI.card_label(supply, "Supply train", Rect2(58, 7, 87, 21), 15, FieldUI.TEXT, true)
	var stock = FieldUI.card_label(supply, "", Rect2(58, 28, 87, 25), 20, FieldUI.GOLD, true)
	roster_labels["supply"] = {"button": supply, "stock": stock}

func roster_bar(parent: Control, value: float, color: Color, position: Vector2, bar_width: float) -> ProgressBar:
	var bar = FieldUI.bar(value, color)
	bar.custom_minimum_size.y = 3
	bar.position = position
	bar.size = Vector2(bar_width, 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func refresh() -> void:
	if not is_instance_valid(root) or loading:
		return
	if model.save_failed and not save_warning_shown:
		notify("No valid campaign save. Autosaving is disabled; original files were kept." if not model.save_enabled else "Autosave failed. Check available storage and use Save again.")
		save_warning_shown = true
	elif not model.save_failed:
		save_warning_shown = false
	var key = model.state.mode
	if model.state.mode == "campaign" and FieldOperations.enabled(model.state):
		for a in model.state.armies: key += ":" + a.id
	if model.state.battle != null:
		for u in model.state.battle.units:
			if u.side == "player": key += ":" + u.id
	if signature != key:
		var mode_changed = not signature.is_empty() and signature.split(":")[0] != model.state.mode
		signature = key
		if mode_changed:
			call_deferred("build")
			return
		if model.state.mode == "campaign" and FieldOperations.enabled(model.state): build_army_roster()
		else: build_roster()
	if is_instance_valid(time_button):
		time_button.icon = FieldUI.icon("Play" if model.state.paused else "Pause")
		time_button.tooltip_text = "Resume time" if model.state.paused else "Pause time"
		time_button.toggle_mode = true
		time_button.set_pressed_no_signal(not model.state.paused)
		for button in time_button.get_parent().get_children():
			if button.has_meta("speed"):
				button.button_pressed = model.state.speed == button.get_meta("speed")
	cash_label.text = "%d men   %d F" % [FieldData.men(model.state.units), model.state.cash]
	if model.state.mode == "campaign":
		for button in march_buttons:
			button.button_pressed = model.state.army.marchMode == button.get_meta("march_mode")
		clock_label.text = ("April %d, 1796 / %02d:%02d" if model.state.theater == "italy" else "October %d, 1805 / %02d:%02d") % [10 + int(model.state.hours / 24), int(model.state.hours) % 24, int(fmod(model.state.hours, 1) * 60)]
		var enemies = model.state.enemies.filter(func(e): return not e.defeated)
		mission_label.text = "Campaign complete" if enemies.is_empty() else "Engage the advance guard" if model.state.victories == 0 else "Defeat the remaining armies"
		objective_label.text = "%d / 3 armies defeated" % model.state.victories
		if FieldOperations.enabled(model.state):
			clock_label.text = "August %d, 1796 / %02d:%02d" % [1 + int(model.state.hours / 24), int(model.state.hours) % 24, int(fmod(model.state.hours, 1) * 60)]
			mission_label.text = "Operation won" if model.state.operation.status == "victory" else "Army destroyed" if model.state.operation.status == "defeat" else "Secure Mantua and Valeggio"
			var held = model.state.operation.sites.filter(func(site): return site.id in ["mantua", "valeggio"] and site.owner == "player").size()
			objective_label.text = "%d / 2 objectives / %d%% final hold\nRetain a supply depot" % [held, mini(100, int(model.state.operation.hold * 50))]
			for a in model.state.armies:
				if not roster_labels.has(a.id): continue
				var item: Dictionary = roster_labels[a.id]
				item.button.button_pressed = a.id in model.state.armySelection
				item.button.disabled = a.defeated
				item.status.text = "%d men / M %d / F %d%%" % [FieldData.men(FieldOperations.roster(model.state, a)), a.morale, 100 - a.condition]
				if a.retreatUntil > model.state.hours:
					item.status.text = "Withdrawing / Queued" if a.get("pendingOrder") != null else "Withdrawing" if FieldOperations.forced_retreat(model.state, a) else "Marching / recovery" if not a.path.is_empty() else "Recover " + FieldOperations.regroup_time(model.state, a)
					if FieldOperations.pursuit_paused(model.state, a): item.status.text = "Reforming / Queued" if a.get("pendingOrder") != null else "Reforming"
					elif a.get("pendingOrder") != null and not FieldOperations.forced_retreat(model.state, a): item.status.text = "March queued / Paused" if model.state.paused else "March queued"
				item.morale.value = a.morale
				item.condition.value = a.condition
				item.button.tooltip_text = "%s\n%s / %s\nSupply %d / Morale damage %+d%%" % [a.name, a.commander, a.intent, a.supply, roundi((FieldOperations.morale_factor(a.morale) - 1) * 100)]
				if a.retreatUntil > model.state.hours: item.button.tooltip_text += "\nRecovery: " + FieldOperations.regroup_time(model.state, a) + " / March pace 70%"
				if a.get("pendingOrder") != null: item.button.tooltip_text += "\nMarch queued after reforming" if FieldOperations.pursuit_paused(model.state, a) else "\nMarch queued after forced withdrawal" if FieldOperations.forced_retreat(model.state, a) else "\nMarch ready when campaign time resumes"
		if model.state.paused: clock_label.text += " / Paused"
	else:
		var b: Dictionary = model.state.battle
		clock_label.text = "%d:%02d elapsed / %s" % [int(b.time / 60), int(b.time) % 60, "Paused" if model.state.paused else "Clear skies"]
		mission_label.text = "Hold the heights" if b.scenario == "ridge" else "Secure the crossing" if b.scenario == "bridge" else "Capture the village"
		objective_label.text = "%d / %ds held%s" % [int(b.objective.player), int(model.terrain.field.objective.seconds), "\nEnemy reserves approaching" if b.units.any(func(u): return u.side == "enemy" and u.arrival > b.time) else ""]
		if world.show_ai and b.has("ai"): objective_label.text += "\nEnemy plan: " + b.ai.stance.capitalize()
		if is_instance_valid(roster):
			for button in roster.get_children():
				if button.has_meta("commander"):
					var commander = model.find_id(b.commanders, button.get_meta("commander"))
					button.disabled = commander.get("arrival", 0.0) > b.time
					button.set_pressed_no_signal(model.state.selectedCommander == commander.id)
				if button.has_meta("supply"):
					button.set_pressed_no_signal(model.state.selectedSupply)
			if roster_labels.has("supply"):
				var stock = 0.0
				for wagon in b.wagons:
					if wagon.side == "player": stock += wagon.stock
				roster_labels.supply.stock.text = "%d stores" % stock
		if b.has("campaignForces"):
			var incoming = b.campaignForces.filter(func(entry): return entry.side == "player" and entry.arrival > b.time)
			if not incoming.is_empty():
				incoming.sort_custom(func(a, other): return a.arrival < other.arrival)
				objective_label.text += "\nFriendly reinforcements: %ds" % ceili(incoming[0].arrival - b.time)
		for u in b.units:
			if not roster_labels.has(u.id): continue
			var item: Dictionary = roster_labels[u.id]
			item.button.button_pressed = u.id in model.state.selected
			item.button.disabled = u.men <= 0 or u.routed or u.withdrawn or u.arrival > b.time
			item.strength.text = str(int(u.men))
			var status = unit_status(u)
			item.status.text = compact_status(status)
			var status_color = FieldUI.RED if u.routed or u.morale < 35 or u.get("firePressureUntil", 0.0) > b.time else FieldUI.MUTED
			if item.status.get_theme_color("font_color") != status_color: item.status.add_theme_color_override("font_color", status_color)
			item.button.tooltip_text = "%s\n%s / %.1f XP\nMorale %d%% / Fatigue %d%% / Ammunition %d%%" % [u.name, unit_status(u), u.experience, u.morale, 100 - u.condition, u.ammo]
			item.morale.value = u.morale
			item.condition.value = u.condition
		if is_instance_valid(action_row):
			var selection = model.selected_units()
			if is_instance_valid(command_caption):
				command_caption.text = selection[0].name if selection.size() == 1 else "%d regiments selected" % selection.size() if not selection.is_empty() else "Supply train" if model.state.selectedSupply else "Army command" if model.state.selectedCommander != null else "Army orders"
			for control in corps_row.get_children():
				if control.has_meta("corps"):
					var corps_id = control.get_meta("corps")
					var members = b.units.filter(func(u): return u.side == "player" and u.corpsId == corps_id and u.men > 0 and not u.routed and not u.withdrawn)
					control.set_pressed_no_signal(not members.is_empty() and members.all(func(u): return u.id in model.state.selected))
			for button in action_row.get_children():
				if not button is Button: continue
				if button.tooltip_text in ["Withdraw from battle", "Rally"]: continue
				button.disabled = selection.is_empty() and not (button.tooltip_text == "Halt" and (model.state.selectedSupply or model.state.selectedCommander != null)) and not (button.tooltip_text == "General follows army" and model.state.selectedCommander != null)
				var command = button.tooltip_text
				if command == "Leave defensive position": button.disabled = not selection.any(func(u): return u.coverId != null or u.coverOrderId != null)
				if command == "Charge": button.disabled = not selection.any(func(u): return FieldCharge.eligible(u, b.time))
				if command.ends_with(" formation"):
					var formation_name = command.trim_suffix(" formation").to_lower()
					button.disabled = not selection.any(func(u): return u.kind == "infantry")
					button.toggle_mode = true
					button.button_pressed = not selection.is_empty() and selection.all(func(u): return (u.formationChange.to if u.formationChange != null else u.formation) == formation_name)
				if command == "Limber / deploy guns": button.disabled = not selection.any(func(u): return u.kind == "artillery")
				if command == "Dismount / mount": button.disabled = not selection.any(func(u): return u.kind == "cavalry" and FieldData.weapons()[u.weapon].get("dismount", false))
				if command == "Detach / recall skirmishers": button.disabled = not selection.any(func(u): return u.kind == "infantry")
				if command in ["Run / walk", "Melee only / fire at will", "Dismount / mount", "Limber / deploy guns"]:
					var flag = {"Run / walk": "running", "Melee only / fire at will": "holdFire", "Dismount / mount": "dismounted", "Limber / deploy guns": "limbered"}[command]
					button.toggle_mode = true
					button.button_pressed = not selection.is_empty() and selection.all(func(u): return u[flag])
	if is_instance_valid(minimap): minimap.queue_redraw()
	if model.state.report != null and not is_instance_valid(modal):
		call_deferred("report_dialog")

func compact_status(status: String) -> String:
	if status.contains(" men / "): return "Ready"
	return {"Packing to retreat": "Packing", "Taking position": "Moving", "Manning position": "Manning", "Preparing guns": "Preparing", "Rear attack!": "Rear!", "Flank attack!": "Flank!", "Falling back": "Fallback", "Melee only": "Melee"}.get(status, status.get_slice(" / ", 0))

func unit_status(u: Dictionary) -> String:
	if u.men <= 0: return "Destroyed"
	if u.withdrawn: return "Withdrawn"
	if u.arrival > model.state.battle.time: return "Incoming"
	if u.routed: return "Routing"
	if u.retreating: return "Packing to retreat" if u.limberChange > 0 else "Retreating"
	if u.get("firePressureUntil", 0.0) > model.state.battle.time: return "Rear attack!" if u.firePressure == "rear" else "Flank attack!"
	if not u.movementBlocked.is_empty(): return u.movementBlocked
	if u.coverOrderId != null: return "Taking position"
	if u.coverId != null: return "In cover" if u.coverDeploy >= 4 else "Manning position"
	if u.formationChange != null: return "Reforming / %ds" % ceili(u.formationChange.duration - u.formationChange.elapsed)
	if u.limberChange > 0: return "Preparing guns"
	if u.limbered: return "Limbered"
	if u.charging: return "Charging / %d%%" % roundi(FieldCharge.momentum(u) * 100)
	if u.chargeImpactUntil > model.state.battle.time: return "Charge impact"
	if u.fallingBack: return "Falling back"
	if u.target != null: return "Running" if u.running else "Marching"
	if u.holdFire: return "Melee only"
	if not u.blocked.is_empty(): return u.blocked
	if u.fireTargetId != null: return "Engaging" if not u.aimComplete and u.attackId != null else "Reloading" if u.reload > 0 else "Firing"
	return "%d men / %d%% fatigue" % [u.men, roundi(100 - u.condition)]

func notify(message: String) -> void:
	toast_time = 4.0
	if is_instance_valid(toast): toast.text = message

func inspect(entity: Dictionary) -> void:
	remove_node(inspector)
	inspected_id = entity.id
	inspector = PanelContainer.new()
	var size_value = get_viewport().get_visible_rect().size
	inspector.position = Vector2(16 if size_value.x < 740 else 22, minf(size_value.y - world.ui_bottom - 244, world.ui_top + 264))
	inspector.size = Vector2(minf(290, size_value.x - 84), 0)
	root.add_child(inspector)
	var column = VBoxContainer.new()
	inspector.add_child(column)
	var head = HBoxContainer.new()
	head.add_child(FieldUI.insignia(entity.kind, 22, entity.side))
	var name = FieldUI.wrapped(entity.name, 22, FieldUI.TEXT)
	name.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	head.add_child(name)
	head.add_child(FieldUI.button("", "X", func(): remove_node(inspector); inspected_id = "", "Close unit information"))
	column.add_child(head)
	column.add_child(FieldUI.label(entity.kind.capitalize(), 11, FieldUI.GOLD))
	if entity.has("weapon"):
		column.add_child(FieldUI.wrapped(FieldData.weapons()[entity.weapon].name, 12))
		column.add_child(FieldUI.wrapped("%d men / %s" % [entity.men, FieldArsenal.summary(FieldData.weapons()[entity.weapon])], 12))
		column.add_child(FieldUI.label("Morale %d%% / Fatigue %d%%" % [entity.morale, 100 - entity.condition], 12, FieldUI.MUTED))
		column.add_child(FieldUI.label("Ammunition %d%% / Kills %d" % [entity.ammo, entity.kills], 12, FieldUI.MUTED))
		if entity.has("armyMorale"): column.add_child(FieldUI.label("Army resolve: %s / morale damage %+d%%" % [FieldOperations.morale_name(entity.armyMorale), roundi((FieldOperations.morale_factor(entity.armyMorale) - 1) * 100)], 11, FieldUI.GOLD))
		column.add_child(FieldUI.wrapped(unit_status(entity), 12, FieldUI.GOLD))
		if world.show_ai and entity.side == "enemy" and entity.has("ai"):
			column.add_child(FieldUI.wrapped("AI / " + entity.ai.state.capitalize(), 12, FieldUI.GOLD))
			column.add_child(FieldUI.wrapped(entity.ai.reason, 11, FieldUI.MUTED))
			column.add_child(FieldUI.wrapped(model.state.battle.ai.personality.capitalize() + " / " + model.state.battle.ai.reason, 11, FieldUI.MUTED))
	elif entity.kind == "wagon":
		column.add_child(FieldUI.label("%d supplies / %d%% integrity" % [entity.stock, entity.health], 12))
	elif entity.kind == "general":
		column.add_child(FieldUI.label("%dm command radius" % entity.radius, 12))
	else:
		column.add_child(FieldUI.label("~%d troops / reported" % entity.men if entity.get("uncertain", false) else "%d troops" % entity.men, 12))
		if FieldOperations.enabled(model.state) and not entity.get("uncertain", false):
			column.add_child(FieldUI.wrapped(entity.commander, 13, FieldUI.GOLD))
			column.add_child(FieldUI.label("%s / %d morale / %d%% fatigue" % [FieldOperations.morale_name(entity.morale), entity.morale, 100 - entity.condition], 11))
			column.add_child(FieldUI.label("Supply %d / morale damage %+d%%" % [entity.supply, roundi((FieldOperations.morale_factor(entity.morale) - 1) * 100)], 11))
			column.add_child(FieldUI.label(entity.intent, 11, FieldUI.GOLD))
			if entity.retreatUntil > model.state.hours:
				column.add_child(FieldUI.label("Recovery: %dm / march pace 70%%" % ceili((entity.retreatUntil - model.state.hours) * 60), 11, FieldUI.GOLD))
				if entity.get("pendingOrder") != null:
					column.add_child(FieldUI.label("March queued after reforming" if FieldOperations.pursuit_paused(model.state, entity) else "March queued after withdrawal" if FieldOperations.forced_retreat(model.state, entity) else "March ready when time resumes", 11, FieldUI.GOLD))
			if not entity.path.is_empty():
				var hours = FieldOperations.travel_hours(model.terrain, entity, entity.path, FieldOperations.recovery_pace(model.state, entity))
				column.add_child(FieldUI.label("Arrival in %dh %02dm" % [int(hours), int(fmod(hours, 1) * 60)], 11, FieldUI.GOLD))
			if entity.side == "player":
				column.add_child(FieldUI.button("Split army", "Users", split_dialog))
				column.add_child(FieldUI.button("Merge armies", "ArrowDownToLine", merge_dialog))
		if entity.get("personality") != null and not entity.get("uncertain", false):
			column.add_child(FieldUI.wrapped("%s / %s" % [entity.personality.capitalize(), entity.get("intent", "Patrolling")], 12, FieldUI.MUTED))
			column.add_child(FieldUI.label("Fatigue %d%%" % [100 - entity.condition], 12, FieldUI.MUTED))
	column.add_child(FieldUI.button("Center", "Crosshair", func(): world.center_entity(entity)))

func open_headquarters() -> void:
	if is_instance_valid(hq): return
	model.state.paused = true
	world.input_blocked = true
	remove_node(inspector)
	hq = FieldHeadquarters.new()
	hq.z_index = 10
	root.add_child(hq)
	hq.setup(model)
	hq.closed.connect(func(): remove_node(hq); world.input_blocked = false; refresh())
	hq.notify.connect(notify)

func begin_modal(title_text: String) -> VBoxContainer:
	remove_node(modal)
	model.state.paused = true
	world.input_blocked = true
	modal = Control.new()
	modal.z_index = 20
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.05, 0.07, 0.80)
	modal.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel = PanelContainer.new()
	panel.name = "DispatchFrame"
	panel.add_theme_stylebox_override("panel", FieldUI.plate(Color("24282e"), FieldUI.GOLD, 18))
	panel.custom_minimum_size.x = minf(620, get_viewport().get_visible_rect().size.x - 32)
	center.add_child(panel)
	panel.add_child(FieldUI.paper_grain())
	var scroll = ScrollContainer.new()
	scroll.name = "DispatchScroll"
	scroll.custom_minimum_size.y = minf(540, get_viewport().get_visible_rect().size.y - 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var top = HBoxContainer.new()
	var modal_title = FieldUI.wrapped(title_text, 30, FieldUI.TEXT)
	modal_title.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	top.add_child(modal_title)
	top.add_child(FieldUI.spacer())
	top.add_child(FieldUI.button("", "X", close_modal, "Close"))
	column.add_child(top)
	column.add_child(HSeparator.new())
	return column

func close_modal() -> void:
	if is_instance_valid(modal) and modal.get_meta("report", false) and model.state.report != null:
		model.dismiss_report()
		if exercise:
			campaign_requested.emit()
			return
	remove_node(modal)
	modal = null
	world.input_blocked = is_instance_valid(hq)
	refresh()

func save_game() -> void:
	if exercise:
		notify("Exercises do not overwrite the campaign.")
		return
	notify("Campaign saved." if model.save_campaign() else "Unable to write the campaign save.")

func settings_dialog() -> void:
	var column = begin_modal("Field Options")
	var sound = CheckBox.new()
	sound.text = "Sound"
	sound.button_pressed = model.state.settings.sound
	sound.toggled.connect(func(value): model.set_sound(value, model.state.settings.volume))
	column.add_child(sound)
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = model.state.settings.volume
	volume.custom_minimum_size.y = 30
	volume.value_changed.connect(func(value): model.set_sound(model.state.settings.sound, value))
	column.add_child(FieldUI.label("Volume", 12, FieldUI.MUTED))
	column.add_child(volume)
	if model.state.battle != null:
		var diagnostics = CheckBox.new()
		diagnostics.name = "AIDiagnostics"
		diagnostics.text = "AI diagnostics"
		diagnostics.button_pressed = world.show_ai
		diagnostics.toggled.connect(func(value):
			world.show_ai = value
			world.invalidate()
			refresh()
			if is_instance_valid(inspector):
				var entity = model.find_id(model.state.battle.units, inspected_id)
				if not entity.is_empty(): inspect(entity)
		)
		column.add_child(diagnostics)
	column.add_child(HSeparator.new())
	column.add_child(FieldUI.button("Save campaign", "Save", save_game, "Save current campaign", exercise))
	column.add_child(FieldUI.button("Load campaign", "RotateCcw", func():
		loading = true
		var ok = model.load_campaign(model.save_path)
		loading = false
		close_modal()
		build()
		notify("Campaign loaded." if ok else "No valid campaign save was found.")
	, "Load native campaign save", exercise))
	column.add_child(FieldUI.button("Import browser save", "ArrowDownToLine", import_dialog, "Import a version 3 browser campaign JSON", exercise))
	column.add_child(FieldUI.button("Dispatches", "Flag", journal_dialog))
	column.add_child(HSeparator.new())
	column.add_child(FieldUI.label("New campaign", 24, FieldUI.GOLD, true))
	for theater in ["mantua", "italy", "danube"]:
		column.add_child(FieldUI.button("Mantua operation" if theater == "mantua" else "Northern Italy sector" if theater == "italy" else "Danube campaign", "Flag", func(): confirm_new(theater)))
	column.add_child(FieldUI.button("Return to map", "ArrowLeft", close_modal))

func journal_dialog() -> void:
	var column = begin_modal("Dispatches")
	for entry in model.state.log:
		column.add_child(FieldUI.label("%02d:%02d" % [int(entry.hours) % 24, int(fmod(entry.hours, 1) * 60)], 11, FieldUI.GOLD))
		column.add_child(FieldUI.wrapped(entry.text, 13, FieldUI.TEXT))
		column.add_child(HSeparator.new())
	column.add_child(FieldUI.button("Return to map", "ArrowLeft", close_modal))

func confirm_new(theater: String) -> void:
	var column = begin_modal("New Campaign")
	column.add_child(FieldUI.wrapped("Replace the current native campaign? The browser campaign is not affected.", 14, FieldUI.TEXT))
	column.add_child(FieldUI.button("Begin new campaign", "Flag", func(): new_campaign_requested.emit(theater)))
	column.add_child(FieldUI.button("Cancel", "X", close_modal))

func import_dialog() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; Campaign JSON"])
	dialog.use_native_dialog = true
	root.add_child(dialog)
	dialog.file_selected.connect(func(path):
		loading = true
		var ok = model.load_campaign(path, true)
		loading = false
		dialog.queue_free()
		close_modal()
		build()
		notify("Browser campaign imported." if ok else "Invalid or unsupported campaign JSON. Current campaign preserved.")
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.8)

func skirmish_dialog() -> void:
	var column = begin_modal("Battle Exercises")
	column.add_child(FieldUI.button("Mincio / 12 vs 12", "Swords", func(): skirmish_requested.emit("polish")))
	column.add_child(FieldUI.button("Mincio / 20 vs 20", "Swords", func(): skirmish_requested.emit("grand")))
	column.add_child(FieldUI.button("Coordinated Defense", "Shield", func(): skirmish_requested.emit("defense")))
	for scenario in ["bridge", "village", "ridge"]:
		column.add_child(FieldUI.button({"bridge": "The Valeggio Crossing", "village": "Saint Martin", "ridge": "The Heights"}[scenario], "Swords", func(): skirmish_requested.emit(scenario)))
	column.add_child(FieldUI.button("Return to campaign", "ArrowLeft", close_modal))

func return_campaign() -> void:
	if exercise:
		campaign_requested.emit()
	elif model.state.mode == "battle":
		var column = begin_modal("Withdraw From Battle")
		column.add_child(FieldUI.wrapped("Order a retreat toward a friendly depot? Casualties persist and army morale will fall." if FieldOperations.enabled(model.state) else "Withdraw to the forward depot? Existing casualties are retained; no victory reward is paid.", 14, FieldUI.TEXT))
		column.add_child(FieldUI.button("Withdraw", "ArrowLeft", func():
			close_modal()
			model.finish_battle(false, true)
		))
		column.add_child(FieldUI.button("Remain in battle", "X", close_modal))
	else:
		world.home()

func report_dialog() -> void:
	if model.state.report == null: return
	var r: Dictionary = model.state.report
	var column = begin_modal("Victory" if r.won else "Army Withdrawn" if r.retreat else "Defeat")
	modal.set_meta("report", true)
	column.add_child(FieldUI.label("AFTER-ACTION DISPATCH", 10, FieldUI.GOLD))
	var heading = HBoxContainer.new()
	var commander = model.find_id(model.state.officers, model.state.army.get("officerId"))
	heading.add_child(FieldUI.portrait_frame(commander.get("portrait", 0), 52))
	var title = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(FieldUI.wrapped(r.name, 22, FieldUI.TEXT))
	title.add_child(FieldUI.wrapped(model.state.army.commander if FieldOperations.enabled(model.state) else model.state.general.name, 12, FieldUI.MUTED))
	heading.add_child(title)
	column.add_child(heading)
	var figures = HBoxContainer.new()
	for spec in [["OUR LOSSES", r.casualties, FieldUI.RED], ["ENEMY LOSSES", r.enemyCasualties, FieldUI.TEXT], ["AWARD / F", r.reward, FieldUI.GOLD]]:
		var item = VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(FieldUI.label(spec[0], 9, FieldUI.MUTED))
		item.add_child(FieldUI.label(str(int(spec[1])), 27, spec[2], true))
		figures.add_child(item)
	column.add_child(figures)
	for change in r.get("armyMorale", []):
		column.add_child(FieldUI.wrapped("%s / morale %d -> %d (%+d)" % [change.name, change.before, change.after, change.after - change.before], 12, FieldUI.BLUE if change.after >= change.before else FieldUI.RED))
	if r.complete: column.add_child(FieldUI.label("All opposing armies defeated", 20, FieldUI.GOLD, true))
	column.add_child(FieldUI.section("Regimental Returns", "Users"))
	var returns = GridContainer.new()
	returns.name = "RegimentalReturns"
	returns.columns = 4
	returns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	returns.add_theme_constant_override("h_separation", 10)
	for label in ["REGIMENT", "PRESENT", "LOST", "INFLICTED"]: returns.add_child(FieldUI.label(label, 9, FieldUI.MUTED))
	for u in r.regiments:
		returns.add_child(FieldUI.wrapped(u.name, 12, FieldUI.TEXT))
		for key in ["men", "losses", "kills"]:
			var value: float = u[key]
			var number = FieldUI.label(str(int(value)), 12, FieldUI.RED if key == "losses" and value > 0 else FieldUI.TEXT)
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			returns.add_child(number)
	column.add_child(returns)
	var recovered: Dictionary = r.get("capturedWeapons", {"musket": r.loot})
	if recovered.values().any(func(amount): return amount > 0):
		column.add_child(FieldUI.section("Captured Stores", "Swords"))
		for key in recovered:
			if recovered[key] <= 0: continue
			var row = HBoxContainer.new()
			var weapon = FieldUI.weapon_art(key, 38)
			weapon.custom_minimum_size.x = 82
			row.add_child(weapon)
			var damaged: int = r.get("damagedWeapons", {}).get(key, 0)
			row.add_child(FieldUI.wrapped("%d %s / %d ready, %d need refit" % [recovered[key], FieldData.weapons()[key].name, recovered[key] - damaged, damaged], 12, FieldUI.GOLD))
			column.add_child(row)
	if not r.officers.is_empty(): column.add_child(FieldUI.section("Officer Dispatches", "Award"))
	for o in r.officers:
		column.add_child(FieldUI.wrapped(o.name + " / " + o.status, 12, FieldUI.GOLD))
	column.add_child(FieldUI.button("Return to campaign", "ArrowLeft", func():
		model.dismiss_report()
		if exercise: campaign_requested.emit()
		else: close_modal(); build()
	))

func _process(dt: float) -> void:
	if Vector2(width, height) != get_viewport().get_visible_rect().size:
		build()
		if is_instance_valid(modal):
			var frame = modal.find_child("DispatchFrame", true, false)
			var scroll = modal.find_child("DispatchScroll", true, false)
			if frame != null and scroll != null:
				frame.custom_minimum_size.x = minf(620, width - 32)
				scroll.custom_minimum_size.y = minf(540, height - 100)
				frame.reset_size()
	# Container wrapping settles after resize; keep map hit areas in step with it.
	update_map_obstacles()
	refresh_clock += dt
	if toast_time > 0:
		toast_time -= dt
		if toast_time <= 0 and is_instance_valid(toast): toast.text = ""
	if refresh_clock > 0.2:
		refresh_clock = 0
		if is_instance_valid(minimap): minimap.queue_redraw()
