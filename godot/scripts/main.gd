extends Node

var model: FieldModel
var campaign: FieldModel
var world: FieldWorld
var hud: FieldHud
var audio: FieldAudio
var exercise = false
var test_mode = false
var physics_micros = 0

func _ready() -> void:
	var started = Time.get_ticks_usec()
	test_mode = "--verify" in OS.get_cmdline_user_args() or "--verify-cover" in OS.get_cmdline_user_args() or "--verify-ai" in OS.get_cmdline_user_args() or "--verify-campaign" in OS.get_cmdline_user_args() or "--verify-theme" in OS.get_cmdline_user_args() or "--verify-slopes" in OS.get_cmdline_user_args() or "--verify-animation" in OS.get_cmdline_user_args() or "--profile" in OS.get_cmdline_user_args()
	var campaign_demo = "--campaign-demo" in OS.get_cmdline_user_args()
	var valeggio_demo = "--valeggio-demo" in OS.get_cmdline_user_args()
	var battle_demo = "--battle-demo" in OS.get_cmdline_user_args() or "--grand-battle-demo" in OS.get_cmdline_user_args()
	test_mode = test_mode or "--verify-maps" in OS.get_cmdline_user_args()
	model = FieldModel.new(not test_mode and not campaign_demo and not valeggio_demo and not battle_demo)
	if campaign_demo and not test_mode:
		model.new_campaign("mantua")
		model.save_path = "user://mantua-operation.json"
		model.save_enabled = true
		model.load_recoverable(model.save_path)
	campaign = model
	if not valeggio_demo and not battle_demo: install(model)
	if test_mode: print("GODOT STARTUP: %.2fs / %d disk-cache hits" % [(Time.get_ticks_usec() - started) / 1000000.0, FieldArt.cache_hits])
	get_tree().auto_accept_quit = false
	if test_mode:
		var runner = load("res://tests/visual.gd").new()
		add_child(runner)
		if "--profile" in OS.get_cmdline_user_args(): runner.run_profile(self)
		else: runner.run(self)
	elif "--ai-demo" in OS.get_cmdline_user_args():
		start_skirmish("defense")
	elif valeggio_demo:
		start_skirmish("bridge")
		get_window().title = "Field Command - Valeggio Preview"
		print("VALEGGIO PREVIEW READY: paused exercise; campaign saving disabled")
	elif battle_demo:
		start_skirmish("grand" if "--grand-battle-demo" in OS.get_cmdline_user_args() else "polish")
		get_window().title = "Field Command - The Mincio Battlefield"
		print("BATTLE POLISH READY: %d formations; isolated exercise" % model.state.battle.units.size())

func install(game: FieldModel) -> void:
	for node in [world, hud, audio]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	model = game
	world = FieldWorld.new()
	add_child(world)
	world.setup(model)
	hud = FieldHud.new()
	add_child(hud)
	hud.setup(model, world, exercise)
	hud.skirmish_requested.connect(start_skirmish)
	hud.campaign_requested.connect(resume_campaign)
	hud.new_campaign_requested.connect(new_campaign)
	audio = FieldAudio.new()
	add_child(audio)
	audio.setup(model, world)

func start_skirmish(scenario: String = "bridge") -> void:
	if scenario in ["polish", "grand"]:
		if not exercise:
			campaign = model
			campaign.state.paused = true
		exercise = true
		install(FieldBattleExercises.create(20 if scenario == "grand" else 12))
		world.center = model.terrain.map_size * 0.5 - Vector2(320, 0)
		world.zoom = 0.65
		world.update_camera()
		return
	var defensive_drill = scenario == "defense"
	if defensive_drill: scenario = "village"
	if not exercise:
		campaign = model
		campaign.state.paused = true
	exercise = true
	var drill = FieldModel.new(false)
	drill.start_battle("e1", scenario == "bridge")
	drill.state.battle.scenario = scenario
	drill.state.battle.name = {"bridge": "The Valeggio Crossing", "village": "Saint Martin", "ridge": "The Heights"}[scenario]
	drill.terrain.configure(drill.state)
	drill.prepare_deployment()
	if defensive_drill:
		drill.state.battle.name = "Coordinated Defense"
		drill.state.battle["aiPersonality"] = "cautious"
		FieldBattleAI.initialize(drill)
		FieldBattleAI.choose_plan(drill, FieldTactics.active(drill.state.battle, "enemy"), [])
		var friends = FieldTactics.active(drill.state.battle, "enemy")
		for u in friends:
			var point = FieldBattleAI.position_for(drill, u, FieldData.pos(u.ai.station), friends)
			if point == null: continue
			u.x = point.x
			u.y = point.y
			drill.formations.reset(u)
		drill.state.battle.ai.until = -1.0
	drill.tactics.update_visibility(drill)
	install(drill)

func resume_campaign() -> void:
	if exercise:
		exercise = false
		install(campaign)

func new_campaign(theater: String) -> void:
	exercise = false
	var path: String = campaign.save_path
	campaign = FieldModel.new(false)
	campaign.save_path = path
	campaign.save_enabled = not test_mode
	campaign.new_campaign(theater)
	install(campaign)

func _physics_process(dt: float) -> void:
	if model != null:
		var start = Time.get_ticks_usec()
		if not model.state.paused: world.remember_transforms()
		model.tick(dt)
		physics_micros += Time.get_ticks_usec() - start

func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)
	FieldArt.textures.clear()
	FieldAudio.prepared.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and model != null and not test_mode:
		model.state.paused = true
		model.publish(false)
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if campaign != null and campaign.save_enabled:
			campaign.save_campaign()
		get_tree().quit()
