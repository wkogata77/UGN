class_name FieldModel
extends RefCounted

signal changed
signal sound_requested(kind: String, x: float)

const SAVE_PATH = "user://campaign.json"
var save_path = SAVE_PATH
var state: Dictionary
var terrain = FieldTerrain.new()
var formations = FieldFormations.new()
var tactics: FieldTactics
var save_enabled = true
var save_failed = false
var save_suspended = false
var save_clock = 0.0
var ui_clock = 0.0
var pursuit_clock = 0.0
var profile_usec = {"tactics": 0, "figures": 0}
# Tactical rules update at the engine's 30 Hz. Presentation steering samples
# at 15 Hz, with positions and stride phases interpolated on the GPU.
var figure_interval = 1.0 / 15.0
var figure_clock = 0.0
var figure_dt = 0.0
var visual_clock = 0.0
var figure_previous_clock = 0.0
var figure_sample_clock = 0.0
var figure_revision = 0
var figure_commands: Dictionary = {}
var figure_previous_commands: Dictionary = {}

func _init(load_saved: bool = true) -> void:
	state = FieldData.fresh()
	formations.terrain_ref = terrain
	save_enabled = load_saved
	terrain.configure(state)
	tactics = FieldTactics.new()
	if load_saved: load_recoverable(SAVE_PATH)

func load_recoverable(path: String = SAVE_PATH) -> bool:
	if FileAccess.file_exists(path) and load_campaign(path): return true
	if FileAccess.file_exists(path + ".bak") and load_campaign(path + ".bak"):
		log_event("Recovered the previous campaign save after the latest save failed validation.")
		return true
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		save_suspended = save_enabled or save_suspended
		save_enabled = false
		save_failed = true
		log_event("No valid campaign save could be loaded. Original files kept; automatic saving disabled.")
	return false

func publish(persist: bool = true) -> void:
	if persist and save_enabled:
		save_campaign()
	changed.emit()

func reset_presentation() -> void:
	figure_clock = 0.0
	figure_dt = 0.0
	figure_previous_clock = visual_clock
	figure_sample_clock = visual_clock
	figure_revision += 1
	figure_commands.clear()
	figure_previous_commands.clear()

func log_event(text: String) -> void:
	state.log.push_front({"text": text, "hours": state.hours})
	if state.log.size() > 20:
		state.log.resize(20)

func find_id(items: Array, id) -> Dictionary:
	for item in items:
		if item is Dictionary and item.get("id") == id:
			return item
	return {}

func save_campaign(path: String = "") -> bool:
	if state.has("exerciseSize"): return false
	if path.is_empty(): path = save_path
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_failed = true
		return false
	file.store_string(JSON.stringify({"format": "field-command-godot", "version": 1, "state": state}))
	file.close()
	if FileAccess.file_exists(path):
		var json = JSON.new()
		var previous = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
		if previous is Dictionary and previous.get("format") == "field-command-godot" and valid_state(previous.get("state")):
			if DirAccess.copy_absolute(path, path + ".bak") != OK:
				save_failed = true
				return false
	var error = DirAccess.rename_absolute(path + ".tmp", path)
	save_failed = error != OK
	if not save_failed and save_suspended:
		save_enabled = true
		save_suspended = false
	return not save_failed

func valid_state(s) -> bool:
	if not valid_shape(s, FieldData.load_data().state):
		return false
	if not s is Dictionary or not s.get("mode") in ["campaign", "battle"]:
		return false
	if s.version != 3 or not s.get("theater", "danube") in ["italy", "danube", "mantua"] or not s.orderMode in ["move", "deploy", "frontline"]:
		return false
	if not valid_shape(s.get("campaignMapVersion", 1), 0) or float(s.get("campaignMapVersion", 1)) not in [1.0, 2.0, 3.0, 4.0]: return false
	if s.battle is Dictionary and (not valid_shape(s.battle.get("mapVersion", 1), 0) or float(s.battle.get("mapVersion", 1)) not in [1.0, 2.0, 3.0]): return false
	if s.selectedCommander != null and not s.selectedCommander is String: return false
	for key in ["cash", "hours", "speed", "supply"]:
		if not (s.get(key) is float or s.get(key) is int) or not is_finite(float(s[key])) or s[key] < 0:
			return false
	if not float(s.speed) in [0.5, 1.0, 2.0, 4.0] or s.supply > 500:
		return false
	for key in ["units", "enemies", "corps", "officers", "selected", "log"]:
		if not s.get(key) is Array:
			return false
	if s.has("exerciseSize") and (not valid_shape(s.exerciseSize, 0) or float(s.exerciseSize) not in [12.0, 20.0]): return false
	var exercise_size: int = s.get("exerciseSize", 0)
	var roster_limit = exercise_size if exercise_size > 0 else 32 if FieldOperations.enabled(s) else 8
	var corps_valid: bool = s.corps.size() == exercise_size / 4 if exercise_size > 0 else not s.corps.is_empty() and s.corps.size() <= 8 if FieldOperations.enabled(s) else s.corps.size() == 2
	if s.units.is_empty() or s.units.size() > roster_limit or s.enemies.size() != 3 or not corps_valid:
		return false
	for key in ["army", "inventory", "market", "general", "recon", "settings"]:
		if not s.get(key) is Dictionary:
			return false
	if not valid_points(s.army.path) or s.settings.volume < 0 or s.settings.volume > 1:
		return false
	for key in ["units", "enemies", "corps", "officers"]:
		var ids: Dictionary = {}
		for entry in s[key]:
			if entry.id.is_empty() or ids.has(entry.id): return false
			ids[entry.id] = true
	# Old saves contain only the seven original stock keys. Validate before migration.
	for stocks in [s.inventory, s.market, s.get("damagedWeapons", {})]:
		if not stocks is Dictionary: return false
		for key in stocks:
			if not FieldData.weapons().has(key) or not valid_shape(stocks[key], 0) or stocks[key] < 0: return false
	if not valid_shape(s.get("arsenalVersion", 0), 0) or float(s.get("arsenalVersion", 0)) not in [0.0, float(FieldArsenal.VERSION)]: return false
	if s.get("arsenalVersion", 0) == FieldArsenal.VERSION:
		for key in FieldData.weapons():
			if not s.inventory.has(key) or not s.market.has(key) or not s.get("damagedWeapons", {}).has(key): return false
	for u in s.units:
		if not u is Dictionary or not FieldData.weapons().has(u.get("weapon")) or FieldData.weapons()[u.weapon].kind != u.get("kind"):
			return false
		if not u.get("men") is float and not u.get("men") is int:
			return false
		if not is_finite(float(u.men)) or u.men < 0 or u.men > u.get("maxMen", 0) or find_id(s.corps, u.get("corpsId")).is_empty():
			return false
	for c in s.corps:
		if s.units.filter(func(u): return u.corpsId == c.id).size() > 4:
			return false
	for enemy in s.enemies:
		if not valid_points(enemy.path) or enemy.strength < 0: return false
		if not valid_shape(enemy.get("condition", 100.0), 0.0) or enemy.get("condition", 100.0) < 0 or enemy.get("condition", 100.0) > 100: return false
		if enemy.get("marchMode", "normal") not in FieldCampaign.MARCH_MODES or not enemy.get("resting", false) is bool: return false
		if enemy.get("personality", "aggressive") not in ["aggressive", "cautious", "opportunist"]: return false
		if enemy.get("lastSighting") != null and not valid_shape(enemy.lastSighting, {"x": 0.0, "y": 0.0, "at": 0.0, "strength": 0.0}): return false
	if s.army.get("marchMode", "normal") not in FieldCampaign.MARCH_MODES: return false
	if s.army.get("attackId") != null and find_id(s.enemies, s.army.attackId).is_empty(): return false
	for u in s.units:
		if not valid_regiment(u) or u.maxMen <= 0: return false
		if u.officerId != null and find_id(s.officers, u.officerId).is_empty(): return false
	if s.mode == "battle":
		if not s.get("battle") is Dictionary or not FieldData.load_data().fields.has(s.battle.get("scenario")):
			return false
		for key in ["units", "wagons", "commanders", "enemyIds"]:
			if not s.battle.get(key) is Array:
				return false
		for u in s.battle.units:
			if not valid_regiment(u) or not valid_shape(u, {"x": 0.0, "y": 0.0, "side": "", "startMen": 0.0}) or not u.side in ["player", "enemy"]:
				return false
		if not valid_shape(s.battle, {"name": "", "playerEdge": "", "time": 0.0, "reward": 0.0, "startMen": 0.0, "enemyStartMen": 0.0, "origin": {"x": 0.0, "y": 0.0}, "aiClock": 0.0, "visibilityClock": 0.0, "objective": {"player": 0.0, "enemy": 0.0, "owner": null}, "enemyIds": [""], "officerStart": [{"id": "", "rank": 0.0, "woundedUntil": 0.0, "dead": false}]}): return false
		if not s.battle.playerEdge in ["east", "west"] or s.battle.time < 0: return false
		if not valid_shape(s.battle.get("artilleryImpacts", []), [{"x": 0.0, "y": 0.0, "time": 0.0, "hit": false, "visible": true}]): return false
		if not s.battle.get("battlePolish", false) is bool: return false
		var traffic = s.battle.get("bridgeTraffic", {})
		if not traffic is Dictionary or traffic.size() > 24: return false
		for key in traffic:
			if not key is String or not traffic[key] is String: return false
		var bodies = s.battle.get("bodies", [])
		if not valid_shape(bodies, [{"x": 0.0, "y": 0.0, "facing": 0.0, "side": "", "kind": "", "mounted": false, "time": 0.0}]) or bodies.size() > 4096: return false
		if s.battle.units.is_empty() or s.battle.units.size() > (96 if FieldOperations.enabled(s) else 48) or s.battle.wagons.size() != 2 or s.battle.commanders.is_empty(): return false
		if not FieldBattleAI.valid(self, s.battle): return false
		for c in s.battle.commanders:
			if not valid_shape(c, {"id": "", "name": "", "corpsId": null, "specialty": "", "x": 0.0, "y": 0.0, "radius": 0.0, "cooldown": 0.0, "shaken": 0.0, "rallyFlash": 0.0, "following": false}) or not valid_orders(c): return false
		for w in s.battle.wagons:
			if not valid_shape(w, {"id": "", "side": "", "x": 0.0, "y": 0.0, "stock": 0.0, "health": 0.0, "visible": true}) or not valid_orders(w): return false
	else:
		if s.get("battle") != null: return false
	if s.report != null and not valid_shape(s.report, {"name": "", "won": false, "retreat": false, "casualties": 0.0, "enemyCasualties": 0.0, "reward": 0.0, "loot": 0.0, "complete": false, "regiments": [{"name": "", "men": 0.0, "losses": 0.0, "kills": 0.0}], "officers": [{"name": "", "status": ""}]}): return false
	if s.report != null:
		for field in ["capturedWeapons", "damagedWeapons"]:
			var stores = s.report.get(field, {})
			if not stores is Dictionary: return false
			for key in stores:
				if not FieldData.weapons().has(key) or not valid_shape(stores[key], 0) or stores[key] < 0: return false
				if field == "damagedWeapons" and stores[key] > s.report.get("capturedWeapons", {}).get(key, 0): return false
	return FieldOperations.valid(self, s)

