extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Martial = preload("res://scripts/martial_specialty_upgrades.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_stage_paths()
	_check_vanishing_power()
	_check_vanishing_technique()
	_check_martial_effect_reuse()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Martial forge ranks and Vanishing Cut's two combat paths passed.")
	quit(0 if failures.is_empty() else 1)


func _check_stage_paths() -> void:
	var names := {}
	for family: String in Martial.PATHS:
		var tiers := TilePacking.forge_tiers(family)
		var widths: int = ArenaSim.TILES[family].width
		for branch in range(2):
			var track: String = ["power", "technique"][branch]
			var stages: Array = Martial.PATHS[family][track].stages
			var cumulative := {}
			for rank in range(stages.size()):
				var stage: Dictionary = stages[rank]
				var spec: Dictionary = ArenaSim.TILES[tiers[rank + 1][branch]]
				var adds_something: bool = stage.effects.keys().any(func(key: String): return cumulative.get(key) != stage.effects[key])
				_check(not names.has(stage.name) and adds_something and stage.name in spec.label and spec.width == widths,
					"%s needs a distinct name and mechanic at rank %d while keeping its width." % [family, rank + 1])
				names[stage.name] = true
				cumulative.merge(stage.effects, true)
				_check(cumulative.keys().all(func(key: String): return spec.get(key) == cumulative[key]),
					"%s must inherit the earlier upgrades in the selected branch." % spec.label)
				if rank < stages.size() - 1:
					_check(TilePacking.next_options(tiers[rank + 1][branch]) == tiers[rank + 2],
						"Both branches must remain reachable after choosing %s." % spec.label)
	_check(names.size() == 96, "Every martial branch must have four individually named ranks.")


func _check_vanishing_power() -> void:
	var uncommon := _rank("vanishing_cut", 1, 0)
	var rare := _rank("vanishing_cut", 2, 0)
	var epic := _rank("vanishing_cut", 3, 0)
	var legendary := _rank("vanishing_cut", 4, 0)
	var breach := _fixture([[_tile(uncommon, 0)]], ["duelist"])
	breach.units[1].guard = 10
	_advance(breach, 3 * BEAT - 1)
	_check(_events(breach, uncommon, "guard_break").is_empty() and _events(breach, uncommon, "teleport").is_empty(),
		"The first Finishing Step waits for its right edge before blinking and stripping Guard.")
	breach.step()
	var broken := _events(breach, uncommon, "guard_break")
	_check(broken.size() == 1 and broken[0].tick == 3 * BEAT and broken[0].amount == ArenaSim.TILES[uncommon].guard_break,
		"Uncommon Finishing Step strips the marked target's Guard as part of its real blink strike.")

	var pursuit := _fixture([[_tile("tap_bolt", 0), _tile(rare, 1)]], ["duelist"])
	_advance(pursuit, 4 * BEAT)
	var repeated := _events(pursuit, rare, "hit")
	var focused: int = ArenaSim.TILES[rare].damage + ArenaSim.TILES[rare].repeat_target_damage + 2
	_check(repeated.size() == 1 and int(repeated[0].amount) == _critical_damage(repeated[0], focused),
		"Rare Finishing Step adds its own damage when following a hit on the same enemy.")

	var cleave := _fixture([[_tile(epic, 0)]], ["duelist"])
	_advance(cleave, 3 * BEAT)
	var hits := _events(cleave, epic, "hit")
	_check(hits.size() == 2 and hits[1].target == cleave.units[2].id and hits[1].amount == ArenaSim.TILES[epic].splash_damage,
		"Epic Finishing Step also cleaves a nearby enemy.")

	var echoing := _fixture([[_tile(legendary, 0)]], ["duelist"])
	_advance(echoing, 3 * BEAT)
	var blinks := _events(echoing, legendary, "teleport")
	var echoes := _events(echoing, legendary, "veil_echo")
	var echo_hits := _events(echoing, legendary, "hit").filter(func(event: Dictionary): return event.get("veil_echo", false))
	_check(blinks.size() == 2 and echoes.size() == 1 and echo_hits.size() == 1
		and echo_hits[0].amount == ArenaSim.TILES[legendary].blink_echo_damage and echo_hits[0].tick == 3 * BEAT
		and echo_hits[0].from == blinks[1].from and echo_hits[0].target == echoing.units[1].id,
		"Legendary Finishing Step lands a second blink and a separately credited afterimage strike.")


func _check_vanishing_technique() -> void:
	var rare := _rank("vanishing_cut", 2, 1)
	var marked := _fixture([[_tile(rare, 0)], [_tile("shot", 3)]], ["duelist", "warden"])
	_advance(marked, 5 * BEAT)
	var guard := _events(marked, rare, "guard")
	var marks := _events(marked, rare, "mark")
	var spent := _events(marked, "shot", "mark_spent")
	_check(guard.size() == 1 and guard[0].amount == ArenaSim.TILES[rare].guard and guard[0].target == marked.units[0].id
		and marks.size() == 1 and spent.size() == 1 and spent[0].actor == marked.units[1].id,
		"Chain Hunt keeps its earlier Guard and lets a teammate claim the new mark.")

	var epic := _rank("vanishing_cut", 3, 1)
	var evade := _fixture([[_tile(epic, 0)]], ["duelist"])
	_advance(evade, 3 * BEAT)
	var retreat := _events(evade, epic, "retreat")
	_check(retreat.size() == 1 and retreat[0].to.distance_to(evade.units[1].pos) > retreat[0].from.distance_to(evade.units[1].pos),
		"Epic Chain Hunt physically backs away after landing its strike.")

	var legendary := _rank("vanishing_cut", 4, 1)
	var dash_then_cut := _fixture([[_tile("retreat_shot", 0), _tile(legendary, 2)]], ["duelist"])
	_advance(dash_then_cut, 5 * BEAT)
	var followup := _events(dash_then_cut, legendary, "hit").filter(func(event: Dictionary): return event.get("dash_followup", false))
	_check(followup.size() == 1 and followup[0].amount == ArenaSim.TILES[legendary].dash_followup_damage
		and followup[0].tick == 5 * BEAT and _events(dash_then_cut, "retreat_shot", "retreat").size() == 1,
		"Legendary Chain Hunt adds its extra strike after a real earlier dash, including the final beat of the window.")


func _check_martial_effect_reuse() -> void:
	var reversal := _rank("reversal_plate", 3, 0)
	var guarded := _fixture([[_tile(reversal, 0)]], ["warden"])
	guarded.units[0].pos = Vector2(300, 260)
	guarded.units[0].guard = 10
	_advance(guarded, BEAT)
	guarded._damage(guarded.units[1], guarded.units[0], 4, "enemy_attack")
	_advance(guarded, 2 * BEAT)
	var wave := _events(guarded, reversal, "hit").filter(func(event: Dictionary): return event.target == guarded.units[2].id)
	_check(wave.size() == 1 and wave[0].amount == ArenaSim.TILES[reversal].block_wave_damage and "Guard wave" in wave[0].message,
		"Reversal Plate's Epic Power creates a real guard wave under its original block condition.")

	var rush := _rank("rampart_rush", 4, 0)
	var carrier := _fixture([[_tile(rush, 0)]], ["warden"])
	carrier.units[2].pos = Vector2(650, 406)
	_advance(carrier, 3 * BEAT)
	var motion := _events(carrier, rush, "charge")
	_check(motion.size() == 1 and motion[0].get("route", []).size() >= 4 and motion[0].has("impact_index"),
		"Rampart Rush's Legendary Power uses the real swept shoulder carry.")


func _fixture(lanes: Array, party: Array) -> ArenaSim:
	var sim := ArenaSim.new()
	var heroes := party.map(func(id: String): return {"hero": id})
	sim.start(lanes, "solo", {"encounter": "battle", "heroes": heroes, "formation": [
		{"id": "recruit", "x": 448.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
		{"id": "scout", "x": 520.0, "dy": 0.0, "delay": 0, "health_scale": 1.0, "damage_scale": 1.0},
	]})
	var positions := [Vector2(278, 260), Vector2(270, 340), Vector2(448, 260), Vector2(520, 264)]
	if party.size() == 1:
		positions.remove_at(1)
	for index in range(sim.units.size()):
		var unit: Dictionary = sim.units[index]
		unit.pos = positions[index]
		unit.speed = 0.0
		unit.next_attack = 99999
		if unit.side == "enemy":
			unit.hp = 220
			unit.max_hp = 220
	return sim


func _rank(family: String, rarity: int, branch: int) -> String:
	return TilePacking.forge_tiers(family)[rarity][branch]


func _tile(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": "nearest"}


func _advance(sim: ArenaSim, until: int) -> void:
	while sim.tick < until and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, tile: String, kind: String) -> Array:
	return sim.trace.filter(func(event: Dictionary): return event.tile == tile and event.kind == kind)


func _critical_damage(hit: Dictionary, amount: int) -> int:
	return roundi(amount * ArenaSim.CRITICAL_DAMAGE_MULTIPLIER) if hit.get("critical", false) else amount


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
