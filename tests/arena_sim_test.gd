extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var first := ArenaSim.new()
	first.start(ArenaSim.default_lanes("duo"), "duo")
	_check(first.target_for(0, "pull", "farthest").get("id") == "clockwork", "Farthest should select the clockwork")
	_check(first.target_for(0, "pull", "nearest").get("id") == "scout", "Nearest should select the scout")
	_check(first.target_for(0, "pull", "lowest_hp").get("id") == "scout", "Lowest HP should select the scout")
	_check(first.target_for(0, "pull", "highest_hp").get("id") == "clockwork", "Highest HP should select the clockwork")
	_check(first.target_for(1, "guard", "self").get("id") == "hero_2", "Guard should target its owner")
	_run(first)
	_check(_event(first, "pull", "pull", 84).get("target") == "clockwork", "The first Pull should fire at beat 4 on the farthest enemy")
	_check(_event(first, "hit", "bash", 126).get("target") == "clockwork", "The first Bash should fire at beat 6 on the enemy brought into range")
	_check(not _event(first, "guard", "bash", 126).is_empty(), "Warden should gain guard on the first Bash")
	_check(not _event(first, "teleport", "blink", 231).is_empty(), "Blink should teleport at beat 11")
	_check(first.outcome == "victory", "Default duo should win")
	_check(first.tick >= 20 * 60 and first.tick <= 45 * 60, "Default duo should resolve in the standard encounter window")
	for unit in first.units:
		_check(Rect2(Vector2.ZERO, ArenaSim.ARENA_SIZE).has_point(unit.pos), "Every unit should stay in the arena")
	var second := ArenaSim.new()
	second.start(ArenaSim.default_lanes("duo"), "duo")
	_run(second, 2)
	_check(first.trace == second.trace, "Two steps per frame should preserve every combat event")
	_check(first.activations == second.activations, "Two steps per frame should preserve every exact tile activation")
	var without_pull := ArenaSim.new()
	var other_lanes := ArenaSim.default_lanes("duo")
	other_lanes[0].remove_at(0)
	without_pull.start(other_lanes, "duo")
	_run(without_pull)
	_check(_event(without_pull, "hit", "bash", 126).get("target") == "scout", "Without the pull, Bash should hit the nearby scout")
	var shared_beat := ArenaSim.new()
	shared_beat.start([
		[{"id": "pull", "start": 1, "target": "farthest"}, {"id": "shot", "start": 2, "target": "nearest"}],
		[{"id": "guard", "start": 2, "target": "self"}]
	], "duo")
	for i in range(84):
		shared_beat.step()
	_check(shared_beat.trace.size() == 3, "An overlapping tile should be rejected")
	if shared_beat.trace.size() >= 3:
		_check(shared_beat.trace[0].actor == "hero_1" and shared_beat.trace[2].actor == "hero_2", "Same-beat effects should follow lane order")
	_check(shared_beat.activations.size() == 2 and shared_beat.activations[0].lane == 0 and shared_beat.activations[1].lane == 1,
		"Same-beat review events follow lane order and exclude rejected tiles")
	var solo := ArenaSim.new()
	solo.start(ArenaSim.default_lanes("solo"), "solo")
	_run(solo)
	_check(solo.units.size() == 2, "Solo should spawn one hero and one enemy")
	_check(solo.outcome == "victory", "Default solo should win")
	_check(solo.tick >= 20 * 60 and solo.tick <= 45 * 60, "Default solo should resolve in the standard encounter window")
	var empty := ArenaSim.new()
	empty.start([[]], "solo")
	_run(empty)
	_check(empty.outcome == "defeat", "An empty solo lane should lose")
	_check_tile_edges()
	_check_activation_review()
	_check_boss_review()
	if _failures.is_empty():
		print("Arena simulation checks passed (duo %d ticks, solo %d ticks)." % [first.tick, solo.tick])
	else:
		for failure in _failures:
			printerr(failure)
		print("Duo %s (%d ticks), solo %s (%d ticks)." % [first.outcome, first.tick, solo.outcome, solo.tick])
		for event in first.trace.slice(0, 20):
			print(event)
	quit(0 if _failures.is_empty() else 1)


