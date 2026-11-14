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
	_check_prism_ward()
	_check_tempered_colossus()
	_check_crown_coordination()
	_check_crown_marshal_combo()
	_check_crown_regent_combo()
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


func _check_prism_ward() -> void:
	var options := {"location": "glass", "difficulty": "medium", "segment": 2, "encounter": "boss",
		"boss_id": "prism_warden", "heroes": [{"hero": "starshot"}, {"hero": "warden", "hp": 60}]}
	var sim := ArenaSim.new()
	sim.start([[{"id": "shot", "start": 0}], []], "duo", options)
	var prism: Dictionary = sim.units[2]
	_check(prism.get("sprite") == "prism_warden", "Glass Medium leg two summons the Prism Warden")
	for frame in range(330):
		sim.step()
		if prism.intent != "":
			break
	_check(prism.intent == "hero_1" and prism.prism_secondary == "hero_2",
		"Prism marks ranged and low-health heroes separately")
	sim._resolve_intent(prism)
	_check(sim.units[0].hp < 100 and sim.units[1].hp < 60, "Prism's dual beams hit both marked heroes in range")
	sim._damage(sim.units[0], prism, 370, "shot")
	_check(prism.prism_warded, "Prism ward rises at its phase change")
	sim._displace("pull", sim.units[0], prism, "pull", Vector2.LEFT, 800.0)
	_check(prism.prism_window_until > sim.tick and _has_event(sim, "interrupt", "prism_exposed"),
		"Displacement exposes the prism ward")
	sim._damage(sim.units[0], prism, 14, "shot")
	_check(prism.prism_warded, "Same hero cannot break the prism ward")
	prism.intent = "hero_1"
	sim._damage(sim.units[1], prism, 14, "shot")
	_check(not prism.prism_warded and prism.intent == "" and _has_event(sim, "interrupt", "prism_shattered"),
		"Second hero shatters the prism ward and cancels the charged beams")

	options.segment = 1
	options.boss_id = "crucible_twins"
	var first_leg := ArenaSim.new()
	first_leg.start([[]], "solo", options)
	_check(first_leg.units[2].get("sprite") == "glass_twin" and first_leg.units[2].max_hp > 139,
		"Glass Medium leg one keeps strengthened Crucible Twins")


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


func _check_tempered_colossus() -> void:
	var options := {"location": "glass", "difficulty": "hard", "segment": 3, "encounter": "boss",
		"boss_id": "tempered_colossus", "seed": 42,
		"heroes": [{"hero": "warden"}, {"hero": "starshot"}, {"hero": "duelist"}]}
	var common_lanes := [[{"id": "bash", "start": 2}], [{"id": "shot", "start": 3}], [{"id": "shot", "start": 4}]]
	var sim := ArenaSim.new()
	sim.start(common_lanes, "solo", options)
	var boss: Dictionary = sim.units[3]
	_check(boss.get("sprite") == "tempered_colossus", "Glass Hard leg three summons the Tempered Colossus")
	for frame in range(ArenaSim.LOOP_TICKS + 1):
		sim.step()
	_check(boss.colossus_stage == 1 and boss.colossus_window_until == 441, "First Forge Sweep telegraphs on loop two")
	for frame in range(190):
		sim.step()
	_check(_has_event(sim, "interrupt", "colossus_displaced") and _has_event(sim, "interrupt", "colossus_cracked"),
		"Common Bash and Shot produce the opening and crack")
	_check(boss.colossus_shattered and boss.colossus_stage == 0 and _has_event(sim, "interrupt", "colossus_shattered"),
		"The third distinct hero shatters the guard")
	_check(not _has_event(sim, "intent", "colossus_forge_sweep"), "Shatter cancels the attack")

	sim.start([[], [], []], "solo", options)
	boss = sim.units[3]
	for frame in range(ArenaSim.LOOP_TICKS + 1):
		sim.step()
	sim._damage(sim.units[1], boss, 14, "shot")
	_check(boss.colossus_stage == 1, "Damage before displacement does not crack the guard")
	sim._displace("pull", sim.units[0], boss, "pull", Vector2.LEFT, 700.0)
	sim._damage(sim.units[0], boss, 14, "shot")
	_check(boss.colossus_stage == 2, "Opening hero cannot also crack the guard")
	sim._damage(sim.units[1], boss, 14, "shot")
	sim._damage(sim.units[1], boss, 14, "shot")
	sim._damage(sim.units[0], boss, 14, "shot")
	_check(boss.colossus_stage == 3, "Third hit requires the hero who has not contributed")
	for frame in range(190):
		sim.step()
	_check(boss.colossus_stage == 0 and boss.colossus_first == "" and boss.colossus_second == "",
		"A missed Forge Sweep window resets progress")
	_check(_has_event(sim, "intent", "colossus_forge_sweep"), "Incomplete sequence releases the attack")


