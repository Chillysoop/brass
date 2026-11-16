extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const Repairmaster = preload("res://scripts/brass_repairmaster.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for art_id: String in [Repairmaster.BOSS_ID, Repairmaster.DRONE_ID]:
		var art := GameIcons.enemy_art(art_id)
		_expect(art != null and art.resource_path == "res://assets/combatants/%s.png" % art_id,
			"%s should resolve to its own imported combat sprite." % art_id)
	var view := ArenaView.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(850, 357)
	_check_repair(view, false)
	_check_repair(view, true)
	view.queue_free()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Repairmaster retreat, repair link, and cancellation playback passed.")
	quit(0 if _failures.is_empty() else 1)


func _check_repair(view: ArenaView, interrupt: bool) -> void:
	var sim := ArenaSim.new()
	var lanes := [[], []]
	sim.start(lanes, "duo", {"seed": 42, "encounter": "boss", "location": "brass",
		"segment": 2, "difficulty": "medium", "boss_id": Repairmaster.BOSS_ID,
		"heroes": [{"hero": "warden", "max_hp": 900}, {"hero": "hexwright", "max_hp": 900}]})
	var boss: Dictionary = sim.units[2]
	boss.hp = int(boss.max_hp * 0.65)
	view.reset_view(sim.units, lanes)
	_play_step(sim, view)
	var retreat_until: int = boss.intent_tick
	var drone: Dictionary = sim._find_unit(boss.intent)
	_expect(boss.intent_attack_id == Repairmaster.DASH and not drone.is_empty()
		and view._windups.get(boss.id) == Vector2i(sim.tick, retreat_until)
		and view._windup_details(boss).profile.style == "dash",
		"The retreat warning should start on the sim's selected path and windup clock.")
	if drone.is_empty() or retreat_until <= sim.tick:
		return
	var departure: Vector2 = boss.pos
	while sim.tick < retreat_until and sim.outcome.is_empty():
		_play_step(sim, view)
	var route_record: Dictionary = view._curved_charges.get(boss.id, {})
	var retreats := view._effects.filter(func(effect: Dictionary):
		return effect.kind == "charge" and effect.tile == Repairmaster.DASH)
	var repair_until: int = boss.intent_tick
	_expect(retreats.size() == 1 and not route_record.is_empty()
		and route_record.route[0].is_equal_approx(departure)
		and route_record.route[-1].is_equal_approx(boss.pos)
		and view._positions[boss.id].is_equal_approx(departure),
		"The boss should animate from the actual departure to the landing using one retreat trail.")
	_expect(boss.intent_attack_id == Repairmaster.REPAIR and boss.intent == drone.id
		and view._windups.get(boss.id) == Vector2i(sim.tick, repair_until)
		and view._windup_details(boss).profile.style == "heal",
		"The retreat should hand off immediately to the selected drone's live repair windup.")
	if repair_until <= sim.tick:
		return
	view._process(ArenaView.CURVED_CHARGE_SECONDS + 0.01)
	_expect(view._positions[boss.id].is_equal_approx(boss.pos) and not view._curved_charges.has(boss.id),
		"The retreat animation should settle on the actual battlefield location.")
	var expected_hp: int = boss.hp + Repairmaster.HEAL_AMOUNT
	if interrupt:
		sim._events.clear()
		sim._damage(sim.units[0], boss, Repairmaster.BURST_THRESHOLD, "repairmaster_test")
		view.present(sim.units, sim._events, sim.tick, [], 3)
		expected_hp = boss.hp
		_expect(not view._windups.has(boss.id) and view._effects.any(func(effect: Dictionary):
			return effect.kind == "repair_interrupted" and effect.actor == boss.id and effect.target == drone.id),
			"An actual interruption should clear the repair warning and show the broken link.")
	while sim.tick < repair_until and sim.outcome.is_empty():
		_play_step(sim, view)
	var heals := view._effects.filter(func(effect: Dictionary):
		return effect.kind == "repair_heal" and effect.tile == Repairmaster.REPAIR)
	var repair_windup: bool = view._windups.has(boss.id) and boss.intent_attack_id == Repairmaster.REPAIR
	_expect(boss.hp == expected_hp and not repair_windup,
		"Repair should resolve at tick %d with %d HP (actual %d, active: %s)." % [
			repair_until, expected_hp, boss.hp, repair_windup])
	if interrupt:
		_expect(heals.is_empty(), "An interrupted attempt should never play a heal beam.")
	else:
		_expect(heals.size() == 1 and heals[0].actor == drone.id and heals[0].target == boss.id
			and heals[0].amount == Repairmaster.HEAL_AMOUNT,
			"Completed repair should play one beam in the drone-to-boss direction.")


func _play_step(sim: ArenaSim, view: ArenaView) -> void:
	var events := sim.step()
	view.present(sim.units, events, sim.tick, sim.visual_cues, 3)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
