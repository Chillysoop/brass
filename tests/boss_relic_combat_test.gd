extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_signet()
	_check_medal()
	_check_repair_kit()
	_check_clapper()
	_check_long_echo()
	_check_resonant_plate()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Tollkeeper and Bellmaker relics passed finishing beat, per-hero, splash, Guard cap, and heal checks.")
	quit(0 if failures.is_empty() else 1)


func _check_signet() -> void:
	var lanes := [[_tile("shot", 2), _tile("shot", 4)], [_tile("shot", 2)]]
	var sim := _sim(["tollkeeper_signet"], lanes)
	var base: int = ArenaSim.TILES.shot.damage
	_advance(sim, 4 * BEAT - 1)
	_check(sim.activations.is_empty() and _procs(sim, "tollkeeper_signet").is_empty(),
		"The Signet does not fire before either tile’s right edge.")
	sim.step()
	var early := _procs(sim, "tollkeeper_signet")
	_check(early.size() == 2 and early[0].beat == 4 and early[1].beat == 4
		and early[0].actor != early[1].actor and sim.activations[0].damage == base + 3
		and sim.activations[1].damage == base + 3,
		"Both heroes’ on-beat attacks land for three extra damage and record separate reviews.")
	_advance(sim, 6 * BEAT)
	_check(sim.activations[-1].damage == base and _procs(sim, "tollkeeper_signet").size() == 2,
		"A tile that starts on the fourth beat but finishes later still deals its full normal damage.")

	var area := _sim(["tollkeeper_signet"], [[_tile("shrapnel", 0)]])
	area._add_campaign_enemy("bruiser", Vector2(480, 317))
	_park_enemy(area.units[2], Vector2(480, 317))
	_advance(area, 3 * BEAT)
	_check(_procs(area, "tollkeeper_signet").size() == 2
		and area.activations[0].damage == ArenaSim.TILES.shrapnel.damage + ArenaSim.TILES.shrapnel.splash_damage + 6,
		"An early tile grants the bonus to each enemy it directly hits, including a splash target.")
	var miss := _sim(["tollkeeper_signet"], [[_tile("bash", 0)]])
	_advance(miss, 2 * BEAT)
	_check(miss.activations[0].status == "miss" and _procs(miss, "tollkeeper_signet").is_empty(),
		"The Signet does not trigger when an eligible tile misses.")


func _check_medal() -> void:
	var party := _sim(["bastion_medal"], [[_tile("aegis_network", 0, "self")], [], []])
	party.units[1].hp = 70
	party.units[2].hp = 0
	_advance(party, 5 * BEAT)
	var guards := _procs(party, "bastion_medal")
	_check(party.units[0].guard == 23 and party.units[1].guard == 28 and party.units[2].guard == 0
		and guards.size() == 2 and guards[0].amount == 3 and guards[1].amount == 1 and party.activations[0].guard == 51,
		"Party Guard adds a single bonus to each living recipient, clamps at the cap, and is included in the activation total.")

	var heal := _sim(["bastion_medal"], [[_tile("first_aid", 0, "self")]])
	heal.units[0].hp = 80
	_advance(heal, 2 * BEAT)
	_check(heal.units[0].hp == 86 and heal.units[0].guard == 6,
		"A healing tile keeps its full heal and only its Guard changes.")

	var passive := _sim(["bastion_medal", "pocket_bell"], [[_tile("bash", 0)]])
	_park_enemy(passive.units[1], Vector2(401, 265))
	_advance(passive, 2 * BEAT)
	_check(passive.units[0].guard == 9 and _procs(passive, "bastion_medal").is_empty(),
		"Neither the Warden passive nor Pocket Bell earns the Medal bonus.")

	var riposte := _sim(["bastion_medal"], [[_tile("riposte", 0)]])
	_advance(riposte, 2 * BEAT)
	_check(riposte.units[0].guard == 11 and riposte.activations[0].reason.begins_with("11 Guard granted"),
		"A guarding tile that cannot reach an enemy retains its full Guard grant and reports the total.")

	var ward_id := "chorus_bolt_upgrade_rare_technique"
	var ward: Dictionary = ArenaSim.TILES[ward_id]
	var marked := _sim(["bastion_medal"], [[_tile(ward_id, 0)], [_tile("shot", ward.width)]], ["cantor", "warden"])
	_advance(marked, int(ward.width) * BEAT)
	var before: Array = [marked.units[0].guard, marked.units[1].guard]
	_check(_procs(marked, "bastion_medal").size() == 1, "The Medal boosts the warding attack’s immediate Guard grant.")
	_advance(marked, (int(ward.width) + 2) * BEAT)
	_check(marked.units[0].guard == before[0] + ward.chorus_guard and marked.units[1].guard == before[1] + ward.chorus_guard
		and _procs(marked, "bastion_medal").size() == 1,
		"A separate attack that consumes a warding mark preserves its normal party Guard without a second Medal bonus.")