func _check_crown_coordination() -> void:
	var options := {"location": "crown", "difficulty": "easy", "segment": 1, "encounter": "battle",
		"seed": 42, "heroes": [{"hero": "warden"}]}
	var sim := ArenaSim.new()
	sim.start([[]], "solo", options)
	var ally: Dictionary = sim.units[1]
	var guard: Dictionary = sim.units[2]
	_check(guard.get("sprite") == "relay_guard" and guard.relay_link_target == ally.id
		and ally.relay_shield_source == guard.id, "A Relay Guard initially links to its nearby partner")
	var before: int = ally.hp
	sim._damage(sim.units[0], ally, 20, "shot")
	_check(before - ally.hp == 11 and _has_event(sim, "guard", "relay_absorb"),
		"A relay link protects against 45% of tile damage")
	var away: Vector2 = (ally.pos - guard.pos).normalized()
	sim._displace("pull", sim.units[0], ally, "pull", away, 850.0)
	_check(guard.relay_link_target == "" and ally.relay_shield_source == ""
		and _has_event(sim, "interrupt", "relay_link_broken"), "Pull can separate and break a relay link")
	var unshielded_hp: int = ally.hp
	sim._damage(sim.units[0], ally, 20, "shot")
	_check(unshielded_hp - ally.hp == 20, "The separated ally takes full tile damage")

	sim.start([[]], "solo", options)
	ally = sim.units[1]
	guard = sim.units[2]
	sim._damage(sim.units[0], guard, 1000, "shot")
	_check(guard.relay_link_target == "" and ally.relay_shield_source == "",
		"Defeating the Guard immediately drops its partner's protection")

	options.encounter = "boss"
	options.boss_id = "relay_captain"
	sim.start([[{"id": "bash", "start": 1}]], "solo", options)
	var captain: Dictionary = sim.units[1]
	for frame in range(ArenaSim.TICKS_PER_BEAT + 1):
		sim.step()
	_check(captain.get("sprite") == "relay_captain" and captain.relay_charge_active and captain.intent_tick == 147,
		"The Relay Captain opens a predictable beat-2 charge")
	for frame in range(140):
		sim.step()
	_check(not captain.relay_charge_active and captain.intent_tick == 0 and _has_event(sim, "interrupt", "relay_interrupted"),
		"Common Bash on beat 3 interrupts the Relay Charge")
	_check(not _has_event(sim, "intent", "relay_discharge"), "An interrupted charge does not fire")
	sim.start([[{"id": "shot", "start": 1}]], "solo", options)
	for frame in range(147):
		sim.step()
	_check(_has_event(sim, "intent", "relay_discharge") and not _has_event(sim, "interrupt", "relay_interrupted"),
		"Damage without displacement does not stop the charged strike")


func _check_crown_marshal_combo() -> void:
	var options := {"location": "crown", "difficulty": "medium", "segment": 2, "encounter": "boss",
		"boss_id": "relay_marshal", "seed": 42, "heroes": [{"hero": "hexwright"}, {"hero": "warden"}]}
	var sim := ArenaSim.new()
	sim.start([[{"id": "pull", "start": 0}], [{"id": "bash", "start": 3, "target": "farthest"}]], "solo", options)
	var marshal: Dictionary = sim.units[2]
	var guard: Dictionary = sim.units[3]
	_check(marshal.get("sprite") == "relay_marshal" and marshal.relay_shield_source == guard.id,
		"Crown Medium's Marshal starts with a live Relay Guard link")
	for frame in range(22):
		sim.step()
	_check(marshal.relay_charge_active and marshal.relay_combo_stage == 1 and marshal.intent_tick == 189,
		"Linked Charge warns from beat 2 through beat 9 while shielded")
	for frame in range(41):
		sim.step()
	_check(marshal.relay_combo_stage == 2 and marshal.relay_breaker == "hero_1",
		"First hero's common Pull separates the link")
	for frame in range(42):
		sim.step()
	var interrupted: Array = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "relay_marshal_interrupted")
	_check(interrupted.size() == 1 and interrupted[0].amount == 1 and interrupted[0].actor == "hero_2",
		"Different hero's common Bash completes the linked interrupt")
	_check(not marshal.relay_charge_active and marshal.intent_tick == 0,
		"Interrupt cancels Linked Charge and clears the countdown")

	sim.start([[], []], "solo", options)
	marshal = sim.units[2]
	guard = sim.units[3]
	for frame in range(22):
		sim.step()
	sim._displace("pull", sim.units[0], marshal, "pull", Vector2.LEFT, 950.0)
	sim._displace("push", sim.units[0], marshal, "bash", Vector2.RIGHT, 600.0)
	_check(marshal.relay_charge_active and marshal.relay_combo_stage == 2,
		"Same hero cannot both separate the link and interrupt")
	guard.pos = marshal.pos + Vector2(78.0, 0.0)
	guard.relay_relink_tick = sim.tick
	sim._refresh_relay_links()
	_check(marshal.relay_combo_stage == 1 and marshal.relay_breaker == "",
		"Reforming the relay shield closes the Bash window")
	sim._damage(sim.units[0], guard, 1000, "shot")
	_check(marshal.relay_combo_stage == 3, "Defeating the Guard leaves an unshielded interrupt path")
	sim._displace("push", sim.units[0], marshal, "bash", Vector2.RIGHT, 600.0)
	interrupted = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "relay_marshal_interrupted")
	_check(interrupted.size() == 1 and interrupted[0].amount == 0 and not marshal.relay_charge_active,
		"Any hero can Bash an unshielded Marshal without counting a linked combo")


