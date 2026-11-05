class_name FieldHeadquarters
extends Control

signal closed
signal notify(message: String)
var model: FieldModel
var tab = "Army"
var selected_id = "u1"
var content: VBoxContainer
var unit_list: VBoxContainer
var detail: VBoxContainer
var unit_selection: OptionButton
var viewport_width = 0.0
var notice_text = ""
var selected_corps = "all"
var commander_dialog: AcceptDialog
var armory_kind = "infantry"
var armory_faction = "All"

func setup(game: FieldModel) -> void:
	model = game
	selected_id = game.army_units()[0].id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = FieldUI.theme()
	build()

func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func act(success: bool, message: String) -> void:
	notice_text = "" if success else message
	build()

func build() -> void:
	clear()
	viewport_width = get_viewport_rect().size.x
	var narrow = viewport_width < 740
	var background = ColorRect.new()
	background.color = Color("171b1b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var map_art = FieldUI.atlas_background()
	map_art.name = "HeadquartersAtlas"
	map_art.modulate = Color(0.68, 0.72, 0.77)
	map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map_art)
	var frame = VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	var header = HBoxContainer.new()
	header.add_child(FieldUI.button("", "ArrowLeft", func(): closed.emit(), "Return to map"))
	var heading = VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.add_child(FieldUI.label("Army Headquarters", 26 if narrow else 32, FieldUI.TEXT, true))
	if not narrow: heading.add_child(FieldUI.label("ETAT-MAJOR / " + ("ITALIAN THEATER" if model.state.theater != "danube" else "DANUBE THEATER"), 10, FieldUI.MUTED))
	header.add_child(heading)
	header.add_child(FieldUI.spacer())
	if not narrow:
		header.add_child(FieldUI.label("%d men    %d F" % [FieldData.men(model.army_units()), model.state.cash], 13, FieldUI.GOLD))
	var header_band = PanelContainer.new()
	header_band.add_theme_stylebox_override("panel", FieldUI.plate(Color(0.09, 0.10, 0.12, 0.93), FieldUI.RULE, 12))
	header_band.add_child(header)
	frame.add_child(header_band)
	var tabs = HBoxContainer.new()
	for name in ["Army", "Armory", "Officers"]:
		var button = FieldUI.button(name, {"Army": "Shield", "Armory": "Swords", "Officers": "Users"}[name], func(): tab = name; build())
		button.toggle_mode = true
		button.theme_type_variation = "FieldTab"
		button.button_pressed = tab == name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	if not notice_text.is_empty():
		frame.add_child(FieldUI.margin(FieldUI.wrapped(notice_text, 12, FieldUI.GOLD), 12))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin = FieldUI.margin(content, 16 if narrow else 24)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if tab == "Army" and not narrow:
		scroll.free()
		frame.add_child(margin)
	else:
		frame.add_child(scroll)
		scroll.add_child(margin)
	if model.state.mode == "battle":
		content.add_child(FieldUI.label("Field inspection / administration unavailable during battle", 12, FieldUI.GOLD))
	if tab == "Army":
		build_army(narrow)
	elif tab == "Armory":
		build_armory(narrow)
	else:
		build_officers(narrow)
	frame.add_child(FieldUI.margin(tabs, 12))

func available_commanders(target: Dictionary) -> Array:
	var required = 0 if target.get("kind") == "artillery" else 1 if target.has("kind") else 3
	return model.state.officers.filter(func(o):
		return FieldData.ready(o, model.state.hours) and FieldData.rank_of(o) >= required and not model.command_targets().any(func(item): return item.get("officerId") == o.id)
	)