func valid_shape(value, template) -> bool:
	if template == null: return true
	if template is float or template is int:
		return (value is float or value is int) and is_finite(float(value))
	if typeof(value) != typeof(template): return false
	if template is Dictionary:
		for key in template:
			if key == "officerId" and value.get(key) == null: continue
			if not value.has(key) or not valid_shape(value[key], template[key]): return false
	if template is Array and not template.is_empty():
		for entry in value:
			if not valid_shape(entry, template[0]): return false
	return true

func valid_points(value) -> bool:
	return valid_shape(value, [{"x": 0.0, "y": 0.0}])

func valid_orders(u: Dictionary) -> bool:
	for key in ["target", "goal"]:
		if u.get(key) != null and not valid_shape(u[key], {"x": 0.0, "y": 0.0}): return false
	for path_key in ["waypoints", "routPath"]:
		if not valid_points(u.get(path_key, [])): return false
	if u.has("routRetryAt") and not valid_shape(u.routRetryAt, 0.0): return false
	if u.get("desiredFacing") != null and not valid_shape(u.desiredFacing, 0.0): return false
	for order in u.get("orderQueue", []):
		if not valid_shape(order, {"point": {"x": 0.0, "y": 0.0}}): return false
		if order.get("facing") != null and not valid_shape(order.facing, 0.0): return false
	return true

func valid_regiment(u) -> bool:
	if not valid_shape(u, {"id": "", "name": "", "kind": "", "weapon": "", "men": 0.0, "maxMen": 0.0}): return false
	if u.has("meleeContacts") and (not valid_shape(u.meleeContacts, [""]) or u.meleeContacts.size() > 96): return false
	if not FieldData.weapons().has(u.weapon) or FieldData.weapons()[u.weapon].kind != u.kind: return false
	if u.has("visualCount") and (not valid_shape(u.visualCount, 0) or u.visualCount < 1 or u.visualCount > 100 or u.visualCount != floor(u.visualCount)): return false
	var slots = u.get("deadSlots", [])
	if not slots is Array or slots.size() > 100: return false
	var seen_slots: Dictionary = {}
	for slot in slots:
		if not valid_shape(slot, 0) or slot != floor(slot) or slot < 0 or slot >= u.get("visualCount", FieldFormations.figure_count(u, u.get("startMen", u.men))) or seen_slots.has(slot): return false
		seen_slots[slot] = true
	if u.has("visualSlots"):
		var assignment = u.visualSlots
		var count = int(u.get("visualCount", FieldFormations.figure_count(u, u.get("startMen", u.men))))
		if not assignment is Array or assignment.size() != count: return false
		seen_slots.clear()
		for slot in assignment:
			if not valid_shape(slot, 0) or slot != floor(slot) or slot < 0 or slot >= count or seen_slots.has(slot): return false
			seen_slots[slot] = true
	var normalized: Dictionary = u.duplicate(true)
	FieldData.regiment_defaults(normalized)
	var baseline = {"kind": u.kind}
	FieldData.regiment_defaults(baseline)
	if not valid_shape(normalized, baseline) or not valid_orders(normalized): return false
	for key in ["condition", "morale", "ammo"]:
		if normalized[key] < 0 or normalized[key] > 100: return false
	for key in ["chargeDistance", "chargeReadyAt", "chargeExpires", "chargeImpactUntil"]:
		if normalized[key] < 0: return false
	if normalized.chargeDistance > 100: return false
	if normalized.chargeTargetId != null and not normalized.chargeTargetId is String: return false
	if normalized.coverWidth < 0 or normalized.coverWidth > 200 or normalized.coverDeploy < 0 or normalized.coverDeploy > 4: return false
	for key in ["coverId", "coverOrderId"]:
		if normalized[key] != null and not FieldCover.TYPES.has(normalized[key]): return false
	if not normalized.formation in ["line", "column", "square"] or normalized.men < 0 or normalized.men > normalized.maxMen: return false
	if normalized.formationChange != null:
		var change = normalized.formationChange
		if not valid_shape(change, {"from": "", "to": "", "elapsed": 0.0, "duration": 0.0}): return false
		if not change.to in ["line", "column", "square"] or change.duration <= 0 or change.elapsed < 0: return false
	return true

func load_campaign(path: String, browser: bool = false) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 8000000: return false
	var json = JSON.new()
	var parsed = json.data if json.parse(file.get_as_text()) == OK else null
	file.close()
	if not parsed is Dictionary:
		return false
	var incoming = parsed if browser else parsed.get("state")
	if not browser and (parsed.get("format") != "field-command-godot" or parsed.get("version") != 1):
		return false
	if not valid_state(incoming):
		return false
	if not browser and incoming.get("arsenalVersion", 0) < FieldArsenal.VERSION:
		var backup = path + ".pre-arsenal.bak"
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK: return false
	if not browser and incoming.get("campaignMapVersion", 1) < FieldCampaign.MAP_VERSION:
		var backup = path + (".pre-grand-map.bak" if incoming.get("campaignMapVersion", 1) >= 3 else ".pre-large-maps.bak")
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK:
			return false
	if not browser and incoming.get("theater", "italy") == "italy" and incoming.get("campaignMapVersion", 1) < 2:
		var backup = path + ".pre-expanded-map.bak"
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(path, backup) != OK:
			return false
	state = incoming.duplicate(true)
	FieldArsenal.initialize(state)
	tactics.clear_ai()
	state.paused = true
	state["theater"] = state.get("theater", "danube" if browser else "italy")
	FieldCampaign.migrate(state)
	FieldCampaign.march_defaults(state)
	if FieldOperations.enabled(state): FieldOperations.bind_selection(state)
	state["portVersion"] = 1
	for u in state.units:
		FieldData.regiment_defaults(u)
	if state.battle != null:
		state.battle["bodies"] = state.battle.get("bodies", [])
		state.battle.erase("bridgeTraffic")
		for u in state.battle.units:
			FieldData.regiment_defaults(u)
			if u.kind == "artillery": FieldCharge.cancel(u)
			if u.has("deadSlots"): u.deadSlots = u.deadSlots.map(func(slot): return int(slot))
			if u.has("visualSlots"): u.visualSlots = u.visualSlots.map(func(slot): return int(slot))
			u["meleeTargetId"] = null
			u["meleeContacts"] = []
			if u.has("visualCount"): u.visualCount = int(u.visualCount)
		state.battle["artilleryImpacts"] = state.battle.get("artilleryImpacts", [])
		for w in state.battle.wagons:
			w["name"] = "Supply train" if w.side == "player" else "Enemy supply"
			w["kind"] = "wagon"
			w["facing"] = w.get("facing", 0.0)
		for c in state.battle.commanders:
			c["facing"] = c.get("facing", 0.0)
			c["unavailable"] = c.get("unavailable", false)
			c["officerId"] = c.get("officerId")
			if c.get("corpsId") != null and c.get("hostId") == null:
				var members = state.battle.units.filter(func(u): return u.side == "player" and u.corpsId == c.corpsId)
				c["hostId"] = members[0].id if not members.is_empty() else null
	terrain.configure(state)
	if state.battle != null:
		sync_hosts()
		tactics.update_visibility(self)
	formations.groups.clear()
	formations.motion.clear()
	reset_presentation()
	if save_suspended:
		save_enabled = true
		save_suspended = false
	save_failed = false
	publish(browser)
	return true

