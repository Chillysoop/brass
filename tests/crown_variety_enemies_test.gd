extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_check_page_and_slinger()
	_check_pike_and_vault()
	_check_runner_press()
	_check_glaiveguard_and_templar()
	_check_spotter()
	_check_drummer_and_twinspur()
	_check_feintblade()
	_check_ballista_and_beacon()
	_check_banneret_and_galvanist()
	_check_oathbreaker_and_chorister()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Crown Relay threats passed the timing, placement, and combat response checks.")
	quit(0 if failures.is_empty() else 1)


func _check_page_and_slinger() -> void:
	var page := _fixture("crown_page", [[{"id": "guard", "start": 0}]], 20)
	_advance(page, 57)
	_check(page.units[1].intent == "hero_1" and page.units[0].guard == 10,
		"The Page should show its windup in time to place an early Guard.")
	page.step()
	_check(page.units[0].hp == 100 and page.units[0].guard == 7,
		"An early Guard should absorb the Page's starter-safe strike.")
	var formation := _fixture("crown_page")
	var nearby := _enemy(formation, "relay_runner", Vector2(460, 320), 999)
	var distant := _enemy(formation, "relay_runner", Vector2(660, 260), 999)
	_advance(formation, 39)
	_check(nearby.pos.distance_to(formation.units[0].pos) < 140.0 and distant.pos == Vector2(660, 260)
		and _events(formation, "charge", "crown_page_advance").size() == 1,
		"The Page's advance should move only nearby idle allies forward.")
	var slinger := _fixture("crown_slinger")
	_advance(slinger, 39)
	_check(_events(slinger, "retreat", "crown_slinger").size() == 1 and slinger.units[1].pos.x > 420.0,
		"After the sling shot lands, the Slinger should open distance with the target.")


func _check_pike_and_vault() -> void:
	var idle := _fixture("relay_recruit", [[]], 999)
	var braced := _fixture("relay_recruit")
	_advance(braced, 1)
	for sim: ArenaSim in [idle, braced]:
		sim._displace("push", sim.units[0], sim.units[1], "bash", Vector2.RIGHT, 200.0)
	_check(braced.units[1].impulse.x < idle.units[1].impulse.x,
		"A planted pike resists displacement only during its windup.")
	var lancer := _fixture("relay_lancer")
	_advance(lancer, 34)
	_check(lancer.units[1].pos.x < lancer.units[0].pos.x and lancer.units[0].impulse.x > 0.0
		and _events(lancer, "charge", "relay_lancer").size() == 1,
		"The Lancer should vault behind the hero and push them back toward the enemy line.")


func _check_runner_press() -> void:
	var heavy := _fixture("relay_runner", [[], [{"id": "slam", "start": 0}]], 2)
	var fast := _fixture("relay_runner", [[], [{"id": "shot", "start": 0}]], 2)
	for fight: ArenaSim in [heavy, fast]:
		fight.units[1].pos = Vector2(310, 326)
	_advance(heavy, 29)
	_advance(fast, 29)
	_check(heavy.units[0].hp == 100 and heavy.units[1].hp == 87
		and _events(heavy, "hit", "relay_runner_press").size() == 1,
		"The Runner pressures a hero winding a large attack and gains damage while that attack is still pending.")
	_check(fast.units[0].hp == 92 and fast.units[1].hp == 100,
		"A short tile avoids the pressure bonus and leaves the Runner on its closest target.")


func _check_glaiveguard_and_templar() -> void:
	var glaive := _fixture("crown_glaiveguard", [[], [], []])
	glaive.units[2].pos = Vector2(300, 450)
	_advance(glaive, 56)
	_check(glaive.units.back().has("pilot_ring_radius") and glaive.units[0].hp == 100,
		"Glaiveguard should show the radius through its long windup.")
	glaive.step()
	_check(glaive.units[0].hp == 93 and glaive.units[1].hp == 93 and glaive.units[2].hp == 100,
		"Only heroes within the telegraphed ring should take the Glaiveguard sweep.")
	var storm := _fixture("crown_storm_templar", [[], []])
	storm.units[1].guard = 10
	_advance(storm, 50)
	_check(storm.units[0].hp == 91 and storm.units[0].impulse.x > 0.0,
		"The Storm Templar should draw heroes toward it if the pulse reaches HP.")
	_check(storm.units[1].hp == 100 and storm.units[1].impulse == Vector2.ZERO and storm.units[1].guard == 1,
		"Guard should block damage and prevent the Storm Templar pull.")