func choose_commander(target: Dictionary) -> void:
	if model.state.mode != "campaign": return
	commander_dialog = AcceptDialog.new()
	commander_dialog.title = "Assign commander / " + target.name
	commander_dialog.ok_button_text = "Close"
	commander_dialog.theme = FieldUI.theme()
	commander_dialog.theme.set_stylebox("panel", "AcceptDialog", FieldUI.box(FieldUI.INK, FieldUI.GOLD, 16))
	add_child(commander_dialog)
	var candidates = available_commanders(target)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(minf(420, get_viewport_rect().size.x - 50), minf(maxf(112, candidates.size() * 66), minf(360, get_viewport_rect().size.y - 180)))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	commander_dialog.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if candidates.is_empty():
		list.add_child(FieldUI.wrapped("No available officers of the required rank.", 13))
		list.add_child(FieldUI.button("Officers", "Users", func(): tab = "Officers"; build()))
	for officer in candidates:
		var row = HBoxContainer.new()
		row.add_child(FieldUI.portrait(officer.portrait, 48))
		var title = "%s %s\n%s" % [FieldData.load_data().ranks[FieldData.rank_of(officer)], officer.name, officer.specialty]
		var current = model.find_id(model.state.officers, target.get("officerId"))
		title += " / %d XP (%+d)" % [officer.xp, officer.xp - current.get("xp", 0)]
		var assign = FieldUI.button(title, "", func(): act(model.assign_officer(target.id, officer.id), "Officer is no longer available."))
		assign.tooltip_text = "Assign " + officer.id
		assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		assign.alignment = HORIZONTAL_ALIGNMENT_LEFT
		assign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(assign)
		list.add_child(row)
	commander_dialog.popup_centered()

func commander_portrait(target: Dictionary, size_value: int = 64) -> Button:
	var officer = model.find_id(model.state.officers, target.officerId)
	var button = FieldUI.button("", "", func(): choose_commander(target), "Change commander: " + target.name, model.state.mode != "campaign")
	button.custom_minimum_size = Vector2(size_value, size_value)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var portrait = FieldUI.portrait(officer.get("portrait", 15), 0)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.set_offset(SIDE_LEFT, 3)
	portrait.set_offset(SIDE_TOP, 3)
	portrait.set_offset(SIDE_RIGHT, -3)
	portrait.set_offset(SIDE_BOTTOM, -3)
	button.add_child(portrait)
	return button

func commander_name(target: Dictionary) -> Button:
	var button = FieldUI.button(target.commander, "", func(): choose_commander(target), "Change commander: " + target.name, model.state.mode != "campaign")
	button.custom_minimum_size = Vector2(0, 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", FieldUI.box(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", FieldUI.box(Color("353b3b"), Color.TRANSPARENT, 0))
	return button

func regiment_tile(u: Dictionary) -> Button:
	var tile = FieldUI.button("", "", func(): selected_id = u.id; build(), "Inspect " + u.name)
	tile.custom_minimum_size = Vector2(164, 96)
	tile.theme_type_variation = "FieldRecord"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.toggle_mode = true
	tile.button_pressed = selected_id == u.id
	var inner = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 9
	inner.offset_right = -9
	inner.offset_top = 6
	inner.offset_bottom = -8
	inner.add_theme_constant_override("separation", 3)
	tile.add_child(inner)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(FieldUI.troop_art(u.kind, 38, 62))
	var text = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)
	inner.add_child(row)
	var heading = FieldUI.wrapped(u.name, 12, FieldUI.GOLD if selected_id == u.id else FieldUI.TEXT)
	heading.custom_minimum_size.y = 28
	heading.max_lines_visible = 2
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(heading)
	text.add_child(FieldUI.label("%d" % u.men, 23, FieldUI.TEXT, true))
	inner.add_child(FieldUI.label("%s / %.1f XP" % [u.kind.capitalize(), u.experience], 10, FieldUI.GOLD if u.perk != null else FieldUI.MUTED))
	var strength = FieldUI.bar(u.men / maxf(1, u.maxMen) * 100, FieldUI.BLUE)
	strength.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(strength)
	return tile

func officer_select(target: Dictionary) -> OptionButton:
	var officers = model.state.officers.filter(func(o): return o.hired)
	var labels: Array = ["Vacant command"]
	var selected = 0
	for i in officers.size():
		var o: Dictionary = officers[i]
		var assigned: Dictionary = {}
		for item in model.command_targets():
			if item.officerId == o.id:
				assigned = item
		labels.append(FieldData.load_data().ranks[FieldData.rank_of(o)] + " " + o.name + (" / killed" if o.dead else " / wounded" if o.woundedUntil > model.state.hours else " / " + assigned.name if not assigned.is_empty() and assigned.id != target.id else ""))
		if o.id == target.officerId:
			selected = i + 1
	var dropdown = FieldUI.select(labels, selected, func(index):
		if index > 0:
			act(model.assign_officer(target.id, officers[index - 1].id), "Officer unavailable or rank too low for this command.")
	)
	dropdown.disabled = model.state.mode != "campaign"
	dropdown.set_item_disabled(0, true)
	for i in officers.size():
		var required = 0 if target.get("kind") == "artillery" else 1 if target.has("kind") else 3
		dropdown.set_item_disabled(i + 1, not FieldData.ready(officers[i], model.state.hours) or FieldData.rank_of(officers[i]) < required)
	return dropdown

