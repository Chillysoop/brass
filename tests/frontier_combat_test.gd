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
	_check_blink_upgrades()
	_check_wayfarers_pin()
	_check_enemy_variants()
	_check_glass_targeting()
	_check_medium_marshal_counters()
	_check_prism_ward()
	_check_tempered_colossus()
	_check_crown_coordination()
	_check_crown_marshal_combo()
	_check_crown_regent_combo()
	_check_moonwreck_combat()
	_check_tidekeeper_combo()
	_check_admiral_combo()
	_check_regent_seals()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier combat checks passed (%d classes × 3 starters, fresh-profile win at %d HP)." % [ArenaSim.HERO_CLASSES.size(), hp])
	quit(0 if failures.is_empty() else 1)


func _check_enemy_variants() -> void:
	var variants := {"brass": "brass_sapper", "glass": "glass_duelist", "crown": "crown_mender", "moonwreck": "dock_corsair"}
	for location: String in variants:
		for encounter in ["battle", "elite"]:
			var sim := ArenaSim.new()
			var options := {"location": location, "encounter": encounter, "seed": 1, "hero": "warden"}
			sim.start([[]], "solo", options)
			var expected: String = variants[location]
			_check(sim.units.any(func(unit: Dictionary) -> bool: return unit.get("sprite") == expected),
				"Seeded %s %s includes its new enemy." % [location, encounter])
			var repeated := ArenaSim.new()
			repeated.start([[]], "solo", options)
			_check(sim.units == repeated.units, "Encounter variants are reproducible.")
			options.seed = 42
			repeated.start([[]], "solo", options)
			_check(not repeated.units.any(func(unit: Dictionary) -> bool: return unit.get("sprite") == expected),
				"Legacy compositions still appear on other seeds.")

	var sim := ArenaSim.new()
	sim.start([[]], "solo", {"location": "brass", "encounter": "battle", "seed": 1, "hero": "warden"})
	var hero: Dictionary = sim.units[0]
	var mortar: Dictionary = sim.units[1]
	mortar.next_attack = 1
	hero.speed = 0.0
	mortar.speed = 0.0
	sim.step()
	var target_position: Vector2 = hero.pos
	_check(mortar.blast_center == target_position, "The Bombardier aims at a fixed point.")
	hero.pos += Vector2(0, 130)
	for tick in range(2 * ArenaSim.TICKS_PER_BEAT):
		sim.step()
	_check(sim.trace.any(func(event: Dictionary) -> bool:
		return event.kind == "hazard_burst" and event.tile == "sapper_blast" and event.from == target_position),
		"The Bombardier fires at the marked spot after two beats.")
	_check(not _has_event(sim, "hit", "sapper_blast"), "Moving out of a marked spot avoids mortar damage.")

	sim.start([[]], "solo", {"location": "glass", "encounter": "battle", "seed": 1, "hero": "warden"})
	sim.units[1].pos = sim.units[0].pos + Vector2(182, 0)
	sim.units[1].next_attack = 1
	for tick in range(40):
		sim.step()
	_check(_has_event(sim, "teleport", "duelist_blink"), "Kiln Duelists blink to land their strike.")

	sim.start([[]], "solo", {"location": "crown", "encounter": "battle", "seed": 1, "hero": "warden"})
	var ally: Dictionary = sim.units[1]
	ally.hp -= 20
	var injured: int = ally.hp
	sim.units[2].next_attack = 1
	for tick in range(40):
		sim.step()
	_check(ally.hp > injured and _has_event(sim, "heal", "mender_repair"), "Relay Menders heal nearby wounded allies.")

	sim.start([[]], "solo", {"location": "moonwreck", "encounter": "battle", "seed": 1, "hero": "warden"})
	sim.units[1].pos = sim.units[0].pos + Vector2(230, 0)
	sim.units[1].next_attack = 1
	sim.units[0].speed = 0.0
	sim.units[1].speed = 0.0
	for tick in range(34):
		sim.step()
	_check(_has_event(sim, "pull", "corsair_hook"), "Dock Corsairs pull the marked hero toward their blade.")


