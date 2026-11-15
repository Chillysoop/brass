extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var styles := {}
	var profiles := {}
	for id: String in ArenaSim.TILES:
		var profile := HeroChoreography.profile(id, ArenaSim.TILES[id])
		profiles[JSON.stringify(profile)] = true
		styles[profile.style] = true
	_expect(profiles.size() == ArenaSim.TILES.size(), "Every tile must have its own profile, including forge upgrades.")
	_expect(styles.size() >= 12, "Tiles should vary in shape and pose as well as color.")
	_expect(HeroChoreography.profile("bash", ArenaSim.TILES.bash).style == "thrust"
		and HeroChoreography.profile("slam", ArenaSim.TILES.slam).style == "heavy"
		and HeroChoreography.profile("rail_shot", ArenaSim.TILES.rail_shot).style == "bolt", "Core attacks need distinct animation families.")

	var view := ArenaView.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(850, 357)
	var sim := ArenaSim.new()
	var lanes := [[{"id": "shot", "start": 1, "target": "nearest"}]]
	sim.start(lanes, "solo", {"kind": "opening"})
	view.reset_view(sim.units, lanes)
	var hero: Dictionary = sim.units[0]
	var fire_tick := ArenaSim.TICKS_PER_BEAT * 3
	for _i in range(fire_tick - 1):
		var events := sim.step()
		view.present(sim.units, events, sim.tick, sim.visual_cues)
	_expect(not view._windup_details(hero).is_empty() and not view._actor_casts.has(hero.id),
		"At the tick before the tile's right edge the hero is still preparing.")
	var events := sim.step()
	view.present(sim.units, events, sim.tick, sim.visual_cues)
	_expect(view._actor_casts.has(hero.id) and view._actor_casts[hero.id].tile == "shot"
		and view._actor_casts[hero.id].profile.style == "shot" and view._windup_details(hero).is_empty(),
		"The shot's animation must reach the view on the exact right edge.")
	view._process(1.0)
	_expect(view._attack_casts.is_empty() and view._actor_casts.is_empty(), "Expired effects must release every sprite pose.")

	var queued: Array = sim.visual_cues.duplicate()
	view.present(sim.units, [], sim.tick, queued)
	view.reset_view(sim.units, lanes)
	_expect(view._attack_casts.is_empty() and view._actor_casts.is_empty() and view._windups.is_empty(),
		"Reset must clear the old attack effects and windups.")
	view.queue_free()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("All %d tile animation profiles and exact-edge arena playback passed." % ArenaSim.TILES.size())
	quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
