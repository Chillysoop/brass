extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassMasteries = preload("res://scripts/class_masteries.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var ids := {}
	for hero_id: String in ArenaSim.HERO_CLASSES:
		var options := ClassMasteries.options(hero_id)
		_check(options.size() == 2, "%s has two masteries." % hero_id)
		for option: Dictionary in options:
			_check(not ids.has(option.id) and ClassMasteries.belongs_to(hero_id, option.id),
				"%s has a unique ID belonging to %s." % [option.label, hero_id])
			ids[option.id] = true
	_check_hexwright()
	_check_consistent_reach()
	_check_base_passives()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Class masteries passed catalog, right-edge, loop, range, and base passive checks.")
	quit(0 if failures.is_empty() else 1)


func _check_hexwright() -> void:
	var tiles := [_tile("pull", 0), _tile("pull", 3)]
	var warded := _fixture("hexwright", "anchor_ward", tiles)
	var splash := _fixture("hexwright", "shrapnel_tether", tiles)
	var baseline := _fixture("hexwright", "", tiles)
	for sim: ArenaSim in [warded, splash, baseline]:
		_step_to(sim, 3 * ArenaSim.TICKS_PER_BEAT - 1)
		_check(sim.units[0].guard == 0 and sim.units[2].hp == 200,
			"Pull masteries wait for the tile's right edge.")
		sim.step()
	_check(warded.units[0].guard == 5 and "Anchor Ward" in warded.activations[0].reason,
		"Anchor Ward adds Guard and names the mastery in Battle Review.")
	_check(splash.units[2].hp == 194 and splash.units[1].hp == baseline.units[1].hp
		and "Shrapnel Tether" in splash.activations[0].reason,
		"Shrapnel Tether adds a separate hit to the neighboring enemy on the pull's activation.")
	var source_push: Vector2 = baseline.units[1].impulse
	_check(source_push.length() > 850.0 and source_push.is_equal_approx(warded.units[1].impulse),
		"Anchor Ward leaves Hexwright's original stronger pull in place.")
	_step_to(warded, 6 * ArenaSim.TICKS_PER_BEAT)
	_check(warded.units[0].guard == 5, "A second pull does not repeat Anchor Ward in the same loop.")
	_step_to(warded, ArenaSim.LOOP_TICKS + 3 * ArenaSim.TICKS_PER_BEAT)
	_check(warded.units[0].guard == 10, "Anchor Ward can fire in the next loop.")


func _check_consistent_reach() -> void:
	var surveyed := _fixture("starshot", "surveyor", [_tile("shot", 0)])
	var wrong_class := _fixture("duelist", "surveyor", [_tile("shot", 0)])
	for sim: ArenaSim in [surveyed, wrong_class]:
		sim.units[0].pos = Vector2(205, 260)
		sim.units[1].pos = Vector2(820, 260)
		sim.units[2].hp = 0
	_check(not surveyed.target_for(0, "shot", "nearest").is_empty()
		and wrong_class.target_for(0, "shot", "nearest").is_empty(),
		"Only Starshot gets Surveyor's extra range, including the preview at its exact limit.")
	_step_to(surveyed, 2 * ArenaSim.TICKS_PER_BEAT)
	_step_to(wrong_class, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(surveyed.activations[0].damage == ArenaSim.TILES.shot.damage + 5
		and wrong_class.activations[0].status == "miss",
		"The simulation uses the preview's reach and retains Starshot's normal long-range damage.")


func _check_base_passives() -> void:
	var warden := _fixture("warden", "brace_and_strike", [_tile("bash", 0)])
	warden.units[0].guard = 1
	warden.units[1].pos = warden.units[0].pos + Vector2(100, 0)
	warden.units[2].hp = 0
	_step_to(warden, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(warden.units[0].guard == 5 and warden.activations[0].damage == ArenaSim.TILES.bash.damage + 5,
		"Brace and Strike adds damage to a guarded Warden and preserves the Bash Guard passive.")

	var wayfarer := _fixture("wayfarer", "blink_strike", [_tile("blink", 0)])
	_step_to(wayfarer, 3 * ArenaSim.TICKS_PER_BEAT)
	_check(wayfarer.activations[0].damage == ArenaSim.TILES.blink.damage + 6
		and wayfarer.units[0].get("haste_until", 0) > wayfarer.tick,
		"Blink Strike adds damage on a successful teleport and preserves Wayfarer's haste.")


func _fixture(hero: String, mastery: String, tiles: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([tiles], "solo", {"encounter": "battle", "heroes": [{"id": hero, "mastery": mastery}], "formation": [
		{"id": "recruit", "x": 450.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
		{"id": "scout", "x": 490.0, "dy": 55.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
	]})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
		if unit.side == "enemy":
			unit.hp = 200
			unit.max_hp = 200
	return sim


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": "nearest"}


func _step_to(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _check(passed: bool, failure: String) -> void:
	if not passed:
		failures.append(failure)
