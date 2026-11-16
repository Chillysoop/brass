extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassRelics = preload("res://scripts/class_relics.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_guard_and_intercept()
	_check_collision_and_pull()
	_check_mobility()
	_check_cantor_and_apothecary()
	_check_rune_and_duel()
	_check_critical_and_burn()
	for message in failures:
		printerr(message)
	if failures.is_empty():
		print("All twelve class relics passed ownership, timing, targeting, and once-per-loop combat checks.")
	quit(0 if failures.is_empty() else 1)


func _check_guard_and_intercept() -> void:
	var warden := _fixture("warden", [])
	var hero: Dictionary = warden.units[0]
	var enemy: Dictionary = warden.units[1]
	warden.tick = BEAT
	hero.guard = 10
	warden._damage(enemy, hero, 6, "enemy_attack")
	_check(hero.guard == 4 + ClassRelics.WARDEN_GUARD and _procs(warden).size() == 1,
		"Shield Rivet must return Guard to its Warden after an enemy strike is blocked.")
	warden._damage(enemy, hero, 2, "enemy_attack")
	_check(_procs(warden).size() == 1, "A second block in the same loop must not refund Guard.")
	warden.tick = ArenaSim.LOOP_TICKS + 1
	warden._damage(enemy, hero, 1, "enemy_attack")
	_check(_procs(warden).size() == 2, "Shield Rivet must re-arm at the next loop.")

	var bulwark := _fixture("bulwark", [], [], 100)
	var ally: Dictionary = bulwark.units[1]
	var defender := bulwark._intercept_target(ally)
	bulwark._damage(bulwark.units[2], defender, 11, "enemy_attack")
	var intercepts := _procs(bulwark)
	_check(defender == bulwark.units[0] and ally.guard == ClassRelics.BULWARK_GUARD
		and intercepts.size() == 1 and intercepts[0].target == ally.id
		and bulwark._intercept_target(ally) == ally,
		"Watch Badge must protect the ally chosen by a real Bulwark intercept.")
	var supported := _fixture("bulwark", ["cover"], [], 70)
	_advance(supported, 2 * BEAT)
	var guarded: Dictionary = supported.units[1]
	_check(guarded.guard == 9 + ClassRelics.BULWARK_GUARD and _procs(supported).size() == 1
		and _procs(supported)[0].source_tile == "cover" and supported._intercept_target(guarded) == supported.units[0]
		and _procs(supported).size() == 1,
		"The first real external tile Guard grant and the first intercept must share Watch Badge's per-loop cap.")

	var unowned := _fixture("duelist", ["jab", "jab"], [], 100, true, "warden_shield_rivet")
	unowned.units[1].guard = 12
	unowned._damage(unowned.units[2], unowned.units[1], 8, "enemy_attack")
	_advance(unowned, 3 * BEAT)
	_check(not unowned.units[0].has("class_relic") and not unowned.units[1].has("class_relic") and _procs(unowned).is_empty(),
		"A foreign class ID and the shared relic list must never equip a class relic on either hero.")


func _check_collision_and_pull() -> void:
	var breaker := _fixture("breaker", ["bash"], [], -1, true)
	breaker.units[1].pos = Vector2(415, 255)
	breaker.units[2].pos = Vector2(486, 255)
	_advance(breaker, 6 * BEAT)
	var collisions := _procs(breaker)
	var extra := _events(breaker, "hit", "breaker")
	_check(collisions.size() == 1 and collisions[0].source_tile == "bash" and extra.size() == 2
		and collisions[0].target == breaker.units[1].id and collisions[0].amount == ClassRelics.BREAKER_COLLISION_DAMAGE
		and extra[0].amount == 5 and extra[1].amount == 5 + ClassRelics.BREAKER_COLLISION_DAMAGE
		and extra[1].target == breaker.units[2].id,
		"Impact Pin must damage the pushed enemy and carry its bonus only into the body struck by that push.")
	var solo_breaker := _fixture("breaker", ["bash", "bash"])
	_advance(solo_breaker, 6 * BEAT)
	_check(_procs(solo_breaker).size() == 1 and _events(solo_breaker, "hit", "breaker").is_empty(),
		"Impact Pin must also proc once from a moving push against a lone target.")

	var hexwright := _fixture("hexwright", ["grapple", "grapple"])
	_advance(hexwright, 2 * BEAT - 1)
	_check(_procs(hexwright).is_empty(), "Tow Hook must wait for the pulling tile's right edge.")
	_advance(hexwright, 4 * BEAT)
	var pulls := _procs(hexwright)
	_check(pulls.size() == 1 and pulls[0].tick == 2 * BEAT and pulls[0].amount == ClassRelics.HEXWRIGHT_PULL_DAMAGE
		and _events(hexwright, "pull", "grapple").size() == 2,
		"Tow Hook must add damage to the first successful pull and leave later pulls ordinary.")


func _check_mobility() -> void:
	var wayfarer := _fixture("wayfarer", ["veil_step", "shot", "shot"])
	_advance(wayfarer, 6 * BEAT)
	var compass := _procs(wayfarer)
	_check(_events(wayfarer, "teleport", "veil_step").size() == 1
		and compass.size() == 1 and compass[0].tick == 4 * BEAT and compass[0].source_tile == "shot",
		"Glass Compass must wait for a damaging tile after the actual blink.")

	var lancer := _fixture("lancer", ["phalanx_charge", "shot"], [], -1, true)
	lancer.units[1].pos = Vector2(490, 255)
	lancer.units[2].pos = Vector2(500, 337)
	_advance(lancer, 3 * BEAT - 1)
	_check(_procs(lancer).is_empty(), "Trail Spur must wait for the charge tile's right edge.")
	_advance(lancer, 5 * BEAT)
	var waves := _events(lancer, "class_relic_wave", "lancer_trail_spur")
	var dash_procs := _procs(lancer)
	_check(waves.size() == 1 and waves[0].tick == 3 * BEAT and waves[0].from == waves[0].to
		and waves[0].radius == ClassRelics.LANCER_WAVE_RADIUS and dash_procs.size() == 1
		and dash_procs[0].amount == ClassRelics.LANCER_HIT_DAMAGE + ClassRelics.LANCER_WAVE_DAMAGE,
		"A real pre-impact dash must pulse around its target and include both impact and splash damage.")
	var still := _fixture("lancer", ["shot"])
	_advance(still, 2 * BEAT)
	_check(_procs(still).is_empty(), "A shot without a real dash must leave Trail Spur unused.")
	var lone := _fixture("lancer", ["phalanx_charge"])
	lone.units[1].pos = Vector2(490, 255)
	_advance(lone, 3 * BEAT)
	var solo_procs := _procs(lone)
	_check(solo_procs.size() == 1 and solo_procs[0].amount == ClassRelics.LANCER_HIT_DAMAGE,
		"Trail Spur must also contribute against one remaining enemy.")


func _check_cantor_and_apothecary() -> void:
	for marker: String in ["signal_flare", "echo_chime"]:
		var cantor := _fixture("cantor", [marker], [{"id": "shot", "start": 1}], 100, true)
		_advance(cantor, 3 * BEAT)
		var echoes := _procs(cantor)
		_check(echoes.size() == 1 and echoes[0].actor == "hero_1" and echoes[0].target == "hero_2"
			and echoes[0].source_tile == "shot" and echoes[0].grant_tile == marker and echoes[0].amount == ClassRelics.CANTOR_GUARD,
			"Echo Clasp must protect the ally spending %s with matching source attribution." % marker)

	var ally_attacks := [{"id": "shot", "start": 2}, {"id": "shot", "start": 4}]
	var apothecary := _fixture("apothecary", ["pilgrim_aid"], ally_attacks, 70)
	_advance(apothecary, 3 * BEAT)
	var ready := _events(apothecary, "class_relic_ready", "apothecary_tonic_charm")
	_check(ready.size() == 1 and ready[0].target == "hero_2" and _procs(apothecary).is_empty(),
		"Tonic Charm must ready the injured tile recipient and wait for them to attack.")
	_advance(apothecary, 6 * BEAT)
	var tonics := _procs(apothecary)
	_check(tonics.size() == 1 and tonics[0].tick == 4 * BEAT and tonics[0].actor == "hero_1"
		and tonics[0].beneficiary == "hero_2" and tonics[0].grant_tile == "pilgrim_aid"
		and tonics[0].amount == ClassRelics.APOTHECARY_HIT_DAMAGE,
		"Tonic Charm must boost only the recipient's next eligible hit and preserve the healing source.")
	var full := _fixture("apothecary", ["pilgrim_aid"], ally_attacks, 100)
	_advance(full, 6 * BEAT)
	_check(_events(full, "class_relic_ready", "apothecary_tonic_charm").is_empty() and _procs(full).is_empty(),
		"A Guard-only action at full health must not prime Tonic Charm.")


func _check_rune_and_duel() -> void:
	var rune_smith := _fixture("rune_smith", ["hammer_stamp", "quick_etch", "shot"])
	_advance(rune_smith, 6 * BEAT)
	var runes := _procs(rune_smith)
	_check(runes.size() == 1 and runes[0].source_tile == "quick_etch" and runes[0].tick == 4 * BEAT
		and runes[0].target == "hero_1" and runes[0].amount == ClassRelics.RUNE_SMITH_GUARD,
		"Etcher's Seal must grant Guard on the first actual rune-enhanced hit.")
	var wide := _fixture("rune_smith", ["quick_etch", "slam"], [], -1, true)
	wide._lanes[0][1].target = "farthest"
	_advance(wide, 5 * BEAT)
	var stamps := _procs(wide)
	var spent := _events(wide, "rune_charge_spent", "slam")
	_check(stamps.size() == 1 and stamps[0].source_tile == "slam" and spent.size() == 1
		and spent[0].target == wide.units[1].id and wide.activations[1].target == wide.units[2].id,
		"A rune-enhanced area recipient can spend Etcher's Seal ahead of the selected enemy.")

	var duelist := _fixture("duelist", ["jab", "jab", "jab"])
	_advance(duelist, 3 * BEAT)
	var repeat := _procs(duelist)
	_check(repeat.size() == 1 and repeat[0].tick == 2 * BEAT and repeat[0].amount == ClassRelics.DUELIST_HIT_DAMAGE,
		"Second Point must wait for a repeat primary hit, then stop for the loop.")


func _check_critical_and_burn() -> void:
	var shots := ["shot", "shot", "shot", "shot", "shot", "shot"]
	var starshot := _fixture("starshot", shots)
	var bare := _fixture("starshot", shots, [], -1, false, "")
	_advance(starshot, 4 * ArenaSim.LOOP_TICKS)
	_advance(bare, 4 * ArenaSim.LOOP_TICKS)
	var sight := _procs(starshot)
	var enhanced := _events(starshot, "hit", "shot")
	var base := _events(bare, "hit", "shot")
	var seen := {}
	for index in range(base.size()):
		var event: Dictionary = base[index]
		var loop := ceili(float(event.tick) / ArenaSim.LOOP_TICKS)
		var bonus := 0
		if event.critical and not seen.has(loop):
			seen[loop] = true
			bonus = ClassRelics.STARSHOT_CRIT_DAMAGE
		_check(enhanced[index].critical == event.critical and enhanced[index].amount == event.amount + bonus,
			"Sight Glass must add the stated damage after the normal critical multiplier without changing its RNG.")
	_check(not seen.is_empty() and sight.size() == seen.size(), "Sight Glass must trigger on the first ranged critical once per loop.")

	var cinder := _fixture("cinder_mage", ["cinder_brand"], [], -1, true)
	_advance(cinder, 4 * BEAT)
	var ember := _procs(cinder)
	var burn := _events(cinder, "hit", "cinder_mage")
	_check(ember.size() == 1 and ember[0].tick == 3 * BEAT and ember[0].secondary_target == cinder.units[2].id
		and burn.size() >= 2 and burn[0].amount == 3 + ClassRelics.CINDER_BURN_DAMAGE and burn[1].amount == 3,
		"Ember Locket must add damage only to the first actual Burn tick and spark the nearby enemy.")


func _fixture(hero: String, tiles: Array, ally_tiles: Array = [], ally_hp := -1,
		extra := false, relic := "auto") -> ArenaSim:
	var sim := ArenaSim.new()
	var heroes := [{"hero": hero, "class_relic": ClassRelics.id_for(hero) if relic == "auto" else relic}]
	var lanes := [_lane(tiles)]
	if ally_hp >= 0:
		heroes.append({"hero": "warden", "hp": ally_hp, "max_hp": 100})
		lanes.append(ally_tiles)
	var formation := [{"id": "bruiser", "x": 409.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0}]
	if extra:
		formation.append({"id": "bruiser", "x": 420.0, "dy": 79.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0})
	sim.start(lanes, "solo", {"heroes": heroes, "relics": ["warden_shield_rivet"], "formation": formation, "seed": 7})
	sim.units[0].pos = Vector2(320, 255)
	if ally_hp >= 0:
		sim.units[1].pos = Vector2(305, 165)
	for index in range(sim.units.size()):
		var unit: Dictionary = sim.units[index]
		unit.speed = 0.0
		unit.next_attack = 999999
		if index >= heroes.size():
			unit.pos = Vector2(409, 255) if index == heroes.size() else Vector2(420, 334)
			unit.hp = 1800
			unit.max_hp = 1800
	return sim


func _lane(ids: Array) -> Array:
	var lane := []
	var beat := 0
	for id: String in ids:
		var tile: Dictionary = ArenaSim.TILES[id]
		lane.append({"id": id, "start": beat, "target": tile.targets[0]})
		beat += int(tile.width)
	return lane


func _advance(sim: ArenaSim, until: int) -> void:
	while sim.tick < until and sim.outcome.is_empty():
		sim.step()


func _procs(sim: ArenaSim) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "relic_proc" and event.get("class_relic", false))


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == kind and event.tile == tile)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
