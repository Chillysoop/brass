extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	for hero in ArenaSim.HERO_CLASSES:
		for starter in ["bash", "shot", "slam"]:
			var opening := _fight(hero, "opening", 100, [starter], ["quartermasters_coin"])
			_check(opening.outcome == "victory" and opening.units[0].hp >= 85, "%s opening with %s" % [hero, starter])

	var hp := 100
	for encounter in ["opening", "battle", "battle", "elite", "boss"]:
		var tiles := ["slam"] if encounter == "opening" else ["slam", "guard", "shot", "shield_ram"]
		var sim := _fight("warden", encounter, hp, tiles, ["copper_compass"])
		_check(sim.outcome == "victory", "Fresh Warden wins %s" % encounter)
		hp = sim.units[0].hp
		if encounter == "boss":
			_check(_has_event(sim, "guard", "tollkeeper_rallies"), "The Tollkeeper should gain guard at half HP")

	var carry := ArenaSim.new()
	var options := {"hero": "apothecary", "hp": 57, "max_hp": 120, "encounter": "elite", "relics": ["pocket_bell"], "seed": 142}
	carry.start([[]], "solo", options)
	_check(carry.units[0].hp == 57 and carry.units[0].max_hp == 120, "Carried HP and max HP")
	_check(carry.units.size() == 3, "Elite spawns a captain and a scout")
	carry.step()
	_check(carry.units[0].guard == 5 and _has_event(carry, "guard", "pocket_bell"), "Pocket Bell grants guard each loop")
	var duplicate := ArenaSim.new()
	duplicate.start([[]], "solo", options)
	duplicate.step()
	_check(carry.units == duplicate.units, "Same encounter seed gives the same combat state")
	var healer := _fight("apothecary", "opening", 80, ["shot"], [])
	_check(_has_event(healer, "heal", "apothecary"), "Apothecary heals on a tile hit")
	_check_glass_targeting()
	_check_regent_seals()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier combat checks passed (%d classes × 3 starters, fresh-profile win at %d HP)." % [ArenaSim.HERO_CLASSES.size(), hp])
	quit(0 if failures.is_empty() else 1)


func _check_glass_targeting() -> void:
	var sim := ArenaSim.new()
	sim.start([[{"id": "shot", "start": 0}], [{"id": "bash", "start": 0}]], "duo",
		{"location": "glass", "encounter": "boss", "heroes": [{"hero": "starshot"}, {"hero": "warden", "hp": 60}]})
	_check(sim.units[2].get("sprite") == "glass_twin" and sim.units[3].get("sprite") == "glass_twin",
		"Glass boss spawns both Crucible Twins")
	for tick in range(270):
		sim.step()
	var intents: Array = sim.trace.filter(func(event: Dictionary) -> bool: return event.kind == "intent")
	_check(intents.any(func(event: Dictionary) -> bool:
		return event.actor.begins_with("glass_twin") and event.target == "hero_1"), "Glass Twin prioritizes ranged damage")
	_check(intents.any(func(event: Dictionary) -> bool:
		return event.actor.begins_with("ember_twin") and event.target == "hero_2"), "Ember Twin prioritizes current low HP")
	sim._damage(sim.units[0], sim.units[2], 200, "shot")
	_check(sim.units[3].get("enraged", false), "The surviving Twin rallies")


func _check_regent_seals() -> void:
	var sim := ArenaSim.new()
	sim.start([[], [], []], "solo", {"difficulty": "hard", "segment": 3, "encounter": "boss",
		"heroes": [{"hero": "starshot"}, {"hero": "warden"}, {"hero": "cantor"}]})
	var regent: Dictionary = sim.units[3]
	_check(regent.get("sprite") == "regent", "Hard leg three summons the Iron Regent")
	sim._damage(sim.units[0], regent, 520, "shot")
	_check(regent.regent_sealed and regent.regent_seals_left == 3, "Regent raises three seals at its phase change")
	sim._damage(sim.units[0], regent, 14, "shot")
	sim._damage(sim.units[0], regent, 14, "shot")
	_check(regent.regent_seals_left == 2, "Repeated hits from one hero count once")
	for tick in range(ArenaSim.TICKS_PER_BEAT * 4 + 1):
		sim.step()
	_check(regent.regent_seals_left == 3 and regent.regent_window_until == 0, "An expired window resets seal progress")
	for lane in range(3):
		sim._damage(sim.units[lane], regent, 14, "shot")
	_check(not regent.regent_sealed and _has_event(sim, "interrupt", "regent_shattered"),
		"Three distinct heroes break the seals and stagger the Regent")


func _fight(hero: String, encounter: String, hp: int, tile_ids: Array, relics: Array) -> RefCounted:
	var lane: Array[Dictionary] = []
	var start := 0
	for id in tile_ids:
		var tile: Dictionary = ArenaSim.TILES[id]
		lane.append({"id": id, "start": start, "target": tile.targets[0]})
		start += tile.width
	var sim := ArenaSim.new()
	sim.start([lane], "solo", {"hero": hero, "encounter": encounter, "hp": hp, "max_hp": 100, "relics": relics, "seed": 41})
	for frame in range(4500):
		if not sim.outcome.is_empty():
			break
		sim.step()
	return sim


func _has_event(sim: RefCounted, kind: String, tile: String) -> bool:
	return sim.trace.any(func(event: Dictionary) -> bool: return event.kind == kind and event.tile == tile)


func _check(passed: bool, label: String) -> void:
	if not passed:
		failures.append(label)