func _check_crown_regent_combo() -> void:
	var options := {"location": "crown", "difficulty": "hard", "segment": 3, "encounter": "boss",
		"boss_id": "crown_regent", "seed": 42,
		"heroes": [{"hero": "warden"}, {"hero": "duelist"}, {"hero": "bulwark"}]}
	var lanes := [
		[{"id": "pull", "start": 0, "target": "relay_left"}],
		[{"id": "pull", "start": 1, "target": "relay_right"}],
		[{"id": "bash", "start": 2, "target": "relay_regent"}],
	]
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", options)
	var regent: Dictionary = sim.units[3]
	var left: Dictionary = sim.units[4]
	var right: Dictionary = sim.units[5]
	_check(regent.get("sprite") == "crown_regent" and regent.relay_shield_sources == [left.id, right.id],
		"The Crown Regent starts with two independent Relay Guard links")
	_check("relay_left" in sim.target_rules("pull") and "relay_regent" in sim.target_rules("bash")
		and sim.target_rules("guard") == ["self"], "Only offensive tiles can select Crown Regent targets")
	var hp: int = regent.hp
	sim._damage(sim.units[0], regent, 20, "shot")
	_check(hp - regent.hp == 8, "Two live links block 60% of incoming tile damage")
	for frame in range(63):
		sim.step()
	_check(regent.relay_charge_active and regent.intent_tick == 189 and regent.relay_shield_sources == [right.id],
		"First common Pull drops only the left link during Crown Charge")
	_check(left.relay_relink_tick == 168 and regent.crown_breakers.get(left.id) == "hero_1",
		"Left guard tracks its own cooldown and the hero that separated it")
	for frame in range(21):
		sim.step()
	var combo: Array = sim.trace.filter(func(event: Dictionary) -> bool:
		return event.tile in ["crown_link_separated", "crown_regent_interrupted"])
	_check(combo.map(func(event: Dictionary) -> String: return event.actor) == ["hero_1", "hero_2", "hero_3"],
		"Two distinct common Pulls followed by a third hero's Bash cancel Crown Charge")
	_check(not regent.relay_charge_active and right.relay_relink_tick == 189
		and combo.size() == 3 and combo[2].amount == 1, "Only the full live-link combo earns a full interrupt")

	sim.start([[], [], []], "solo", options)
	regent = sim.units[3]
	left = sim.units[4]
	right = sim.units[5]
	for frame in range(22):
		sim.step()
	sim._displace("pull", sim.units[0], left, "pull", Vector2.LEFT, 1000.0)
	sim._displace("pull", sim.units[0], right, "pull", Vector2.LEFT, 1000.0)
	sim._displace("push", sim.units[2], regent, "bash", Vector2.RIGHT, 600.0)
	_check(regent.relay_charge_active, "The same hero cannot qualify as both link breakers")
	sim._damage(sim.units[1], left, 1000, "shot")
	sim._damage(sim.units[1], right, 1000, "shot")
	sim._displace("push", sim.units[0], regent, "bash", Vector2.RIGHT, 600.0)
	var interrupts: Array = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "crown_regent_interrupted")
	_check(not regent.relay_charge_active and interrupts.size() == 1 and interrupts[0].amount == 0,
		"Defeating the guards leaves a normal Bash fallback without awarding a full interrupt")


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