func new_campaign(theater: String = "italy") -> void:
	state = FieldData.fresh(theater)
	tactics.clear_ai()
	terrain.configure(state)
	formations.groups.clear()
	formations.motion.clear()
	reset_presentation()
	publish()

func pause() -> void:
	state.paused = not state.paused
	if not state.paused and state.orderMode == "deploy":
		state.orderMode = "move"
	publish()

func speed(value: float) -> void:
	if value in [0.5, 1.0, 2.0, 4.0]:
		state.speed = value
		publish()

func march_mode(value: String) -> bool:
	if state.mode != "campaign" or not FieldCampaign.MARCH_MODES.has(value): return false
	for a in campaign_selection(): a.marchMode = value
	publish()
	return true

func campaign_selection() -> Array:
	return FieldOperations.selected(state) if FieldOperations.enabled(state) else [state.army]

func army_units() -> Array:
	return FieldOperations.roster(state, state.army) if FieldOperations.enabled(state) else state.units

func army_corps() -> Array:
	return state.corps.filter(func(c): return c.armyId == state.selectedArmyId) if FieldOperations.enabled(state) else state.corps

func select_armies(ids: Array) -> bool:
	return FieldOperations.enabled(state) and FieldOperations.select(self, ids)

func split_army(ids: Array, name: String = "") -> bool:
	return FieldOperations.enabled(state) and FieldOperations.split(self, ids, name)

func merge_army(id: String) -> bool:
	return FieldOperations.enabled(state) and FieldOperations.merge(self, id)

func select(ids: Array) -> void:
	state.selected = ids
	state.selectedCommander = null
	state.selectedSupply = false
	state.orderMode = "move"
	publish(false)

func select_corps(id: String) -> void:
	var units: Array = state.units if state.battle == null else state.battle.units
	select(units.filter(func(u): return u.corpsId == id and u.men > 0 and not u.get("routed", false) and not u.get("withdrawn", false)).map(func(u): return u.id))

func select_commander(id: String) -> void:
	if state.battle == null:
		return
	var c = find_id(state.battle.commanders, id)
	if c.is_empty() or c.get("arrival", 0.0) > state.battle.time:
		return
	if c.get("hostId") != null:
		select([c.hostId])
		return
	state.selected = []
	state.selectedCommander = id
	state.selectedSupply = false
	state.orderMode = "move"
	publish(false)

func select_supply() -> void:
	if state.battle == null:
		return
	state.selected = []
	state.selectedCommander = null
	state.selectedSupply = true
	state.orderMode = "move"
	publish(false)

func selected_units() -> Array:
	if state.battle == null:
		return []
	return state.battle.units.filter(func(u): return u.side == "player" and u.men > 0 and u.id in state.selected and not u.routed and not u.withdrawn and u.arrival <= state.battle.time)

func command_support(u: Dictionary) -> Array:
	if state.battle == null or u.side != "player":
		return []
	return state.battle.commanders.filter(func(c): return c.shaken <= 0 and not c.unavailable and c.get("arrival", 0.0) <= state.battle.time and (c.get("armyId") == null or c.armyId == u.get("armyId")) and (c.corpsId == null or c.corpsId == u.corpsId) and FieldData.distance(c, u) <= c.radius)

func efficiency(u: Dictionary) -> float:
	var o = find_id(state.officers, u.officerId)
	if not FieldData.ready(o, state.hours):
		return 0.7
	var rank = FieldData.rank_of(o)
	return minf(1.12, 0.88 + rank * 0.06) * minf(1, [250, 600, 1000, 1800, 3000][rank] / maxf(1, u.men))

func assign_corps(unit_id: String, corps_id: String) -> bool:
	var u = find_id(state.units, unit_id)
	if state.mode != "campaign" or u.is_empty() or u.corpsId == corps_id or find_id(state.corps, corps_id).is_empty() or state.units.filter(func(item): return item.corpsId == corps_id).size() >= 4:
		return false
	if FieldOperations.enabled(state) and find_id(state.corps, corps_id).armyId != u.armyId: return false
	u.corpsId = corps_id
	log_event(u.name + " transferred to " + find_id(state.corps, corps_id).name + ".")
	publish()
	return true

func hire_officer(id: String) -> bool:
	var o = find_id(state.officers, id)
	if state.mode != "campaign" or o.is_empty() or o.hired or state.cash < o.cost:
		return false
	state.cash -= o.cost
	o.hired = true
	log_event(o.name + " joined headquarters.")
	publish()
	return true

func command_targets() -> Array:
	return state.units + state.corps + (state.armies if FieldOperations.enabled(state) else [])

func assign_officer(target_id: String, officer_id: String) -> bool:
	var target = find_id(command_targets(), target_id)
	var o = find_id(state.officers, officer_id)
	if state.mode != "campaign" or target.is_empty() or not FieldData.ready(o, state.hours):
		return false
	var required_rank = 0 if target.get("kind") == "artillery" else 1 if target.has("kind") else 3
	if FieldData.rank_of(o) < required_rank:
		return false
	for item in command_targets():
		if item.officerId == officer_id:
			item.officerId = null
			item.commander = "Vacant command"
	target.officerId = officer_id
	target.commander = FieldData.load_data().ranks[FieldData.rank_of(o)] + " " + o.name
	if not target.has("kind"):
		target.specialty = o.specialty
	log_event(o.name + " assigned to " + target.name + ".")
	publish()
	return true

func rename_regiment(id: String, value: String) -> bool:
	var u = find_id(state.units, id)
	var clean = value.strip_edges().left(36)
	if state.mode != "campaign" or u.is_empty() or clean.is_empty():
		return false
	u.name = clean
	publish()
	return true

func train(id: String, skill: String) -> bool:
	var u = find_id(state.units, id)
	if state.mode != "campaign" or u.is_empty() or not FieldData.load_data().skills.has(skill) or state.cash < 450 or u.trainedUntil > state.hours or u.skills[skill] >= 100:
		return false
	state.cash -= 450
	u.skills[skill] = minf(100, u.skills[skill] + 5)
	u.experience = minf(5, u.experience + 0.15)
	u.condition = maxf(0, u.condition - 12)
	u.trainedUntil = state.hours + 2
	log_event(u.name + " completed " + skill + " drill.")
	publish()
	return true

func choose_perk(id: String, value: String) -> bool:
	var u = find_id(state.units, id)
	if state.mode != "campaign" or u.is_empty() or u.perk != null or u.experience < 0.75 or not FieldData.load_data().perks.has(value):
		return false
	u.perk = value
	publish()
	return true

func set_unit_size(id: String, amount: int) -> bool:
	var u = find_id(state.units, id)
	if state.mode != "campaign" or u.is_empty():
		return false
	var cap = 240 if u.kind == "artillery" else 400 if u.kind == "cavalry" else 1200
	if amount < maxf(u.men, 30 if u.kind == "artillery" else 100) or amount > cap:
		return false
	u.maxMen = amount
	publish()
	return true

func trade(key: String, direction: String, quantity: int) -> bool:
	var quote = trade_quote(key, direction, quantity)
	if not quote.available: return false
	var sign_value = 1 if direction == "buy" else -1
	state.inventory[key] += quote.count * sign_value
	state.market[key] -= quote.count * sign_value
	state.cash -= quote.cost * sign_value
	publish()
	return true

