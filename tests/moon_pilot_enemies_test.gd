extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const MoonPilotEnemies = preload("res://scripts/moon_pilot_enemies.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_powder_runner()
	_check_bulwark_intercepts()
	_check_tar_pitcher()
	_check_deck_ram()
	_check_patch_rigger()
	_check_reef_diver()
	_check_signal_gunner()
	_check_chain_warden()
	_check_wreck_bell()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Eight Moonwreck enemy threats and their combat responses passed.")
	quit(0 if failures.is_empty() else 1)


func _check_powder_runner() -> void:
	var disarm := _arena("powder_runner", [[_tile("shot", 0), _tile("shot", 2)]], 150.0, 19)
	var runner: Dictionary = disarm.units.back()
	_advance(disarm, 2 * BEAT)
	_check(runner.get("powder_hits", 0) == 1 and runner.intent_tick == 4 * BEAT,
		"A tile hit on the fuse should leave one hit remaining.")
	var first_order: int = disarm.activations[-1].order
	MoonPilotEnemies.on_tile_hit(disarm, disarm.units[0], runner, 2, "shot", first_order)
	MoonPilotEnemies.on_tile_hit(disarm, disarm.units[0], runner, 0, "shot", first_order + 1)
	_check(runner.get("powder_hits", 0) == 1, "A second hit from one activation and blocked damage must not advance the fuse.")
	_advance(disarm, 4 * BEAT)
	_check(_events(disarm, "interrupt", "powder_runner_disarmed").size() == 1 and runner.intent == "" and disarm.units[0].hp == 100,
		"Two shots from the same hero should disarm the fuse on its final tick, before it can fire.")
	var one_shot := _arena("powder_runner", [[_tile("shot", 0)]], 150.0, 19)
	_advance(one_shot, 4 * BEAT)
	_check(_events(one_shot, "hit", "powder_runner").size() == 1 and one_shot.units[0].hp < 100,
		"One weak shot alone should leave the fuse lit.")
	var burst := _arena("powder_runner", [[_tile("star_piercer", 0)]], 270.0, 42)
	_advance(burst, 5 * BEAT)
	_check(burst.outcome == "victory" and _events(burst, "intent", "powder_runner").size() == 1
		and _events(burst, "hit", "powder_runner").is_empty() and _events(burst, "interrupt", "powder_runner_disarmed").is_empty(),
		"A single lethal tile during the fuse should prevent the shot.")


func _check_tar_pitcher() -> void:
	var unguarded := _arena("tar_pitcher", [[]], 220.0, 19)
	var guarded := _arena("tar_pitcher", [[_tile("guard", 0)]], 220.0, 19)
	_advance(unguarded, 51)
	_advance(guarded, 51)
	_check(unguarded.units[0].get("tar_slow_until", 0) == 51 + 2 * BEAT and guarded.units[0].get("tar_slow_until", 0) == 0,
		"Tar should slow a hero only when its hit breaks through Guard.")
	for sim in [unguarded, guarded]:
		sim.units[0].speed = 120.0
		sim.step()
	_check(is_equal_approx(unguarded.units[0].pos.x - 300.0, 1.3) and is_equal_approx(guarded.units[0].pos.x - 300.0, 2.0),
		"Tar should slow actual movement.")


func _check_deck_ram() -> void:
	var straight := _arena("deck_ram", [[]], 140.0)
	var dodge := _arena("deck_ram", [[]], 140.0)
	dodge.step()
	dodge.units[0].pos.y += 80.0
	_advance(straight, 40)
	_advance(dodge, 40)
	_check(straight.units[0].hp < 100 and dodge.units[0].hp == 100,
		"Deck Ram's charge must hit along its marked line and let a hero escape sideways.")


func _check_patch_rigger() -> void:
	var close := _arena("patch_rigger", [[]], 130.0)
	var apart := _arena("patch_rigger", [[]], 130.0)
	for sim in [close, apart]:
		sim._add_campaign_enemy("dock_recruit", Vector2(500.0, 260.0), 1000)
		sim.units[2].hp = 10
		sim.units[2].speed = 0.0
		sim.step()
	apart.units[2].pos.y += 200.0
	_advance(close, 37)
	_advance(apart, 37)
	_check(close.units[2].guard == 10 and apart.units[2].guard == 0,
		"Separating Patch Rigger from the marked crewmate should prevent its Guard grant.")


func _check_reef_diver() -> void:
	var interrupt := _arena("reef_diver", [[_tile("shot", 0)]], 116.0, 12)
	var guard := _arena("reef_diver", [[_tile("guard", 0)]], 116.0, 12)
	_advance(interrupt, 52)
	_advance(guard, 52)
	_check(_events(interrupt, "interrupt", "reef_diver_interrupted").size() == 1
		and _events(interrupt, "teleport", "reef_diver_retreat").size() == 1 and interrupt.units[0].hp == 100,
		"A quick tile hit should interrupt the Reef Diver and force a retreat.")
	_check(_events(guard, "hit", "reef_diver").size() == 1 and guard.units[0].hp == 100 and guard.units[0].guard == 2,
		"A timed Guard should absorb the Reef Diver's unbroken harpoon attack.")


func _check_signal_gunner() -> void:
	var distant := _arena("signal_gunner", [[]], 290.0)
	var advance := _arena("signal_gunner", [[]], 290.0)
	advance.step()
	advance.units[0].pos.x += 80.0
	_advance(distant, 40)
	_advance(advance, 40)
	_check(distant.units[0].hp < 100 and advance.units[0].hp == 100,
		"Closing the distance should make Signal Gunner's long shot miss.")


func _check_chain_warden() -> void:
	var sim := _arena("chain_warden", [[], []], 110.0)
	sim.units[1].guard = 18
	_advance(sim, 36)
	_check(sim.units[0].hp == 100 and sim.units[1].hp == 100 and sim.units[1].guard == 3,
		"Chain Warden should target the most guarded hero in reach and strip Guard before dealing damage.")


func _check_wreck_bell() -> void:
	var sim := _arena("wreck_bell", [[], []], 100.0)
	sim.units[1].pos.y += 150.0
	_advance(sim, 45)
	_check(sim.units[0].hp < 100 and sim.units[0].impulse.length() > 300.0 and sim.units[1].hp == 100,
		"Wreck Bell should knock back nearby heroes and leave distant heroes alone.")


func _check_bulwark_intercepts() -> void:
	var sim := _arena("powder_runner", [[], []], 150.0)
	var bulwark: Dictionary = sim.units[1]
	var runner: Dictionary = sim.units.back()
	bulwark["class"] = "bulwark"
	_advance(sim, 66)
	_check(bulwark.hp == 95 and sim.units[0].hp == 100,
		"Bulwark must intercept the first powder shot and reduce it by six.")
	# Give the runner a second shot in the same loop.
	bulwark.hp = 100
	runner.next_attack = sim.tick + 1
	_advance(sim, 132)
	_check(bulwark.hp == 100 and sim.units[0].hp == 89,
		"An intercepted pilot attack must spend Bulwark's protection for the loop.")


func _arena(kind: String, lanes: Array, distance: float, first := 1) -> ArenaSim:
	var heroes: Array = []
	for lane in lanes:
		heroes.append({"hero": "warden", "hp": 100, "max_hp": 100})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"location": "moonwreck", "encounter": "opening", "heroes": heroes})
	sim.units.resize(heroes.size())
	for lane in range(heroes.size()):
		var hero: Dictionary = sim.units[lane]
		hero.pos = Vector2(300.0, 260.0 + 58.0 * lane)
		hero.speed = 0.0
	sim._add_campaign_enemy(kind, Vector2(300.0 + distance, 260.0))
	sim.units[-1].speed = 0.0
	sim.units[-1].next_attack = first
	return sim


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start}


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary) -> bool: return event.kind == kind and event.tile == tile)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