func build_army(narrow: bool) -> void:
	var economy = HBoxContainer.new()
	if FieldOperations.enabled(model.state):
		var armies: Array = model.state.armies
		var selector = FieldUI.select(armies.map(func(a): return a.name), armies.find(model.state.army), func(index):
			model.select_armies([armies[index].id])
			selected_id = model.army_units()[0].id
			selected_corps = "all"
			build()
		)
		selector.disabled = model.state.mode != "campaign"
		economy.add_child(selector)
	else: economy.add_child(FieldUI.label("ARMY OF ITALY" if model.state.theater == "italy" else "ARMY OF THE DANUBE", 15, FieldUI.GOLD, true))
	economy.add_child(FieldUI.spacer())
	if not narrow: economy.add_child(FieldUI.label("%d regiments    %d supplies" % [model.army_units().size(), model.state.supply], 12, FieldUI.MUTED))
	content.add_child(economy)
	if FieldOperations.enabled(model.state):
		content.add_child(FieldUI.wrapped("%s / %s / Morale %d / Fatigue %d%%" % [model.state.army.commander, FieldOperations.morale_name(model.state.army.morale), model.state.army.morale, 100 - model.state.army.condition], 12, FieldUI.MUTED))
		if viewport_width < 1200: content.add_child(commander_name(model.state.army))
	var actions = HFlowContainer.new()
	for kind in ["infantry", "cavalry", "artillery"]:
		actions.add_child(FieldUI.button("" if narrow else "Recruit " + kind, {"infantry": "Shield", "cavalry": "Swords", "artillery": "Target"}[kind], func(): act(model.recruit(kind), "Recruitment needs money, reserve weapons, and a free corps slot."), "Recruit " + kind, model.state.mode != "campaign"))
	actions.add_child(FieldUI.button("" if narrow else "Light company", "Binoculars", func(): act(model.recruit("company"), "Company recruitment needs 400 F, 100 muskets, and a free corps slot at a depot."), "Recruit 100-man light company / 400 F", model.state.mode != "campaign"))
	actions.add_child(FieldUI.button("" if narrow else "Resupply", "Truck", func(): act(model.resupply(), "Supply is full or funds are insufficient."), "Resupply: %d F" % model.resupply_cost(), model.state.mode != "campaign"))
	content.add_child(actions)
	var layout: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	content.add_child(layout)
	if not narrow:
		if viewport_width >= 1200:
			var commands = VBoxContainer.new()
			commands.custom_minimum_size.x = 174
			commands.add_theme_constant_override("separation", 10)
			commands.add_child(FieldUI.label("1805" if model.state.theater == "danube" else "1796", 40, FieldUI.TEXT, true))
			commands.add_child(FieldUI.label("ARMY COMMAND", 10, FieldUI.GOLD))
			commands.add_child(commander_portrait(model.state.army, 92) if FieldOperations.enabled(model.state) else FieldUI.portrait_frame(0, 86))
			commands.add_child(FieldUI.wrapped(model.state.army.commander if FieldOperations.enabled(model.state) else model.state.general.name, 16, FieldUI.GOLD))
			commands.add_child(HSeparator.new())
			var all_corps = FieldUI.button("All corps", "Users", func(): selected_corps = "all"; build())
			all_corps.theme_type_variation = "FieldRecord"
			all_corps.toggle_mode = true
			all_corps.button_pressed = selected_corps == "all"
			commands.add_child(all_corps)
			for corps in model.army_corps():
				var choose = FieldUI.button(corps.name, "Shield", func(): selected_corps = corps.id; build())
				choose.theme_type_variation = "FieldRecord"
				choose.toggle_mode = true
				choose.button_pressed = selected_corps == corps.id
				commands.add_child(choose)
				var command_row = HBoxContainer.new()
				command_row.add_child(commander_portrait(corps, 42))
				command_row.add_child(commander_name(corps))
				commands.add_child(command_row)
			layout.add_child(commands)
		var roster_scroll = ScrollContainer.new()
		roster_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		layout.add_child(roster_scroll)
		unit_list = VBoxContainer.new()
		unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unit_list.add_theme_constant_override("separation", 14)
		roster_scroll.add_child(unit_list)
	else:
		var units: Array = model.army_units()
		var index = 0
		for i in units.size():
			if units[i].id == selected_id:
				index = i
		unit_selection = FieldUI.select(units.map(func(u): return u.name), index, func(i): selected_id = units[i].id; build())
		layout.add_child(unit_selection)
	for corps in model.army_corps():
		if not narrow:
			if selected_corps != "all" and selected_corps != corps.id and viewport_width >= 1200: continue
			var corps_header = HBoxContainer.new()
			corps_header.add_child(FieldUI.insignia("army", 26))
			corps_header.add_child(commander_portrait(corps, 46))
			var corps_title = VBoxContainer.new()
			corps_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			corps_title.add_child(FieldUI.label(corps.name, 24, FieldUI.GOLD, true))
			corps_title.add_child(commander_name(corps))
			corps_header.add_child(corps_title)
			var members = model.army_units().filter(func(u): return u.corpsId == corps.id)
			corps_header.add_child(FieldUI.label("%d / 4\n%d men" % [members.size(), FieldData.men(members)], 12, FieldUI.MUTED))
			unit_list.add_child(corps_header)
			unit_list.add_child(HSeparator.new())
			var regiments = GridContainer.new()
			regiments.columns = 4 if viewport_width >= 1500 else 3 if viewport_width >= 1320 else 2 if viewport_width >= 920 else 1
			unit_list.add_child(regiments)
			for u in model.army_units():
				if u.corpsId == corps.id:
					regiments.add_child(regiment_tile(u))
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not narrow:
		layout.add_child(VSeparator.new())
		var detail_scroll = ScrollContainer.new()
		detail_scroll.custom_minimum_size.x = 358
		detail_scroll.add_theme_stylebox_override("panel", FieldUI.plate(Color(0.10, 0.12, 0.14, 0.94), FieldUI.RULE, 12))
		detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		detail_scroll.add_child(detail)
		layout.add_child(detail_scroll)
	else:
		layout.add_child(detail)
	var unit = model.find_id(model.army_units(), selected_id)
	if unit.is_empty():
		unit = model.army_units()[0]
	build_unit(unit, narrow)
	if narrow:
		for corps in model.army_corps():
			content.add_child(FieldUI.label(corps.name, 24, FieldUI.GOLD, true))
			content.add_child(officer_select(corps))

