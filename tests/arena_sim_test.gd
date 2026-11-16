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
	_check(solo.tick >= 18 * 60 and solo.tick <= 45 * 60, "Default solo should resolve in the standard encounter window with critical hits")
	var empty := ArenaSim.new()
	empty.start([[]], "solo")
	_run(empty)
	_check(empty.outcome == "defeat", "An empty solo lane should lose")
	_check_tile_edges()
	_check_activation_review()
	_check_boss_review()
	_check_new_forge_families()
	_check_core_forge_effects()
	_check_mobility()
	if _failures.is_empty():
		print("Arena simulation checks passed (duo %d ticks, solo %d ticks)." % [first.tick, solo.tick])
	else:
		for failure in _failures:
			printerr(failure)
		print("Duo %s (%d ticks), solo %s (%d ticks)." % [first.outcome, first.tick, solo.outcome, solo.tick])
		for event in first.trace.slice(0, 20):
			print(event)
	quit(0 if _failures.is_empty() else 1)


func _check_mobility() -> void:
	var melee := ArenaSim.new()
	melee.start([[{"id": "bash", "start": 0}]], "solo", {"hero": "lancer"})
	var lancer: Dictionary = melee.units[0]
	var recruit: Dictionary = melee.units[1]
	lancer.pos = Vector2(150.0, 255.0)
	recruit.pos = Vector2(800.0, 255.0)
	var start: Vector2 = lancer.pos
	lancer.lance_travel = 0.0
	melee.step()
	_check(lancer.velocity.x > lancer.speed * 1.40 and -recruit.velocity.x > recruit.speed * 1.40,
		"An unoccupied battlefield should let both heroes and normal enemies sprint toward each other.")
	_check(is_equal_approx(lancer.travel, start.distance_to(lancer.pos))
		and is_equal_approx(lancer.lance_travel, lancer.travel),
		"Lancer mobility should count the distance actually covered.")
	var walked: float = lancer.travel
	lancer.impulse = Vector2(-300.0, 0.0)
	melee.step()
	_check(lancer.travel == walked and lancer.lance_travel == walked,
		"Knockback should not charge Lancer's travel effects.")
	lancer.impulse = Vector2.ZERO
	recruit.pos = lancer.pos + Vector2(108.0, 0.0)
	melee.step()
	_check(0.0 < lancer.velocity.x and lancer.velocity.x < lancer.speed,
		"The sprint should settle into a controlled approach before attack spacing.")

	var boss := ArenaSim.new()
	boss.start([[{"id": "bash", "start": 0}]], "solo", {"encounter": "boss"})
	boss.units[0].pos = Vector2(150.0, 255.0)
	boss.units[1].pos = Vector2(800.0, 255.0)
	boss.step()
	_check(is_equal_approx(boss.units[1].velocity.length(), boss.units[1].speed),
		"Scripted boss pursuit should keep its established speed.")

	var ranged := ArenaSim.new()
	ranged.start([[{"id": "rivet_bolt", "start": 0}]], "solo", {"hero": "starshot"})
	var starshot: Dictionary = ranged.units[0]
	var threat: Dictionary = ranged.units[1]
	var wall: float = ArenaSim.WALL_MARGIN + starshot.radius
	starshot.pos = Vector2(wall, 260.0)
	threat.pos = Vector2(wall + 145.0, 272.0)
	threat.speed = 0.0
	var initial_separation: float = starshot.pos.distance_to(threat.pos)
	ranged.step()
	_check(starshot.velocity.y < -70.0 and starshot.facing == 1.0,
		"A cornered ranged hero should strafe away along the wall while facing the threat.")
	for _step in range(2 * ArenaSim.TICKS_PER_BEAT - 2):
		ranged.step()
	_check(ranged.activations.is_empty(), "Moving around the wall should preserve the tile edge timing.")
	ranged.step()
	_check(ranged.activations.size() == 1 and ranged.activations[0].damage > 0
		and starshot.pos.distance_to(threat.pos) > initial_separation + 14.0,
		"Wall steering should create space without delaying the ranged attack.")
	starshot.pos = Vector2(wall, wall)
	threat.pos = starshot.pos + Vector2(25.0, 130.0)
	ranged.step()
	_check(starshot.velocity.x > 70.0 and is_zero_approx(starshot.velocity.y),
		"In a corner the ranged hero should take the clearer of both wall routes.")


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


