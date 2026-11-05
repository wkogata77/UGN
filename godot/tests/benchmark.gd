extends SceneTree

func _initialize() -> void:
	var m = FieldModel.new(false)
	m.start_battle("e1", true)
	m.state.battle.visibilityClock = -1000
	m.state.battle.aiClock = -1000
	m.select_corps("c1")
	m.move_units(Vector2(660, 480))
	var start = Time.get_ticks_usec()
	for i in 10: m.tactics.update_visibility(m)
	print("visibility ms/call ", (Time.get_ticks_usec() - start) / 10000.0)
	start = Time.get_ticks_usec()
	for i in 100: m.tactics.update(m, 1.0 / 60)
	print("tactics ms/call ", (Time.get_ticks_usec() - start) / 100000.0)
	start = Time.get_ticks_usec()
	for i in 100: m.formations.advance(m.state.battle.units, m.state.battle.time, 1.0 / 60)
	print("followers ms/call ", (Time.get_ticks_usec() - start) / 100000.0)
	start = Time.get_ticks_usec()
	for i in 10000: m.terrain.height_at(Vector2(440 + i % 100, 400 + i / 100))
	print("10000 ground samples ms ", (Time.get_ticks_usec() - start) / 1000.0)
	quit()
