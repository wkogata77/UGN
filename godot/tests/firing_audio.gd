extends SceneTree

var checks = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("FAIL: " + label)

func energy(stream: AudioStreamWAV, start: float, end: float, bass_only: bool = false) -> float:
	var total = 0.0
	var low = 0.0
	var alpha = 1.0 - exp(-TAU * 250 / stream.mix_rate)
	for i in mini(stream.data.size() / 2, ceili(end * stream.mix_rate)):
		var value = stream.data.decode_s16(i * 2) / 32768.0
		low = lerpf(low, value, alpha)
		if i >= start * stream.mix_rate: total += pow(low if bass_only else value, 2)
	return total

func run() -> void:
	var bake = "--bake" in OS.get_cmdline_user_args()
	var generated: Dictionary = {}
	if bake: DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for kind in ["musket", "cannon"]:
		for variant in 3:
			var stream = FieldAudio.synthesize(kind, variant)
			var key = kind + str(variant)
			generated[key] = stream
			if bake: check(stream.save_to_wav("res://assets/audio/" + key + ".wav") == OK, "bake " + key)
			check(stream.mix_rate == 44100 and not stream.stereo, key + " is full-rate mono for camera panning")
			check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, key + " has no discontinuous start or cut-off tail")
			var peak = 0
			for i in stream.data.size() / 2: peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
			check(peak > 28000 and peak < 30000, key + " has consistent headroom without sample clipping")
			var total = energy(stream, 0, 2.8)
			var bass = energy(stream, 0, 2.8, true) / total
			var tail = energy(stream, 0.15, 2.8) / total
			print(key, " bass=", snappedf(bass, 0.001), " tail=", snappedf(tail, 0.001))
			check(bass > 0.6 if kind == "cannon" else bass < 0.3, key + " has the intended boom/crack frequency balance")
			check(tail > 0.25 if kind == "cannon" else energy(stream, 0.025, 0.15) / total > 0.2, key + " has audible body beyond its transient")
	firing_events()
	var buses = AudioServer.bus_count
	var m = FieldModel.new(false)
	m.state.settings.sound = true
	m.state.settings.volume = 0.3
	m.state.paused = false
	var sound = FieldAudio.new()
	root.add_child(sound)
	sound.setup(m)
	if not bake:
		for key in generated:
			check(not sound.streams[key].resource_path.is_empty() and sound.streams[key].data == generated[key].data, key + " plays the baked asset without runtime synthesis")
	check(sound.voices.size() == 24 and sound.streams.size() == 21, "large battles retain bounded voice and variant pools")
	check(sound.filters.size() == 24 and sound.ambience_voice.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "distance filters and looping outdoor ambience are available")
	var mix = AudioServer.get_bus_index(sound.buses[0])
	check(AudioServer.get_bus_effect(mix, 0) is AudioEffectHardLimiter, "simultaneous reports have a shared peak limiter")
	check(sound.voices.all(func(voice): return AudioServer.get_bus_send(AudioServer.get_bus_index(voice.bus)) == sound.buses[0]), "all panned voices feed the protected mix")
	if "--playback" in OS.get_cmdline_user_args():
		for kind in ["musket", "musket", "cannon"]:
			sound.play(kind)
			var voice = sound.voices.filter(func(v): return v.playing)[0]
			check(voice.get_meta("kind") == kind, "native playback chooses " + kind)
			var deadline = Time.get_ticks_msec() + (2000 if kind == "musket" else 3600)
			while voice.playing and Time.get_ticks_msec() < deadline:
				await create_timer(0.05).timeout
			check(not voice.playing, kind + " playback drains naturally")
		var capture = AudioEffectCapture.new()
		capture.buffer_length = 1.0
		AudioServer.add_bus_effect(mix, capture)
		# Exercise a full-volume volley internally without blasting the speakers.
		AudioServer.set_bus_mute(mix, true)
		m.state.settings.volume = 1.0
		for i in 12: sound.play("musket")
		sound.play("cannon")
		check(sound.voices.any(func(v): return v.playing and v.get_meta("kind") == "cannon"), "cannon report can preempt a busy musket volley")
		await create_timer(0.25).timeout
		var frames = capture.get_buffer(capture.get_frames_available())
		var peak = 0.0
		for frame in frames: peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
		check(peak > 0.1 and peak <= db_to_linear(-1.0) + 0.002, "native simultaneous-volley output stays under the limiter ceiling")
		m.state.settings.sound = false
		sound._process(0.1)
		check(sound.voices.all(func(v): return not v.playing), "mute stops every firing tail")
		m.state.settings.sound = true
		m.state.settings.volume = 0.3
		sound.play("cannon")
		m.state.paused = true
		sound._process(0.1)
		check(sound.voices.all(func(v): return not v.playing), "pause stops the longer cannon tail")
		m.state.settings.volume = 0
		sound.play("musket")
		check(sound.voices.all(func(v): return not v.playing), "zero volume suppresses new firing sounds")
	sound.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	check(AudioServer.bus_count == buses, "scene teardown releases voices and the mix bus")
	print("GODOT FIRING AUDIO: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func firing_events() -> void:
	for label in ["infantry", "cavalry", "dismounted cavalry", "artillery"]:
		var kind = "cavalry" if label == "dismounted cavalry" else label
		var m = FieldModel.new(false)
		m.start_battle("e1", true)
		m.state.battle.scenario = "village"
		m.terrain.configure(m.state)
		m.terrain.field = m.terrain.field.duplicate(true)
		m.terrain.field.hills = []
		m.terrain.field.forests = []
		m.terrain.buildings.clear()
		m.terrain.defenses.clear()
		m.terrain.relief = 0
		m.state.battle.aiClock = -10000
		for u in m.state.battle.units: u.arrival = 99999
		var a: Dictionary = m.state.battle.units[0]
		var b: Dictionary = m.state.battle.units[5]
		a.merge({"kind": kind, "weapon": "cannon" if kind == "artillery" else "carbine" if kind == "cavalry" else "musket", "x": 450.0, "y": 400.0, "facing": 0.0, "arrival": 0.0, "reload": 0.0, "holdFire": false, "visible": true}, true)
		a.dismounted = label == "dismounted cavalry"
		b.merge({"x": 560.0, "y": 400.0, "facing": PI, "arrival": 0.0, "holdFire": true, "visible": true}, true)
		var events: Array = []
		m.sound_requested.connect(func(event, _x): events.append(event))
		m.tactics.update(m, 0.05)
		check(events == ["cannon" if kind == "artillery" else "musket"], label + " actual volley emits the intended shared firearm event")