func _check_blink_upgrades() -> void:
	for tier: Array in ArenaSim.BLINK_TIERS:
		for tile_id: String in tier:
			var spec: Dictionary = ArenaSim.TILES[tile_id]
			var sim := _blink_fixture([[{"id": tile_id, "start": 0}], []])
			var hero: Dictionary = sim.units[0]
			var ally: Dictionary = sim.units[1]
			var target: Dictionary = sim.units[2]
			var nearby: Dictionary = sim.units[3]
			var target_hp: int = target.hp
			var nearby_hp: int = nearby.hp
			for beat_tick in range(int(spec.width) * ArenaSim.TICKS_PER_BEAT):
				sim.step()
			var teleports: Array[Dictionary] = sim.trace.filter(func(event: Dictionary) -> bool:
				return event.kind == "teleport" and event.tile == tile_id)
			_check(teleports.size() == 1 and teleports[0].beat == spec.width,
				"%s teleports on its last beat" % spec.label)
			_check(target_hp - target.hp == spec.damage, "%s deals its listed damage" % spec.label)
			_check(nearby_hp - nearby.hp == (spec.damage if spec.has("splash") else 0),
				"%s applies area damage only if listed" % spec.label)
			_check(_has_event(sim, "push", tile_id) == spec.has("push"), "%s applies listed knockback" % spec.label)
			_check(hero.guard == spec.get("guard", 0), "%s applies listed guard" % spec.label)
			_check(ally.guard == (spec.guard if spec.has("guard_radius") else 0),
				"%s applies listed ally guard" % spec.label)
			_check(sim._free_position(hero.pos, hero) and hero.pos == sim._bounded(hero.pos, hero.radius),
				"%s lands clear of walls and combatants" % spec.label)
			if not teleports.is_empty():
				var hop: Dictionary = teleports[0]
				if spec.has("retreat"):
					_check(hop.to.distance_to(target.pos) > hop.from.distance_to(target.pos),
						"%s teleports away from the target" % spec.label)
				else:
					_check(hop.to.x > target.pos.x, "%s lands behind the target" % spec.label)
	var corner := _blink_fixture([[], []])
	var hero: Dictionary = corner.units[0]
	var target: Dictionary = corner.units[2]
	var hp: int = target.hp
	hero.pos = Vector2(49, 49)
	target.pos = Vector2(200, 200)
	corner._cast(hero, "ward_step", "nearest")
	_check(hero.pos == Vector2(49, 49) and hero.guard == 0 and target.hp == hp
		and _has_event(corner, "miss", "ward_step"), "Ward Step misses when no legal retreat opens space")


func _check_wayfarers_pin() -> void:
	var sim := _blink_fixture([[], []], ["wayfarers_pin"])
	var hero: Dictionary = sim.units[0]
	var ally: Dictionary = sim.units[1]
	var target: Dictionary = sim.units[2]
	sim.tick = 1
	# A distant target cannot cause a teleport or spend the relic's activation.
	var original_position: Vector2 = target.pos
	target.pos = Vector2(900, 400)
	sim.units[3].pos = Vector2(880, 470)
	sim._cast(hero, "blink", "nearest")
	_check(hero.guard == 0 and _has_event(sim, "miss", "blink"), "Wayfarer's Pin ignores a missed teleport")
	target.pos = original_position
	sim._cast(hero, "blink", "nearest")
	sim._cast(hero, "blink", "nearest")
	sim._cast(ally, "blink", "nearest")
	_check(hero.guard == 6 and ally.guard == 6, "Wayfarer's Pin grants 6 guard once per loop to each hero")
	_check(ally.haste_until == sim.tick + 3 * ArenaSim.TICKS_PER_BEAT, "Wayfarer gains haste from a successful teleport")
	sim.tick = ArenaSim.LOOP_TICKS + 1
	sim._cast(hero, "blink", "nearest")
	_check(hero.guard == 12 and ally.guard == 6, "Wayfarer's Pin can trigger again on the next loop")