func _check_new_forge_families() -> void:
	var precision := ArenaSim.new()
	precision.start([[{"id": "longshot", "start": 0}], []], "duo")
	_stop_movement(precision)
	precision.units[0].pos = Vector2(150, 260)
	precision.units[2].pos = Vector2(600, 260)
	precision.units[3].pos = Vector2(400, 260)
	for frame in range(2 * ArenaSim.TICKS_PER_BEAT):
		precision.step()
	var hit := _event(precision, "hit", "longshot", 2 * ArenaSim.TICKS_PER_BEAT)
	_check(hit.get("target") == "scout" and hit.get("amount") == 23,
		"Longshot should add its distance bonus on the tile's exact end tick")
	for mixed in [false, true]:
		var lane := [{"id": "longshot", "start": 0}]
		if mixed:
			lane.append({"id": "bash", "start": 2})
		precision.start([lane], "solo")
		precision.units[0].pos = Vector2(250, 260)
		precision.units[1].pos = Vector2(400, 260)
		precision.units[1].speed = 0.0
		precision.step()
		var hero_pos: Vector2 = precision.units[0].pos
		_check(hero_pos.x > 250.0 if mixed else hero_pos.x < 250.0,
			"A marksman should backstep with precision-only offense and close when equipped with Bash")

	var volley := ArenaSim.new()
	volley.start([[{"id": "split_shot", "start": 0}], []], "duo")
	_stop_movement(volley)
	volley.units[0].pos = Vector2(230, 260)
	volley.units[2].pos = Vector2(460, 260)
	volley.units[3].pos = Vector2(560, 260)
	for frame in range(2 * ArenaSim.TICKS_PER_BEAT):
		volley.step()
	var hits := volley.trace.filter(func(event): return event.kind == "hit" and event.tile == "split_shot")
	_check(hits.size() == 2 and hits[0].amount == 16 and hits[1].amount == 12,
		"Split Shot should hit the primary and splash a nearby second enemy at the same beat")

	var defense := ArenaSim.new()
	defense.start([[{"id": "guard", "start": 0}, {"id": "riposte", "start": 2}], [{"id": "rally_guard", "start": 4}]], "duo")
	_stop_movement(defense)
	defense.units[0].pos = Vector2(275, 260)
	defense.units[3].pos = Vector2(400, 260)
	for frame in range(6 * ArenaSim.TICKS_PER_BEAT):
		defense.step()
	var counter := _event(defense, "hit", "riposte", 4 * ArenaSim.TICKS_PER_BEAT)
	_check(counter.get("amount") == 23 and defense.units[0].guard == 21,
		"Riposte should spend stored Guard for damage, gain its own Guard, and receive its ally's support")
	_check(defense.units[1].guard == 13 and defense.activations[-1].target == "hero_1",
		"Rally Guard should shield the caster and the other hero on the intended beat")
	defense.start([[{"id": "riposte", "start": 0}]], "solo")
	_stop_movement(defense)
	for frame in range(2 * ArenaSim.TICKS_PER_BEAT):
		defense.step()
	_check(defense.units[0].guard == 8 and "No enemy was in reach" in defense.activations[0].reason,
		"An out-of-range counter should still grant Guard and explain the missed strike")


func _stop_movement(sim: RefCounted) -> void:
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 10000