func trade_quote(key: String, direction: String, quantity: int) -> Dictionary:
	if not FieldData.weapons().has(key) or not direction in ["buy", "sell"] or quantity < 1: return {"count": 0, "cost": 0, "available": false}
	var weapon: Dictionary = FieldData.weapons()[key]
	var count = mini(quantity, state.market[key] if direction == "buy" else state.inventory[key])
	var cost: float = count * (weapon.price if direction == "buy" else weapon.resale)
	return {"count": count, "cost": cost, "available": state.mode == "campaign" and count > 0 and (direction == "sell" or state.cash >= cost)}

func repair_quote(key: String, quantity: int) -> Dictionary:
	if not FieldData.weapons().has(key) or quantity < 1: return {"count": 0, "cost": 0, "available": false}
	var count = mini(quantity, state.damagedWeapons[key])
	var cost = count * maxi(1, ceili(FieldData.weapons()[key].price * 0.35))
	return {"count": count, "cost": cost, "available": state.mode == "campaign" and count > 0 and state.cash >= cost}

func repair_weapons(key: String, quantity: int) -> bool:
	var quote = repair_quote(key, quantity)
	if not quote.available: return false
	state.damagedWeapons[key] -= quote.count
	state.inventory[key] += quote.count
	state.cash -= quote.cost
	publish()
	return true

func equip(id: String, key: String) -> bool:
	var u = find_id(state.units, id)
	if state.mode != "campaign" or u.is_empty() or not FieldData.weapons().has(key) or FieldData.weapons()[key].kind != u.kind or key == u.weapon or state.inventory[key] < FieldData.weapon_count(u):
		return false
	state.inventory[u.weapon] += FieldData.weapon_count(u)
	state.inventory[key] -= FieldData.weapon_count(u)
	u.weapon = key
	if not FieldData.weapons()[key].get("dismount", false): u.dismounted = false
	log_event(u.name + " issued " + FieldData.weapons()[key].name + ".")
	publish()
	return true

func replenish(id: String, quality: String = "recruits", requested: int = 99999) -> bool:
	var u = find_id(state.units, id)
	if state.mode != "campaign" or u.is_empty() or not quality in ["recruits", "veterans"] or requested <= 0:
		return false
	if FieldOperations.enabled(state):
		var army = FieldOperations.force(state, u.armyId)
		if not FieldOperations.can_admin(state, army) or not FieldOperations.at_depot(state, army): return false
	var quote = replacement_quote(u, quality, requested)
	var count: int = quote.count
	if count <= 0:
		return false
	var old: float = u.men
	state.inventory[u.weapon] -= FieldData.weapon_count(u, old + count) - FieldData.weapon_count(u, old)
	state.cash -= quote.cost
	u.men += count
	if quality == "recruits":
		u.experience *= old / u.men
		for key in u.skills:
			u.skills[key] = (u.skills[key] * old + FieldData.base_skills(u.kind)[key] * count) / u.men
	log_event(str(count) + " replacements joined " + u.name + ".")
	publish()
	return true

func replacement_quote(u: Dictionary, quality: String, requested: int) -> Dictionary:
	var price = 6 if quality == "veterans" else 2
	var available: float = state.inventory[u.weapon] * 30 + FieldData.weapon_count(u) * 30 - u.men if u.kind == "artillery" else state.inventory[u.weapon]
	var count = maxi(0, floori(minf(requested, minf(u.maxMen - u.men, minf(available, floorf(state.cash / price))))))
	var experience: float = u.experience if quality == "veterans" or count == 0 else float(u.experience) * u.men / (u.men + count)
	return {"count": count, "cost": count * price, "experience": experience, "weapons": FieldData.weapon_count(u, u.men + count) - FieldData.weapon_count(u, u.men)}

func recruit(kind: String) -> bool:
	var company = kind == "company"
	var specs = {"infantry": [400, 1200, "musket", "Line Regiment"], "company": [100, 400, "musket", "Light Company"], "cavalry": [160, 1600, "sabre", "Hussars"], "artillery": [90, 1500, "cannon", "Foot Artillery"]}
	if state.mode != "campaign" or not specs.has(kind) or army_units().size() >= 8 or state.units.size() >= 32:
		return false
	if FieldOperations.enabled(state) and (not FieldOperations.can_admin(state, state.army) or not FieldOperations.at_depot(state, state.army)): return false
	var spec: Array = specs[kind]
	var required = int(spec[0] / 30) if kind == "artillery" else int(spec[0])
	if state.cash < spec[1] or state.inventory[spec[2]] < required:
		return false
	var corps_id = ""
	for corps in army_corps():
		if state.units.filter(func(u): return u.corpsId == corps.id).size() < 4:
			corps_id = corps.id
			break
	if corps_id.is_empty() and FieldOperations.enabled(state) and army_corps().size() < 2:
		corps_id = "c" + str(int(state.operation.nextCorps))
		state.operation.nextCorps += 1
		var corps = state.corps[0].duplicate(true)
		corps.merge({"id": corps_id, "armyId": state.army.id, "commanderId": "commander-" + corps_id, "name": "Field Corps " + corps_id.trim_prefix("c"), "officerId": null, "commander": "Vacant command"}, true)
		state.corps.append(corps)
	if corps_id.is_empty():
		return false
	state.cash -= spec[1]
	state.inventory[spec[2]] -= required
	var number = int(state.nextId)
	state.nextId += 1
	var id = "u" + str(number)
	var u = {"id": id, "name": str(number) + "th " + spec[3], "kind": "infantry" if company else kind, "men": float(spec[0]), "maxMen": float(spec[0]), "weapon": spec[2], "commander": "Major Antoine Delmas", "corpsId": corps_id, "officerId": "officer-" + id}
	FieldData.regiment_defaults(u)
	if company: u["role"] = "skirmishers"
	if FieldOperations.enabled(state): u["armyId"] = state.selectedArmyId
	state.units.append(u)
	state.officers.append(FieldData.officer(u.officerId, "Antoine Delmas", (number + 4) % 15 + 1, 20))
	log_event(u.name + " has joined the army.")
	publish()
	return true

func resupply_cost() -> int:
	var amount = 500.0 - state.supply
	if FieldOperations.enabled(state): amount = maxf(0, amount - state.operation.reserveSupply)
	for u in army_units():
		amount += (100.0 - u.ammo) * 2
	return ceili(amount)

func resupply() -> bool:
	var cost = resupply_cost()
	if state.mode != "campaign" or state.cash < cost or (cost <= 0 and (not FieldOperations.enabled(state) or state.supply >= 500)):
		return false
	if FieldOperations.enabled(state) and (not FieldOperations.can_admin(state, state.army) or not FieldOperations.at_depot(state, state.army)): return false
	state.cash -= cost
	if FieldOperations.enabled(state): state.operation.reserveSupply = maxf(0, state.operation.reserveSupply - (500 - state.supply))
	state.supply = 500
	if FieldOperations.enabled(state): state.army.supply = 500.0
	for u in army_units():
		u.ammo = 100.0
	log_event("Ammunition and supply train replenished.")
	publish()
	return true

func scout() -> bool:
	if FieldOperations.enabled(state):
		if state.mode != "campaign" or state.cash < 100 or state.army.scoutReady > state.hours or state.army.defeated: return false
		state.cash -= 100
		state.army.scoutUntil = state.hours + 3.6
		state.army.scoutReady = state.hours + 7.2
		log_event("Patrols dispatched from " + state.army.name + ".")
		publish()
		return true
	if state.mode != "campaign" or state.recon.cooldown > 0 or state.cash < 100:
		return false
	state.cash -= 100
	state.recon = {"remaining": 45.0, "cooldown": 90.0}
	log_event("Cavalry patrols dispatched.")
	publish()
	return true

func enemy_visible(e: Dictionary) -> bool:
	if FieldOperations.enabled(state): return state.armies.any(func(a): return not a.defeated and FieldOperations.visible(state, a, e))
	return FieldData.distance(state.army, e) <= (760 if state.recon.remaining > 0 else 380)

func move_army(p: Vector2) -> bool:
	if FieldOperations.enabled(state): return FieldOperations.move(self, p)
	if state.mode != "campaign" or state.report != null:
		return false
	var path = terrain.route(FieldData.pos(state.army), p)
	if path.is_empty():
		return false
	state.army.path = path
	state.army["attackId"] = null
	log_event("Marching orders issued.")
	sound_requested.emit("order", p.x)
	publish()
	return true

func attack_army(id: String) -> bool:
	var enemy = find_id(state.enemies, id)
	if FieldOperations.enabled(state):
		return not enemy.is_empty() and not enemy.defeated and enemy_visible(enemy) and FieldOperations.move(self, FieldData.pos(enemy), id)
	if enemy.is_empty() or enemy.defeated or not enemy_visible(enemy) or not move_army(FieldData.pos(enemy)): return false
	state.army["attackId"] = id
	pursuit_clock = 0.0
	log_event("Intercept " + enemy.name + "'s army.")
	publish()
	return true

