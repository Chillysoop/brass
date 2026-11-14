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
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier combat checks passed (%d classes × 3 starters, fresh-profile win at %d HP)." % [ArenaSim.HERO_CLASSES.size(), hp])
	quit(0 if failures.is_empty() else 1)


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