func _check_core_forge_effects() -> void:
	var beat := ArenaSim.TICKS_PER_BEAT
	_check(is_equal_approx(ArenaSim.critical_chance("warden", "deadeye", 211.0) -
		ArenaSim.critical_chance("warden", "deadeye", 210.0), 0.10),
		"Deadeye adds critical chance strictly beyond the long-range threshold")
	var shots := ArenaSim.new()
	shots.start([[{"id": "star_piercer", "start": 0}], [{"id": "shot", "start": 4}]], "duo")
	_stop_movement(shots)
	shots.units[0].pos = Vector2(200, 260)
	shots.units[1].pos = Vector2(250, 260)
	shots.units[2].pos = Vector2(525, 260)
	shots.units[2].hp = 200
	shots.units[2].max_hp = 200
	shots.units[2].guard = 9
	shots.units[3].pos = Vector2(740, 380)
	for frame in range(6 * beat):
		shots.step()
	_check(_event(shots, "guard_break", "star_piercer", 5 * beat).get("amount") == 7
		and _event(shots, "mark", "star_piercer", 5 * beat).get("target") == shots.units[2].id
		and _event(shots, "hit", "shot", 6 * beat).get("amount") == ArenaSim.TILES.shot.damage + 7,
		"Star Piercer strips Guard and gives a teammate a long-range follow-up")

	var flak := ArenaSim.new()
	flak.start([[{"id": "flak_burst", "start": 0}], []], "duo")
	_stop_movement(flak)
	flak.units[0].pos = Vector2(200, 260)
	flak.units[2].pos = Vector2(440, 260)
	flak.units[2].guard = 6
	flak.units[3].pos = Vector2(500, 310)
	flak.units[3].guard = 6
	flak.units[3].intent = "enemy_attack"
	flak.units[3].intent_tick = 5 * beat
	for frame in range(4 * beat):
		flak.step()
	var flak_hits := flak.trace.filter(func(event: Dictionary): return event.kind == "hit" and event.tile == "flak_burst")
	_check(_event(flak, "guard_break", "flak_burst", 4 * beat).get("target") == flak.units[3].id
		and flak_hits.size() == 2 and flak_hits[0].amount == 22 and flak_hits[1].amount == 26,
		"Flak Burst strips Guard and exploits a wind-up on splash targets while leaving the primary strike alone")

	var guard := ArenaSim.new()
	guard.start([[{"id": "ward_link", "start": 0}], []], "duo")
	_stop_movement(guard)
	var ally: Dictionary = guard.units[1]
	ally.hp = 45
	for frame in range(3 * beat):
		guard.step()
	_check(ally.hp == 51 and ally.guard == 17 and guard.units[0].guard == 17,
		"Ward Link heals its ally while preserving both Guard grants")
	ally.hp = 45
	for frame in range(ArenaSim.LOOP_TICKS):
		guard.step()
	_check(ally.hp == 45, "Ward Link grants healing only once from the same tile")

	guard.start([[{"id": "last_stand", "start": 0}]], "solo")
	_stop_movement(guard)
	guard.units[0].pos = Vector2(200, 260)
	guard.units[1].pos = Vector2(580, 260)
	for frame in range(5 * beat):
		guard.step()
	guard._damage(guard.units[1], guard.units[0], 9, "enemy_attack")
	_check(_event(guard, "bastion_ready", "last_stand", 5 * beat).get("amount") == 6
		and _event(guard, "bastion_release", "last_stand", 5 * beat).get("amount") == 5,
		"Last Stand can ready and release its ward even without an enemy in strike reach")

	var blink := ArenaSim.new()
	blink.start([[{"id": "phase_cut", "start": 0}, {"id": "mirror_step", "start": 3}]], "solo")
	_stop_movement(blink)
	blink.units[0].pos = Vector2(250, 260)
	blink.units[0].hp = 65
	blink.units[1].pos = Vector2(435, 260)
	blink.units[1].hp = 200
	blink.units[1].max_hp = 200
	blink.units[1].guard = 8
	for frame in range(6 * beat):
		blink.step()
	_check(_event(blink, "guard_break", "phase_cut", 3 * beat).get("amount") == 5
		and not _event(blink, "teleport", "phase_cut", 3 * beat).is_empty()
		and _event(blink, "heal", "mirror_step", 6 * beat).get("amount") == 5,
		"Phase Cut strips Guard on a successful blink and Mirror Step restores the caster's HP")

	var armor := ArenaSim.new()
	armor.start([[{"id": "skybreaker", "start": 0}], []], "duo")
	_stop_movement(armor)
	armor.units[0].pos = Vector2(205, 240)
	armor.units[2].pos = Vector2(375, 240)
	armor.units[3].pos = Vector2(405, 340)
	for foe: Dictionary in armor.units.slice(2):
		foe.hp = 200
		foe.max_hp = 200
	armor.units[2].guard = 20
	for frame in range(5 * beat):
		armor.step()
	_check(armor.units[2].has("ally_mark") and not armor.units[3].has("ally_mark")
		and _event(armor, "guard_break", "skybreaker", 5 * beat).get("amount") == 20,
		"Skybreaker marks the foe whose Guard it actually stripped and still hits the other foe")


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
