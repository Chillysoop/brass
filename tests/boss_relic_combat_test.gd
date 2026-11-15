extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_signet()
	_check_medal()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Boss relics passed finishing beat, party, splash, Guard cap, and heal checks.")
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