func path_unit(u: Dictionary, p: Vector2, facing = null) -> bool:
	p = p.clamp(terrain.order_bounds().position, terrain.order_bounds().end)
	var clearance = 2.0
	var destination = terrain.open_point(p, clearance)
	if destination == null:
		u["movementBlocked"] = "No route to destination"
		return false
	p = destination
	var path = terrain.route(FieldData.pos(u), p, clearance)
	if path.is_empty():
		u["movementBlocked"] = "No route to destination"
		return false
	u["movementBlocked"] = ""
	u.target = path.pop_front()
	u.waypoints = path
	u.goal = FieldData.point(p)
	u.desiredFacing = facing
	return true

func prepare_deployment() -> void:
	if state.battle == null or state.battle.time > 0: return
	for u in state.battle.units:
		var clearance = FieldFormations.bounds(u).size.length() * 0.5
		var origin = FieldData.pos(u)
		if terrain.passable(origin, true, clearance): continue
		var destination = origin
		for radius in range(12, 241, 12):
			for i in 24:
				var candidate = origin + Vector2.from_angle(i * TAU / 24.0) * radius
				if not terrain.order_bounds().has_point(candidate) or not terrain.passable(candidate, true, clearance): continue
				var trial = u.duplicate()
				trial.x = candidate.x
				trial.y = candidate.y
				if state.battle.units.any(func(other): return other.id != u.id and FieldContact.gap(FieldContact.shape(trial), FieldContact.shape(other)) < 6): continue
				destination = candidate
				break
			if destination != origin: break
		u.x = destination.x
		u.y = destination.y
		formations.reset(u)
	sync_hosts()

func clear_engagement(u: Dictionary) -> void:
	u.fireTargetId = null
	u.aimOrderId = null
	u.aimComplete = false
	u["batteryReposition"] = false
	u["batteryRetryAt"] = 0.0

func move_placements(p: Vector2, facing = null) -> Array:
	if state.battle == null:
		return []
	var units = selected_units()
	if state.selectedSupply or state.selectedCommander != null:
		var u = state.battle.wagons[0] if state.selectedSupply else find_id(state.battle.commanders, state.selectedCommander)
		units = [u] if not u.is_empty() and u.get("health", 100.0) > 0 else []
	var placements: Array = []
	var widths: Array[Rect2] = []
	var total = 0.0
	var center = Vector2.ZERO
	for u in units: center += FieldData.pos(u) / units.size()
	if facing != null:
		for u in units:
			var bounds = FieldFormations.bounds(u)
			widths.append(bounds)
			total += bounds.size.x
		total += maxf(0, units.size() - 1) * 12.0
	var cursor = -total / 2.0
	for i in units.size():
		# A simple group move translates its existing spacing, without swapping files
		# or squeezing wide regiments into overlapping fixed-width destinations.
		var destination = p + FieldData.pos(units[i]) - center
		if facing != null:
			# Share the exact frontage with the drag preview; keep the group centered on the press.
			var offset = cursor - widths[i].position.x if units.size() > 1 else 0.0
			destination = p + Vector2(offset, 0).rotated(facing - PI / 2.0)
			cursor += widths[i].size.x + 12.0
		placements.append({"unit": units[i], "point": destination.clamp(terrain.order_bounds().position, terrain.order_bounds().end), "facing": facing})
	return placements

func frontline_placements(a: Vector2, b: Vector2) -> Array:
	var units = selected_units()
	var placements: Array = []
	for i in units.size():
		var p = a.lerp(b, 0.5 if units.size() == 1 else float(i) / (units.size() - 1))
		placements.append({"unit": units[i], "point": p.clamp(terrain.order_bounds().position, terrain.order_bounds().end), "facing": (b - a).angle() - PI / 2.0})
	return placements

func move_units(p: Vector2, attack_id = null, queue: bool = false, facing = null) -> bool:
	if state.battle == null:
		return false
	if state.selectedSupply or state.selectedCommander != null:
		var u = state.battle.wagons[0] if state.selectedSupply else find_id(state.battle.commanders, state.selectedCommander)
		if u.is_empty() or u.get("health", 100.0) <= 0:
			return false
		if not path_unit(u, p, facing):
			return false
		u["following"] = false
		publish()
		return true
	var ordered = false
	for placement in move_placements(p, facing):
		var u: Dictionary = placement.unit
		var destination: Vector2 = placement.point
		if queue and u.target != null:
			u.orderQueue.append({"point": FieldData.point(destination), "facing": facing})
			ordered = true
			continue
		if not path_unit(u, destination, facing):
			continue
		FieldCover.leave(u)
		clear_engagement(u)
		u.orderQueue = []
		u.attackId = attack_id
		FieldCharge.cancel(u)
		u.retreating = false
		u.fallingBack = false
		ordered = true
	if ordered:
		sound_requested.emit("order", p.x)
		publish()
	return ordered

func frontline(a: Vector2, b: Vector2) -> void:
	for placement in frontline_placements(a, b):
		var u: Dictionary = placement.unit
		if not path_unit(u, placement.point, placement.facing): continue
		FieldCover.leave(u)
		FieldCharge.cancel(u)
		u.retreating = false
		u.fallingBack = false
		u.attackId = null
		u.orderQueue = []
		clear_engagement(u)
	state.orderMode = "move"
	publish()

func deploy(p: Vector2) -> bool:
	var b = state.battle
	if b == null or b.time > 0 or not state.paused:
		return false
	var east = b.playerEdge == "east"
	var limit = terrain.deployment_limit(east)
	if (p.x < limit if east else p.x > limit) or not terrain.passable(p):
		return false
	var units = selected_units()
	for i in units.size():
		var u: Dictionary = units[i]
		u.x = clampf(p.x, limit + 10 if east else 65, terrain.map_size.x - 65 if east else limit - 10)
		u.y = clampf(p.y + (i - (units.size() - 1) / 2.0) * 90, 90, terrain.map_size.y - 90)
		stop_unit(u)
		formations.reset(u)
	sync_hosts()
	publish()
	return true

func stop_unit(u: Dictionary) -> void:
	FieldCover.leave(u)
	u.target = null
	u.attackId = null
	FieldCharge.cancel(u)
	u.retreating = false
	u.waypoints = []
	u.orderQueue = []
	u.fallingBack = false
	u.desiredFacing = null
	u.turnVelocity = 0.0
	clear_engagement(u)

func halt() -> void:
	if state.mode == "campaign":
		for a in campaign_selection():
			a.erase("pendingOrder")
			if FieldOperations.enabled(state) and FieldOperations.forced_retreat(state, a): continue
			a.path = []
			a["attackId"] = null
			if FieldOperations.enabled(state): a.intent = "Holding"
	elif state.selectedSupply:
		state.battle.wagons[0].target = null
		state.battle.wagons[0].waypoints = []
	elif state.selectedCommander != null:
		var c = find_id(state.battle.commanders, state.selectedCommander)
		if not c.is_empty():
			c.target = null
			c.waypoints = []
			c.following = false
	else:
		for u in selected_units():
			var occupied = {"coverId": u.coverId, "coverWidth": u.coverWidth, "coverDeploy": u.coverDeploy}
			stop_unit(u)
			if occupied.coverId != null: u.merge(occupied, true)
	publish()

func attack_stop_distance(u: Dictionary) -> float:
	var reach: float = FieldData.weapons()[u.weapon].range
	return 0.0 if u.charging or u.holdFire or reach <= 45 else reach

func engage_enemy() -> int:
	var ordered = 0
	for u in selected_units():
		var current = find_id(state.battle.units, u.fireTargetId)
		if tactics.automatic_target(self, u, current) and u.target == null and FieldData.distance(u, current) <= attack_stop_distance(u):
			ordered += 1
			continue
		var enemy = current if tactics.automatic_target(self, u, current) else nearest_enemy(u)
		if enemy.is_empty():
			continue
		FieldCharge.cancel(u)
		u.retreating = false
		if FieldData.distance(u, enemy) > attack_stop_distance(u) and not path_unit(u, FieldData.pos(enemy)):
			continue
		if FieldData.distance(u, enemy) <= attack_stop_distance(u):
			u.target = null
			u.waypoints = []
		clear_engagement(u)
		FieldCover.leave(u)
		u.attackId = enemy.id
		u.desiredFacing = null
		u.orderQueue = []
		u.fallingBack = false
		ordered += 1
	publish()
	return ordered