func build_unit(u: Dictionary, narrow: bool) -> void:
	var editable = model.state.mode == "campaign"
	var officer = model.find_id(model.state.officers, u.officerId)
	detail.add_child(FieldUI.section("Regimental Record", "Shield"))
	var header = HBoxContainer.new()
	header.add_child(commander_portrait(u, 78 if narrow else 88))
	var title = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(FieldUI.wrapped(u.kind.to_upper(), 11, FieldUI.GOLD))
	var name = FieldUI.wrapped(u.name, 24, FieldUI.TEXT)
	name.add_theme_font_override("font", load("res://assets/fonts/Cormorant.woff2"))
	title.add_child(name)
	title.add_child(commander_name(u))
	header.add_child(title)
	detail.add_child(header)
	var naming = HBoxContainer.new()
	var edit = LineEdit.new()
	edit.text = u.name
	edit.max_length = 36
	edit.editable = editable
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(value): act(model.rename_regiment(u.id, value), "Enter a regiment name."))
	naming.add_child(edit)
	naming.add_child(FieldUI.button("", "Check", func(): act(model.rename_regiment(u.id, edit.text), "Enter a regiment name."), "Rename regiment", not editable))
	detail.add_child(naming)
	var available_corps = model.army_corps()
	var corps = FieldUI.select(available_corps.map(func(c): return c.name), available_corps.find(model.find_id(available_corps, u.corpsId)), func(index): act(model.assign_corps(u.id, available_corps[index].id), "Each corps can command at most four regiments."))
	corps.disabled = not editable
	detail.add_child(corps)
	detail.add_child(HSeparator.new())
	var strength_line = HBoxContainer.new()
	strength_line.add_child(FieldUI.label("%d" % u.men, 30, FieldUI.TEXT, true))
	strength_line.add_child(FieldUI.label("/ %d men" % u.maxMen, 11, FieldUI.MUTED))
	strength_line.add_child(FieldUI.spacer())
	strength_line.add_child(FieldUI.label("%.2f XP" % u.experience, 12, FieldUI.GOLD))
	detail.add_child(strength_line)
	for key in ["condition", "ammo"]:
		detail.add_child(FieldUI.label(("Condition" if key == "condition" else "Ammunition") + "  %d%%" % u[key], 11))
		detail.add_child(FieldUI.bar(u[key], FieldUI.FATIGUE if key == "condition" else FieldUI.BLUE))
	detail.add_child(FieldUI.section("Training", "Award"))
	var skill_grid = VBoxContainer.new()
	detail.add_child(skill_grid)
	for key in FieldData.load_data().skills:
		var row = HBoxContainer.new()
		var column = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(FieldUI.label(FieldData.load_data().skills[key] + "  %d" % u.skills[key], 11))
		column.add_child(FieldUI.bar(u.skills[key]))
		row.add_child(column)
		row.add_child(FieldUI.label("450 F", 10, FieldUI.MUTED))
		row.add_child(FieldUI.button("", "Plus", func(): act(model.train(u.id, key), "Drill requires 450 F and an available training slot."), "Train " + key, not editable or u.trainedUntil > model.state.hours or u.skills[key] >= 100))
		skill_grid.add_child(row)
	if u.perk != null:
		detail.add_child(FieldUI.label(FieldData.load_data().perks[u.perk].name, 14, FieldUI.GOLD))
		detail.add_child(FieldUI.label(FieldData.load_data().perks[u.perk].description, 11, FieldUI.MUTED))
	elif u.experience >= 0.75:
		detail.add_child(FieldUI.label("Select distinction", 12, FieldUI.GOLD))
		for key in FieldData.load_data().perks:
			detail.add_child(FieldUI.button(FieldData.load_data().perks[key].name, "Star", func(): act(model.choose_perk(u.id, key), "Distinction is unavailable."), FieldData.load_data().perks[key].description, not editable))
	detail.add_child(HSeparator.new())
	detail.add_child(FieldUI.section("Equipment", "Swords"))
	detail.add_child(weapon_art(u.weapon, 80))
	var keys = FieldData.weapons().keys().filter(func(k): return FieldData.weapons()[k].kind == u.kind)
	var weapons = FieldUI.select(keys.map(func(k): return FieldData.weapons()[k].name + " / " + str(int(model.state.inventory[k])) + " reserve"), keys.find(u.weapon), func(_index): pass)
	weapons.name = "EquipmentChoice"
	weapons.disabled = not editable
	detail.add_child(weapons)
	var current_weapon: Dictionary = FieldData.weapons()[u.weapon]
	var comparison = FieldUI.wrapped("", 11, FieldUI.MUTED)
	comparison.name = "EquipmentComparison"
	detail.add_child(comparison)
	var issue = FieldUI.button("Issue equipment", "Check", func(): act(model.equip(u.id, keys[weapons.selected]), "Insufficient compatible weapons in reserve."), "Issue selected equipment")
	issue.name = "IssueEquipment"
	detail.add_child(issue)
	var compare = func(_index = 0):
		var key: String = keys[weapons.selected]
		var candidate: Dictionary = FieldData.weapons()[key]
		comparison.text = "%s / %s\n%s\nRange %d (%+d) / Reload %.1fs (%+.1f)\nAccuracy %d (%+d) / Firepower %.2f\n%s" % [candidate.grade, candidate.role, candidate.description, candidate.range, candidate.range - current_weapon.range, candidate.reload, candidate.reload - current_weapon.reload, roundi(candidate.accuracy * 100), roundi((candidate.accuracy - current_weapon.accuracy) * 100), candidate.power, FieldArsenal.loadout(u)]
		issue.disabled = not editable or key == u.weapon or model.state.inventory[key] < FieldData.weapon_count(u)
	weapons.item_selected.connect(compare)
	compare.call()
	var strength = HBoxContainer.new()
	strength.add_child(FieldUI.label("Authorized strength", 11))
	var size_input = SpinBox.new()
	size_input.min_value = maxf(u.men, 30 if u.kind == "artillery" else 100)
	size_input.max_value = 240 if u.kind == "artillery" else 400 if u.kind == "cavalry" else 1200
	size_input.step = 1
	size_input.value = u.maxMen
	size_input.editable = editable
	strength.add_child(size_input)
	strength.add_child(FieldUI.button("", "Check", func(): act(model.set_unit_size(u.id, int(size_input.value)), "Invalid authorized strength."), "Set authorized strength", not editable))
	detail.add_child(strength)
	detail.add_child(FieldUI.section("Replacements", "Users"))
	var quality = FieldUI.select(["Recruits / 2 F each", "Veterans / 6 F each"], 0, func(_index): pass)
	quality.name = "ReplacementQuality"
	quality.disabled = not editable
	detail.add_child(quality)
	var replacements = HBoxContainer.new()
	var amount = SpinBox.new()
	amount.name = "ReplacementAmount"
	amount.min_value = 1
	amount.max_value = maxf(1, u.maxMen - u.men)
	amount.value = maxf(1, u.maxMen - u.men)
	amount.step = 1
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replacements.add_child(amount)
	replacements.add_child(FieldUI.button("Replenish", "Plus", func(): act(model.replenish(u.id, "veterans" if quality.selected == 1 else "recruits", int(amount.value)), "Replacements require losses, reserve weapons, and funds."), "Replenish regiment", not editable or u.men >= u.maxMen))
	detail.add_child(replacements)
	var quote_label = FieldUI.wrapped("", 12, FieldUI.GOLD)
	quote_label.name = "ReplacementQuote"
	detail.add_child(quote_label)
	var refresh_quote = func(_value = 0):
		var quote = model.replacement_quote(u, "veterans" if quality.selected == 1 else "recruits", int(amount.value))
		quote_label.text = "%d men / %d F / %d weapons\nExperience %.2f -> %.2f" % [quote.count, quote.cost, quote.weapons, u.experience, quote.experience]
	quality.item_selected.connect(refresh_quote)
	amount.value_changed.connect(refresh_quote)
	refresh_quote.call()
	if not u.history.is_empty():
		detail.add_child(FieldUI.section("Service History", "Flag"))
		for record in u.history:
			detail.add_child(FieldUI.wrapped("%s / %s / %d losses / %d inflicted" % [record.battle, "Victory" if record.won else "Withdrawal" if record.retreat else "Defeat", record.losses, record.kills], 12))

