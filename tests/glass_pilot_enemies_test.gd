extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const BEAT := ArenaSim.TICKS_PER_BEAT

var failures: Array[String] = []


func _initialize() -> void:
	_check_slinger_and_porter()
	_check_hound_and_lacquerer()
	_check_binder()
	_check_mirrorback()
	_check_annealer()
	_check_arbalist_and_ram()
	_check_conductor()
	_check_siphon_and_knight()
	_check_quench()
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Thirteen Glass Foundry threats passed telegraph, impact, and counter checks.")
	quit(0 if failures.is_empty() else 1)


func _check_slinger_and_porter() -> void:
	var still := _fixture([[]], "glass_cullet_slinger")
	var across := _fixture([[]], "glass_cullet_slinger")
	still.step()
	across.step()
	across.units[0].pos.y += 75.0
	_advance(still, 34)
	_advance(across, 34)
	_check(still.units[0].hp == 96 and across.units[0].hp == 100,
		"The Slinger should hit the original line and miss a target that crosses it.")
	var close := _fixture([[]], "glass_kiln_porter")
	var wide := _fixture([[]], "glass_kiln_porter")
	close.units[1].pos = close.units[0].pos + Vector2(99.0, 0.0)
	wide.units[1].pos = wide.units[0].pos + Vector2(137.0, 0.0)
	_advance(close, 43)
	_advance(wide, 43)
	_check(close.units[0].hp == 94 and wide.units[0].hp == 97,
		"The Porter's hammer should deal half damage when held outside 110 range.")


func _check_hound_and_lacquerer() -> void:
	var close := _fixture([[]], "glass_facet_hound")
	var wide := _fixture([[]], "glass_facet_hound")
	close.units[1].pos = close.units[0].pos + Vector2(70.0, 0.0)
	wide.units[1].pos = wide.units[0].pos + Vector2(103.0, 0.0)
	_advance(close, 25)
	_advance(wide, 25)
	_check(close.units[0].hp == 93 and wide.units[0].hp == 96,
		"The Hound's bite should reward leaving space between fighters.")
	var unbroken := _fixture([[]], "glass_lacquerer", 9)
	var early_hit := _fixture([[_tile("shot", 0)]], "glass_lacquerer", 9)
	_advance(unbroken, 47)
	_advance(early_hit, 47)
	_check(unbroken.units[1].guard == 10 and early_hit.units[1].guard == 0
		and _events(early_hit, "interrupt", "glass_lacquerer_interrupted").size() == 1,
		"A hit during the Lacquerer's coating windup should prevent the Guard grant.")


func _check_binder() -> void:
	var together := _fixture([[]], "glass_crucible_binder")
	var separated := _fixture([[]], "glass_crucible_binder")
	for sim: ArenaSim in [together, separated]:
		sim._add_campaign_enemy("glass_facet_hound", Vector2(525.0, 265.0), 500)
		sim.units[2].speed = 0.0
		sim.step()
	separated.units[2].pos.y += 185.0
	_advance(together, 38)
	_advance(separated, 38)
	_check(together.units[1].guard == 6 and together.units[2].guard == 6
		and separated.units[1].guard == 0 and separated.units[2].guard == 0,
		"Separating a Binder from its linked ally should deny the Guard on both.")


func _check_mirrorback() -> void:
	var bait := _fixture([[_tile("guard", 0), _tile("shot", 2), _tile("slam", 4)]], "glass_mirrorback", 43)
	var delay := _fixture([[_tile("slam", 2)]], "glass_mirrorback", 43)
	var unguarded := _fixture([[_tile("shot", 2)]], "glass_mirrorback", 43)
	_advance(bait, 4 * BEAT - 1)
	_check(bait.units[1].get("special_intent", "") == "glass_mirrorback" and bait.units[0].guard == 10,
		"Mirrorback must telegraph the stance before a quick hit lands under Guard.")
	bait.step()
	_check(_events(bait, "counter", "glass_mirrorback_counter").size() == 1 and bait.units[0].hp == 100
		and bait.units[0].guard < 10 and bait.units[1].intent == "",
		"A quick hit must spend the stance and resolve the reflection against Guard on the same tick.")
	_advance(bait, 8 * BEAT)
	_check(_events(bait, "counter", "glass_mirrorback_counter").size() == 1 and bait.activations[-1].damage > 0,
		"The heavy follow-up must land without a second counter after the stance is spent.")
	_advance(delay, 6 * BEAT)
	_check(_events(delay, "counter", "glass_mirrorback_counter").is_empty() and delay.activations[-1].damage > 0,
		"Delaying the heavy attack to after the stance must bypass the reflection.")
	_advance(unguarded, 4 * BEAT)
	_check(unguarded.units[0].hp < 100, "The same bait without Guard must cost HP.")