func _check_spotter() -> void:
	var sim := _fixture("crown_spotter")
	var initiate := _enemy(sim, "relay_recruit", Vector2(410, 315), 1)
	_advance(sim, 25)
	_check(_events(sim, "mark", "crown_spotter").size() == 1 and sim.units[0].hp == 100,
		"Spotter should mark while an ally is available to follow up.")
	_advance(sim, 31)
	_check(sim.units[0].hp == 93 and _events(sim, "mark_spent", "crown_spotter").size() == 1,
		"The next hit against a marked hero should gain three damage and spend the mark.")
	sim._damage(initiate, sim.units[0], 4, "relay_recruit")
	_check(sim.units[0].hp == 89, "A spent mark should have no effect on a later strike.")


func _check_drummer_and_twinspur() -> void:
	var faster := _fixture("crown_war_drummer", [[]], 4)
	var split := _fixture("crown_war_drummer", [[]], 4)
	for sim: ArenaSim in [faster, split]:
		sim.units[1].pos = Vector2(550, 185)
		_enemy(sim, "crown_twinspur", Vector2(420, 260), 1)
		_advance(sim, 4)
		_check(sim.units[1].get("special_intent", "") == "crown_war_drummer" and sim.units[2].intent_tick == 49,
			"The drummer should signal the impending acceleration of Twinspur's windup.")
	split.units[1].pos = Vector2(760, 185)
	_advance(faster, 28)
	_advance(split, 28)
	_check(faster.units[0].hp == 94 and _events(faster, "haste", "crown_war_drummer").size() == 1,
		"A drumbeat should bring the attack forward by up to a beat.")
	_check(split.units[0].hp == 100 and split.units[2].intent_tick == 49,
		"Splitting the drummer from its ally before the drumbeat should keep the original timing.")
	_advance(faster, 47)
	_check(faster.units[0].hp == 88 and _events(faster, "hit", "crown_twinspur_followup").size() == 1,
		"Twinspur should telegraph and land its distinct second strike.")


func _check_feintblade() -> void:
	var sim := _fixture("crown_feintblade", [[], []])
	_advance(sim, 1)
	_check(sim.units.back().intent == "hero_1", "The original feint should initially face the nearest hero.")
	sim.units[0].pos = Vector2(170, 260)
	sim.units[1].pos = Vector2(320, 260)
	sim.units[1].guard = 10
	_advance(sim, 37)
	_check(sim.units[0].hp == 100 and sim.units[1].guard == 2 and sim.units[1].hp == 100,
		"Feintblade should switch its strike to the hero who moved into range and Guard it there.")


func _check_ballista_and_beacon() -> void:
	var ballista := _fixture("crown_ballista", [[], [], []])
	ballista.units[1].pos = Vector2(360, 260)
	ballista.units[2].pos = Vector2(380, 280)
	_advance(ballista, 1)
	_check(ballista.units.back().pilot_aim_point == Vector2(300, 260), "Ballista must lock a line through to the farthest hero.")
	ballista.units[2].pos = Vector2(380, 325)
	_advance(ballista, 51)
	_check(ballista.units[0].hp == 90 and ballista.units[1].hp == 90 and ballista.units[2].hp == 100,
		"A locked Ballista line should pierce multiple heroes, while heroes outside it remain safe.")
	var beacon := _fixture("crown_beacon_sentry")
	_advance(beacon, 1)
	_check(beacon.units.back().blast_center == Vector2(300, 260), "Beacon Sentry should mark its impact position.")
	beacon.units[0].pos = Vector2(300, 345)
	_advance(beacon, 59)
	_check(beacon.units[0].hp == 100 and _events(beacon, "miss", "crown_beacon_sentry").size() == 1,
		"Leaving the marked position should avoid Beacon Sentry's shot.")