func formation(value: String) -> void:
	for u in selected_units():
		FieldCover.leave(u)
		FieldFormations.order(u, value)
	publish()

func occupy_cover(id: String) -> int:
	if state.battle == null: return 0
	var cover = FieldCover.find(terrain, id)
	for u in selected_units():
		if FieldCover.order(self, u, cover):
			sound_requested.emit("order", u.x)
			publish()
			return 1
	return 0

func leave_cover() -> void:
	for u in selected_units():
		var cover = FieldCover.find(terrain, u.get("coverId") if u.get("coverId") != null else u.get("coverOrderId"))
		if cover.is_empty(): continue
		stop_unit(u)
		path_unit(u, FieldData.pos(u) - Vector2.from_angle(cover.facing) * 55, cover.facing)
	publish()

func toggle_order(key: String) -> void:
	if not key in ["running", "holdFire"]:
		return
	var units = selected_units()
	var value = units.any(func(u): return not u[key])
	for u in units:
		u[key] = value
	publish()

func charge() -> int:
	var ordered = 0
	for u in selected_units():
		if not FieldCharge.eligible(u, state.battle.time):
			continue
		var enemy = nearest_enemy(u)
		if not enemy.is_empty() and path_unit(u, FieldData.pos(enemy)):
			FieldCover.leave(u)
			clear_engagement(u)
			u.attackId = enemy.id
			u.orderQueue = []
			u.fallingBack = false
			FieldCharge.start(u, enemy, state.battle.time)
			u.holdFire = false
			ordered += 1
	publish()
	return ordered

func fall_back() -> void:
	for u in selected_units():
		var enemy = nearest_enemy(u)
		var facing = (FieldData.pos(enemy) - FieldData.pos(u)).angle() if not enemy.is_empty() else float(u.facing)
		stop_unit(u)
		u.fallingBack = true
		path_unit(u, FieldData.pos(u) - Vector2.from_angle(facing) * 100.0, facing)
	publish()

func retreat_units() -> int:
	if state.battle == null: return 0
	var ordered = 0
	for u in selected_units():
		var edge = 45.0 if state.battle.playerEdge == "west" else terrain.map_size.x - 45.0
		var destination = Vector2(edge, clampf(u.y, 45, terrain.map_size.y - 45))
		var path = terrain.route(FieldData.pos(u), destination)
		if path.is_empty(): continue
		stop_unit(u)
		u.retreating = true
		u.running = true
		u.target = path.pop_front()
		u.waypoints = path
		u.goal = FieldData.point(destination)
		if u.kind == "artillery" and (not u.limbered or u.limberChange > 0):
			u.limberChange = FieldData.weapons()[u.weapon].deploy
			u["nextLimber"] = true
		ordered += 1
	publish()
	return ordered

func limber() -> void:
	for u in selected_units():
		if u.kind == "artillery" and u.limberChange <= 0 and not u.retreating:
			u.limberChange = FieldData.weapons()[u.weapon].deploy
			u["nextLimber"] = not u.limbered
	publish()

func dismount() -> void:
	for u in selected_units():
		if u.kind == "cavalry" and FieldData.weapons()[u.weapon].get("dismount", false):
			u.dismounted = not u.dismounted
			FieldCharge.cancel(u)
			u.condition = maxf(0, u.condition - 3)
	publish()

func detach_skirmishers() -> void:
	if state.battle == null:
		return
	var b: Dictionary = state.battle
	for u in selected_units():
		if u.get("parentId") != null:
			var parent = find_id(b.units, u.parentId)
			if parent.is_empty() or parent.routed or FieldData.distance(parent, u) > 90:
				continue
			parent.ammo = (parent.ammo * parent.men + u.ammo * u.men) / (parent.men + u.men)
			parent.men += u.men
			parent.kills += u.kills
			formations.reset_roster(parent)
			b.units.erase(u)
			state.selected = [parent.id]
		elif u.kind == "infantry" and u.men >= 300 and u.formationChange == null and not b.units.any(func(p): return p.get("parentId") == u.id):
			var amount = floorf(u.men * 0.2)
			u.men -= amount
			var detachment: Dictionary = u.duplicate(true)
			detachment.merge({"id": u.id + "-skirmish", "parentId": u.id, "name": u.name.split(" ")[0] + " skirmishers", "men": amount, "startMen": amount, "maxMen": amount, "x": u.x + (-40 if b.playerEdge == "east" else 40), "y": u.y + 25, "formation": "line", "role": "skirmishers", "kills": 0.0}, true)
			stop_unit(detachment)
			formations.reset_roster(u)
			formations.reset_roster(detachment)
			b.units.append(detachment)
			state.selected = [detachment.id]
	publish()

func rally(id = null) -> bool:
	if state.battle == null:
		return false
	if id == null:
		id = state.selectedCommander if state.selectedCommander != null else "general"
	var c = find_id(state.battle.commanders, id)
	if c.is_empty() or c.cooldown > 0 or c.shaken > 0 or c.unavailable or c.get("arrival", 0.0) > state.battle.time:
		return false
	var units = state.battle.units.filter(func(u): return u.side == "player" and u.men > 0 and not u.withdrawn and u.arrival <= state.battle.time and (c.get("armyId") == null or c.armyId == u.get("armyId")) and (c.corpsId == null or c.corpsId == u.corpsId) and FieldData.distance(c, u) <= c.radius and u.morale < 100)
	if units.is_empty():
		return false
	for u in units:
		u.morale = minf(100, u.morale + 18)
		var enemy = nearest_enemy(u)
		if u.routed and u.men > u.startMen * 0.23 and (enemy.is_empty() or FieldData.distance(u, enemy) > 90):
			u.routed = false
	c.cooldown = 45.0
	c.rallyFlash = 2.0
	log_event(c.name + " rallied " + str(units.size()) + " regiments.")
	publish()
	return true

func follow_command() -> void:
	if state.battle == null:
		return
	var c = find_id(state.battle.commanders, state.selectedCommander)
	if not c.is_empty():
		c.following = true
		c.target = null
		publish()

func nearest_enemy(u: Dictionary) -> Dictionary:
	if state.battle == null:
		return {}
	var found: Dictionary = {}
	var best = INF
	for enemy in state.battle.units:
		if not tactics.visible_target(self, u, enemy):
			continue
		if u.side == "enemy" and not terrain.line_of_sight(u, enemy):
			continue
		var d = FieldData.distance(u, enemy)
		if d < best:
			found = enemy
			best = d
	return found

func march(entity: Dictionary, dt: float, pace: float) -> void:
	if not entity.path.is_empty():
		var direction = (FieldData.pos(entity.path[0]) - FieldData.pos(entity)).normalized()
		pace *= terrain.movement_factor(FieldData.pos(entity), FieldData.pos(entity) + direction * 12)
	var remaining = dt * pace
	while not entity.path.is_empty() and remaining > 0:
		var destination: Dictionary = entity.path[0]
		var d = FieldData.distance(entity, destination)
		var step = minf(d, remaining)
		var delta = FieldData.pos(destination) - FieldData.pos(entity)
		if d > 0.01:
			entity["facing"] = rotate_toward(entity.get("facing", delta.angle()), delta.angle(), dt * 0.65)
			entity.x += delta.x / d * step
			entity.y += delta.y / d * step
		remaining -= step
		if step >= d:
			entity.path.pop_front()
		else:
			break

func tick(real_dt: float) -> void:
	if state.paused or state.report != null:
		return
	var dt = minf(real_dt, 0.1) * state.speed
	visual_clock += minf(real_dt, 0.1)
	if state.mode == "campaign":
		update_campaign(dt)
	else:
		var started = Time.get_ticks_usec() if terrain.profile_enabled else 0
		tactics.update(self, dt)
		if terrain.profile_enabled: profile_usec.tactics += Time.get_ticks_usec() - started
		if state.battle != null:
			figure_clock += minf(real_dt, 0.1)
			figure_dt += dt
			if figure_clock + 0.000001 >= figure_interval:
				started = Time.get_ticks_usec() if terrain.profile_enabled else 0
				formations.advance(state.battle.units, state.battle.time, figure_dt, state.battle.bodies, terrain)
				if terrain.profile_enabled: profile_usec.figures += Time.get_ticks_usec() - started
				figure_dt = 0.0
				figure_clock = fposmod(figure_clock, figure_interval)
				if figure_clock < 0.000001 or figure_clock > figure_interval - 0.000001: figure_clock = 0.0
				figure_previous_clock = figure_sample_clock
				figure_sample_clock = visual_clock
				figure_revision += 1
				figure_previous_commands = figure_commands
				figure_commands = {}
				for entity in state.battle.commanders + state.battle.wagons: figure_commands[entity.id] = FieldData.pos(entity)
	ui_clock += real_dt
	save_clock += real_dt
	if ui_clock >= 0.15:
		ui_clock = 0
		publish(false)
	if save_clock >= 4.0:
		save_clock = 0
		if save_enabled:
			save_campaign()