func _check_repair_kit() -> void:
	var relic := "tollkeeper_repair_kit"
	var sim := _sim([relic], [[], []])
	var lead: Dictionary = sim.units[0]
	var ally: Dictionary = sim.units[1]
	var enemy: Dictionary = sim.units[2]
	sim.step()
	lead.hp = 80
	lead.guard = 2
	sim._damage(enemy, lead, 0, "enemy_attack")
	sim._damage(enemy, lead, 4, "enemy_attack")
	_check(lead.hp == 78 and _procs(sim, relic).is_empty(), "Zero damage and partial blocks do not qualify for Repair Kit.")
	lead.guard = 20
	sim._damage(enemy, lead, 5, "enemy_attack")
	sim._damage(enemy, lead, 5, "enemy_attack")
	ally.hp = ally.max_hp - 1
	ally.guard = 10
	sim._damage(enemy, ally, 5, "enemy_attack")
	var heals := _procs(sim, relic)
	_check(lead.hp == 81 and ally.hp == ally.max_hp and heals.size() == 2
		and heals[0].amount == 3 and heals[1].amount == 1 and sim.activations.is_empty(),
		"Repair Kit triggers separately for each hero at the enemy hit, clamps HP, and creates no fake tile activation.")
	_advance(sim, ArenaSim.LOOP_TICKS + 1)
	sim._damage(enemy, lead, 5, "enemy_attack")
	_check(lead.hp == 84 and _procs(sim, relic).size() == 3, "Repair Kit readies again on the next loop.")


func _check_clapper() -> void:
	var relic := "bellmaker_clapper"
	var sim := _sim([relic, "tollkeeper_signet"], [[_tile("guard", 0, "self"), _tile("brace", 2, "self")]])
	_park_enemy(sim.units[1], Vector2(365, 265))
	sim._add_campaign_enemy("bruiser", Vector2(282, 356))
	_park_enemy(sim.units[2], Vector2(282, 356))
	sim._add_campaign_enemy("bruiser", Vector2(480, 265))
	_park_enemy(sim.units[3], Vector2(480, 265))
	_advance(sim, 2 * BEAT - 1)
	_check(_procs(sim, relic).is_empty(), "Clapper does not ring before the support tile finishes.")
	sim.step()
	var rings := _procs(sim, relic)
	_check(rings.size() == 1 and rings[0].beat == 2 and sim.activations[0].damage == 16
		and sim.units[1].hp == 992 and sim.units[2].hp == 992 and sim.units[3].hp == 1000
		and _procs(sim, "tollkeeper_signet").is_empty(),
		"The Clapper hits each enemy in range without chaining into a damage-tile relic.")
	_advance(sim, 4 * BEAT)
	_check(_procs(sim, relic).size() == 1, "A second support tile does not ring again during the same loop.")
	_advance(sim, ArenaSim.LOOP_TICKS + 2 * BEAT)
	_check(_procs(sim, relic).size() == 2, "Clapper readies again on the next loop.")

	var delayed := _sim([relic], [[_tile("guard", 0, "self"), _tile("brace", 2, "self")]])
	_advance(delayed, 2 * BEAT)
	_check(_procs(delayed, relic).is_empty(), "Clapper has no target at long range.")
	_park_enemy(delayed.units[1], Vector2(365, 265))
	_advance(delayed, 4 * BEAT)
	_check(_procs(delayed, relic).size() == 1, "An empty shockwave does not use up Clapper for the loop.")


