extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const CombatMeter = preload("res://scripts/combat_meter.gd")
const CombatTotals = preload("res://scripts/combat_totals.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_damage_and_assists()
	_check_delayed_burn()
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Combat meter ranks actual damage, movement assists, kills, and healing, and restores its saved totals.")
	quit(0 if failures.is_empty() else 1)


func _check_damage_and_assists() -> void:
	var sim := ArenaSim.new()
	sim.start([[], []], "duo")
	var first: Dictionary = sim.units[0]
	var second: Dictionary = sim.units[1]
	var enemy: Dictionary = sim.units[2]
	var other: Dictionary = sim.units[3]
	enemy.hp = 7
	enemy.guard = 2
	sim._damage(first, enemy, 1, "bash")
	sim._damage(first, enemy, 2, "bash")
	sim._displace("pull", first, enemy, "pull", Vector2.LEFT, 560.0)
	sim._displace("pull", first, enemy, "pull", Vector2.LEFT, 560.0)
	sim._damage(second, enemy, 30, "shot")
	other.hp = 6
	sim._damage(first, other, 3, "shot")
	sim._damage(second, other, 2, "shot")
	sim._damage(second, other, 5, "shot", "Splash")
	second.hp = second.max_hp - 3
	sim._restore_mastery_health(first, second, "field_dressing", 9, "Field Dressing")
	sim._emit("heal", "Relic without a source tile", first, first, "tollkeeper_repair_kit", 3)
	sim._emit("guard", "Guard is not healing", first, first, "guard", 10)

	var meter := CombatMeter.new()
	root.add_child(meter)
	meter.hide()
	meter.record(sim.trace, sim.units)
	var damage := meter.totals.ranked("damage")
	_check(damage.size() == 3 and damage[0].tile == "shot" and damage[0].actor == second.id
		and damage[0].damage == 9 and damage[1].tile == "shot" and damage[1].actor == first.id
		and damage[1].damage == 3 and damage[2].damage == 1,
		"Damage should exclude blocked and excess damage, separate heroes and rank highest first.")
	var assists := meter.totals.ranked("assists")
	_check(assists.size() == 3 and assists.all(func(row: Dictionary): return row.actor == first.id and row.assists == 1)
		and assists.any(func(row: Dictionary): return row.tile == "pull"),
		"Each earlier tile should get one assist per kill regardless of repeated movement, with the finishing tile excluded.")
	var kills := meter.totals.ranked("kills")
	_check(kills.size() == 1 and kills[0].kills == 2 and kills[0].actor == second.id,
		"Direct and splash kills should contribute to the same source tile.")
	var healing := meter.totals.ranked("healing")
	_check(healing.size() == 1 and healing[0].healing == 3 and healing[0].actor == first.id,
		"Count actual ally healing and attribute it to the caster's tile.")

	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(meter.snapshot()))
	snapshot.rows.append({"tile": "guard", "class_id": "warden", "lane": 8, "damage": 99})
	snapshot.rows.append({"tile": "guard", "class_id": "warden", "lane": 1, "damage": -99, "kills": "2"})
	meter.reset()
	meter.restore(snapshot)
	meter.set_metric("assists")
	meter.show()
	var ranks: VBoxContainer = meter.find_child("CombatRanks", true, false)
	_check(meter.metric == "assists" and ranks.get_child_count() == 3 and ranks.get_child(0).visible
		and meter.totals.ranked("damage") == damage and meter.totals.ranked("kills") == kills,
		"The meter can track while hidden, restore valid serialized results, and switch rankings.")
	meter.free()


func _check_delayed_burn() -> void:
	var sim := ArenaSim.new()
	sim.start([[]], "solo")
	var hero: Dictionary = sim.units[0]
	var enemy: Dictionary = sim.units[1]
	var tile_id: String = ""
	for id: String in ArenaSim.TILES:
		if ArenaSim.TILES[id].label == "Coal Brand":
			tile_id = id
			break
	_check(not tile_id.is_empty(), "A delayed-burn tile must be available in the fixture.")
	if tile_id.is_empty():
		return
	enemy.hp = 3
	sim._apply_ember_burn(hero, enemy, tile_id, ArenaSim.TILES[tile_id], enemy.pos, false)
	sim.tick += ArenaSim.TICKS_PER_BEAT
	sim._tick_ember_burns(enemy)
	var totals := CombatTotals.new()
	totals.record(sim.trace, sim.units)
	var hits: Array = totals.ranked("damage")
	_check(hits.size() == 1 and hits[0].tile == tile_id and hits[0].damage == 3 and hits[0].kills == 1,
		"Delayed burn must attribute actual damage and the kill to its tile exactly once.")


func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)