func _check_banneret_and_galvanist() -> void:
	var alone := _fixture("crown_banneret")
	var supported := _fixture("crown_banneret")
	_enemy(supported, "crown_page", Vector2(470, 335), 999)
	_advance(alone, 40)
	_advance(supported, 40)
	_check(alone.units[1].guard == 8 and alone.units[0].hp == 89 and supported.units[1].guard == 0
		and supported.units[0].hp == 93, "The Banneret should harden and hit harder only while alone.")
	var relay := _fixture("crown_galvanist")
	var runner := _enemy(relay, "relay_runner", Vector2(570, 250), 999)
	_advance(relay, 41)
	_check(relay.units[1].pos == Vector2(570, 250) and runner.pos == Vector2(420, 260)
		and _events(relay, "teleport", "crown_galvanist").size() == 2,
		"Galvanist should exchange positions with its ally at the end of the windup.")


func _check_oathbreaker_and_chorister() -> void:
	var quick := _fixture("crown_oathbreaker", [[{"id": "shot", "start": 1}], [{"id": "slam", "start": 0}]])
	_advance(quick, 63)
	var oath: Dictionary = quick.units.back()
	_check(oath.hp == 59 and oath.get("crown_oathbrace_until", 0) > quick.tick,
		"The first tile after Oathbreaker's strike should deal full damage and trigger its brace.")
	quick._damage(quick.units[0], oath, 5, "shot")
	_check(oath.hp == 54 and oath.get("crown_oathbrace_until", 0) > quick.tick,
		"A small hit should pass through the brace and leave it available for the next heavy one.")
	_advance(quick, 84)
	_check(oath.hp == 42 and not oath.has("crown_oathbrace_until"),
		"A heavy hit during the brace should lose at most eight damage and use the brace up.")
	var delayed := _fixture("crown_oathbreaker", [[{"id": "shot", "start": 1}], [{"id": "slam", "start": 2}]])
	_advance(delayed, 126)
	_check(delayed.units.back().hp == 39, "A heavy hit delayed past the brace should deal full damage.")
	var chime := _fixture("crown_chorister")
	var dodged := _fixture("crown_chorister")
	for sim: ArenaSim in [chime, dodged]:
		var ally := _enemy(sim, "crown_page", Vector2(490, 285), 999)
		ally.hp -= 15
		_advance(sim, 1)
		_check(sim.units[1].intent == ally.id and sim.units[1].blast_center == ally.pos,
			"Chorister should mark the wounded ally's position before the chime takes effect.")
	dodged.units[2].pos.y += 50.0
	_advance(chime, 41)
	_advance(dodged, 41)
	_check(chime.units[2].hp == 25 and _events(chime, "heal", "crown_chorister").size() == 1,
		"An ally who stays in the chime should recover nine health.")
	_check(dodged.units[2].hp == 16 and _events(dodged, "miss", "crown_chorister").size() == 1,
		"Moving the wounded ally out of the chime should deny recovery.")


func _fixture(enemy_id: String, lanes: Array = [[]], first := 1) -> ArenaSim:
	var heroes: Array[Dictionary] = []
	for _lane in lanes:
		heroes.append({"hero": "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"location": "crown", "encounter": "opening", "heroes": heroes})
	sim.units.resize(lanes.size())
	for lane in range(lanes.size()):
		sim.units[lane].speed = 0.0
		sim.units[lane].pos = Vector2(300, 260 + 60 * lane)
	_enemy(sim, enemy_id, Vector2(420, 260), first)
	return sim


func _enemy(sim: ArenaSim, enemy_id: String, position: Vector2, first: int) -> Dictionary:
	sim._add_campaign_enemy(enemy_id, position)
	var unit: Dictionary = sim.units.back()
	unit.next_attack = first
	unit.speed = 0.0
	return unit


func _advance(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary) -> bool: return event.kind == kind and event.tile == tile)


func _check(passed: bool, message: String) -> void:
	if not passed:
		failures.append(message)