func _check_long_echo() -> void:
	var relic := "bellmaker_long_echo"
	var lane := [_tile("shot", 0), _tile("shot", 2), _tile("shot", 4)]
	var sim := _sim([relic], [lane, lane])
	var enemy: Dictionary = sim.units[2]
	_park_enemy(enemy, Vector2(900, 265))
	_advance(sim, 2 * BEAT)
	_check(_procs(sim, relic).is_empty(), "Missing a shot does not spend Long Echo.")
	_park_enemy(enemy, Vector2(480, 265))
	_advance(sim, 4 * BEAT)
	var echoes := _procs(sim, relic)
	var shot_damage: int = ArenaSim.TILES.shot.damage
	_check(echoes.size() == 2 and echoes[0].actor != echoes[1].actor and echoes[0].beat == 4 and echoes[1].beat == 4
		and sim.activations[2].damage == shot_damage + 4 and sim.activations[3].damage == shot_damage + 4,
		"Long Echo lands once for each hero on their first ranged hit.")
	_advance(sim, 6 * BEAT)
	_check(_procs(sim, relic).size() == 2 and sim.activations[4].damage == shot_damage and sim.activations[5].damage == shot_damage,
		"Later shots land normally once Long Echo is spent for both heroes.")


func _check_resonant_plate() -> void:
	var relic := "bellmaker_resonant_plate"
	var lane := [_tile("shot", 0), _tile("pull", 2), _tile("pull", 5)]
	var sim := _sim([relic, "bastion_medal"], [lane, lane], ["cantor", "warden"])
	sim.units[1].guard = 27
	_advance(sim, 5 * BEAT - 1)
	_check(sim.units[0].guard == 0 and sim.units[1].guard == 27 and _procs(sim, relic).is_empty(),
		"Resonant Plate waits for the first wide tile's right edge.")
	sim.step()
	var plates := _procs(sim, relic)
	_check(sim.units[0].guard == 4 and sim.units[1].guard == 28 and plates.size() == 2
		and plates[0].amount == 4 and plates[1].amount == 1 and _procs(sim, "bastion_medal").is_empty(),
		"Resonant Plate grants capped Guard to each hero without triggering a second bonus from the Medal or Cantor.")
	_advance(sim, 8 * BEAT)
	_check(_procs(sim, relic).size() == 2, "A later wide tile does not add more Guard in the same loop.")


func _sim(relics: Array, lanes: Array, classes: Array = []) -> ArenaSim:
	var heroes: Array = []
	for lane in range(lanes.size()):
		heroes.append({"hero": classes[lane] if lane < classes.size() else "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": "opening", "heroes": heroes, "relics": relics})
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
		unit.next_attack = 99999
	_park_enemy(sim.units[lanes.size()], Vector2(480, 265))
	return sim


func _park_enemy(unit: Dictionary, at: Vector2) -> void:
	unit.speed = 0.0
	unit.next_attack = 99999
	unit.pos = at
	unit.max_hp = 1000
	unit.hp = 1000


func _tile(id: String, start: int, rule := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": rule}


func _advance(sim: ArenaSim, target_tick: int) -> void:
	while sim.tick < target_tick and sim.outcome.is_empty():
		sim.step()


func _procs(sim: ArenaSim, relic: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.kind == "relic_proc" and event.tile == relic)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