func update_campaign(dt: float) -> void:
	if FieldOperations.enabled(state):
		FieldOperations.update(self, dt)
		return
	state.hours += dt * 0.08
	state.enemyClock += dt
	state.immunity = maxf(0, state.immunity - dt)
	state.recon.remaining = maxf(0, state.recon.remaining - dt)
	state.recon.cooldown = maxf(0, state.recon.cooldown - dt)
	pursuit_clock += dt
	if state.army.get("attackId") != null and pursuit_clock >= 0.75:
		pursuit_clock = 0
		var enemy = find_id(state.enemies, state.army.attackId)
		if enemy.is_empty() or enemy.defeated or not enemy_visible(enemy):
			state.army.attackId = null
		else:
			var path = terrain.route(FieldData.pos(state.army), FieldData.pos(enemy))
			if not path.is_empty(): state.army.path = path
	var before = FieldData.pos(state.army)
	var march_order: Dictionary = FieldCampaign.MARCH_MODES[state.army.marchMode]
	var woods = FieldTerrain.kind(FieldData.pos(state.army), {"forests": terrain.forests}) == "woods"
	march(state.army, dt, (14.0 if woods else 24.0) * march_order.pace * (0.65 + state.army.condition * 0.0035))
	var moving = before.distance_to(FieldData.pos(state.army)) > 0.0001
	state.army.condition = clampf(state.army.condition + dt * (-march_order.fatigue if moving else 0.65), 0, 100)
	for u in state.units:
		u.condition = clampf(u.condition + dt * (-march_order.fatigue * 0.65 if moving else 0.6), 0, 100)
	for e in state.enemies:
		if e.defeated:
			continue
		if enemy_visible(e):
			var precision = 50.0 if state.recon.remaining > 0 else 200.0
			e.intel = {"x": e.x, "y": e.y, "at": state.hours, "strength": roundf(e.strength / precision) * precision}
		if state.enemyClock > 3:
			var target = FieldCampaign.decision(state, terrain, e)
			e.path = terrain.route(FieldData.pos(e), target)
		e.resting = e.condition < 50 if e.resting else e.condition < 18
		e.marchMode = "slow" if e.condition < 40 else "route" if e.intent == "Intercepting" else "normal"
		var enemy_order: Dictionary = FieldCampaign.MARCH_MODES[e.marchMode]
		var enemy_before = FieldData.pos(e)
		if not e.resting:
			var terrain_pace = 0.58 if FieldTerrain.kind(enemy_before, {"forests": terrain.forests}) == "woods" else 1.0
			march(e, dt, 10 * enemy_order.pace * terrain_pace * (0.65 + e.condition * 0.0035))
		e.condition = clampf(e.condition + dt * (-enemy_order.fatigue if FieldData.pos(e).distance_to(enemy_before) > 0.0001 else 0.65), 0, 100)
		if state.immunity <= 0 and FieldData.men(state.units) > 0 and FieldData.distance(e, state.army) < 48:
			start_battle(e.id)
			break
	if state.enemyClock > 3:
		state.enemyClock = 0

func start_battle(id: String, demonstration: bool = false, map_version: int = FieldBattlefield.VERSION) -> bool:
	var main = find_id(state.enemies, id)
	if state.mode != "campaign" or main.is_empty() or main.defeated or state.report != null or FieldData.men(state.units) == 0:
		return false
	tactics.clear_ai()
	var operational = FieldOperations.enabled(state)
	if operational and (state.army.defeated or state.army.retreatUntil > state.hours or main.retreatUntil > state.hours): return false
	var encounter_data = FieldOperations.encounter(self, id) if operational else {}
	var involved = [main]
	for e in state.enemies:
		if e.id != id and not e.defeated and FieldData.distance(e, main) < 210:
			involved.append(e)
	var edge = "east" if state.army.x > main.x else "west"
	var scenario = "bridge" if absf(main.y - terrain.river_y(main.x)) < 90 * terrain.campaign_scale else "ridge" if main.id == "e2" else "village"
	if demonstration:
		scenario = "bridge"
		edge = "west"
	if operational:
		scenario = encounter_data.scenario
		edge = encounter_data.edge
		involved = state.enemies.filter(func(e): return encounter_data.schedule.any(func(entry): return entry.armyId == e.id))
	var units: Array = []
	var own = army_units().filter(func(u): return u.men > 0)
	for i in own.size():
		var u: Dictionary = own[i].duplicate(true)
		u.merge({"side": "player", "startMen": u.men, "x": (430.0 if scenario == "ridge" else 280.0) if edge == "west" else 1160.0, "y": 480.0 + (i - (own.size() - 1) / 2.0) * minf(140, 750.0 / maxf(1, own.size() - 1)), "morale": 100.0, "condition": minf(u.condition, state.army.condition), "reload": i * 0.3, "facing": 0.0 if edge == "west" else PI}, true)
		FieldData.regiment_defaults(u)
		stop_unit(u)
		units.append(u)
	for index in involved.size():
		var army: Dictionary = involved[index]
		for i in 5:
			var kind = "cavalry" if i == 3 else "artillery" if i == 4 else "infantry"
			var count = roundf(army.strength * [0.3, 0.3, 0.23, 0.11, 0.06][i])
			var u = {"id": army.id + "-" + str(i), "name": ["Grenadiers", "Line Infantry", "Fusiliers", "Chevaulegers", "Field Battery"][i], "kind": kind, "weapon": FieldArsenal.enemy_issue(i, index), "men": count, "maxMen": count, "startMen": count, "side": "enemy", "x": 1100.0 + index * 85 if edge == "west" else 340.0 - index * 85, "y": 200.0 + i * 140, "experience": index * 0.1, "reload": 1.0 + i * 0.35, "arrival": 35.0 + index * 12 if index > 0 else 0.0, "facing": PI if edge == "west" else 0.0, "aiRole": "flank" if kind == "cavalry" else "battery" if kind == "artillery" else "reserve" if i == 2 else "line"}
			FieldData.regiment_defaults(u)
			u.condition = army.condition
			units.append(u)
	if operational: units = FieldOperations.muster(state, encounter_data)
	var towns: Array = FieldCampaign.layout(state.theater).towns
	var nearest: Dictionary = towns[0]
	for t in towns:
		if FieldData.distance(t, main) < FieldData.distance(nearest, main):
			nearest = t
	var reward = 0.0
	for e in involved:
		reward += e.reward
	var commanders: Array = [{"id": "general", "name": state.general.name, "corpsId": null, "specialty": "Army command", "radius": 220.0, "x": 125.0, "y": 480.0}]
	for corps in state.corps:
		var members = units.filter(func(u): return u.side == "player" and u.corpsId == corps.id)
		if operational and members.is_empty(): continue
		commanders.append({"id": corps.commanderId, "name": corps.commander, "corpsId": corps.id, "specialty": corps.specialty, "officerId": corps.officerId, "radius": 175.0, "x": 190.0, "y": 760.0, "hostId": members[0].id if not members.is_empty() else null})
	for c in commanders:
		c.merge({"target": null, "waypoints": [], "following": c.corpsId == null, "cooldown": 0.0, "shaken": 0.0, "rallyFlash": 0.0, "facing": 0.0, "unavailable": false, "officerId": c.get("officerId")}, true)
		if edge == "east":
			c.x = 1440 - c.x
	state.battle = {"scenario": scenario, "playerEdge": edge, "enemyIds": involved.map(func(e): return e.id), "name": "The Valeggio Crossing" if demonstration else "Battle of " + nearest.name, "units": units, "commanders": commanders, "time": 0.0, "startMen": FieldData.men(state.units), "enemyStartMen": FieldData.men(units.filter(func(u): return u.side == "enemy")), "origin": FieldData.point(FieldData.pos(state.army)), "reward": reward, "officerStart": state.officers.map(func(o): return {"id": o.id, "rank": FieldData.rank_of(o), "woundedUntil": o.woundedUntil, "dead": o.dead}), "visibilityClock": 0.0, "aiClock": 0.0, "objective": {"player": 0.0, "enemy": 0.0, "owner": null}, "artilleryImpacts": [], "wagons": [{"id": "supply-player", "name": "Supply train", "side": "player", "kind": "wagon", "x": 145.0 if edge == "west" else 1295.0, "y": 565.0, "stock": state.supply, "health": 100.0, "target": null, "waypoints": [], "visible": true, "facing": 0.0}, {"id": "supply-enemy", "name": "Enemy supply", "side": "enemy", "kind": "wagon", "x": 1300.0 if edge == "west" else 140.0, "y": 485.0, "stock": 700.0, "health": 100.0, "target": null, "waypoints": [], "visible": false, "facing": PI}]}
	if operational:
		state.battle.merge({"campaignForces": encounter_data.schedule, "origin": encounter_data.origin, "name": encounter_data.name, "siteId": encounter_data.siteId, "startMen": FieldData.men(units.filter(func(u): return u.side == "player"))}, true)
		state.battle.commanders[0].name = state.army.commander
		state.battle.commanders[0].officerId = state.army.get("officerId")
		state.battle.commanders[0]["armyId"] = state.army.id
		for entry in encounter_data.schedule:
			if entry.side != "player" or entry.armyId == state.army.id: continue
			var force = FieldOperations.force(state, entry.armyId)
			var members = units.filter(func(u): return u.armyId == force.id)
			var general = state.battle.commanders[0].duplicate(true)
			general.merge({"id": "general-" + force.id, "armyId": force.id, "name": force.commander, "officerId": force.get("officerId"), "arrival": entry.arrival, "x": clampf(members[0].x - cos(members[0].facing) * 65, 45, 1395), "y": clampf(members[0].y - sin(members[0].facing) * 65, 45, 915), "unavailable": entry.arrival > 0, "following": true}, true)
			state.battle.commanders.append(general)
		state.battle.wagons[1].stock = main.supply
	if demonstration:
		for i in own.size():
			units[i].x = 380.0 if i == 4 else 450.0 if i == 3 else 390.0 if i == 2 else 490.0
			units[i].y = [300.0, 435.0, 565.0, 715.0, 660.0][i] if i < 5 else 180.0 + i * 85.0
		for i in range(own.size(), units.size()):
			units[i].x = 805.0 if (i - own.size()) % 5 == 1 else 880.0
			units[i].y = 280.0 + ((i - own.size()) % 5) * 112.0
		commanders[0].x = 350.0
		commanders[0].y = 470.0
		commanders[0].following = false
		state.battle.wagons[0].x = 335.0
		state.battle.wagons[0].y = 580.0
	FieldBattlefield.prepare(state.battle, map_version)
	state.mode = "battle"
	state.battle["bodies"] = []
	for u in state.battle.units:
		formations.reset_roster(u)
	state.paused = true
	state.army.path = []
	state.army["attackId"] = null
	state.selectedCommander = null
	state.selectedSupply = false
	state.orderMode = "move"
	state.selected = [units[0].id]
	terrain.configure(state)
	prepare_deployment()
	formations.groups.clear()
	formations.motion.clear()
	reset_presentation()
	for u in state.battle.units: formations.positions(u)
	sync_hosts()
	tactics.update_visibility(self)
	log_event(main.name + "'s army engaged.")
	publish()
	return true