func weapon_art(key: String, height: float = 90) -> TextureRect:
	return FieldUI.weapon_art(key, height)

func build_armory(narrow: bool) -> void:
	content.add_child(FieldUI.label("Treasury / %d F" % model.state.cash, 20, FieldUI.GOLD, true))
	var filters = HBoxContainer.new()
	var kinds = ["infantry", "cavalry", "artillery"]
	var nations = ["All", "France", "Austria"]
	var kind_filter = FieldUI.select(["Infantry", "Cavalry", "Artillery"], kinds.find(armory_kind), func(index): armory_kind = kinds[index]; build())
	kind_filter.name = "ArmoryKind"
	filters.add_child(kind_filter)
	var nation_filter = FieldUI.select(nations, nations.find(armory_faction), func(index): armory_faction = nations[index]; build())
	nation_filter.name = "ArmoryFaction"
	filters.add_child(nation_filter)
	content.add_child(filters)
	for key in FieldData.weapons():
		var w: Dictionary = FieldData.weapons()[key]
		if w.kind != armory_kind or (armory_faction != "All" and w.faction not in [armory_faction, "Both"]): continue
		var row: BoxContainer = VBoxContainer.new() if narrow else HBoxContainer.new()
		row.name = "Weapon_" + key
		var art = weapon_art(key, 66)
		art.custom_minimum_size.x = 150 if not narrow else 0
		row.add_child(art)
		var name = VBoxContainer.new()
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_child(FieldUI.wrapped(w.name, 18, FieldUI.TEXT))
		name.add_child(FieldUI.wrapped("%s / %s / %s" % [w.faction, w.grade, w.role], 11, FieldUI.GOLD))
		name.add_child(FieldUI.wrapped(w.description, 12))
		name.add_child(FieldUI.wrapped(FieldArsenal.summary(w), 11, FieldUI.MUTED))
		if w.kind == "artillery": name.add_child(FieldUI.wrapped("Move %d%% / Deploy %.1fs / Supply %d" % [roundi(w.mobility * 100), w.deploy, w.ammoCost], 11, FieldUI.MUTED))
		name.add_child(FieldUI.wrapped("%d ready / %d damaged / %d dealer stock" % [model.state.inventory[key], model.state.damagedWeapons[key], model.state.market[key]], 12, FieldUI.GOLD))
		row.add_child(name)
		var trade = VBoxContainer.new()
		var amount = SpinBox.new()
		amount.min_value = 1
		amount.max_value = 10000
		amount.step = 1
		amount.value = w.lot
		trade.add_child(amount)
		var commands = HBoxContainer.new()
		var buy = FieldUI.button("", "ArrowDownToLine", func(): act(model.trade(key, "buy", int(amount.value)), "Insufficient funds or dealer stock."), "Buy reserve weapons")
		var sell = FieldUI.button("", "ArrowUpFromLine", func(): act(model.trade(key, "sell", int(amount.value)), "No reserve weapons to sell."), "Sell reserve weapons")
		commands.add_child(buy)
		commands.add_child(sell)
		trade.add_child(commands)
		var repair = FieldUI.button("", "Wrench", func(): act(model.repair_weapons(key, int(amount.value)), "Refurbishment requires damaged weapons and funds."), "Refurbish captured weapons")
		trade.add_child(repair)
		var total = FieldUI.wrapped("", 11, FieldUI.MUTED)
		trade.add_child(total)
		var refresh_trade = func(_value = 0):
			var purchase = model.trade_quote(key, "buy", int(amount.value))
			var sale = model.trade_quote(key, "sell", int(amount.value))
			var repair_cost = model.repair_quote(key, int(amount.value))
			buy.text = "Buy / %d F" % purchase.cost
			sell.text = "Sell / %d F" % sale.cost
			buy.disabled = not purchase.available
			sell.disabled = not sale.available
			repair.text = "Refit %d / %d F" % [repair_cost.count, repair_cost.cost]
			repair.disabled = not repair_cost.available
			total.text = "%d to buy / %d to sell" % [purchase.count, sale.count]
		amount.value_changed.connect(refresh_trade)
		refresh_trade.call()
		row.add_child(trade)
		content.add_child(row)
		content.add_child(HSeparator.new())