func _blink_fixture(lanes: Array, relics: Array = []) -> RefCounted:
	var sim := ArenaSim.new()
	sim.start(lanes, "duo", {"encounter": "elite", "heroes": [{"hero": "warden"}, {"hero": "wayfarer"}], "relics": relics})
	var positions := [Vector2(310, 260), Vector2(280, 345), Vector2(485, 260), Vector2(485, 375)]
	for index in range(sim.units.size()):
		sim.units[index].pos = positions[index]
		sim.units[index].speed = 0.0
		sim.units[index].next_attack = 1000
	return sim


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


func _check_moonwreck_combat() -> void:
	var options := {"location": "moonwreck", "encounter": "battle", "seed": 42, "hero": "warden"}
	var sim := ArenaSim.new()
	sim.start([[]], "solo", options)
	for frame in range(94):
		sim.step()
	var bruiser: Dictionary = sim.units[1]
	var operator: Dictionary = sim.units[2]
	var hero: Dictionary = sim.units[0]
	var impulse: Vector2 = bruiser.impulse
	var toward_hero: Vector2 = hero.pos - bruiser.pos
	_check(operator.get("sprite") == "dock_winch" and bruiser.get("sprite") == "dock_bruiser"
		and impulse.dot(toward_hero) > 0.0 and _has_event(sim, "intent", "dock_winch_pull"),
		"Winch Pull applies a real impulse to the allied Bruiser toward the hero")
	_check(bruiser.get("displaced_until", 0) > sim.tick,
		"Winch Pull makes the Bruiser eligible for displacement bonuses")
	sim.start([[{"id": "bash", "start": 2}]], "solo", options)
	for frame in range(94):
		sim.step()
	_check(_has_event(sim, "interrupt", "dock_winch_interrupted") and not _has_event(sim, "intent", "dock_winch_pull"),
		"Beat-4 Bash can interrupt the Winch Operator before the pull")

	options.encounter = "boss"
	options.boss_id = "wreckmaster"
	sim.start([[{"id": "bash", "start": 3}]], "solo", options)
	for frame in range(63):
		sim.step()
	var boss: Dictionary = sim.units[1]
	_check(boss.get("sprite") == "wreckmaster" and _has_event(sim, "pull", "wreckmaster_harpoon")
		and boss.wreckmaster_phase == 2 and boss.intent_tick == 126,
		"Harpoon pulls the hero and telegraphs Deck Slam through beat 6")
	for frame in range(63):
		sim.step()
	hero = sim.units[0]
	var distance: float = hero.pos.distance_to(boss.pos)
	_check(hero.hp == hero.max_hp and _has_event(sim, "miss", "wreckmaster_slam_miss")
		and distance > boss.wreckmaster_slam_radius,
		"Common Bash at beat 5 makes Deck Slam miss by moving the boss out of actual reach")
	sim.start([[{"id": "guard", "start": 3}]], "solo", options)
	for frame in range(126):
		sim.step()
	_check(sim.units[0].hp == 95 and not _has_event(sim, "miss", "wreckmaster_slam_miss"),
		"Guard reduces Deck Slam's damage when the hero stays within reach")


