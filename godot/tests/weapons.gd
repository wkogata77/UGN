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

func fixture(weapon: String = "cannon") -> FieldModel:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.scenario = "village"
	m.state.battle.aiClock = -10000
	m.terrain.configure(m.state)
	m.terrain.field = m.terrain.field.duplicate(true)
	m.terrain.field.hills = []
	m.terrain.field.forests = []
	m.terrain.buildings.clear()
	m.terrain.defenses.clear()
	m.terrain.grids.clear()
	m.terrain.heights.clear()
	for u in m.state.battle.units: u.arrival = 99999
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	a.merge({"x": 450.0, "y": 400.0, "kind": FieldData.weapons()[weapon].kind, "weapon": weapon, "arrival": 0.0, "facing": 0.0, "men": 120.0, "maxMen": 800.0, "startMen": 120.0, "holdFire": false, "reload": 0.0}, true)
	b.merge({"x": 660.0, "y": 400.0, "arrival": 0.0, "facing": PI, "men": 600.0, "maxMen": 600.0, "startMen": 600.0, "holdFire": true, "reload": 1000.0, "visible": true}, true)
	for c in m.state.battle.commanders:
		c.x = 50
		c.y = 50
		c.following = false
		c.hostId = null
	for w in m.state.battle.wagons: w.stock = 0
	m.formations.reset_roster(a)
	m.formations.reset_roster(b)
	m.tactics.update_visibility(m)
	m.select([a.id])
	return m