func build_officers(narrow: bool) -> void:
	var command = HBoxContainer.new()
	command.add_child(commander_portrait(model.state.army, 88) if FieldOperations.enabled(model.state) else FieldUI.portrait(0, 88))
	var title = VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(FieldUI.label("Army command", 12, FieldUI.GOLD))
	title.add_child(commander_name(model.state.army) if FieldOperations.enabled(model.state) else FieldUI.wrapped(model.state.general.name, 23, FieldUI.TEXT))
	title.add_child(FieldUI.label(model.state.army.name, 12, FieldUI.MUTED))
	command.add_child(title)
	content.add_child(command)
	content.add_child(HSeparator.new())
	for o in model.state.officers:
		var row = HBoxContainer.new()
		row.add_child(FieldUI.portrait(o.portrait, 58 if narrow else 72))
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(FieldUI.wrapped(FieldData.load_data().ranks[FieldData.rank_of(o)] + " " + o.name, 16, FieldUI.TEXT))
		var assignment = "Available for assignment" if o.hired else "Available for commission"
		for item in model.command_targets():
			if item.officerId == o.id:
				assignment = item.name
		if o.dead:
			assignment = "Killed in action"
		elif o.woundedUntil > model.state.hours:
			assignment = "Recovering / %dh" % ceili(o.woundedUntil - model.state.hours)
		info.add_child(FieldUI.wrapped(assignment, 12, FieldUI.RED if o.dead else FieldUI.MUTED))
		info.add_child(FieldUI.label("%s / %d XP / %d wounds" % [o.specialty, o.xp, o.wounds], 11, FieldUI.GOLD))
		if not o.hired:
			info.add_child(FieldUI.button("Commission / %d F" % o.cost, "Plus", func(): act(model.hire_officer(o.id), "Insufficient funds to commission this officer."), "Recruit officer", model.state.mode != "campaign"))
		row.add_child(info)
		content.add_child(row)
		content.add_child(HSeparator.new())

func _process(_dt: float) -> void:
	if absf(get_viewport_rect().size.x - viewport_width) > 1:
		build()