func _check_tidekeeper_combo() -> void:
	var options := {"location": "moonwreck", "difficulty": "medium", "segment": 2, "encounter": "boss",
		"boss_id": "tidekeeper", "seed": 42, "heroes": [{"hero": "warden"}, {"hero": "hexwright"}]}
	var sim := ArenaSim.new()
	sim.start([[{"id": "bash", "start": 3}], [{"id": "pull", "start": 3}]], "solo", options)
	var boss: Dictionary = sim.units[2]
	for frame in range(22):
		sim.step()
	_check(boss.get("sprite") == "tidekeeper" and boss.tidekeeper_phase == 1 and boss.intent_tick == 63
		and boss.tidekeeper_targets == ["hero_1", "hero_2"],
		"Twin Harpoons mark both living heroes through beat 3")
	for frame in range(41):
		sim.step()
	for hero in [sim.units[0], sim.units[1]]:
		var toward_boss: Vector2 = boss.pos - hero.pos
		var impulse: Vector2 = hero.impulse
		_check(impulse.dot(toward_boss) > 0.0, "Twin Harpoons physically pull %s toward the Tidekeeper" % hero.id)
	_check(boss.tidekeeper_phase == 2 and boss.intent_tick == 168, "Breakwater Slam is due at beat 8")
	for frame in range(42):
		sim.step()
	_check(boss.tidekeeper_phase == 3 and boss.tidekeeper_breaker == "hero_1",
		"Common Bash at beat 5 knocks the Tidekeeper off its anchor")
	for frame in range(63):
		sim.step()
	var cancels := sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "tidekeeper_interrupted")
	_check(cancels.size() == 1 and cancels[0].amount == 1 and cancels[0].actor == "hero_2" and cancels[0].tick == 126
		and boss.tidekeeper_phase == 0 and boss.intent_tick == 0 and boss.tidekeeper_targets.is_empty()
		and not _has_event(sim, "intent", "tidekeeper_slam"),
		"Other hero's common Pull at beat 6 cancels the Slam and clears its marks")

	sim.start([[], []], "solo", options)
	boss = sim.units[2]
	for frame in range(63):
		sim.step()
	var hero: Dictionary = sim.units[0]
	sim._displace("pull", hero, boss, "pull", Vector2.LEFT, 120.0)
	_check(boss.tidekeeper_phase == 2, "Pull alone cannot unanchor the Tidekeeper")
	sim._displace("push", hero, boss, "bash", Vector2.RIGHT, 120.0)
	sim._displace("pull", hero, boss, "pull", Vector2.LEFT, 120.0)
	_check(boss.tidekeeper_phase == 3, "Same hero cannot follow up while the other hero is alive")
	for frame in range(105):
		sim.step()
	var slams := sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "tidekeeper_slam")
	_check(slams.size() == 1 and slams[0].amount == 2 and sim.units[0].hp == 71 and sim.units[1].hp == 71,
		"An unbroken Breakwater Slam hits both heroes inside its real radius")

	options.heroes[1]["hp"] = 0
	sim.start([[{"id": "bash", "start": 3}, {"id": "pull", "start": 5}], []], "solo", options)
	for frame in range(168):
		sim.step()
	cancels = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "tidekeeper_interrupted")
	_check(cancels.size() == 1 and cancels[0].amount == 0 and cancels[0].actor == "hero_1",
		"Last surviving hero can still cancel the Slam with a Bash–Pull sequence")