func _check_tile_edges() -> void:
	var last_tick := ArenaSim.LOOP_TICKS
	_check(ArenaSim.loop_progress(0) == 0.0, "The playhead starts at the left edge")
	_check(ArenaSim.loop_progress(last_tick - 1) < 1.0 and ArenaSim.loop_progress(last_tick) == 1.0,
		"The playhead reaches the final edge exactly at the end of beat 12")
	_check(is_equal_approx(ArenaSim.loop_progress(last_tick + 1), 1.0 / last_tick),
		"The playhead wraps only after tiles at the final edge fire")
	for id in ["shot", "blink", "slam", "meteor_seal", "event_horizon"]:
		var width: int = ArenaSim.TILES[id].width
		var start := 12 - width
		var sim := ArenaSim.new()
		sim.start([[{"id": id, "start": start}]], "solo")
		for before_edge in range(last_tick - 1):
			sim.step()
		_check(sim.activations.is_empty() and not sim.trace.any(func(event): return event.tile == id),
			"%s should have no effect one tick before its right edge" % id)
		sim.step()
		_check(sim.activations.size() == 1 and sim.activations[0].tick == last_tick and sim.activations[0].beat == 12
			and sim.activations[0].start == start and sim.activations[0].loop == 1,
			"%s should activate exactly at its right edge in the last beat" % id)
		_check(sim.trace.any(func(event): return event.tile == id and event.kind == "hit" and event.tick == last_tick),
			"%s should apply its actual effect on the activation tick" % id)
		for next_loop in range(last_tick):
			sim.step()
		_check(sim.activations.size() == 2 and sim.activations[1].tick == last_tick * 2 and sim.activations[1].loop == 2,
			"%s should activate once per loop" % id)
	var offset := ArenaSim.new()
	offset.start([[{"id": "shot", "start": 3}]], "solo")
	var edge := 5 * ArenaSim.TICKS_PER_BEAT
	for before_edge in range(edge - 1):
		offset.step()
	_check(offset.activations.is_empty(), "An offset tile should not fire at its leading edge")
	offset.step()
	_check(offset.activations.size() == 1 and offset.activations[0].tick == edge and offset.activations[0].damage == 14,
		"An offset tile should fire at (start + width) times ticks per beat")


func _check_activation_review() -> void:
	var sim := ArenaSim.new()
	sim.start([[{"id": "bash", "start": 0}], [{"id": "guard", "start": 0}]], "duo")
	sim.units[1].hp = 0
	for i in range(2 * ArenaSim.TICKS_PER_BEAT):
		sim.step()
	_check(sim.activations.size() == 2, "Review should record the living miss and fallen hero's scheduled tile")
	if sim.activations.size() == 2:
		var missed := sim.activations[0]
		_check(missed.status == "miss" and "out of range" in missed.reason and missed.target_name == "Clockwork Scout",
			"Review should name the out-of-range target and explain the miss")
		_check(sim.activations[1].status == "unavailable" and sim.activations[1].hero == "Warden",
			"Review should distinguish a fallen hero's tile from a miss")
	sim.start([[{"id": "guard", "start": 0}]], "solo")
	_check(sim.activations.is_empty() and sim.boss_events.is_empty(), "A new fight clears the previous review")
	sim.units[0].guard = 28
	for i in range(2 * ArenaSim.TICKS_PER_BEAT):
		sim.step()
	_check(sim.activations.size() == 1 and sim.activations[0].status == "landed" and "already full" in sim.activations[0].reason,
		"Review should record Guard even when the shield is already full")


func _check_boss_review() -> void:
	var sim := ArenaSim.new()
	sim.start([[{"id": "shot", "start": 0}, {"id": "shot", "start": 2}]], "solo", {"encounter": "boss", "difficulty": "hard", "segment": 3})
	var regent := sim.units[1]
	regent.hp = floori(float(regent.max_hp) * 0.60)
	for i in range(8 * ArenaSim.TICKS_PER_BEAT + 1):
		sim.step()
	var raised := sim.boss_events.filter(func(event): return event.tile == "regent_seals")
	_check(raised.size() == 1 and raised[0].stage == "start" and raised[0].source_tile == "shot"
		and raised[0].lane == 0 and raised[0].start == 0 and raised[0].order > sim.activations[0].order,
		"Review should associate the Regent phase transition with the exact attack that triggered it, without duplicate Guard events")
	_check(sim.boss_events.any(func(event): return event.tile == "regent_window_missed" and event.stage == "miss" and "1 of 3" in event.message),
		"Review should explain how many heroes connected before the Regent's window expired")


func _run(sim: RefCounted, steps_per_frame: int = 1) -> void:
	for frame in range(5000):
		if sim.outcome != "":
			break
		for step in range(steps_per_frame):
			sim.step()


func _event(sim: RefCounted, kind: String, tile_id: String, tick: int) -> Dictionary:
	for event in sim.trace:
		if event.kind == kind and event.tile == tile_id and event.tick == tick:
			return event
	return {}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
