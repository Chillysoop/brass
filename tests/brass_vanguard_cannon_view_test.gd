extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const BrassVanguardCannon = preload("res://scripts/brass_vanguard_cannon.gd")
const GameIcons = preload("res://scripts/game_icons.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for id: String in [BrassVanguardCannon.VANGUARD, BrassVanguardCannon.CANNON]:
		var art := GameIcons.enemy_art(id)
		_expect(art != null and art.resource_path == "res://assets/sprite_fusion/characters/enemy_%s.png" % id,
			"%s should use its own arena sprite." % id)
	var view := ArenaView.new()
	view.size = Vector2(850, 357)
	root.add_child(view)
	view.set_process(false)
	_check_releases(view)
	_check_interruption(view)
	view.queue_free()
	for failure in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Brass Hard finale windups, charge motion, shell impact, and disruption playback passed.")
	quit(0 if _failures.is_empty() else 1)


func _fixture(view: ArenaView) -> ArenaSim:
	var sim := ArenaSim.new()
	var lanes := [[], [], []]
	sim.start(lanes, "trio", {"seed": 42, "location": "brass", "difficulty": "hard",
		"segment": 3, "encounter": "boss", "boss_id": BrassVanguardCannon.BOSS_ID,
		"heroes": [{"hero": "warden", "max_hp": 950}, {"hero": "hexwright", "max_hp": 950},
			{"hero": "bulwark", "max_hp": 950}]})
	for unit: Dictionary in sim.units:
		if unit.side == "hero":
			unit.speed = 0.0
	view.reset_view(sim.units, lanes)
	return sim


func _check_releases(view: ArenaView) -> void:
	var sim := _fixture(view)
	var windups := {}
	var charge := false
	var shot := false
	while sim.tick < 250 and (not charge or not shot):
		var events := _step(sim, view)
		for event: Dictionary in events:
			if event.kind == "intent" and event.tile in [BrassVanguardCannon.CHARGE, BrassVanguardCannon.SHOT]:
				var enemy := sim._find_unit(event.actor)
				var style := "dash" if event.tile == BrassVanguardCannon.CHARGE else "shot"
				var window := Vector2i(sim.tick, enemy.intent_tick)
				windups[event.tile] = window
				_expect(view._windups.get(event.actor) == window and view._windup_details(enemy).profile.style == style
					and enemy.get("pilot_aim_origin") == event.from and enemy.get("pilot_aim_point") == event.to,
					"%s should show the sim's exact timer, attack family, and locked lane." % event.tile)
			elif event.kind == "charge" and event.tile == BrassVanguardCannon.CHARGE:
				charge = true
				var route: Dictionary = view._curved_charges.get(event.actor, {})
				var enemy := sim._find_unit(event.actor)
				_expect(not route.is_empty() and route.route == event.route and route.route[-1] == enemy.pos
					and view._positions[event.actor] == event.from and not view._windups.has(event.actor),
					"The moving Captain should follow the recorded departure and actual clipped landing.")
			elif event.kind == BrassVanguardCannon.IMPACT:
				shot = true
				var cast: Dictionary = view._actor_casts.get(event.actor, {})
				var impact := func(effect: Dictionary) -> bool:
					return (effect.kind == BrassVanguardCannon.IMPACT and effect.to == event.to
						and effect.radius == event.radius)
				_expect(not cast.is_empty() and cast.tile == BrassVanguardCannon.SHOT
					and cast.to == event.to and view._effects.any(impact) and not view._windups.has(event.actor),
					"The shell trajectory and its blast should share the actual contact point and blast radius.")
		view._process(1.0 / 180.0)
	_expect(windups.size() == 2 and charge and shot, "The live fight should exercise both windups and releases.")


func _check_interruption(view: ArenaView) -> void:
	var sim := _fixture(view)
	var cannon: Dictionary = sim.units.back()
	while sim.tick < 210 and cannon.get("intent_attack_id", "") != BrassVanguardCannon.SHOT:
		_step(sim, view)
	if not view._windups.has(cannon.id):
		_expect(false, "The cannon should be winding up before the interruption check.")
		return
	cannon.pos += Vector2(0.0, -float(cannon.attack.alignment) - 12.0)
	var events := _step(sim, view)
	var interrupted := func(event: Dictionary) -> bool:
		return event.tile == BrassVanguardCannon.DISRUPTED and event.target == cannon.id
	_expect(events.any(interrupted) and view._effects.any(interrupted) and not view._windups.has(cannon.id)
		and not view._actor_casts.has(cannon.id),
		"Disruption should clear the cannon lane and leave an interrupt cue at the actual boss.")


func _step(sim: ArenaSim, view: ArenaView) -> Array[Dictionary]:
	var events := sim.step()
	view.present(sim.units, events, sim.tick, sim.visual_cues, 3)
	return events


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