func _check_admiral_combo() -> void:
	var options := {"location": "moonwreck", "difficulty": "hard", "segment": 3, "encounter": "boss",
		"boss_id": "drowned_admiral", "seed": 42, "heroes": [{"hero": "warden"}, {"hero": "hexwright"}, {"hero": "bulwark"}]}
	var sim := ArenaSim.new()
	var lanes := [[{"id": "bash", "start": 3}], [{"id": "pull", "start": 3}], [{"id": "bash", "start": 5}]]
	sim.start(lanes, "solo", options)
	var boss: Dictionary = sim.units[3]
	for frame in range(22):
		sim.step()
	_check(boss.get("sprite") == "drowned_admiral" and boss.admiral_phase == 1 and boss.intent_tick == 63
		and boss.admiral_targets == ["hero_1", "hero_2", "hero_3"], "Undertow marks the entire party through beat 3")
	for frame in range(41):
		sim.step()
	for hero in [sim.units[0], sim.units[1], sim.units[2]]:
		var toward_boss: Vector2 = boss.pos - hero.pos
		var impulse: Vector2 = hero.impulse
		_check(impulse.dot(toward_boss) > 0.0, "Undertow physically pulls %s toward the Admiral" % hero.id)
	_check(boss.admiral_phase == 2 and boss.intent_tick == 189, "Undertow Sweep is due at beat 9")
	for frame in range(42):
		sim.step()
	_check(boss.admiral_phase == 3 and boss.admiral_breaker == "hero_1", "Beat-5 Bash breaks the Admiral's anchor")
	for frame in range(21):
		sim.step()
	_check(boss.admiral_phase == 4 and boss.admiral_reverser == "hero_2", "Beat-6 Pull by another hero reverses Undertow")
	for frame in range(63):
		sim.step()
	var cancels := sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "admiral_interrupted")
	_check(cancels.size() == 1 and cancels[0].amount == 1 and cancels[0].actor == "hero_3" and cancels[0].tick == 147
		and boss.admiral_phase == 0 and boss.intent_tick == 0 and boss.admiral_targets.is_empty()
		and not _has_event(sim, "intent", "admiral_sweep"), "Beat-7 Bash by a third hero cancels the Sweep and clears its marks")

	sim.start([[], [], []], "solo", options)
	boss = sim.units[3]
	for frame in range(63):
		sim.step()
	var first: Dictionary = sim.units[0]
	var second: Dictionary = sim.units[1]
	var third: Dictionary = sim.units[2]
	sim._displace("pull", first, boss, "pull", Vector2.LEFT, 120.0)
	_check(boss.admiral_phase == 2, "The first step must be a push")
	sim._displace("push", first, boss, "bash", Vector2.RIGHT, 120.0)
	sim._displace("pull", first, boss, "pull", Vector2.LEFT, 120.0)
	sim._displace("push", second, boss, "bash", Vector2.RIGHT, 120.0)
	_check(boss.admiral_phase == 3, "Only a different hero's Pull reverses the Undertow while all three heroes live")
	sim._displace("pull", second, boss, "pull", Vector2.LEFT, 120.0)
	sim._displace("push", first, boss, "bash", Vector2.RIGHT, 120.0)
	sim._displace("pull", third, boss, "pull", Vector2.LEFT, 120.0)
	_check(boss.admiral_phase == 4, "Only a third hero's push cancels the Sweep while all three heroes live")
	for frame in range(126):
		sim.step()
	var sweeps := sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "admiral_sweep")
	_check(sweeps.size() == 1 and sweeps[0].amount == 3 and [first.hp, second.hp, third.hp] == [62, 62, 68],
		"An uncanceled Undertow Sweep hits all three heroes in reach and respects Bulwark's passive")

	options.heroes[2]["hp"] = 0
	sim.start(lanes, "solo", options)
	for frame in range(189):
		sim.step()
	cancels = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "admiral_interrupted")
	_check(cancels.size() == 1 and cancels[0].amount == 0 and cancels[0].actor == "hero_2",
		"Two survivors can cancel the Sweep with their first two displacements")
	options.heroes[1]["hp"] = 0
	sim.start(lanes, "solo", options)
	for frame in range(189):
		sim.step()
	cancels = sim.trace.filter(func(event: Dictionary) -> bool: return event.tile == "admiral_interrupted")
	_check(cancels.size() == 1 and cancels[0].amount == 0 and cancels[0].actor == "hero_1",
		"A lone survivor can cancel the Sweep with one push")


