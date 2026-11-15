extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var guarded := _fixture("blink", "guarded", 9)
	guarded.units[2].pos = Vector2(820, 200)
	guarded.units[3].pos = Vector2(820, 375)
	_step_to(guarded, ArenaSim.LOOP_TICKS - 1)
	_check(guarded.units[0].guard == 0, "Guarded fired before the right edge.")
	guarded.step()
	_check(guarded.activations.size() == 1 and guarded.activations[0].tick == ArenaSim.LOOP_TICKS
		and guarded.activations[0].status == "miss" and guarded.units[0].guard == TileEnchantments.GUARD_AMOUNT
		and "Guarded granted 5 Guard" in guarded.activations[0].reason, "A missed Blink should grant Guarded at beat 12.")
	_step_to(guarded, 2 * ArenaSim.LOOP_TICKS)
	_check(guarded.units[0].guard == 10, "Guarded should fire each loop.")

	var ranged := _fixture("shot", "longshot")
	var plain := _fixture("shot", "")
	for sim in [ranged, plain]:
		sim.units[2].pos = Vector2(825, 200)
		sim.units[3].pos = Vector2(825, 375)
	_check(ranged.target_for(0, "shot", "nearest", "longshot").get("id") == ranged.units[2].id
		and plain.target_for(0, "shot", "nearest").is_empty()
		and ranged.target_for(0, "bash", "nearest", "longshot").is_empty(), "Longshot should extend only the enchanted attack's preview range.")
	_step_to(ranged, 2 * ArenaSim.TICKS_PER_BEAT - 1)
	_check(ranged.activations.is_empty(), "Longshot fired before the tile edge.")
	ranged.step()
	_step_to(plain, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(ranged.activations[0].damage == ArenaSim.TILES.shot.damage and plain.activations[0].status == "miss",
		"Longshot should reach a foe exactly at the extended boundary.")

	var splash := _fixture("shot", "splash")
	var killed: Dictionary = splash.units[2]
	killed.hp = 1
	var nearest: Dictionary = splash.units[3]
	var third := splash._unit("third", "Third", "enemy", -1, Vector2(360, 279), 40, 17.0, 0.0, 130.0)
	splash.units.append(third)
	var previous: int = nearest.hp
	_step_to(splash, 2 * ArenaSim.TICKS_PER_BEAT - 1)
	_check(killed.hp == 1 and nearest.hp == previous and third.hp == 40, "Splash damage fired before the tile edge.")
	splash.step()
	var damage := roundi(ArenaSim.TILES.shot.damage * TileEnchantments.SPLASH_RATIO)
	_check(killed.hp == 0 and nearest.hp == previous - damage and third.hp == 40
		and splash.activations[0].damage == damage + 1, "Lethal trigger should splash one closest neighbor at the same edge.")
	var hits := splash.trace.filter(func(event: Dictionary): return event.kind == "hit")
	_check(hits.size() == 2 and hits.all(func(event: Dictionary): return event.tick == 2 * ArenaSim.TICKS_PER_BEAT)
		and "Splash dealt" in splash.activations[0].reason, "Splash hit should share the main hit tick and appear in review.")

	var capped := _fixture("shot", "splash")
	capped.units[2].guard = 20
	capped.units[3].marshal_plated = true
	capped.units[3].marshal_exposed_until = 0
	capped.units[3].guard = 2
	previous = capped.units[3].hp
	_step_to(capped, 2 * ArenaSim.TICKS_PER_BEAT)
	_check(capped.units[3].hp == previous - 1, "A fully blocked primary hit should splash, subject to neighboring armor and Guard.")
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Guarded, Longshot and Splash passed exact-edge and combat-result checks.")
	quit(0 if failures.is_empty() else 1)


func _fixture(id: String, enchantment: String, start := 0) -> ArenaSim:
	var sim := ArenaSim.new()
	sim.start([[{"id": id, "enchantment": enchantment, "start": start, "target": "nearest"}], []], "duo")
	var positions := [Vector2(190, 200), Vector2(190, 375), Vector2(360, 200), Vector2(411, 200)]
	for index in range(sim.units.size()):
		var unit: Dictionary = sim.units[index]
		unit.pos = positions[index]
		unit.prev_pos = unit.pos
		unit.speed = 0.0
		unit.next_attack = 99999
	return sim


func _step_to(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _check(passed: bool, failure: String) -> void:
	if not passed:
		failures.append(failure)