func step(m: FieldModel, seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		m.tactics.update(m, 0.05)
		if m.state.battle == null: return

func run() -> void:
	if "--saved-battery-only" in OS.get_cmdline_user_args():
		saved_battery()
		print("GODOT SAVED BATTERY: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if "--battle-view" in OS.get_cmdline_user_args():
		await battle_view()
		print("GODOT ARSENAL BATTLE VIEW: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if "--ui-only" in OS.get_cmdline_user_args():
		await ui_checks()
		print("GODOT ARSENAL UI: %d checks, %d failures" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	catalog_checks()
	artillery_checks()
	infantry_checks()
	stock_checks()
	company_checks()
	save_checks()
	if "--saved-battery" in OS.get_cmdline_user_args(): saved_battery()
	await ui_checks()
	print("GODOT WEAPONS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func catalog_checks() -> void:
	var weapons = FieldData.weapons()
	check(weapons.size() == 22, "22 national equipment entries")
	check(weapons.values().filter(func(w): return w.kind == "infantry").size() == 10, "ten infantry firearms")
	for key in weapons:
		var w: Dictionary = weapons[key]
		check(w.reload > 0 and w.accuracy > 0 and w.range > 0 and w.power > 0, key + " has usable fire parameters")
		check(w.price > w.resale and w.resale > 0 and w.stock >= 0, key + " has bounded economics")
		var art = FieldUI.weapon_art(key, 40)
		check(art.texture != null, key + " uses existing painted weapon art")
		art.free()
	check(not weapons.improved.name.contains("IX"), "1796 selected muskets are not later AN IX arms")
	var m = FieldModel.new(false)
	m.new_campaign("mantua")
	check(m.state.enemyUnits.all(func(u): return weapons[u.weapon].faction == "Austria"), "operational enemy rosters carry Austrian equipment")
	check(m.valid_state(m.state), "new arsenal campaign validates")

func artillery_checks() -> void:
	for key in FieldData.weapons():
		if FieldData.weapons()[key].kind != "artillery": continue
		var m = fixture(key)
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		step(m, 0.05)
		check(a.get("artilleryShots", 0) == 1 and a.ammo < 100, key + " automatically fires in its arc")
		check(a.reload > 0 and a.shotKind == "cannon", key + " drives actual reload and cannon audio")
		check(m.state.battle.artilleryImpacts.size() == 4, key + " emits one impact per gun")
		check(m.state.battle.artilleryImpacts[0].kind == ("shell" if FieldData.weapons()[key].shell else "roundshot"), key + " chooses correct long-range ammunition")
		check(a.reload == a.shotReload, key + " reload animation follows weapon cooldown")
		b.x = 540
		a.reload = 0
		step(m, 0.05)
		check(m.state.battle.artilleryImpacts[-1].kind == "canister", key + " uses canister at short range")
	var m = fixture()
	var a: Dictionary = m.state.battle.units[0]
	var b: Dictionary = m.state.battle.units[5]
	a.limbered = true
	a.attackId = b.id
	step(m, 0.05)
	check(a.limberChange > 0 and a.get("artilleryShots", 0) == 0, "attack order starts deployment without instant firing")
	step(m, 5.2)
	check(not a.limbered and a.get("artilleryShots", 0) > 0, "explicit attack deploys limbered guns and fires")
	m = fixture()
	a = m.state.battle.units[0]
	b = m.state.battle.units[5]
	b.x = 250
	step(m, 0.05)
	check(a.get("artilleryShots", 0) == 0 and a.blocked == "Outside firing arc" and a.facing == 0, "battery does not automatically swivel to rear targets")
	a.attackId = b.id
	step(m, 14)
	check(a.get("artilleryShots", 0) > 0, "explicit attack rotates once and opens fire")
	m = fixture()
	a = m.state.battle.units[0]
	b = m.state.battle.units[5]
	var friend: Dictionary = m.state.battle.units[1]
	friend.merge({"x": 460.0, "y": 400.0, "men": 144.0, "startMen": 144.0, "facing": 0.0, "arrival": 0.0, "holdFire": true}, true)
	m.formations.reset_roster(friend)
	check(not m.tactics.shot_obstruction(m, a, b, FieldData.pos(a)).is_empty(), "partial battery fixture blocks center ray")
	var lanes = m.tactics.firing_lanes(m, a, b)
	check(not lanes.is_empty() and lanes.size() < 4, "unblocked outer guns can fire independently")
	step(m, 0.05)
	check(a.get("artilleryShots", 0) == 1 and m.state.battle.artilleryImpacts.size() == lanes.size(), "only unobstructed guns generate impacts")
	friend.men = 800
	friend.startMen = 800
	friend.x = 540
	m.formations.reset_roster(friend)
	a.reload = 0
	check(not m.tactics.clear_shot(m, a, b), "full friendly frontage blocks every direct-fire gun")
	var ammo: float = a.ammo
	step(m, 0.05)
	check(a.ammo == ammo and a.blocked == "Friendly troops block fire", "blocked battery preserves ammo and reports friendly obstruction")
	friend.arrival = 99999
	m.terrain.field.hills = [{"x": 550, "y": 400, "rx": 100, "ry": 160}]
	m.terrain.heights.clear()
	check(not m.tactics.clear_shot(m, a, b), "round shot cannot fire through a hill")
	a.weapon = "howitzer"
	check(m.tactics.clear_shot(m, a, b), "howitzer trajectory clears a low hill")
	b.visible = false
	check(not m.tactics.automatic_target(m, a, b), "howitzer still needs a spotted target")
	b.visible = true
	m.terrain.field.hills = []
	m.terrain.heights.clear()
	friend.arrival = 0
	check(m.tactics.clear_shot(m, a, b), "shell arc can safely clear friendly troops midway")
	friend.x = 455
	check(not m.tactics.clear_shot(m, a, b), "shells cannot bypass friends immediately in front of muzzles")
	check(FieldArsenal.ammunition(a, 90) == "canister", "howitzer uses direct canister up close")
	a.weapon = "french_12pdr"
	var heavy = FieldFormations.march_pace(a)
	a.weapon = "french_4pdr"
	check(FieldFormations.march_pace(a) > heavy, "light guns march faster than heavy guns")
	m = fixture()
	a = m.state.battle.units[0]
	b = m.state.battle.units[5]
	m.terrain.field.hills = [{"x": 550, "y": 400, "rx": 100, "ry": 160}]
	m.terrain.heights.clear()
	# Another observer spots the target; the battery itself is behind the crest.
	var observer: Dictionary = m.state.battle.units[2]
	observer.merge({"x": 640.0, "y": 500.0, "arrival": 0.0, "holdFire": true}, true)
	m.tactics.update_visibility(m)
	a.attackId = b.id
	step(m, 0.05)
	check(a.get("batteryReposition", false) and a.target != null, "explicit attack seeks a clear nearby position instead of parking behind a crest")
	for i in 1200:
		step(m, 0.05)
		if a.get("artilleryShots", 0) > 0: break
	check(a.get("artilleryShots", 0) > 0, "battery completes obstructed attack order and fires")
	m.halt()
	check(not a.get("batteryReposition", false), "halt cancels firing-position movement")

func infantry_checks() -> void:
	var reloads: Dictionary = {}
	var losses: Dictionary = {}
	for key in ["reserve_musket", "charleville_1766", "republican_musket", "musket", "improved", "rifle", "austrian_reserve", "austrian_1784", "austrian_selected", "jager_rifle"]:
		var m = fixture(key)
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		b.x = 550
		step(m, 0.05)
		reloads[key] = a.reload
		losses[key] = 600 - b.men
		check(a.ammo < 100 and a.shotKind == "musket" and b.men < 600, key + " fires a damaging volley")
		check(FieldArsenal.fire_factor(a, 30) > FieldArsenal.fire_factor(a, FieldData.weapons()[key].range), key + " accuracy falls with range")
	check(reloads.reserve_musket > reloads.musket and reloads.rifle > reloads.reserve_musket, "reserve muskets and rifles have distinct loading tradeoffs")
	check(losses.reserve_musket < losses.musket and losses.musket < losses.improved, "infantry quality tiers differ in actual volley performance")
	check(losses.rifle / reloads.rifle < losses.musket / reloads.musket, "rifles do not replace muskets for close-range volume of fire")
	var m = fixture("carbine")
	var a: Dictionary = m.state.battle.units[0]
	var sabre_power = FieldArsenal.melee_power(a)
	a.weapon = "hussar_carbine"
	check(FieldArsenal.melee_power(a) == sabre_power, "cavalry keeps sabre effectiveness with different firearms")
	var mounted = FieldArsenal.fire_factor(a, 60)
	a.dismounted = true
	check(FieldArsenal.fire_factor(a, 60) > mounted, "dismounting improves cavalry firearm accuracy")

func stock_checks() -> void:
	var m = FieldModel.new(false)
	m.state.cash = 100000
	for key in FieldData.weapons():
		check(m.state.inventory.has(key) and m.state.market.has(key) and m.state.damagedWeapons.has(key), key + " has stock ledgers")
		var stock: int = m.state.market[key]
		var ready: int = m.state.inventory[key]
		check(m.trade(key, "buy", 1) and m.state.market[key] == stock - 1 and m.state.inventory[key] == ready + 1, key + " can be bought")
		check(m.trade(key, "sell", 1) and m.state.market[key] == stock and m.state.inventory[key] == ready, key + " can be sold")
	var damaged = FieldArsenal.salvage(m.state, {"austrian_1784": 100, "austrian_6pdr": 4})
	check(damaged.austrian_1784 == 25 and m.state.inventory.austrian_1784 == 75, "capture splits ready and damaged national stocks")
	check(m.state.inventory.austrian_6pdr == 3 and m.state.damagedWeapons.austrian_6pdr == 1, "captured artillery counted as guns")
	check(FieldArsenal.capture_count("artillery", 90) == 2 and FieldArsenal.capture_count("artillery", 20) == 0, "battery losses yield recoverable whole guns, not fractional crew weapons")
	var money: float = m.state.cash
	var quote = m.repair_quote("austrian_1784", 50)
	check(quote.count == 25 and m.repair_weapons("austrian_1784", 50), "refit is capped at available damaged weapons")
	check(m.state.inventory.austrian_1784 == 100 and m.state.damagedWeapons.austrian_1784 == 0 and m.state.cash == money - quote.cost, "refit conserves weapons and charges funds")
	check(not m.repair_weapons("austrian_1784", 1), "cannot refit nonexistent stock")
	m.state.inventory.reserve_musket = 800
	var old: int = m.state.inventory.musket
	check(m.equip("u1", "reserve_musket") and m.state.inventory.musket == old + 800 and m.state.inventory.reserve_musket == 0, "equipping cheap muskets returns old equipment")
	m.start_battle("e1", true)
	check(not m.trade("musket", "buy", 1) and not m.repair_weapons("austrian_6pdr", 1), "trading and repairs unavailable during battle")
	var enemy: Dictionary = m.state.battle.units[5]
	enemy.men -= 100
	m.finish_battle(true)
	check(m.state.report.capturedWeapons.has(enemy.weapon), "legacy victories capture actual enemy firearms")

func save_checks() -> void:
	var m = FieldModel.new(false)
	check(m.load_campaign("res://tests/fixtures/browser-campaign.json", true), "original browser campaign migrates")
	check(m.valid_state(m.state), "migrated stock and catalog validate")
	var before = m.state.duplicate(true)
	FieldArsenal.initialize(m.state)
	check(m.state == before, "arsenal migration is idempotent")
	check(m.load_campaign("res://tests/fixtures/browser-battle.json", true), "in-progress browser battle migrates")
	check(m.state.battle.units.filter(func(u): return u.side == "enemy").all(func(u): return u.weapon != "musket" and u.weapon != "cannon"), "legacy enemy weapons nationalized without deleting troops")
	check(m.save_campaign("user://test-arsenal.json"), "new arsenal save writes")
	var loaded = FieldModel.new(false)
	check(loaded.load_campaign("user://test-arsenal.json") and loaded.valid_state(loaded.state), "arsenal save round-trips")
	loaded.state.damagedWeapons.musket = -1
	check(not loaded.valid_state(loaded.state), "negative damaged stock rejected")
	loaded.state.damagedWeapons.musket = "bad"
	check(not loaded.valid_state(loaded.state), "malformed damaged stock rejected")

func company_checks() -> void:
	for theater in ["italy", "mantua"]:
		var m = FieldModel.new(false)
		m.new_campaign(theater)
		m.state.cash = 20000
		var stock: float = m.state.inventory.musket
		check(m.recruit("company"), theater + " recruits a small independent light company")
		var u: Dictionary = m.state.units[-1]
		check(u.men == 100 and u.kind == "infantry" and u.role == "skirmishers" and m.state.inventory.musket == stock - 100, "company has the correct manpower, arms and skirmisher role")
		check(m.trade("rifle", "buy", 100) and m.equip(u.id, "rifle"), "scarce French rifles can equip a fresh company")
		check(m.trade("jager_rifle", "buy", 100) and m.equip(u.id, "jager_rifle"), "scarce Austrian rifles can equip a fresh company")
		check(m.valid_state(m.state), "company validates in its campaign")
		check(m.save_campaign("user://test-company-" + theater + ".json"), "company saves")
		var loaded = FieldModel.new(false)
		check(loaded.load_campaign("user://test-company-" + theater + ".json") and loaded.state.units[-1].role == "skirmishers", "independent company and specialist equipment persist")

func saved_battery() -> void:
	var path = "user://mantua-operation.json"
	if not FileAccess.file_exists(path): return
	var original = FileAccess.get_file_as_bytes(path)
	var copy = "user://test-battery-replay.json"
	DirAccess.copy_absolute(path, copy)
	var m = FieldModel.new(false)
	check(m.load_campaign(copy), "copy of actual campaign loads with arsenal migration")
	if m.state.battle != null:
		for u in m.state.battle.units:
			if u.side != "player" or u.kind != "artillery": continue
			print("SAVED BATTERY: ", u.id, " / ", m.tactics.battery_status(m, u, {}))
			for enemy in m.state.battle.units:
				if enemy.side == "enemy" and enemy.visible:
					print("TARGET ", enemy.id, " distance=", FieldData.distance(u, enemy), " arc=", m.tactics.inside_arc(u, enemy), " lanes=", m.tactics.firing_lanes(m, u, enemy).size(), " center=", m.tactics.shot_obstruction(m, u, enemy, FieldData.pos(u)))
			var enemy = m.find_id(m.state.battle.units, "e1-0")
			if not enemy.is_empty():
				# Retain the saved terrain/frontages; isolate the order from other volleys
				# routing the target or ending the battle before the battery can arrive.
				m.state.battle.aiClock = -10000
				m.terrain.field = m.terrain.field.duplicate(true)
				m.terrain.field.objective.seconds = 100000
				for other in m.state.battle.units:
					m.stop_unit(other)
					other.holdFire = other.id != u.id
				enemy.morale = 100
				m.select([u.id])
				check(m.move_units(FieldData.pos(enemy), enemy.id), "saved battery accepts the right-click attack command")
				var shots = u.get("artilleryShots", 0)
				m.state.paused = false
				m.state.speed = 1
				for tick in 1800:
					m.tick(0.05)
					if tick % 100 == 0: print("BATTERY REPLAY ", tick * 0.05, "s p=", FieldData.pos(u), " facing=", u.facing, " order=", u.target, " status=", u.blocked, " motion=", u.movementBlocked)
					if m.state.battle == null or u.get("artilleryShots", 0) > shots: break
				check(u.get("artilleryShots", 0) > shots and u.ammo < 100, "saved battery completes its actual attack route and fires")
	check(FileAccess.get_file_as_bytes(path) == original, "actual player save remains byte-for-byte unchanged")

func ui_checks() -> void:
	var m = FieldModel.new(false)
	m.state.inventory.reserve_musket = 1000
	m.state.damagedWeapons.austrian_1784 = 25
	var hq = FieldHeadquarters.new()
	root.add_child(hq)
	hq.setup(m)
	for width in [1440, 390]:
		root.size = Vector2i(width, 900)
		await process_frame
		for kind in ["infantry", "cavalry", "artillery"]:
			hq.tab = "Armory"
			hq.armory_kind = kind
			hq.build()
			await process_frame
			check(hq.find_child("ArmoryKind", true, false) != null, "armory kind filter builds at %d" % width)
			check(hq.content.get_children().any(func(n): return str(n.name).begins_with("Weapon_")), kind + " stock rows render")
			for row in hq.content.get_children():
				if str(row.name).begins_with("Weapon_"): check(row.size.x <= width, "armory row fits viewport")
			if kind == "infantry" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://test-results/arsenal-infantry-%d.png" % width)
		hq.tab = "Army"
		hq.build()
		await process_frame
		check(hq.find_child("EquipmentComparison", true, false) != null, "equipment comparison builds at %d" % width)
		var choice: OptionButton = hq.find_child("EquipmentChoice", true, false)
		var issue: Button = hq.find_child("IssueEquipment", true, false)
		var keys = FieldData.weapons().keys().filter(func(k): return FieldData.weapons()[k].kind == "infantry")
		var current: String = m.state.units[0].weapon
		choice.select(keys.find("reserve_musket"))
		choice.item_selected.emit(choice.selected)
		check(m.state.units[0].weapon == current, "preview does not equip or spend stock")
		if current != "reserve_musket":
			check(not issue.disabled, "owned reserve muskets enable issue command")
			issue.pressed.emit()
			check(m.state.units[0].weapon == "reserve_musket", "issue button equips the previewed weapon")
			await process_frame
		var comparison: Control = hq.find_child("EquipmentComparison", true, false)
		var parent = comparison.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer: parent.ensure_control_visible(comparison)
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/arsenal-army-%d.png" % width)
		hq.tab = "Armory"
		hq.build()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/arsenal-store-%d.png" % width)
	hq.queue_free()
	await process_frame

func battle_view() -> void:
	var m = fixture("howitzer")
	var a: Dictionary = m.state.battle.units[0]
	a.name = "French Howitzer Battery"
	step(m, 0.05)
	var world = FieldWorld.new()
	root.add_child(world)
	world.setup(m)
	var hud = FieldHud.new()
	root.add_child(hud)
	hud.setup(m, world, true)
	for width in [1440, 390]:
		root.size = Vector2i(width, 900)
		await process_frame
		world.center_entity(a)
		hud.build()
		hud.inspect(a)
		for i in 4: await process_frame
		check(a.get("shotKind") == "cannon" and not m.state.battle.artilleryImpacts.is_empty(), "native battle contains a firing howitzer")
		check(is_instance_valid(hud.inspector) and hud.inspector.get_global_rect().end.x <= width, "weapon inspector fits viewport width")
		check(hud.inspector.get_global_rect().end.y <= 900 - world.ui_bottom, "weapon inspector stays above command rail")
		await RenderingServer.frame_post_draw
		var capture = root.get_texture().get_image()
		var colors: Dictionary = {}
		for x in range(0, capture.get_width(), 40):
			for y in range(100, capture.get_height() - 180, 40): colors[capture.get_pixel(x, y).to_html()] = true
		check(colors.size() > 40, "native battlefield renders nonblank terrain and units")
		capture.save_png("res://test-results/arsenal-battle-%d.png" % width)
	hud.queue_free()
	world.queue_free()
	await process_frame
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	FieldArt.textures.clear()
	FieldUI.icons.clear()
	await process_frame