func _check_medium_marshal_counters() -> void:
	var options := {"location": "brass", "difficulty": "medium", "segment": 2, "encounter": "boss",
		"boss_id": "gilded_marshal", "seed": 42, "heroes": [{"hero": "warden"}, {"hero": "starshot"}]}
	var sim := ArenaSim.new()
	sim.start([[], []], "duo", options)
	var marshal: Dictionary = sim.units.back()
	var lead: Dictionary = sim.units[0]
	sim._damage(lead, marshal, 410, "shot")
	_check(marshal.marshal_plate_integrity == ArenaSim.MARSHAL_MEDIUM_PLATE, "Marshal raises a full plate in Medium")
	sim._damage(lead, marshal, 25, "shot", "Secondary impact")
	_check(marshal.marshal_plate_integrity == ArenaSim.MARSHAL_MEDIUM_PLATE, "Secondary impacts do not wear down the plate")
	sim._damage(lead, marshal, 25, "shot")
	_check(marshal.marshal_plate_integrity == ArenaSim.MARSHAL_MEDIUM_PLATE - 9,
		"Pressure wears the plate by damage lost to its mitigation")
	lead.pos = marshal.pos - Vector2(100, 0)
	_marshal_sweep(sim, marshal, lead)
	marshal.marshal_plate_integrity = 9
	sim._damage(lead, marshal, 25, "shot")
	_check(marshal.get("marshal_last_break") == "pressure" and marshal.intent == lead.id,
		"Pressure breaks the plate but leaves an announced sweep in place")
	sim._resolve_intent(marshal)
	_check(lead.hp == lead.max_hp - ArenaSim.MARSHAL_MEDIUM_SWEEP_DAMAGE
		and sim.visual_cues.back().tile == "marshal_sweep", "The announced sweep keeps its damage and animation after a pressure break")

	sim.start([[], []], "duo", options)
	marshal = sim.units.back()
	lead = sim.units[0]
	var ally: Dictionary = sim.units[1]
	sim._damage(lead, marshal, 410, "shot")
	lead.pos = marshal.pos - Vector2(100, 0)
	lead.guard = ArenaSim.MARSHAL_MEDIUM_SWEEP_DAMAGE - 1
	_marshal_sweep(sim, marshal, lead)
	sim._resolve_intent(marshal)
	_check(lead.hp == lead.max_hp - 1 and marshal.marshal_plate_integrity == ArenaSim.MARSHAL_MEDIUM_PLATE,
		"Any HP lost to the sweep prevents defense progress")
	lead.impulse = Vector2.ZERO
	lead.guard = ArenaSim.MARSHAL_MEDIUM_SWEEP_DAMAGE
	_marshal_sweep(sim, marshal, lead)
	sim._resolve_intent(marshal)
	_check(lead.hp == lead.max_hp - 1 and lead.impulse == Vector2.ZERO and
		marshal.marshal_plate_integrity == ArenaSim.MARSHAL_MEDIUM_PLATE - ArenaSim.MARSHAL_WEATHERED_SWEEP_WEAR,
		"A fully blocked sweep cannot push the crew and wears down the plate")
	lead.pos = marshal.pos - Vector2(300, 0)
	for repeat in range(2):
		_marshal_sweep(sim, marshal, lead)
		sim._resolve_intent(marshal)
	_check(marshal.get("marshal_last_break") == "defense" and marshal.marshal_plate_integrity == 0 and ally.hp == ally.max_hp,
		"The crew can break the plate by clearing the ring")

	for difficulty: String in ["medium", "hard"]:
		options.difficulty = difficulty
		sim.start([[], []], "duo", options)
		marshal = sim.units.back()
		lead = sim.units[0]
		ally = sim.units[1]
		sim._damage(lead, marshal, 410, "shot")
		_marshal_sweep(sim, marshal, lead)
		if difficulty == "hard":
			_check(not marshal.has("marshal_plate_integrity") and marshal.attack.cooldown == 105,
				"Hard keeps the original Marshal plating and attack rate")
		sim._displace("push", lead, marshal, "bash", Vector2.RIGHT, 300.0)
		sim._damage(lead, marshal, 25, "shot")
		_check(marshal.marshal_plated and not str(marshal.intent).is_empty(), "The same hero cannot complete the team counter")
		sim._damage(ally, marshal, 25, "shot")
		_check(not marshal.marshal_plated and not marshal.has("pilot_ring_radius") and str(marshal.intent).is_empty()
			and marshal.next_attack == sim.tick + ArenaSim.TICKS_PER_BEAT * 5
			and _has_event(sim, "interrupt", "marshal_shattered"), "The second hero shatters armor and interrupts the sweep")


func _marshal_sweep(sim: ArenaSim, marshal: Dictionary, target: Dictionary) -> void:
	if marshal.has("marshal_plate_integrity"):
		marshal["pilot_ring_radius"] = marshal.attack.reach + ArenaSim.MARSHAL_SWEEP_EXTRA_REACH
	sim._start_enemy_intent(marshal, target.id, sim.tick + 1, "marshal_sweep")


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
