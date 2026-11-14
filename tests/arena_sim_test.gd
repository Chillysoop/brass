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
	if _failures.is_empty():
		print("Arena simulation checks passed (duo %d ticks, solo %d ticks)." % [first.tick, solo.tick])
	else:
		for failure in _failures:
			printerr(failure)
		print("Duo %s (%d ticks), solo %s (%d ticks)." % [first.outcome, first.tick, solo.outcome, solo.tick])
		for event in first.trace.slice(0, 20):
			print(event)
	quit(0 if _failures.is_empty() else 1)


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