func _check_annealer() -> void:
	var lined_up := _fixture([[]], "glass_annealer", 34)
	var separated := _fixture([[_tile("bash", 0, "farthest")]], "glass_annealer", 34)
	for sim: ArenaSim in [lined_up, separated]:
		sim.units[0].pos = Vector2(467, 255)
		sim.units[1].pos = Vector2(430, 310)
		sim._add_campaign_enemy("glass_kiln_ram", Vector2(578, 255))
		sim.units[2].speed = 0.0
		sim.units[2].next_attack = 99999
		_advance(sim, 76)
	_check(lined_up.units[2].guard == 9 and lined_up.units[1].guard == 0,
		"A nearby ally should receive the Annealer's Guard.")
	_check(separated.units[2].guard == 0 and _events(separated, "miss", "glass_annealer").size() == 1,
		"A timed Bash should move the ally past the Annealer's reach before Guard resolves.")


func _check_arbalist_and_ram() -> void:
	var far := _fixture([[]], "glass_lens_arbalist")
	var close := _fixture([[]], "glass_lens_arbalist")
	far.units[1].pos = Vector2(600, 265)
	_advance(far, 42)
	_advance(close, 42)
	_check(close.units[0].hp - far.units[0].hp == 7,
		"The arbalist's shot must deal its stated bonus only at long range.")
	var ram := _fixture([[]], "glass_kiln_ram")
	var pushed := _fixture([[_tile("bash", 0)]], "glass_kiln_ram", 31)
	_advance(ram, 28)
	_advance(pushed, 58)
	_check(_events(ram, "push", "glass_kiln_ram").size() == 1 and ram.units[0].impulse.x < 0,
		"The ram should physically knock a hero away at the end of its windup.")
	_check(_events(pushed, "push", "glass_kiln_ram").is_empty() and pushed.units[0].hp == 100,
		"Bash should push the ram beyond the headbutt's reach before it lands.")


func _check_conductor() -> void:
	var adjacent := _fixture([[], []], "glass_shard_conductor")
	var spaced := _fixture([[], []], "glass_shard_conductor")
	spaced.units[1].pos = Vector2(285, 380)
	_advance(adjacent, 39)
	_advance(spaced, 39)
	_check(adjacent.units[0].hp == 92 and adjacent.units[1].hp == 96
		and _events(adjacent, "arc", "glass_shard_conductor").size() == 1,
		"A shock should touch both clustered heroes and emit the second arc.")
	_check(spaced.units[0].hp == 92 and spaced.units[1].hp == 100,
		"A distant second hero should stay out of the shock arc.")


func _check_siphon_and_knight() -> void:
	var siphon := _fixture([[]], "glass_ash_siphon", 11)
	var guarded := _fixture([[_tile("guard", 0)]], "glass_ash_siphon", 11)
	for sim: ArenaSim in [siphon, guarded]:
		sim.units[1].hp -= 12
		_advance(sim, 43)
	_check(_events(siphon, "heal", "glass_ash_siphon").size() == 1 and siphon.units[1].hp == 59,
		"The Siphon should recover only the HP it actually drains.")
	_check(_events(guarded, "heal", "glass_ash_siphon").is_empty() and guarded.units[0].hp == 100,
		"Guard before the Siphon's strike should deny healing.")
	var heating := _fixture([[]], "glass_furnace_knight", 9)
	var cooled := _fixture([[_tile("guard", 0)]], "glass_furnace_knight", 9)
	_advance(heating, 44)
	_advance(cooled, 44)
	_check(heating.units[1].get("furnace_heat", 0) == 1 and cooled.units[1].get("furnace_heat", 0) == 0,
		"Furnace heat should build through HP damage, and Guard should deny the build-up.")
	_advance(heating, 233)
	_check(heating.units[0].hp == 81, "The next knight hit should deal three additional damage.")


func _check_quench() -> void:
	var light := _fixture([[_tile("guard", 0)]], "glass_quench_sentinel", 51)
	var stacked := _fixture([[_tile("guard", 0), _tile("guard", 2)]], "glass_quench_sentinel", 51)
	_advance(light, 85)
	_advance(stacked, 85)
	_check(light.units[0].hp == 96 and stacked.units[0].hp == 100 and stacked.units[0].guard == 6,
		"Quench must remove seven Guard before damage, with enough Guard protecting HP.")


func _fixture(lanes: Array, enemy_id: String, first := 1) -> ArenaSim:
	var heroes: Array[Dictionary] = []
	for _lane in lanes:
		heroes.append({"hero": "warden"})
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", {"encounter": "opening", "heroes": heroes})
	sim.units.resize(lanes.size())
	sim._add_campaign_enemy(enemy_id, Vector2(407, 265))
	for unit: Dictionary in sim.units:
		unit.speed = 0.0
	sim.units.back().next_attack = first
	return sim


func _tile(id: String, start: int, target := "nearest") -> Dictionary:
	return {"id": id, "start": start, "target": target}


func _advance(sim: ArenaSim, tick: int) -> void:
	while sim.tick < tick and sim.outcome.is_empty():
		sim.step()


func _events(sim: ArenaSim, kind: String, tile: String) -> Array:
	return sim.trace.filter(func(event: Dictionary) -> bool: return event.kind == kind and event.tile == tile)


func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)
