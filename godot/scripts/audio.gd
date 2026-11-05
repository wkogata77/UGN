class_name FieldAudio
extends Node

var model: FieldModel
var world: FieldWorld
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var pans: Array[AudioEffectPanner] = []
var filters: Array[AudioEffectLowPassFilter] = []
var buses: Array[String] = []
var last_march = -1.0
var sequence = 0
static var prepared: Dictionary = {}
var ambience_voice: AudioStreamPlayer

func setup(game: FieldModel, map: FieldWorld = null) -> void:
	model = game
	world = map
	for kind in ["order", "musket", "cannon", "march", "melee", "hoof", "wheels"]:
		for variant in 3:
			var key = kind + str(variant)
			if not prepared.has(key):
				var path = "res://assets/audio/" + key + ".wav"
				prepared[key] = load(path) if kind in ["musket", "cannon"] and ResourceLoader.exists(path) else synthesize(kind, variant)
			streams[key] = prepared[key]
	var mix = "FieldMix-%d" % get_instance_id()
	AudioServer.add_bus()
	var mix_index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(mix_index, mix)
	var limiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(mix_index, limiter)
	var room = AudioEffectReverb.new()
	room.wet = 0.06
	room.room_size = 0.55
	AudioServer.add_bus_effect(mix_index, room)
	buses.append(mix)
	for i in 24:
		var bus = "FieldVoice-%d-%d" % [get_instance_id(), i]
		AudioServer.add_bus()
		var index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, mix)
		var pan = AudioEffectPanner.new()
		AudioServer.add_bus_effect(index, pan)
		buses.append(bus)
		pans.append(pan)
		var filter = AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 18000
		AudioServer.add_bus_effect(index, filter)
		filters.append(filter)
		var voice = AudioStreamPlayer.new()
		voice.bus = bus
		add_child(voice)
		voices.append(voice)
	if not prepared.has("ambience"): prepared.ambience = wind()
	ambience_voice = AudioStreamPlayer.new()
	ambience_voice.stream = prepared.ambience
	ambience_voice.bus = mix
	add_child(ambience_voice)
	model.sound_requested.connect(play)

static func wind() -> AudioStreamWAV:
	var samples = 22050 * 4
	var data = PackedByteArray()
	data.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1796
	var value = 0.0
	for i in samples:
		value = lerpf(value, rng.randf_range(-1, 1), 0.045)
		var envelope = sin(float(i) / samples * PI)
		data.encode_s16(i * 2, roundi(value * envelope * 24000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples
	return stream

static func synthesize(kind: String, variant: int) -> AudioStreamWAV:
	if kind in ["musket", "cannon"]: return firearm(kind, variant)
	var duration = 0.17 if kind == "hoof" else 0.24 if kind == "wheels" else 0.09
	var cutoff = 480.0
	var rate = 22050
	var rng = RandomNumberGenerator.new()
	rng.seed = (kind + str(variant)).hash()
	var data = PackedByteArray()
	var samples = ceili(duration * rate)
	data.resize(samples * 2)
	var previous = 0.0
	for i in samples:
		var t = float(i) / rate
		var envelope = exp(-t / duration * 8)
		var noise = rng.randf_range(-1, 1)
		previous = lerpf(previous, noise, clampf(cutoff / rate * TAU, 0, 1))
		var value = previous * envelope
		if kind == "hoof": value += sin(t * TAU * (130 + variant * 13)) * envelope * 0.3
		if kind == "wheels": value += sin(t * TAU * 320) * envelope * 0.07
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 32760))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