func sync_hosts() -> void:
	if state.battle == null:
		return
	for c in state.battle.commanders:
		if c.get("hostId") == null:
			continue
		var host = find_id(state.battle.units, c.hostId)
		if not host.is_empty():
			c.x = host.x
			c.y = host.y
		c.unavailable = not FieldData.ready(find_id(state.officers, c.officerId), state.hours) or host.is_empty() or host.men <= 0 or host.routed or host.withdrawn or host.arrival > state.battle.time
		c.target = null
		c.waypoints = []

func finish_battle(won: bool, retreat: bool = false) -> bool:
	if state.mode != "battle" or state.battle == null:
		return false
	if FieldOperations.enabled(state): return FieldOperations.resolve(self, won, retreat)
	var b: Dictionary = state.battle
	for u in state.units:
		var result = find_id(b.units, u.id)
		if result.is_empty():
			continue
		var pieces = [result] + b.units.filter(func(p): return p.get("parentId") == u.id)
		var survivors = 0.0
		var killed = 0.0
		var ammo = 0.0
		for piece in pieces:
			survivors += piece.men
			killed += piece.kills
			ammo += piece.ammo * piece.men
		var lost = maxf(0, u.men - survivors)
		u.men = maxf(0, floorf(survivors))
		u.morale = 100.0
		u.condition = result.condition
		u.ammo = ammo / survivors if survivors > 0 else 0.0
		u.skills = result.skills.duplicate(true)
		u.history.push_front({"battle": b.name, "won": won, "retreat": retreat, "losses": roundi(lost), "kills": floori(killed), "hours": state.hours})
		if u.history.size() > 12:
			u.history.resize(12)
		var officer = find_id(state.officers, u.officerId)
		if FieldData.ready(officer, state.hours):
			officer.xp += minf(45, b.time / 25.0 + (15 if won else 5))
			if survivors < result.startMen * 0.12:
				officer.dead = true
				log_event(officer.name + " killed in action.")
			elif lost > result.startMen * 0.35:
				officer.woundedUntil = state.hours + 8
				officer.wounds += 1
				log_event(officer.name + " wounded; recovering for eight campaign hours.")
			u.commander = FieldData.load_data().ranks[FieldData.rank_of(officer)] + " " + officer.name
		u.experience = minf(5, u.experience + (0.8 if won else 0.25))
	for corps in state.corps:
		var officer = find_id(state.officers, corps.officerId)
		if FieldData.ready(officer, state.hours):
			officer.xp += minf(35, b.time / 40.0 + (12 if won else 4))
			corps.commander = FieldData.load_data().ranks[FieldData.rank_of(officer)] + " " + officer.name
	state.supply = maxf(0, b.wagons[0].stock)
	var total_condition = 0.0
	for u in state.units:
		total_condition += u.condition
	state.army.condition = maxf(20, total_condition / state.units.size())
	var armies = state.enemies.filter(func(e): return e.id in b.enemyIds)
	var loot = 0
	var captured: Dictionary = {}
	var damaged: Dictionary = {}
	if won:
		state.cash += b.reward
		state.victories += armies.size()
		for enemy in b.units:
			if enemy.side != "enemy" or enemy.arrival > b.time: continue
			var amount = FieldArsenal.capture_count(enemy.kind, enemy.startMen - enemy.men)
			captured[enemy.weapon] = captured.get(enemy.weapon, 0) + amount
			loot += amount
		damaged = FieldArsenal.salvage(state, captured)
		for e in armies:
			e.defeated = true
			e.path = []
		log_event("Victory. " + str(int(b.reward)) + " francs awarded.")
	else:
		for e in armies:
			e.strength = maxi(250, FieldData.men(b.units.filter(func(u): return str(u.id).begins_with(e.id + "-"))))
			e.path = []
		state.army.x = 280.0 * FieldCampaign.layout(state.theater, state.campaignMapVersion).scale
		state.army.y = 727.0 * FieldCampaign.layout(state.theater, state.campaignMapVersion).scale
		state.immunity = 18.0
		log_event("Army withdrawn to the forward depot." if retreat else "Defeated. Survivors regrouped at the forward depot.")
	var regiments: Array = []
	for u in state.units:
		if not find_id(b.units, u.id).is_empty():
			regiments.append({"id": u.id, "name": u.name, "men": u.men, "losses": u.history[0].losses, "kills": u.history[0].kills, "experience": u.experience})
	var officer_events: Array = []
	for previous in b.officerStart:
		var o = find_id(state.officers, previous.id)
		if o.dead and not previous.dead:
			officer_events.append({"name": o.name, "status": "Killed in action"})
		elif not o.dead:
			if o.woundedUntil > previous.woundedUntil:
				officer_events.append({"name": o.name, "status": "Wounded"})
			if FieldData.rank_of(o) > previous.rank:
				officer_events.append({"name": o.name, "status": "Promoted to " + FieldData.load_data().ranks[FieldData.rank_of(o)]})
	state.report = {"won": won, "retreat": retreat, "name": b.name, "casualties": b.startMen - FieldData.men(state.units), "enemyCasualties": b.enemyStartMen - FieldData.men(b.units.filter(func(u): return u.side == "enemy")), "reward": b.reward if won else 0, "loot": loot, "regiments": regiments, "officers": officer_events, "complete": state.enemies.all(func(e): return e.defeated)}
	state.report["capturedWeapons"] = captured
	state.report["damagedWeapons"] = damaged
	state.battle = null
	tactics.clear_ai()
	state.selectedCommander = null
	state.selectedSupply = false
	state.mode = "campaign"
	state.paused = true
	state.selected = [state.units[0].id]
	formations.groups.clear()
	terrain.configure(state)
	publish()
	return true

func dismiss_report() -> void:
	state.report = null
	publish()

func set_sound(enabled: bool, volume: float) -> void:
	state.settings = {"sound": enabled, "volume": clampf(volume, 0, 1)}
	publish()