static func firearm(kind: String, variant: int) -> AudioStreamWAV:
	var cannon = kind == "cannon"
	var rate = 44100
	var duration = 2.8 if cannon else 0.95
	var samples = ceili(duration * rate)
	var dry = PackedFloat32Array()
	dry.resize(samples)
	var rng = RandomNumberGenerator.new()
	rng.seed = ("black-powder-v2:" + kind + str(variant)).hash()
	var bass = 0.0
	var body = 0.0
	var air = 0.0
	var bass_alpha = 1.0 - exp(-TAU * (75 if cannon else 100) / rate)
	var body_alpha = 1.0 - exp(-TAU * (300 if cannon else 1050) / rate)
	var air_alpha = 1.0 - exp(-TAU * (1700 if cannon else 6200) / rate)
	var variation = 1.0 + (variant - 1) * 0.035
	var phase = 0.0
	for i in samples:
		var t = float(i) / rate
		var noise = rng.randf_range(-1, 1)
		bass = lerpf(bass, noise, bass_alpha)
		body = lerpf(body, noise, body_alpha)
		air = lerpf(air, noise, air_alpha)
		var attack = 1.0 - exp(-t / (0.004 if cannon else 0.0006))
		if cannon:
			# A short pressure front, noisy low body, and a broad rolling bass tail.
			phase += TAU * (37 + 30 * exp(-t * 9)) * variation / rate
			dry[i] = attack * ((air - body) * 0.35 * exp(-t / 0.025) + body * 4.5 * exp(-t / 0.25) + bass * 5.5 * exp(-t / 0.68) + sin(phase) * 0.28 * exp(-t / 0.32))
		else:
			# The crack has a fast leading edge but enough midrange body to avoid a click.
			dry[i] = attack * ((air - body) * 1.7 * exp(-t / (0.014 * variation)) + (body - bass) * 3.8 * exp(-t / 0.078) + bass * 1.4 * exp(-t / 0.11))
	var taps = [0.105, 0.235, 0.43, 0.71] if cannon else [0.033, 0.079, 0.145]
	var gains = [0.3, 0.2, 0.12, 0.06] if cannon else [0.25, 0.14, 0.07]
	var delays: Array[int] = []
	for tap in taps: delays.append(roundi(tap * variation * rate))
	var output = PackedFloat32Array()
	output.resize(samples)
	var previous = 0.0
	var filtered = 0.0
	var warmth = 0.0
	var warm_alpha = 1.0 - exp(-TAU * 500.0 / rate)
	var peak = 0.0001
	var dc = exp(-TAU * 22.0 / rate)
	for i in samples:
		var value = dry[i]
		for j in delays.size():
			if i >= delays[j]: value += dry[i - delays[j]] * gains[j]
		if cannon:
			warmth = lerpf(warmth, value, warm_alpha)
			value = warmth
		filtered = value - previous + dc * filtered
		previous = value
		var fade = clampf(float(samples - 1 - i) / (rate * 0.04), 0, 1)
		output[i] = filtered * fade
		peak = maxf(peak, absf(output[i]))
	var data = PackedByteArray()
	data.resize(samples * 2)
	for i in samples: data.encode_s16(i * 2, roundi(output[i] / peak * 0.88 * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func play(kind: String, x: float = 720.0, y: float = NAN) -> void:
	if not model.state.settings.sound or model.state.settings.volume <= 0: return
	var priority = 3 if kind in ["order", "cannon"] else 2 if kind in ["musket", "melee"] else 1
	var slot = -1
	for i in voices.size():
		if not voices[i].playing:
			slot = i
			break
		if int(voices[i].get_meta("priority", 0)) < priority: slot = i
	if slot < 0: return
	sequence += 1
	var voice = voices[slot]
	voice.stop()
	voice.set_meta("priority", priority)
	voice.set_meta("kind", kind)
	voice.stream = streams.get(kind + str(sequence % 3), streams.order0)
	var offset = (x - world.center.x) / maxf(200, world.get_viewport().get_visible_rect().size.x / world.zoom * 0.5) if is_instance_valid(world) else 0.0
	var distance = absf(offset)
	if is_instance_valid(world) and kind != "order":
		if is_nan(y) and model.state.battle != null:
			for unit in model.state.battle.units:
				if absf(unit.x - x) < 0.1 and unit.get("shotKind", "") == kind and absf(unit.get("shotTime", -100.0) - model.state.battle.time) < 0.01:
					y = unit.y
					break
		if not is_nan(y):
			var delta = (Vector2(x, y) - world.center) / Vector2(world.camera.size * world.get_viewport().get_visible_rect().size.aspect(), world.camera.size / sin(FieldWorld.CAMERA_PITCH))
			distance = delta.length() * 1.6
	pans[slot].pan = clampf(offset, -0.9, 0.9) if kind != "order" else 0.0
	var level = 0.56 if kind == "cannon" else 0.30 if kind == "musket" else 0.08 if kind == "order" else 0.045
	var attenuation = 1.0 if kind == "order" else 1.0 / (1.0 + distance * distance * 1.1)
	filters[slot].cutoff_hz = 18000 if kind == "order" else lerpf(14000, 2200, clampf(distance / 2.5, 0, 1))
	voice.volume_db = linear_to_db(maxf(0.0001, level * attenuation * model.state.settings.volume))
	voice.pitch_scale = 0.985 + (sequence % 3) * 0.015 if kind in ["musket", "cannon"] else 0.96 + (sequence % 5) * 0.02
	voice.play()

func _process(_dt: float) -> void:
	if model == null: return
	if model.state.paused or not model.state.settings.sound or model.state.settings.volume <= 0:
		if is_instance_valid(ambience_voice): ambience_voice.stop()
		for voice in voices:
			if not model.state.settings.sound or model.state.settings.volume <= 0 or voice.get_meta("kind", "") != "order": voice.stop()
		return
	if is_instance_valid(ambience_voice):
		ambience_voice.volume_db = -34.0 + linear_to_db(maxf(0.0001, model.state.settings.volume))
		if not ambience_voice.playing: ambience_voice.play()
	var time: float = model.state.battle.time if model.state.battle != null else (model.state.hours - 6) / 0.08
	if time < last_march: last_march = time - 1
	if time - last_march <= 0.4: return
	var moving: Array = model.state.battle.units.filter(func(u): return u.visible and u.target != null and u.get("movementBlocked", "").is_empty() and not u.routed and not u.withdrawn) if model.state.battle != null else [model.state.army] if not model.state.army.path.is_empty() else []
	if model.state.battle == null and FieldOperations.enabled(model.state): moving = model.state.armies.filter(func(a): return not a.defeated and not a.get("resting", false) and not a.path.is_empty())
	if moving.is_empty(): return
	if is_instance_valid(world): moving.sort_custom(func(a, b): return FieldData.pos(a).distance_squared_to(world.center) < FieldData.pos(b).distance_squared_to(world.center))
	var u: Dictionary = moving[sequence % mini(3, moving.size())]
	last_march = time
	play("hoof" if u.get("kind") == "cavalry" else "wheels" if u.get("kind") == "artillery" else "march", u.x, u.y)

func _exit_tree() -> void:
	if is_instance_valid(ambience_voice):
		ambience_voice.stop()
		ambience_voice.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	streams.clear()
	for bus in buses:
		var index = AudioServer.get_bus_index(bus)
		if index > 0: AudioServer.remove_bus(index)
